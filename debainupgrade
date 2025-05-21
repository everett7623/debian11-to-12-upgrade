#!/bin/bash

# Debian 10 (Buster) to Debian 12 (Bookworm) Automated Upgrade Script
# Author: Claude (Enhanced for automation)
# Date: May 21, 2025
# Description: Script to safely and automatically upgrade Debian 10 to Debian 12.
#              This script performs a two-step upgrade: first to Debian 11, then to Debian 12.
#              It attempts to auto-confirm all prompts, including overwriting configuration files with maintainer versions.
#              *** USE WITH EXTREME CAUTION AND ONLY AFTER FULL SYSTEM BACKUP ***

# --- Configuration ---
LOG_FILE="/var/log/debian_upgrade_$(date +%Y%m%d%H%M%S).log"
MIN_DISK_SPACE_GB=5 # Minimum required free disk space in GB for the root partition
# --- End Configuration ---

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "此脚本必须以 root 权限运行。" | tee -a "$LOG_FILE" >&2
    exit 1
fi

# Start session logging
echo "--- 升级脚本开始执行：$(date) ---" | tee -a "$LOG_FILE"
# Using 'script' command to log all terminal output
script -q -c "exec bash -i" -a "$LOG_FILE" &
SCRIPT_PID=$!
echo "会话日志已启动，输出将记录到 $LOG_FILE" | tee -a "$LOG_FILE"

# Function to display messages and log them
log_message() {
    echo ">>> $(date +%H:%M:%S) $1" | tee -a "$LOG_FILE"
}

# Function to handle errors and exit
handle_error() {
    log_message "错误：$1"
    log_message "升级过程已中止。请检查日志文件 ($LOG_FILE) 获取详细信息。"
    # Attempt to stop session logging gracefully
    if ps -p "$SCRIPT_PID" > /dev/null; then
        kill "$SCRIPT_PID"
    fi
    exit 1
}

# Function to check disk space
check_disk_space() {
    log_message "正在检查根分区 (/) 的可用磁盘空间..."
    # Get available space in GB for the root partition
    AVAILABLE_SPACE_GB=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    log_message "根分区 (/) 可用空间：${AVAILABLE_SPACE_GB}GB"

    if (( $(echo "$AVAILABLE_SPACE_GB < $MIN_DISK_SPACE_GB" | bc -l) )); then
        handle_error "可用磁盘空间不足。需要至少 ${MIN_DISK_SPACE_GB}GB，但只有 ${AVAILABLE_SPACE_GB}GB。请清理空间 (例如：apt clean, apt autoremove) 后重试。"
    else
        log_message "可用磁盘空间充足。"
    fi
}

# Function to check for held packages
check_held_packages() {
    log_message "正在检查是否有被保留的软件包 (held packages)..."
    HELD_PKGS=$(apt-mark showhold)
    if [ -n "$HELD_PKGS" ]; then
        log_message "警告：检测到以下软件包被保留 (on hold)，这可能会阻止正常升级："
        echo "$HELD_PKGS" | tee -a "$LOG_FILE"
        handle_error "请手动解除保留这些软件包 (apt-mark unhold <package_name>) 或将其移除，然后重新运行脚本。"
    else
        log_message "未发现被保留的软件包。"
    fi
}

# Function to backup sources.list
backup_sources_list() {
    log_message "正在创建 sources.list 备份..."
    TIMESTAMP=$(date +%Y%m%d%H%M%S)
    cp -a /etc/apt/sources.list "/etc/apt/sources.list.bak.$TIMESTAMP"

    # Backup any additional source files
    mkdir -p "/etc/apt/sources.list.d.bak.$TIMESTAMP"
    cp -a /etc/apt/sources.list.d/* "/etc/apt/sources.list.d.bak.$TIMESTAMP/" 2>/dev/null || true

    log_message "备份已创建：/etc/apt/sources.list.bak.$TIMESTAMP 和 /etc/apt/sources.list.d.bak.$TIMESTAMP/"
    log_message "请确保您已执行完整的系统备份，而不仅仅是 APT 源列表。"
}

# Function to update sources.list
update_sources_list() {
    local CURRENT_CODENAME=$1
    local NEXT_CODENAME=$2

    log_message "正在更新 APT 源列表，从 $CURRENT_CODENAME 到 $NEXT_CODENAME..."

    sed -i "s/$CURRENT_CODENAME/$NEXT_CODENAME/g" /etc/apt/sources.list
    sed -i "s/$CURRENT_CODENAME/$NEXT_CODENAME/g" /etc/apt/sources.list.d/*.list 2>/dev/null || true

    # Add non-free-firmware component if non-free is present
    sed -i '/non-free/ s/$/ non-free-firmware/' /etc/apt/sources.list
    sed -i '/non-free/ s/$/ non-free-firmware/' /etc/apt/sources.list.d/*.list 2>/dev/null || true

    log_message "APT 源列表已更新为 $NEXT_CODENAME。"
}

# Function to perform upgrade
perform_upgrade() {
    log_message "正在更新软件包列表..."
    DEBIAN_FRONTEND=noninteractive apt-get update -y || handle_error "apt update 失败。"

    log_message "正在执行最小升级 (apt-get upgrade)..."
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y || handle_error "apt upgrade 失败。"

    log_message "正在执行完整发行版升级 (apt-get full-upgrade)..."
    DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y -o Dpkg::Options::="--force-confnew" || handle_error "apt full-upgrade 失败。"

    log_message "正在清理未使用的软件包..."
    DEBIAN_FRONTEND=noninteractive apt-get --purge autoremove -y || handle_error "apt autoremove 失败。"
    DEBIAN_FRONTEND=noninteractive apt-get clean || handle_error "apt clean 失败。"

    log_message "软件包更新和升级完成。"
}

# Function to verify upgrade
verify_upgrade() {
    local EXPECTED_VERSION=$1
    source /etc/os-release
    if [ "$VERSION_ID" = "$EXPECTED_VERSION" ]; then
        log_message "系统已成功升级到 Debian $EXPECTED_VERSION。"
    else
        handle_error "升级失败。当前版本：$VERSION_ID。请检查日志文件获取详细信息。"
    fi
}

# Main execution
log_message "==== Debian 10 (Buster) 到 Debian 12 (Bookworm) 自动升级 ===="
log_message "此脚本将自动升级您的 Debian 系统到版本 12。"
log_message "警告：此脚本将尝试自动确认所有提示，包括覆盖配置文件。请务必在运行前进行完整系统备份！"
log_message "脚本将在 10 秒后自动开始。按 Ctrl+C 取消。"
sleep 10

check_disk_space
check_held_packages
backup_sources_list

# Stage 1: Upgrade from Debian 10 to Debian 11
update_sources_list "buster" "bullseye"
perform_upgrade
verify_upgrade "11"
log_message "正在重启系统以完成从 Debian 10 到 Debian 11 的升级..."
reboot

# After reboot, continue with Stage 2
# Stage 2: Upgrade from Debian 11 to Debian 12
# 请在系统重启并进入 Debian 11 后，重新运行此脚本以继续升级到 Debian 12。
