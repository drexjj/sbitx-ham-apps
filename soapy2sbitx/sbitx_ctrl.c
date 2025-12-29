/* sbitx_ctrl.c - simple TCP control for sBitx core (freq + PTT)
 *
 * Listens on 127.0.0.1:9999
 *
 * Commands (one per line):
 *   f              -> print frequency (Hz)
 *   F <hz>         -> set frequency (Hz), reply "OK <hz>"
 *   t              -> print ptt state (0 RX, 1 TX)
 *   T <0|1>         -> set ptt state, reply "OK <0|1>"
 */

#define _GNU_SOURCE
#include <arpa/inet.h>
#include <errno.h>
#include <inttypes.h>
#include <netinet/in.h>
#include <pthread.h>
#include <signal.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

#include "sbitx_core.h"

static volatile int g_shutdown = 0;

static radio g_radio;
static pthread_mutex_t g_lock = PTHREAD_MUTEX_INITIALIZER;

// Keep our own "current frequency" so we can answer quickly and consistently.
static uint32_t g_freq_hz = 7100000; // default
static int g_ptt_tx = 0;            // 0=RX, 1=TX

static void on_sigint(int sig) {
  (void)sig;
  g_shutdown = 1;
}

static void replyf(FILE *fp, const char *fmt, ...) {
  va_list ap;
  va_start(ap, fmt);
  vfprintf(fp, fmt, ap);
  va_end(ap);
  fflush(fp);
}

static void do_set_freq(uint32_t hz) {
  pthread_mutex_lock(&g_lock);
  g_freq_hz = hz;
  set_frequency(&g_radio, g_freq_hz);
  pthread_mutex_unlock(&g_lock);
}

static uint32_t do_get_freq(void) {
  pthread_mutex_lock(&g_lock);
  uint32_t hz = g_freq_hz;
  pthread_mutex_unlock(&g_lock);
  return hz;
}

static void do_set_ptt(int tx) {
  pthread_mutex_lock(&g_lock);
  g_ptt_tx = tx ? 1 : 0;
  tr_switch(&g_radio, g_ptt_tx ? IN_TX : IN_RX);
  pthread_mutex_unlock(&g_lock);
}

static int do_get_ptt(void) {
  pthread_mutex_lock(&g_lock);
  int tx = g_ptt_tx;
  pthread_mutex_unlock(&g_lock);
  return tx;
}

static void *client_thread(void *arg) {
  int fd = (int)(intptr_t)arg;
  FILE *fp = fdopen(fd, "r+");
  if (!fp) {
    close(fd);
    return NULL;
  }

  char line[256];
  while (!g_shutdown && fgets(line, sizeof(line), fp)) {
    // trim newline
    size_t n = strlen(line);
    while (n && (line[n - 1] == '\n' || line[n - 1] == '\r'))
      line[--n] = 0;

    // ignore empty
    if (n == 0)
      continue;

    // Commands:
    // f
    // F <hz>
    // t
    // T <0|1>

    if (line[0] == 'f' && line[1] == 0) {
      uint32_t hz = do_get_freq();
      replyf(fp, "%u\n", hz);
      continue;
    }

    if (line[0] == 'F') {
      // allow "F14234000" or "F 14234000"
      const char *p = line + 1;
      while (*p == ' ' || *p == '\t')
        p++;
      if (*p == 0) {
        replyf(fp, "ERR missing\n");
        continue;
      }
      uint32_t hz = (uint32_t)strtoul(p, NULL, 10);
      if (hz < 100000 || hz > 600000000) {
        replyf(fp, "ERR range\n");
        continue;
      }
      do_set_freq(hz);
      replyf(fp, "OK %u\n", hz);
      continue;
    }

    if (line[0] == 't' && line[1] == 0) {
      replyf(fp, "%d\n", do_get_ptt());
      continue;
    }

    if (line[0] == 'T') {
      const char *p = line + 1;
      while (*p == ' ' || *p == '\t')
        p++;
      if (*p != '0' && *p != '1') {
        replyf(fp, "ERR arg\n");
        continue;
      }
      int tx = (*p == '1') ? 1 : 0;
      do_set_ptt(tx);
      replyf(fp, "OK %d\n", tx);
      continue;
    }

    replyf(fp, "ERR unknown\n");
  }

  fclose(fp); // closes fd
  return NULL;
}

int main(int argc, char **argv) {
  (void)argc;
  (void)argv;

  signal(SIGINT, on_sigint);

  memset(&g_radio, 0, sizeof(g_radio));
  // These must match your working "simple radio" app:
  strcpy(g_radio.i2c_device, "/dev/i2c-22");
  g_radio.bfo_frequency = 40035000;
  g_radio.bridge_compensation = 100;

  hw_init(&g_radio);

  // Start in RX
  do_set_ptt(0);
  // Set initial freq
  do_set_freq(g_freq_hz);

  int listen_fd = socket(AF_INET, SOCK_STREAM, 0);
  if (listen_fd < 0) {
    perror("socket");
    return 1;
  }

  int one = 1;
  setsockopt(listen_fd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one));

  struct sockaddr_in addr;
  memset(&addr, 0, sizeof(addr));
  addr.sin_family = AF_INET;
  addr.sin_port = htons(9999);
  inet_pton(AF_INET, "127.0.0.1", &addr.sin_addr);

  if (bind(listen_fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
    perror("bind");
    close(listen_fd);
    return 1;
  }

  if (listen(listen_fd, 8) < 0) {
    perror("listen");
    close(listen_fd);
    return 1;
  }

  printf("sbitx_ctrl listening on 127.0.0.1:9999\n");
  fflush(stdout);

  while (!g_shutdown) {
    int fd = accept(listen_fd, NULL, NULL);
    if (fd < 0) {
      if (errno == EINTR)
        continue;
      perror("accept");
      continue;
    }
    pthread_t th;
    pthread_create(&th, NULL, client_thread, (void *)(intptr_t)fd);
    pthread_detach(th);
  }

  close(listen_fd);

  // Always leave radio in RX
  do_set_ptt(0);
  hw_shutdown(&g_radio);

  return 0;
}
