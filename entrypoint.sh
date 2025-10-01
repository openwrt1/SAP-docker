#!/bin/sh
# set -e: 脚本中任何命令失败则立即退出
set -e

# 避免 clear/终端能力报错
export TERM="${TERM:-xterm}"
export LANG="${LANG:-C.UTF-8}"
export LC_ALL="${LC_ALL:-C.UTF-8}"

UUID_FILE="/tmp/uuid.txt"

echo "==== DEBUG: SCRIPT START ===="
echo "==== DEBUG: Printing environment variables ===="
printenv
echo "=============================================="

# ==== 版权信息横幅 ====
cat <<'EOF'
----------------------------------------------------------------
🚀📺⚠️  YOUTUBE频道：Uncle LUO老罗叔叔的数字生活指南 ｜ 项目：SAP-VPN ｜ 直连简化版  🚀📺⚠️
声明：仅供学习与隐私保护使用，请遵守当地法律法规与平台条款。
关键词：Uncle LUO、老罗叔叔、数字生活指南
----------------------------------------------------------------
EOF
echo "油管频道：老罗叔叔｜SAP-VPN直连版"

# ==== UUID 管理（可外部注入 UUID；否则持久化到 /etc/uuid.txt）====
if [ -n "${UUID:-}" ]; then
	echo "$UUID" >"$UUID_FILE"
elif [ -f "$UUID_FILE" ]; then
	UUID="$(cat "$UUID_FILE")"
else
	UUID="$(cat /proc/sys/kernel/random/uuid)"
	echo "$UUID" >"$UUID_FILE"
fi
echo "==== DEBUG: UUID set to: ${UUID} ===="

# ==== 环境变量与默认值 ====
# 在 Cloud Foundry 这样的 PaaS 平台上，平台会为应用分配一个随机的内部端口，
# 并通过 $PORT 环境变量告知应用。应用必须监听这个端口，才能接收到来自平台路由器的流量。
# 因此，我们优先使用 $PORT 环境变量。
# 只有在本地测试等没有 $PORT 变量的环境中，我们才使用一个固定的默认端口（如 10086）作为备用。
if [ -n "${PORT:-}" ]; then
	echo "==== INFO: Found '$PORT' environment variable provided by the platform. Using it as the inbound port. ===="
	INBOUND_PORT="$PORT"
else
	echo "==== INFO: No '$PORT' environment variable found. Using default inbound port '10086'. ===="
	INBOUND_PORT="10086"
fi
WS_PATH="${WS_PATH:-/laoluo}"
TUNNEL_TOKEN="${TUNNEL_TOKEN:-}" # 从环境变量读取 Cloudflare Tunnel Token
DOMAIN="${DOMAIN:-}"

if [ -n "${VCAP_APPLICATION:-}" ]; then
	# 优先解析 VCAP_APPLICATION.application_uris[0]
	# 有 jq 更稳；若失败则用 grep/sed 兜底
	HOST_FROM_VCAP="$(echo "$VCAP_APPLICATION" | jq -r '.application_uris[0] // empty' 2>/dev/null || true)"
	if [ -z "$HOST_FROM_VCAP" ]; then
		HOST_FROM_VCAP="$(echo "$VCAP_APPLICATION" |
			grep -oE '"application_uris":\[[^]]+\]' |
			sed -n 's/.*\[\s*"\([^"]\+\)".*/\1/p' | head -n1 || true)"
	fi
	ROUTE_HOST="$HOST_FROM_VCAP"
else
	ROUTE_HOST=""
fi

# 优先顺序: 外部注入的 DOMAIN -> 从 VCAP 解析的 ROUTE_HOST
HOST="${DOMAIN:-$ROUTE_HOST}"
if [ -z "$HOST" ]; then
	HOST="your-domain.com"
fi

echo "==== DEBUG: Inbound port set to: ${INBOUND_PORT} ===="
echo "==== DEBUG: WebSocket path set to: ${WS_PATH} ===="
echo "==== DEBUG: Host for VMess link set to: ${HOST} ===="

