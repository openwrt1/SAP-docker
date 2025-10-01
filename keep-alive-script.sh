#!/bin/sh
set -e

echo "--- Keep-Alive Script Started ---"

# 检查必要的环境变量
if [ -z "$CF_API" ] || [ -z "$CF_USERNAME" ] || [ -z "$CF_PASSWORD" ] || [ -z "$CF_ORG" ] || [ -z "$CF_SPACE" ] || [ -z "$CF_APP" ]; then
	echo "FATAL: One or more required CF environment variables are not set."
	exit 1
fi

echo "1. Setting API endpoint to ${CF_API}"
cf api "${CF_API}"

echo "2. Authenticating as ${CF_USERNAME}"
cf auth "${CF_USERNAME}" "${CF_PASSWORD}"

echo "3. Targeting Org '${CF_ORG}' and Space '${CF_SPACE}'"
cf target -o "${CF_ORG}" -s "${CF_SPACE}"

echo "4. Checking status of app '${CF_APP}'..."
# 获取应用第一个实例的状态 (例如 "running", "down", "crashed")
# `|| true` 可以防止在应用停止、没有实例输出时 grep 失败导致脚本退出
APP_STATUS=$(cf app "${CF_APP}" | grep '^#0' | awk '{print $2}' || true)

if [ "$APP_STATUS" = "running" ]; then
	echo "App is already running. No action needed."
	echo "App is already running. No action needed."
	echo "App is already running. No action needed."
	echo "App is already running. No action needed."
else
	echo "App is not running (status: '${APP_STATUS:-stopped}'). Attempting to start it..."
	cf start "${CF_APP}"
fi

echo "--- Keep-Alive Script Finished Successfully ---"
