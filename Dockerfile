FROM debian:bullseye

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    jq \
    qrencode \
    bash \
    unzip \
    && rm -rf /var/lib/apt/lists/*


# 拷贝启动脚本
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 设置默认端口（可被 PORT 环境变量覆盖）
EXPOSE 10086

# 设置入口
ENTRYPOINT ["/entrypoint.sh"]
