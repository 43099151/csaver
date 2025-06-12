# --- 构建最终的多服务镜像 ---
FROM jiangrui1994/cloudsaver:latest

# 设置镜像的维护者信息
LABEL maintainer="Your Name <your.email@example.com>"

# --- 设置环境变量 (可选) ---
# ENV PATH="/usr/local/go/bin:${PATH}" # 不再需要，因为使用 apk 安装

# --- 步骤 1: 设置时区和更新包索引 ---
RUN apk update && \
    apk add --no-cache tzdata && \
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone

# --- 步骤 2: 安装所有基础工具、Go 环境和编译依赖 ---
# ==> 关键修复：
# 1. 使用 apk 直接安装 go
# 2. 将 build-base 和 sqlite-dev 直接集成进来
RUN apk add --no-cache \
    openssh sudo curl wget busybox-suid nano tar gzip unzip sshpass \
    python3 py3-pip supervisor \
    go build-base sqlite-dev

# --- 步骤 3: 启用 Corepack 来管理 pnpm ---
RUN corepack enable

# --- 步骤 4: 清理 APK 缓存 ---
RUN rm -rf /var/cache/apk/*

# --- 准备服务目录 ---
RUN mkdir -p /app/cloud189 /app/quark

# --- 准备 Supervisor 配置模板 ---
RUN mkdir -p /etc/supervisor_templates/
COPY supervisord.conf /etc/supervisor_templates/
COPY services.ini /etc/supervisor_templates/

# --- 配置 SSH ---
RUN mkdir -p /var/run/sshd && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "UsePAM no" >> /etc/ssh/sshd_config

# --- 配置入口脚本 ---
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# --- 暴露端口 ---
EXPOSE 8008 22

# --- 定义容器启动命令 ---
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/app/supervisord/supervisord.conf"]
