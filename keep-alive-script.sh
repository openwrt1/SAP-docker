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

echo "4. Restarting app '${CF_APP}' to keep it alive"
cf restart "${CF_APP}"

echo "--- Keep-Alive Script Finished Successfully ---"
