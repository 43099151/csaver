# --- 阶段一：Go 语言项目构建器 ---
# 使用最新的 Go 1.24 Alpine 镜像，确保编译环境版本正确
FROM golang:1.24-alpine AS golang_builder

# 安装 C 语言编译环境和 SQLite 开发库，这是 Go 项目的编译依赖
RUN apk add --no-cache git build-base sqlite-dev

# 设置工作目录
WORKDIR /src

# 克隆项目。注意，这次没有最后的 '.', 会创建一个新目录
RUN git clone https://github.com/1307super/cloud189-auto-save.git

# --- 关键修复：进入克隆下来的项目目录 ---
WORKDIR /src/cloud189-auto-save

# 现在在正确的目录里，执行 go mod tidy
RUN go mod tidy

# 编译 Go 项目。
RUN go build -ldflags '-s -w' -o /cloud189-auto-save


# --- 阶段二：构建最终的多服务镜像 ---
FROM jiangrui1994/cloudsaver:latest

# 设置镜像的维护者信息
LABEL maintainer="Your Name <your.email@example.com>"

# --- 关键更新：设置时区为上海，并手动安装指定版本的Go ---
# 定义 Go 版本和架构，方便管理
ENV GO_VERSION=1.24.4
ENV GO_ARCH=amd64
# 将 Go 的路径加入系统 PATH，这样才能在任何地方直接使用 go 命令
ENV PATH="/usr/local/go/bin:${PATH}"

# 一条 RUN 指令完成所有安装和配置
RUN \
    # 更新 apk 索引
    apk update && \
    # 1. 安装时区数据并设置时区
    apk add --no-cache tzdata && \
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone && \
    # 2. 安装基础工具、Python和临时编译依赖
    apk add --no-cache \
        openssh-server sudo curl wget busybox-suid nano tar gzip unzip sshpass \
        python3 py3-pip supervisor \
        git build-base python3-dev && \
    # 3. 手动安装指定版本的 Go
    wget "https://go.dev/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz" -O /tmp/go.tar.gz && \
    tar -C /usr/local -xzf /tmp/go.tar.gz && \
    rm /tmp/go.tar.gz && \
    # 4. 安装 Python 项目
    git clone https://github.com/Cp0204/quark-auto-save.git /app/quark && \
    pip install --no-cache-dir -r /app/quark/requirements.txt && \
    # 5. 清理临时文件和工具，保持镜像小巧
    apk del git build-base python3-dev && \
    rm -rf /var/cache/apk/*

# --- 准备服务和配置 ---
RUN mkdir -p /app/cloud189
COPY --from=golang_builder /src/cloud189-auto-save/cloud189-auto-save /app/cloud189/

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
