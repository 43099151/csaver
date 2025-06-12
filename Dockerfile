# --- 构建最终的多服务镜像 ---
FROM jiangrui1994/cloudsaver:latest

# 设置镜像的维护者信息
LABEL maintainer="Your Name <your.email@example.com>"

# --- 设置环境变量 ---
# 定义此环境变量是为了在脚本中使用，但Go是通过apk安装的
ENV GO_VERSION=1.24.4
ENV GO_ARCH=amd64
ENV PATH="/usr/local/go/bin:${PATH}"

# --- 步骤 1: 设置时区和更新包索引 ---
RUN apk update && \
    apk add --no-cache tzdata && \
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone

# --- 步骤 2: 安装所有基础工具、语言环境和编译依赖 ---
RUN apk add --no-cache \
    # 基础工具
    openssh sudo curl wget busybox-suid nano tar gzip unzip sshpass \
    # 语言和包管理器
    python3 py3-pip supervisor go \
    # 版本控制和编译工具
    git build-base python3-dev

# --- 步骤 3: 启用 Corepack 来管理 pnpm ---
RUN corepack enable

# --- 步骤 4: 在构建阶段安装所有 Python 依赖 ---
RUN \
    # 创建一个临时目录用于构建，避免污染最终目录
    mkdir -p /tmp/pip_build && \
    cd /tmp/pip_build && \
    # 克隆项目以获取 requirements.txt
    git clone https://github.com/Cp0204/quark-auto-save.git . && \
    # 安装所有已知的 Python 依赖
    pip install --no-cache-dir --break-system-packages \
        -r requirements.txt \
        flask \
        apscheduler && \
    # 清理临时文件
    cd / && \
    rm -rf /tmp/pip_build

# --- 步骤 5: 清理 APK 缓存 ---
RUN rm -rf /var/cache/apk/*

# --- 准备服务目录 ---
# 为后续的手动部署创建空目录
RUN mkdir -p /app/cloud189 /app/quark

# --- 准备 Supervisor 配置模板 ---
# 将配置模板复制到镜像中，以便入口脚本在首次运行时使用
RUN mkdir -p /etc/supervisor_templates/
COPY supervisord.conf /etc/supervisor_templates/
COPY services.ini /etc/supervisor_templates/

# --- 配置 SSH ---
# 创建 sshd 运行时目录并强制启用密码登录
RUN mkdir -p /var/run/sshd && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "UsePAM no" >> /etc/ssh/sshd_config

# --- 配置入口脚本 ---
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# --- 暴露端口 ---
# 暴露原始应用的前端端口和SSH端口
EXPOSE 8008 22

# --- 定义容器启动命令 ---
# 使用我们自己的入口脚本来启动容器
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
# 将 Supervisor 作为主命令传递给入口脚本
CMD ["/usr/bin/supervisord", "-c", "/app/supervisord/supervisord.conf"]
