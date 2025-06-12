# --- 阶段一：Go 语言项目构建器 ---
# 使用最新的 Go 1.24 Alpine 镜像
FROM golang:1.24-alpine AS golang_builder

# --- 关键修复：安装 C 语言编译环境和 SQLite 开发库 ---
# 这是解决 `go mod tidy` 和 `go build` 失败的根本原因
RUN apk add --no-cache git build-base sqlite-dev

# 设置工作目录
WORKDIR /src

# 克隆 cloud189-auto-save 项目
RUN git clone https://github.com/1307super/cloud189-auto-save.git .

# 最佳实践：在构建前处理 Go Modules 依赖
RUN go mod tidy

# 编译 Go 项目。现在因为安装了CGO依赖，它可以成功编译
# 注意：我们不再需要 CGO_ENABLED=0，因为我们就是要用CGO
RUN go build -ldflags '-s -w' -o /cloud189-auto-save


# --- 阶段二：构建最终的多服务镜像 ---
# (此阶段及之后的内容保持不变)
FROM jiangrui1994/cloudsaver:latest

# 设置镜像的维护者信息（可选）
LABEL maintainer="Your Name <your.email@example.com>"

# --- 关键更新：设置时区为上海 ---
RUN apk add --no-cache tzdata && \
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone

# --- 安装所有需要的工具和语言环境 ---
RUN apk add --no-cache \
    openssh-server \
    sudo \
    curl \
    wget \
    busybox-suid \
    nano \
    tar \
    gzip \
    unzip \
    sshpass \
    python3 \
    py3-pip \
    go \
    supervisor \
    git build-base python3-dev && \
    git clone https://github.com/Cp0204/quark-auto-save.git /app/quark && \
    pip install --no-cache-dir -r /app/quark/requirements.txt && \
    apk del git build-base python3-dev && \
    rm -rf /var/cache/apk/*

# --- 准备服务和配置 ---
RUN mkdir -p /app/cloud189
COPY --from=golang_builder /cloud189-auto-save /app/cloud189/

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
