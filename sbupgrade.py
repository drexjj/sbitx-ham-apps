#!/usr/bin/env python3

import os
import shutil
import subprocess
import sys
import glob
import logging
from pathlib import Path
import time  # Import the time module

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

class Colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

def clear_screen():
    os.system('cls' if os.name == 'nt' else 'clear')

def print_header():
    clear_screen()
    print(f"{Colors.HEADER}{Colors.BOLD}")
    print("#####################################################")
    print("#            JJ's sBitx OS Flash Utility            #")
    print("#####################################################")
    print(f"{Colors.ENDC}")

def create_mount_point(mount_point):
    try:
        mount_point.mkdir(parents=True, exist_ok=True)
        logging.info(f"Mount point created at {mount_point}")
    except OSError as e:
        logging.error(f"Error creating mount point: {e}")
        sys.exit(1)

def is_mounted(drive_path):
    try:
        output = subprocess.check_output(['mount']).decode('utf-8')
        return any(drive_path in line for line in output.splitlines())
    except subprocess.CalledProcessError as e:
        logging.error(f"Error checking mount status: {e}")
        return False

def unmount_drive(drive_path):
    try:
        subprocess.run(['sudo', 'umount', drive_path], check=True)
        logging.info(f"Unmounted {drive_path}")
    except subprocess.CalledProcessError as e:
        logging.error(f"Error unmounting drive: {e}")
        sys.exit(1)

def mount_usb(drive_path, mount_point):
    create_mount_point(mount_point)
    if is_mounted(drive_path):
        unmount_drive(drive_path)
        time.sleep(2)  # Added delay for remount
    try:
        subprocess.run(['sudo', 'mount', drive_path, str(mount_point)], check=True)
        logging.info(f"Mounted {drive_path} to {mount_point}")
    except subprocess.CalledProcessError as e:
        logging.error(f"Error mounting USB drive: {e}")
        sys.exit(1)

def unmount_usb(mount_point):
    try:
        subprocess.run(['sudo', 'umount', str(mount_point)], check=True)
        logging.info(f"Unmounted {mount_point}")
    except subprocess.CalledProcessError as e:
        logging.error(f"Error unmounting USB drive: {e}")

def manual_progress_bar(progress, total, bar_length=50):
    percent = float(progress) / total
    arrow = '=' * int(round(percent * bar_length) - 1) + '>'
    spaces = ' ' * (bar_length - len(arrow))
    print(f"\rProgress: [{arrow + spaces}] {int(round(percent * 100))}%", end='')

def copy_with_progress(source, destination):
    source = Path(source)
    destination = Path(destination)
    
    total_size = 0
    for root, _, files in os.walk(source):
        for file in files:
            src_file = os.path.join(root, file)
            total_size += os.path.getsize(src_file)
    
    if total_size == 0:
        logging.error(f"Total size of files to copy is zero. Source directory might be empty: {source}")
        sys.exit(1)
    
    logging.info(f"Total size to copy: {total_size} bytes")

    copied_size = 0
    for root, _, files in os.walk(source):
        for file in files:
            src_file = os.path.join(root, file)
            dst_file = os.path.join(destination, os.path.relpath(src_file, source))
            os.makedirs(os.path.dirname(dst_file), exist_ok=True)
            shutil.copy2(src_file, dst_file)
            copied_size += os.path.getsize(src_file)
            manual_progress_bar(copied_size, total_size)
    print("\nCopy completed.")

def backup_data(source_folder, backup_folder):
    try:
        copy_with_progress(source_folder, backup_folder)
        logging.info(f"Backed up data from {source_folder} to {backup_folder}")
    except Exception as e:
        logging.error(f"Error backing up data: {e}")
        sys.exit(1)

def restore_data(backup_folder, target_folder):
    try:
        copy_with_progress(backup_folder, target_folder)
        logging.info(f"Restored data from {backup_folder} to {target_folder}")
    except Exception as e:
        logging.error(f"Error restoring data: {e}")
        sys.exit(1)

def flash_os(image_path, target_drive):
    image_size = os.path.getsize(image_path)
    dd_command = ['sudo', 'dd', f'if={image_path}', f'of={target_drive}', 'bs=4M', 'conv=fsync']
    try:
        with subprocess.Popen(dd_command, stderr=subprocess.PIPE) as process:
            copied_size = 0
            while True:
                output = process.stderr.read(1024)
                if output == b'' and process.poll() is not None:
                    break
                if output:
                    copied_size += len(output)
                    manual_progress_bar(copied_size, image_size)
        print("\nFlashing completed successfully.")
    except subprocess.CalledProcessError as e:
        logging.error(f"Error flashing OS: {e}")
        sys.exit(1)

def find_image(mount_point):
    images = glob.glob(str(mount_point / '*.img'))
    if not images:
        logging.error(f"No .img file found in {mount_point}")
        sys.exit(1)
    return images[0]

def main():
    print_header()
    usb_drive = '/dev/sda1'
    mount_point = Path('/mnt/usb')
    internal_drive = '/dev/mmcblk0'

    data_folder = Path('/home/pi/sbitx/data')
    backup_folder = mount_point / 'data_backup'

    # Mount the USB drive
    mount_usb(usb_drive, mount_point)

    # Find the image file
    os_image_path = find_image(mount_point)
    logging.info(f"Found image file: {os_image_path}")

    # Backup the data folder
    backup_data(data_folder, backup_folder)

    # Flash the OS image to the internal drive
    flash_os(os_image_path, internal_drive)

    # Remount the USB drive to restore data
    mount_usb(usb_drive, mount_point)

    # Restore the data folder
    restore_data(backup_folder, data_folder)

    # Unmount the USB drive
    #unmount_usb(mount_point)

    # Final instructions to the user
    logging.info("Process completed successfully.")
    input("Please remove the USB device and press the ENTER key to reboot.")
    os.system('sudo reboot')

if __name__ == "__main__":
    main()
