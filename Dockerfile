# --- 阶段一：Go 语言项目构建器 ---
# 使用最新的 Go 1.24 Alpine 镜像，确保编译环境版本正确
FROM golang:1.24-alpine AS golang_builder

# 安装编译所需的 C 语言环境、SQLite 开发库和 Git
RUN apk add --no-cache git build-base sqlite-dev

# 设置一个基础工作目录
WORKDIR /src

# --- 关键修复：使用单一的、连续的 RUN 指令来完成所有编译步骤 ---
RUN \
    # 1. 克隆项目到一个名为 cloud189-auto-save 的目录中
    git clone https://github.com/1307super/cloud189-auto-save.git && \
    \
    # 2. 使用 cd 命令，明确进入克隆下来的项目目录
    cd cloud189-auto-save && \
    \
    # 3. (可选但推荐的调试步骤) 列出当前目录内容，确保能看到 go.mod
    echo "--- Listing files in current directory ---" && \
    ls -la && \
    echo "----------------------------------------" && \
    \
    # 4. 在确认无误的目录下，执行 go mod tidy
    go mod tidy && \
    \
    # 5. 最后，执行编译
    go build -ldflags '-s -w' -o /app-binary


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
# --- 注意：这里的源路径也需要更新，以匹配第一阶段的输出路径 ---
COPY --from=golang_builder /src/cloud189-auto-save/app-binary /app/cloud189/cloud189-auto-save

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
