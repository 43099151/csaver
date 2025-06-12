#!/bin/sh

# 开启命令回显和错误时退出
set -e

# --- 1. 执行我们自己的初始化任务 ---
echo "--- Running custom entrypoint setup ---"

# 设置 SSH 密码
DEFAULT_PASS="admin123"
ROOT_PASSWORD="${SSH_PASSWORD:-$DEFAULT_PASS}"
echo "root:${ROOT_PASSWORD}" | chpasswd
echo "SSH root password has been set."

# 检查并生成 SSH 主机密钥
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    echo "SSH host keys not found, generating..."
    ssh-keygen -A
fi

# 初始化我们自己的 Supervisor 配置
SUPERVISOR_DIR="/app/supervisord"
if [ ! -d "$SUPERVISOR_DIR" ]; then
    echo "Supervisor config directory not found, creating from template..."
    mkdir -p "$SUPERVISOR_DIR"
    cp /etc/supervisor_templates/* "$SUPERVISOR_DIR/"
fi

echo "--- Custom entrypoint setup finished ---"
echo ""

# --- 2. 调用原始镜像的入口脚本，并在后台运行 ---
echo "--- Starting original cloudsaver services in background ---"
# 使用 sh 执行，并用 & 放入后台
sh /app/docker-entrypoint.sh &
echo "--- Original services are starting ---"
echo ""

# --- 3. 启动我们自己的 Supervisor 来管理新增服务 ---
# 使用 exec 来让 Supervisor 成为主进程
# "$@" 会接收来自 Dockerfile CMD 的参数
echo "--- Starting custom services with Supervisor in foreground ---"
exec "$@"
