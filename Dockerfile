# --- 构建最终的多服务镜像 ---
FROM jiangrui1994/cloudsaver:latest

# 设置镜像的维护者信息
LABEL maintainer="Your Name <your.email@example.com>"

# --- 设置环境变量 ---
ENV GO_VERSION=1.24.4
ENV GO_ARCH=amd64
ENV PATH="/usr/local/go/bin:${PATH}"

# --- 步骤 1: 设置时区和更新包索引 ---
RUN apk update && \
    apk add --no-cache tzdata && \
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone

# --- 步骤 2: 安装所有基础工具和运行环境 ---
RUN apk add --no-cache \
    openssh sudo curl wget busybox-suid nano tar gzip unzip sshpass \
    python3 py3-pip supervisor

# --- 步骤 3: 手动安装指定版本的 Go ---
RUN wget "https://go.dev/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz" -O /tmp/go.tar.gz && \
    tar -C /usr/local -xzf /tmp/go.tar.gz && \
    rm /tmp/go.tar.gz

# --- 步骤 4: 启用 Corepack 来管理 pnpm ---
RUN corepack enable

# --- 步骤 5: 清理 APK 缓存 ---
RUN rm -rf /var/cache/apk/*

# --- 准备服务目录 ---
RUN mkdir -p /app/cloud189 /app/quark

# --- 准备 Supervisor 配置模板 ---
RUN mkdir -p /etc/supervisor_templates/
COPY supervisord.conf /etc/supervisor_templates/
COPY services.ini /etc/supervisor_templates/

# --- 配置 SSH ---
RUN mkdir -p /var/run/sshd && \
    # --- 关键修复：强制启用密码登录 ---
    # 使用 `echo` 将配置追加到文件末尾，确保它们总是生效
    # 允许 root 用户登录
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    # 明确启用密码验证
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    # (可选但推荐) 关闭 UsePAM 简化认证流程，避免潜在问题
    echo "UsePAM no" >> /etc/ssh/sshd_config

# --- 配置入口脚本 ---
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# --- 暴露端口 ---
EXPOSE 8008 22

# --- 定义容器启动命令 ---
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/app/supervisord/supervisord.conf"]
