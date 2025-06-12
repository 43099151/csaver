# --- 构建最终的多服务镜像 ---
FROM jiangrui1994/cloudsaver:latest

# 设置镜像的维护者信息
LABEL maintainer="Your Name <your.email@example.com>"

# --- 设置时区并手动安装指定版本的Go ---
ENV GO_VERSION=1.24.4
ENV GO_ARCH=amd64
ENV PATH="/usr/local/go/bin:${PATH}"

# --- 步骤 1: 设置时区和更新包索引 ---
RUN apk update && \
    apk add --no-cache tzdata && \
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone

# --- 步骤 2: 安装所有基础工具和运行环境 ---
# 关键修复：将 `openssh-server` 改为正确的 `openssh`
RUN apk add --no-cache \
    openssh sudo curl wget busybox-suid nano tar gzip unzip sshpass \
    python3 py3-pip supervisor

# --- 步骤 3: 手动安装指定版本的 Go ---
RUN wget "https://go.dev/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz" -O /tmp/go.tar.gz && \
    tar -C /usr/local -xzf /tmp/go.tar.gz && \
    rm /tmp/go.tar.gz

# --- 步骤 4: 安装 Python 项目及其依赖 ---
# 这是最容易出错的步骤，我们将其独立出来
RUN \
    # 首先，安装所有编译 Python 包可能需要的C语言库和工具
    # 预先添加 libxml2-dev 和 libxslt-dev 是为了解决 lxml 等常见包的编译问题
    apk add --no-cache git build-base python3-dev libxml2-dev libxslt-dev && \
    \
    # 然后，克隆项目
    git clone https://github.com/Cp0204/quark-auto-save.git /app/quark && \
    \
    # 接着，执行 pip install
    pip install --no-cache-dir -r /app/quark/requirements.txt && \
    \
    # 最后，清理临时的编译工具
    apk del git build-base python3-dev libxml2-dev libxslt-dev

# --- 步骤 5: 清理 APK 缓存 ---
RUN rm -rf /var/cache/apk/*

# --- 准备服务和配置 ---
RUN mkdir -p /app/cloud189

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
