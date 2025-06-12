# --- 阶段一：Go 语言项目构建器 ---
# 使用官方的 golang:alpine 镜像作为临时的构建环境
# AS golang_builder 为这个阶段命名，方便后续引用
FROM golang:1.22-alpine AS golang_builder

# 在构建环境中安装 git
RUN apk add --no-cache git

# 克隆 cloud189-auto-save 项目
WORKDIR /src
RUN git clone https://github.com/1307super/cloud189-auto-save.git .

# 编译 Go 项目。
# CGO_ENABLED=0 和 -ldflags '-s -w' 是为了生成静态链接、体积更小的二进制文件
RUN CGO_ENABLED=0 go build -ldflags '-s -w' -o /cloud189-auto-save

# --- 阶段二：构建最终的多服务镜像 ---
# 使用您指定的镜像作为基础
FROM jiangrui1994/cloudsaver:latest

# 设置镜像的维护者信息（可选）
LABEL maintainer="Your Name <your.email@example.com>"

# --- 安装所有需要的工具和语言环境 ---
# 在一条 RUN 指令中完成所有安装，可以减少镜像层数
RUN apk add --no-cache \
    # 基础工具
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
    # Python 和 Go 语言环境 (根据您的新需求)
    python3 \
    py3-pip \
    go \
    # 进程管理器
    supervisor \
    # 编译和克隆项目所需的临时工具
    git build-base python3-dev && \
    # --- 安装 Quark 保存助手 (Python项目) ---
    # 克隆项目到您指定的 /app/quark 目录下
    git clone https://github.com/Cp0204/quark-auto-save.git /app/quark && \
    # 安装 Python 依赖
    pip install --no-cache-dir -r /app/quark/requirements.txt && \
    # --- 清理工作 ---
    # 删除不再需要的编译工具和 git，保持镜像整洁
    apk del git build-base python3-dev && \
    # 清理 apk 缓存
    rm -rf /var/cache/apk/*

# --- 准备服务和配置 ---
# 创建天翼云盘的工作目录
RUN mkdir -p /app/cloud189
# 从第一阶段复制编译好的 Go 程序到指定目录
COPY --from=golang_builder /cloud189-auto-save /app/cloud189/

# --- 准备 Supervisor 配置模板 ---
# 创建一个临时目录存放 Supervisor 配置模板
RUN mkdir -p /etc/supervisor_templates/
# 复制 Supervisor 主配置文件和具体服务的配置文件到模板目录
COPY supervisord.conf /etc/supervisor_templates/
COPY services.ini /etc/supervisor_templates/

# --- 配置 SSH ---
# 创建 sshd 运行时所需要的目录
RUN mkdir -p /var/run/sshd && \
    # 允许 root 用户通过密码登录
    sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# --- 配置入口脚本 ---
# 复制入口脚本并赋予执行权限
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# --- 暴露端口 ---
# 基础镜像的 8008 端口和 SSH 的 22 端口
EXPOSE 8008 22

# --- 定义容器启动命令 ---
# 使用入口脚本来做一些启动前的准备工作
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
# Supervisor 是主进程，它会从挂载的 /app/supervisord 目录读取配置
CMD ["/usr/bin/supervisord", "-c", "/app/supervisord/supervisord.conf"]
