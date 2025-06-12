# --- 构建最终的多服务镜像 ---
FROM jiangrui1994/cloudsaver:latest

# 设置镜像的维护者信息
LABEL maintainer="Your Name <your.email@example.com>"

# --- 设置环境变量 (包括 pnpm) ---
ENV GO_VERSION=1.24.4
ENV GO_ARCH=amd64
# 设置 pnpm 的安装目录
ENV PNPM_HOME="/usr/local/pnpm"
# 将 Go 和 pnpm 的路径加入系统 PATH
ENV PATH="/usr/local/go/bin:${PNPM_HOME}:${PATH}"

# --- 步骤 1: 设置时区和更新包索引 ---
RUN apk update && \
    apk add --no-cache tzdata && \
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone

# --- 步骤 2: 安装所有基础工具和运行环境 ---
# 注意：这里不再需要任何 build-base 或 -dev 包
RUN apk add --no-cache \
    openssh sudo curl wget busybox-suid nano tar gzip unzip sshpass \
    python3 py3-pip supervisor

# --- 步骤 3: 手动安装指定版本的 Go ---
RUN wget "https://go.dev/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz" -O /tmp/go.tar.gz && \
    tar -C /usr/local -xzf /tmp/go.tar.gz && \
    rm /tmp/go.tar.gz

# --- 步骤 4: 安装 pnpm ---
# 使用官方推荐的脚本进行安装，curl 是必需的
RUN curl -fsSL https://get.pnpm.io/install.sh | sh -

# --- 步骤 5: 清理 APK 缓存 ---
RUN rm -rf /var/cache/apk/*

# --- 准备服务目录 ---
# 为您后续的手动部署创建好空目录
RUN mkdir -p /app/cloud189 /app/quark

# --- 准备 Supervisor 配置模板 ---
RUN mkdir -p /etc/supervisor_templates/
COPY supervisord.conf /etc/supervisor_templates/
COPY services.ini /etc/supervisor_templates/

# --- 配置 SSH ---
RUN mkdir -p /var/run/sshd && \
    sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# --- 配置入口脚本 ---
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# --- 暴露端口 ---
EXPOSE 8008 22

# --- 定义容器启动命令 ---
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/app/supervisord/supervisord.conf"]
