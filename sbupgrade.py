#!/usr/bin/env python3

import os
import shutil
import subprocess
import sys
import glob
import time

def create_mount_point(mount_point):
    if not os.path.exists(mount_point):
        try:
            os.makedirs(mount_point)
            print(f"Created mount point: {mount_point}")
        except OSError as e:
            print(f"Error creating mount point directory: {e}")
            sys.exit(1)

def is_mounted(drive_path):
    try:
        output = subprocess.check_output(['mount']).decode('utf-8')
        return any(drive_path in line for line in output.splitlines())
    except subprocess.CalledProcessError as e:
        print(f"Error checking mount status: {e}")
        return False

def unmount_drive(drive_path):
    try:
        subprocess.run(['sudo', 'umount', drive_path], check=True)
        print(f"Unmounted {drive_path}")
    except subprocess.CalledProcessError as e:
        print(f"Error unmounting drive: {e}")
        sys.exit(1)

def mount_usb(drive_path, mount_point):
    create_mount_point(mount_point)
    if is_mounted(drive_path):
        unmount_drive(drive_path)
    try:
        subprocess.run(['sudo', 'mount', drive_path, mount_point], check=True)
        print(f"Mounted {drive_path} to {mount_point}")
    except subprocess.CalledProcessError as e:
        print(f"Error mounting USB drive: {e}")
        sys.exit(1)

def unmount_usb(mount_point):
    try:
        subprocess.run(['sudo', 'umount', mount_point], check=True)
        print(f"Unmounted {mount_point}")
    except subprocess.CalledProcessError as e:
        print(f"Error unmounting USB drive: {e}")

def manual_progress_bar(progress, total, bar_length=50):
    percent = float(progress) / total
    arrow = '-' * int(round(percent * bar_length) - 1) + '>'
    spaces = ' ' * (bar_length - len(arrow))
    print(f"\rProgress: [{arrow + spaces}] {int(round(percent * 100))}%", end='')

def copy_with_progress(source, destination):
    """Copies files with a manual progress bar."""
    total_size = sum(os.path.getsize(f) for f in glob.glob(os.path.join(source, '**', '*'), recursive=True) if os.path.isfile(f))
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
        print(f"Backed up data from {source_folder} to {backup_folder}")
    except Exception as e:
        print(f"Error backing up data: {e}")
        sys.exit(1)

def restore_data(backup_folder, target_folder):
    try:
        copy_with_progress(backup_folder, target_folder)
        print(f"Restored data from {backup_folder} to {target_folder}")
    except Exception as e:
        print(f"Error restoring data: {e}")
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
        print(f"Error flashing OS: {e}")
        sys.exit(1)

def find_image(mount_point):
    images = glob.glob(os.path.join(mount_point, '*.img'))
    if not images:
        print(f"No .img file found in {mount_point}")
        sys.exit(1)
    return images[0]

def main():
    usb_drive = '/dev/sda1'
    mount_point = '/mnt/usb'
    internal_drive = '/dev/mmcblk0'

    data_folder = '/home/pi/sbitx/data'
    backup_folder = '/mnt/usb/data_backup'

    # Mount the USB drive
    mount_usb(usb_drive, mount_point)

    # Find the image file
    os_image_path = find_image(mount_point)
    print(f"Found image file: {os_image_path}")

    # Backup the data folder
    backup_data(data_folder, backup_folder)

    # Flash the OS image to the internal drive
    flash_os(os_image_path, internal_drive)

    # Remount the USB drive to restore data
    mount_usb(usb_drive, mount_point)

    # Restore the data folder
    restore_data(backup_folder, data_folder)

    # Unmount the USB drive
    unmount_usb(mount_point)

    # Final instructions to the user
    print("\nProcess completed. Please remove the USB storage device and power cycle the Raspberry Pi using the power switch.")

if __name__ == "__main__":
    main()
