#!/bin/bash

# Debian 11 (Bullseye) to Debian 12 (Bookworm) Automated Upgrade Script
# Author: Claude (Enhanced for automation)
# Date: May 21, 2025
# Description: Script to safely and automatically upgrade Debian 11 to Debian 12.
#              This script attempts to auto-confirm all prompts, including
#              overwriting configuration files with maintainer versions.
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
    kill "$SCRIPT_PID" # Stop session logging
    exit 1
}

# Function to detect current Debian version
check_debian_version() {
    log_message "正在检查当前 Debian 版本..."
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        if]; then
            handle_error "此脚本仅适用于 Debian 系统。检测到操作系统为 $ID。"
        fi
        log_message "当前 Debian 版本：$VERSION_ID ($VERSION_CODENAME)"
        if]; then
            log_message "系统已运行 Debian 12。无需升级。"
            kill "$SCRIPT_PID" # Stop session logging
            exit 0
        elif]; then
            handle_error "此脚本设计用于从 Debian 11 升级到 12。您的系统运行的是 Debian $VERSION_ID。请手动确认或调整脚本。"
        fi
    else
        handle_error "无法确定操作系统版本。请确保您正在运行 Debian。"
    fi
}

# Function to check for held packages
check_held_packages() {
    log_message "正在检查是否有被保留的软件包 (held packages)..."
    HELD_PKGS=$(apt-mark showhold)
    if; then
        log_message "警告：检测到以下软件包被保留 (on hold)，这可能会阻止正常升级："
        echo "$HELD_PKGS" | tee -a "$LOG_FILE"
        handle_error "请手动解除保留这些软件包 (apt-mark unhold <package_name>) 或将其移除，然后重新运行脚本。"
    else
        log_message "未发现被保留的软件包。"
    fi
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

# Function to identify and warn about third-party repositories
check_third_party_repos() {
    log_message "正在检查第三方 APT 仓库..."
    THIRD_PARTY_REPOS=$(find /etc/apt/sources.list.d/ -type f -name "*.list" -print)
    if; then
        log_message "警告：检测到以下第三方 APT 仓库文件。这些仓库可能与 Debian 12 不兼容，并可能导致升级失败或问题。强烈建议在升级前手动审查并禁用它们（通过注释掉或移动文件），待升级完成后再逐一启用并验证兼容性。"
        echo "$THIRD_PARTY_REPOS" | tee -a "$LOG_FILE"
        log_message "请手动处理这些仓库，然后重新运行脚本。如果确定要继续，请注释掉此检查函数。"
        # For full automation, you might comment out the next line, but it's risky.
        handle_error "检测到第三方仓库。请手动处理。"
    else
        log_message "未发现第三方 APT 仓库文件。"
    fi
}

# Function to create backup of sources.list
backup_sources_list() {
    log_message "正在创建 sources.list 备份..."
    TIMESTAMP=$(date +%Y%m%d%H%M%S)
    cp -a /etc/apt/sources.list "/etc/apt/sources.list.bullseye.bak.$TIMESTAMP"
    
    # Backup any additional source files
    mkdir -p "/etc/apt/sources.list.d.bak.$TIMESTAMP"
    cp -a /etc/apt/sources.list.d/* "/etc/apt/sources.list.d.bak.$TIMESTAMP/" 2>/dev/null |
| true
    
    log_message "备份已创建：/etc/apt/sources.list.bullseye.bak.$TIMESTAMP 和 /etc/apt/sources.list.d.bak.$TIMESTAMP/"
    log_message "请确保您已执行完整的系统备份，而不仅仅是 APT 源列表。"
}

# Function to update package repositories to Debian 12
update_sources_list() {
    log_message "正在更新软件包仓库到 Debian 12 (Bookworm)..."
    
    # Update main sources.list file
    sed -i 's/bullseye/bookworm/g' /etc/apt/sources.list
    # Add non-free-firmware component if non-free is present
    # This sed command appends ' non-free-firmware' to lines containing 'non-free'
    sed -i '/non-free/ s/$/ non-free-firmware/' /etc/apt/sources.list
    
    # Update any additional source files in sources.list.d/
    find /etc/apt/sources.list.d/ -type f -name "*.list" -exec sed -i 's/bullseye/bookworm/g' {} \;
    find /etc/apt/sources.list.d/ -type f -name "*.list" -exec sed -i '/non-free/ s/$/ non-free-firmware/' {} \;
    
    log_message "仓库源已更新到 Bookworm，并已尝试添加 non-free-firmware 组件。"
    log_message "请手动检查 /etc/apt/sources.list 和 /etc/apt/sources.list.d/ 确保正确。"
}

# Function to update and upgrade packages
update_and_upgrade() {
    log_message "正在更新软件包列表..."
    # Use apt-get for scripting stability and DEBIAN_FRONTEND=noninteractive for automated prompts
    DEBIAN_FRONTEND=noninteractive apt-get update -y |
| handle_error "apt update 失败。"
    
    log_message "正在执行最小升级 (apt-get upgrade)..."
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y |
| handle_error "apt upgrade 失败。"
    
    log_message "正在执行完整发行版升级 (apt-get full-upgrade)..."
    # --force-confnew: Automatically accept new configuration files, overwriting local changes.
    DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y -o Dpkg::Options::="--force-confnew" |
| handle_error "apt full-upgrade 失败。"
    
    log_message "正在清理未使用的软件包..."
    DEBIAN_FRONTEND=noninteractive apt-get --purge autoremove -y |
| handle_error "apt autoremove 失败。"
    DEBIAN_FRONTEND=noninteractive apt-get clean |
| handle_error "apt clean 失败。"
    
    log_message "软件包更新和升级完成。"
}

# Main execution
log_message "==== Debian 11 (Bullseye) 到 Debian 12 (Bookworm) 自动升级 ===="
log_message "此脚本将自动升级您的 Debian 系统到版本 12。"
log_message "警告：此脚本将尝试自动确认所有提示，包括覆盖配置文件。请务必在运行前进行完整系统备份！"
log_message "脚本将在 10 秒后自动开始。按 Ctrl+C 取消。"
sleep 10

# Execute the upgrade process
check_debian_version
check_held_packages
check_disk_space
# check_third_party_repos # 强烈建议启用此行并手动处理第三方仓库

backup_sources_list
update_sources_list
update_and_upgrade

# Verify the upgrade was successful
log_message "正在验证升级是否成功..."
source /etc/os-release
if]; then
    log_message "========================================================"
    log_message "升级成功完成！"
    log_message "您的系统现在运行 Debian 12 (Bookworm)。"
    log_message "强烈建议立即重启系统以应用所有更改。"
    log_message "========================================================"
    log_message "系统将在 10 秒后自动重启。按 Ctrl+C 取消重启。"
    sleep 10
    log_message "正在重启系统..."
    reboot
else
    handle_error "升级似乎不完整。当前版本：$VERSION_ID。请手动检查 /etc/os-release 和系统状态。"
fi

# Stop session logging (should be reached only if reboot is cancelled or fails)
log_message "--- 升级脚本执行结束：$(date) ---"
kill "$SCRIPT_PID"
