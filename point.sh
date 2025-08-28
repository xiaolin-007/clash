#!/usr/bin/env bash
set -e

# 1. 监听端口
INTERNAL_PORT="${PORT:-2053}"
EXTERNAL_PORT="443"

# 2. 客户端 ID
if [ -n "$UUID" ]; then
  CLIENT_ID="$UUID"
elif [ -f /default_uuid ]; then
  CLIENT_ID="$(cat /default_uuid)"
else
  CLIENT_ID="$(openssl rand -hex 16)"
fi

# 3. TLS 域名
DOMAIN="${DOMAIN:-vless.cfapps.us10-001.hana.ondemand.com}"

# 4. 目录准备
CERT_DIR="/etc/xray/certs"
CONFIG_DIR="/etc/xray"
mkdir -p "$CERT_DIR" "$CONFIG_DIR"

# 5. 自签证书（如已存在则跳过）
if [ ! -f "$CERT_DIR/privkey.pem" ] || [ ! -f "$CERT_DIR/fullchain.pem" ]; then
  openssl req -x509 -nodes -newkey rsa:2048 \
    -days 365 \
    -subj "/CN=$DOMAIN" \
    -keyout "$CERT_DIR/privkey.pem" \
    -out "$CERT_DIR/fullchain.pem"
fi

# 6. 生成 Xray 配置
cat > "$CONFIG_DIR/config.json" <<EOF
{
  "inbounds": [
    {
      "port": ${INTERNAL_PORT},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${CLIENT_ID}",
            "flow": "xtls-rprx-direct"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "${CERT_DIR}/fullchain.pem",
              "keyFile": "${CERT_DIR}/privkey.pem"
            }
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF

# 7. 拼接并打印完整 VLESS URI（供客户端一键导入）
VLESS_URI="vless://${CLIENT_ID}@${DOMAIN}:${EXTERNAL_PORT}?encryption=none&security=tls&flow=xtls-rprx-direct&type=tcp#${DOMAIN}"
echo "===== VLESS 节点信息 ====="
echo "URI: ${VLESS_URI}"
echo "=========================="

# 8. 启动 Xray
exec xray -c "${CONFIG_DIR}/config.json"