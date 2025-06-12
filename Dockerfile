# --- 阶段一：Go 语言项目构建器 ---
# 使用最新的 Go 1.24 Alpine 镜像，确保编译环境版本正确
FROM golang:1.24-alpine AS golang_builder

# 安装编译所需的 C 语言环境、SQLite 开发库和 Git
RUN apk add --no-cache git build-base sqlite-dev

# 设置一个基础工作目录
WORKDIR /src

# 克隆项目。这将在 /src 目录下创建一个名为 cloud189-auto-save 的新目录
RUN git clone https://github.com/1307super/cloud189-auto-save.git

# --- 关键修复：使用 WORKDIR 明确进入项目目录 ---
# 这将保证后续所有命令都在正确的目录下执行
WORKDIR /src/cloud189-auto-save

# (可选但推荐) 为了最终确认，我们在这里列出文件，构建时您可以看到 go.mod 文件
RUN echo "--- Verifying files in current directory: $(pwd) ---" && ls -la

# 现在，我们 100% 在正确的目录里，执行 go mod tidy
RUN go mod tidy

# 执行编译，并将输出文件命名为 app-binary (放在当前目录)
RUN go build -ldflags '-s -w' -o app-binary


# --- 阶段二：构建最终的多服务镜像 ---
FROM jiangrui1994/cloudsaver:latest

# 设置镜像的维护者信息
LABEL maintainer="Your Name <your.email@example.com>"

# --- 设置时区并手动安装指定版本的Go ---
ENV GO_VERSION=1.24.4
ENV GO_ARCH=amd64
ENV PATH="/usr/local/go/bin:${PATH}"

# 一条 RUN 指令完成所有安装和配置
RUN \
    apk update && \
    apk add --no-cache tzdata && \
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone && \
    apk add --no-cache \
        openssh-server sudo curl wget busybox-suid nano tar gzip unzip sshpass \
        python3 py3-pip supervisor \
        git build-base python3-dev && \
    wget "https://go.dev/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz" -O /tmp/go.tar.gz && \
    tar -C /usr/local -xzf /tmp/go.tar.gz && \
    rm /tmp/go.tar.gz && \
    git clone https://github.com/Cp0204/quark-auto-save.git /app/quark && \
    pip install --no-cache-dir -r /app/quark/requirements.txt && \
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
