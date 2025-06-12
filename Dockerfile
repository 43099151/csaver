# --- 阶段一：Go 语言项目构建器 ---
# 关键修复：使用项目 go.mod 文件中指定的 go 1.21 版本
FROM golang:1.21-alpine AS golang_builder

# 关键修复：只安装 git 和基础 C 编译器，不再需要 sqlite-dev
RUN apk add --no-cache git build-base

# 设置工作目录
WORKDIR /src

# 将项目克隆到当前目录
RUN git clone https://github.com/1307super/cloud189-auto-save.git .

# 关键修复：完全移除 `go mod tidy` 指令。
# 直接执行编译。Go 编译器会读取 go.mod 并使用 vender 目录中的代码。
RUN go build -ldflags '-s -w' -o /app-binary


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
# --- 从第一阶段复制编译好的二进制文件 ---
COPY --from=golang_builder /src/app-binary /app/cloud189/cloud189-auto-save

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