# ==== 生成 v2ray 配置（vmess + ws，无 tls；CF 路由层终止 tls）====
cat >/etc/v2ray-config.json <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [{
    "port": ${INBOUND_PORT},
    "listen": "127.0.0.1",
    "protocol": "vmess",
    "settings": {
      "clients": [{
        "id": "${UUID}",
        "alterId": 0
      }]
    },
    "streamSettings": {
      "network": "ws",
      "wsSettings": {
        "path": "${WS_PATH}"
      }
    }
  }],
  "outbounds": [{
    "protocol": "freedom",
    "settings": {}
  }]
}
EOF

echo "==== DEBUG: Generated v2ray config file (/etc/v2ray-config.json): ===="
cat /etc/v2ray-config.json
echo "======================================================================"

# ==== 生成 VMess 链接（备注名：油管频道：老罗叔叔｜SAP-VPN直连版）====
# 客户端连接：443 + tls，由 CF 终止后转发到容器 $PORT
PS_NAME="油管频道：老罗叔叔｜SAP-VPN直连版"

VMESS_JSON="$(
	cat <<EOT
{
  "v": "2",
  "ps": "${PS_NAME}",
  "add": "${HOST}",
  "port": "443",
  "id": "${UUID}",
  "aid": "0",
  "scy": "auto",
  "net": "ws",
  "type": "none",
  "host": "${HOST}",
  "path": "${WS_PATH}",
  "tls": "tls"
}
EOT
)"

# base64 一行输出，避免换行导致二维码失效
VMESS_LINK="vmess://$(printf '%s' "$VMESS_JSON" | base64 -w 0 2>/dev/null || printf '%s' "$VMESS_JSON" | base64)"

# ==== 展示信息 ====
echo "================= VMESS (DIRECT) ================="
echo "$VMESS_LINK"
echo "=================================================="

# 打印二维码（没有 qrencode 也不报错）
if command -v qrencode >/dev/null 2>&1; then
	echo "===== SAP-VPN ====="
	qrencode -t ANSIUTF8 "$VMESS_LINK" || echo "(二维码渲染失败，但链接可用)"
	echo "=================================================="
else
	echo "(未安装 qrencode，跳过二维码打印)"
fi

# ====== 自动探测 v2ray 可执行文件 ======
V2RAY_BIN=""
if command -v v2ray >/dev/null 2>&1; then
	V2RAY_BIN="$(command -v v2ray)"
else
	for p in /usr/local/bin/v2ray /usr/bin/v2ray /usr/local/v2ray/v2ray /usr/local/v2ray; do
		[ -x "$p" ] && V2RAY_BIN="$p" && break
	done
fi

if [ -z "$V2RAY_BIN" ]; then
	echo "FATAL: v2ray 可执行文件未找到。请检查镜像内 /usr/local/ 与 /usr/local/bin/。"
	echo "==== DEBUG: Listing /usr/local/bin/ contents: ===="
	ls -l /usr/local/bin/
	echo "=================================================="
	exit 127
fi

echo "==== DEBUG: Found v2ray binary at: ${V2RAY_BIN} ===="
echo "==== DEBUG: Attempting to start v2ray... ===="

# ====== 启动 v2ray 和 cloudflared ======
# 1. 在后台启动 v2ray
"$V2RAY_BIN" run -config /etc/v2ray-config.json &

# 2. 检查是否提供了 Tunnel Token
if [ -n "$TUNNEL_TOKEN" ]; then
	echo "==== DEBUG: Found Tunnel Token, starting cloudflared... ===="
	# 启动 cloudflared，并将其作为主进程 (使用 exec)
	# 它会将外部流量转发到本地的 v2ray 端口
	exec cloudflared tunnel --no-autoupdate run --token "$TUNNEL_TOKEN"
else
	echo "==== WARNING: No TUNNEL_TOKEN found, v2ray is running but not exposed via Cloudflare Tunnel. ===="
	# 如果没有 token，则让 v2ray 作为主进程，保持容器运行
	wait
fi
