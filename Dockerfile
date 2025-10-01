FROM debian:bullseye

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    jq \
    qrencode \
    bash \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# ==== 安装 v2ray ====
# 从 GitHub Releases 下载 v2ray，解压并放置到 /usr/local/bin/
ARG V2RAY_VERSION=v5.15.0
ARG TARGETARCH=amd64
RUN curl -L -H "Cache-Control: no-cache" -o /tmp/v2ray.zip \
    "https://github.com/v2fly/v2ray-core/releases/download/${V2RAY_VERSION}/v2ray-linux-64.zip" \
    && unzip /tmp/v2ray.zip -d /tmp/v2ray \
    && install -m 755 /tmp/v2ray/v2ray /usr/local/bin/v2ray \
    && install -m 644 /tmp/v2ray/geoip.dat /usr/local/share/v2ray/geoip.dat \
    && install -m 644 /tmp/v2ray/geosite.dat /usr/local/share/v2ray/geosite.dat \
    && rm -rf /tmp/v2ray.zip /tmp/v2ray

# 拷贝启动脚本
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 设置默认端口（可被 PORT 环境变量覆盖）
EXPOSE 10086

# 设置入口
ENTRYPOINT ["/entrypoint.sh"]
