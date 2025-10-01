# ---- STAGE 1: Builder ----
# This stage contains all build tools needed to prepare our application files.
FROM debian:bullseye AS builder

# 设置工作目录，这是一个好习惯
WORKDIR /app

# 安装构建时所需的工具
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    unzip \
    dos2unix \
    && rm -rf /var/lib/apt/lists/*

# ==== 安装 v2ray ====
# 下载 v2ray 并解压到当前工作目录 (/app)
ARG V2RAY_VERSION=v5.15.0
RUN curl -L -H "Cache-Control: no-cache" -o /tmp/v2ray.zip \
    "https://github.com/v2fly/v2ray-core/releases/download/${V2RAY_VERSION}/v2ray-linux-64.zip" \
    && unzip /tmp/v2ray.zip -d . \
    && rm -f /tmp/v2ray.zip

# ==== 安装 cloudflared ====
RUN curl -L --output cloudflared.deb "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb" \
    && dpkg -i cloudflared.deb \
    && rm cloudflared.deb

# 拷贝启动脚本到工作目录，并修复其格式
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh && dos2unix entrypoint.sh

# ---- STAGE 2: Final Image ----
# This is a clean, minimal image. We only copy the necessary artifacts from the builder.
FROM debian:bullseye-slim

# 安装运行时脚本真正需要的依赖
RUN apt-get update && apt-get install -y --no-install-recommends jq qrencode && rm -rf /var/lib/apt/lists/*
# 创建 v2ray 规则文件所需的目录
RUN mkdir -p /usr/local/share/v2ray

# Copy prepared files from the builder stage.
COPY --from=builder /app/v2ray /usr/local/bin/v2ray
COPY --from=builder /usr/local/bin/cloudflared /usr/local/bin/cloudflared
COPY --from=builder /app/geoip.dat /usr/local/share/v2ray/
COPY --from=builder /app/geosite.dat /usr/local/share/v2ray/
COPY --from=builder /app/entrypoint.sh /entrypoint.sh

# 设置默认端口（可被 PORT 环境变量覆盖）
EXPOSE 10086

# 设置入口
ENTRYPOINT ["/entrypoint.sh"]
