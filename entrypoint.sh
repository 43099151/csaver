#!/bin/sh

# 开启命令回显和错误时退出
set -e

# --- 1. 设置 SSH 密码 ---
# 从环境变量 SSH_PASSWORD 获取密码，如果变量未设置，则使用默认值 "admin123"
DEFAULT_PASS="admin123"
ROOT_PASSWORD="${SSH_PASSWORD:-$DEFAULT_PASS}"
echo "root:${ROOT_PASSWORD}" | chpasswd
echo "SSH root 密码已设置。如使用默认密码，请务必修改！"

# --- 2. 关键修复：检查并生成 SSH 主机密钥 ---
# 检查其中一个关键的主机密钥文件是否存在
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    echo "SSH 主机密钥不存在，正在生成..."
    # 使用 ssh-keygen -A 命令生成所有类型的默认密钥
    ssh-keygen -A
    echo "SSH 主机密钥生成完毕。"
fi

# --- 3. 初始化 Supervisor 配置 ---
SUPERVISOR_DIR="/app/supervisord"
SUPERVISOR_CONFIG_FILE="${SUPERVISOR_DIR}/supervisord.conf"
SERVICES_CONFIG_FILE="${SUPERVISOR_DIR}/services.ini"
TEMPLATE_DIR="/etc/supervisor_templates"

if [ ! -d "$SUPERVISOR_DIR" ]; then
    echo "Supervisor 配置目录不存在，正在创建..."
    mkdir -p "$SUPERVISOR_DIR"
fi
if [ ! -f "$SUPERVISOR_CONFIG_FILE" ]; then
    echo "Supervisor 主配置文件不存在，正在从模板创建..."
    cp "${TEMPLATE_DIR}/supervisord.conf" "$SUPERVISOR_CONFIG_FILE"
fi
if [ ! -f "$SERVICES_CONFIG_FILE" ]; then
    echo "Supervisor 服务配置文件不存在，正在从模板创建..."
    cp "${TEMPLATE_DIR}/services.ini" "$SERVICES_CONFIG_FILE"
fi

# --- 4. 初始化应用配置 (逻辑保持不变) ---
# Quark 保存助手配置检查 (示例)
QUARK_CONFIG_PATH="/app/quark/Config"
if [ ! -d "$QUARK_CONFIG_PATH" ]; then
    # 这里我们只创建目录，具体的配置文件由用户手动部署应用时创建
    mkdir -p "$QUARK_CONFIG_PATH"
fi

echo "入口脚本：初始化检查完成。"

# --- 5. 启动主进程 ---
# 执行 Docker CMD 中定义的命令 (即启动 supervisord)
exec "$@"
