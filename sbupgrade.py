#!/usr/bin/env python3

import os
import shutil
import subprocess
import sys
import glob

def create_mount_point(mount_point):
    if not os.path.exists(mount_point):
        try:
            os.makedirs(mount_point)
            print(f"Created mount point: {mount_point}")
        except OSError as e:
            print(f"Error creating mount point directory: {e}")
            sys.exit(1)

def mount_usb(drive_path, mount_point):
    create_mount_point(mount_point)
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

def backup_data(source_folder, backup_folder):
    try:
        shutil.copytree(source_folder, backup_folder)
        print(f"Backed up data from {source_folder} to {backup_folder}")
    except Exception as e:
        print(f"Error backing up data: {e}")
        sys.exit(1)

def restore_data(backup_folder, target_folder):
    try:
        shutil.copytree(backup_folder, target_folder, dirs_exist_ok=True)
        print(f"Restored data from {backup_folder} to {target_folder}")
    except Exception as e:
        print(f"Error restoring data: {e}")
        sys.exit(1)

def flash_os(image_path, target_drive):
    try:
        subprocess.run(['sudo', 'dd', f'if={image_path}', f'of={target_drive}', 'bs=4M', 'conv=fsync'], check=True)
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
    usb_drive = '/dev/sda1'  # Replace with the actual USB drive path
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
    print("\nProcess completed. Please remove the USB device and power cycle the Raspberry Pi using the power switch.")

if __name__ == "__main__":
    main()
