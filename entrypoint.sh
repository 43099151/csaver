#!/bin/sh

# 如果任何命令失败，则立即退出
set -e

# --- 1. 初始化我们自己的服务 ---

# 从环境变量设置 SSH 密码
DEFAULT_PASS="admin123"
ROOT_PASSWORD="${SSH_PASSWORD:-$DEFAULT_PASS}"
echo "root:${ROOT_PASSWORD}" | chpasswd
echo "SSH root password has been set."

# 如果 SSH 主机密钥不存在，则自动生成
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    ssh-keygen -A
fi

# 如果用户的 Supervisor 服务文件目录不存在，则从模板创建 (仅首次运行)
SUPERVISOR_DIR="/app/supervisord"
if [ ! -d "$SUPERVISOR_DIR" ]; then
    mkdir -p "$SUPERVISOR_DIR"
    cp /etc/supervisor_templates/services.ini "$SUPERVISOR_DIR/"
fi

# 添加 cron 任务
CRON_FILE="/etc/crontabs/root"
CRON_JOB="16 4 * * * /bin/sh /var/www/html/backup.sh"
# 确保 crontab 文件存在且可写，如果不存在则创建
if [ ! -f "$CRON_FILE" ]; then
    touch "$CRON_FILE"
    chmod 600 "$CRON_FILE"
fi
# 检查任务是否已存在，避免重复添加
if ! grep -qF "$CRON_JOB" "$CRON_FILE"; then
    echo "$CRON_JOB" >> "$CRON_FILE"
    echo "Cron job for backup.sh has been set."
else
    echo "Cron job for backup.sh already exists."
fi

# --- 2. 在后台启动原始镜像的服务 ---
sh /app/docker-entrypoint.sh &

# --- 3. 在前台运行我们自己的 Supervisor 来管理新增服务 ---
# 使用 exec 将 Supervisor 作为此脚本的主进程
exec "$@"
