FROM debian:bullseye

RUN apt update && apt install -y curl jq qrencode bash unzip


# 拷贝启动脚本
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 设置默认端口（可被 PORT 环境变量覆盖）
EXPOSE 10086

# 设置入口
ENTRYPOINT ["/entrypoint.sh"]
