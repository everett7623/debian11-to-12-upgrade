#!/bin/bash

# Debian 11 (Bullseye) to Debian 12 (Bookworm) Upgrade Script
# Author: Claude
# Date: May 21, 2025
# Description: Script to safely upgrade Debian 11 to Debian 12

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

# Function to detect current Debian version
check_debian_version() {
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        if [[ "$ID" != "debian" ]]; then
            echo "This script is only for Debian systems."
            exit 1
        fi
        echo "Current Debian version: $VERSION_ID ($VERSION_CODENAME)"
        if [[ "$VERSION_ID" == "12" ]]; then
            echo "System is already running Debian 12. No upgrade needed."
            exit 0
        elif [[ "$VERSION_ID" != "11" ]]; then
            echo "Warning: This script is designed to upgrade from Debian 11 to 12."
            echo "Your system is running Debian $VERSION_ID."
            read -p "Do you want to continue anyway? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    else
        echo "Cannot determine OS version. Make sure you're running Debian."
        exit 1
    fi
}

# Function to create backup of sources.list
backup_sources_list() {
    echo "Creating backup of sources.list..."
    cp /etc/apt/sources.list /etc/apt/sources.list.bullseye.bak
    
    # Backup any additional source files
    mkdir -p /etc/apt/sources.list.d.bak
    cp -r /etc/apt/sources.list.d/* /etc/apt/sources.list.d.bak/ 2>/dev/null || true
    
    echo "Backup created at /etc/apt/sources.list.bullseye.bak"
}

# Function to update package repositories to Debian 12
update_sources_list() {
    echo "Updating package repositories to Debian 12 (Bookworm)..."
    
    # Update main sources.list file
    sed -i 's/bullseye/bookworm/g' /etc/apt/sources.list
    
    # Update any additional source files
    find /etc/apt/sources.list.d/ -type f -name "*.list" -exec sed -i 's/bullseye/bookworm/g' {} \;
    
    echo "Repository sources updated to Bookworm."
}

# Function to update and upgrade packages
update_and_upgrade() {
    echo "Updating package lists..."
    apt update
    
    echo "Performing minimal upgrade..."
    apt upgrade -y
    
    echo "Performing full distribution upgrade..."
    apt full-upgrade -y
    
    echo "Cleaning up unused packages..."
    apt --purge autoremove -y
    apt clean
}

# Function to check for held packages
check_held_packages() {
    echo "Checking for held packages..."
    HELD_PKGS=$(apt-mark showhold)
    if [ -n "$HELD_PKGS" ]; then
        echo "Warning: The following packages are on hold and may prevent a proper upgrade:"
        echo "$HELD_PKGS"
        read -p "Do you want to continue anyway? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        echo "No held packages found."
    fi
}

# Main execution
echo "==== Debian 11 (Bullseye) to Debian 12 (Bookworm) Upgrade ===="
echo
echo "This script will upgrade your Debian system to version 12."
echo "Make sure you have a full backup before proceeding."
echo
read -p "Continue with the upgrade? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Execute the upgrade process
check_debian_version
check_held_packages
backup_sources_list
update_sources_list
update_and_upgrade

# Verify the upgrade was successful
source /etc/os-release
if [[ "$VERSION_ID" == "12" ]]; then
    echo "========================================================"
    echo "Upgrade completed successfully!"
    echo "Your system is now running Debian 12 (Bookworm)."
    echo "It's recommended to reboot your system."
    echo "========================================================"
    read -p "Would you like to reboot now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        reboot
    fi
else
    echo "Upgrade seems incomplete. Current version: $VERSION_ID"
    echo "Check /etc/os-release and system status manually."
fi
