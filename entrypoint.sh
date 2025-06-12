#!/bin/sh

# 开启命令回显和错误时退出
set -e

# --- 1. 设置 SSH 密码 ---
# 从环境变量 SSH_PASSWORD 获取密码，如果变量未设置，则使用默认值 "admin123"
DEFAULT_PASS="admin123"
ROOT_PASSWORD="${SSH_PASSWORD:-$DEFAULT_PASS}"
echo "root:${ROOT_PASSWORD}" | chpasswd
echo "SSH root 密码已设置。如使用默认密码，请务必修改！"

# --- 2. 初始化 Supervisor 配置 ---
SUPERVISOR_DIR="/app/supervisord"
SUPERVISOR_CONFIG_FILE="${SUPERVISOR_DIR}/supervisord.conf"
SERVICES_CONFIG_FILE="${SUPERVISOR_DIR}/services.ini"
TEMPLATE_DIR="/etc/supervisor_templates"

# 检查 Supervisor 配置目录是否存在，不存在则创建
if [ ! -d "$SUPERVISOR_DIR" ]; then
    echo "Supervisor 配置目录不存在，正在创建..."
    mkdir -p "$SUPERVISOR_DIR"
fi

# 检查主配置文件是否存在，不存在则从模板复制
if [ ! -f "$SUPERVISOR_CONFIG_FILE" ]; then
    echo "Supervisor 主配置文件不存在，正在从模板创建..."
    cp "${TEMPLATE_DIR}/supervisord.conf" "$SUPERVISOR_CONFIG_FILE"
fi

# 检查服务配置文件是否存在，不存在则从模板复制
if [ ! -f "$SERVICES_CONFIG_FILE" ]; then
    echo "Supervisor 服务配置文件不存在，正在从模板创建..."
    cp "${TEMPLATE_DIR}/services.ini" "$SERVICES_CONFIG_FILE"
fi

# --- 3. 初始化应用配置 ---
# Quark 保存助手配置检查
QUARK_CONFIG_PATH="/app/quark/Config"
QUARK_CONFIG_FILE="${QUARK_CONFIG_PATH}/config.ini"
QUARK_TEMPLATE_FILE="/app/quark/config.ini.templete"

if [ ! -d "$QUARK_CONFIG_PATH" ]; then
    mkdir -p "$QUARK_CONFIG_PATH"
fi
if [ ! -f "$QUARK_CONFIG_FILE" ]; then
    echo "Quark 配置文件不存在，正在从模板创建..."
    cp "$QUARK_TEMPLATE_FILE" "$QUARK_CONFIG_FILE"
fi

# 天翼云盘配置检查
CLOUD189_CONFIG_FILE="/app/cloud189/config.json"
if [ ! -f "$CLOUD189_CONFIG_FILE" ]; then
    echo "注意：天翼云盘配置文件 ${CLOUD189_CONFIG_FILE} 不存在。请在挂载的目录下手动创建并配置它。"
fi

echo "入口脚本：初始化检查完成。"

# --- 4. 启动主进程 ---
# 执行 Docker CMD 中定义的命令 (即启动 supervisord)
exec "$@"
