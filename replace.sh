#!/bin/bash

# === Generate UUID and Reality keypair ===
UUID=$(uuidgen)
KEYS=$(docker run --rm ghcr.io/xtls/xray-core x25519)

PRIVATE_KEY=$(echo "$KEYS" | grep "Private key" | awk '{print $3}')
PUBLIC_KEY=$(echo "$KEYS" | grep "Public key" | awk '{print $3}')

# === Validate key generation ===
if [[ -z "$PRIVATE_KEY" || -z "$PUBLIC_KEY" ]]; then
  echo "❌ Failed to generate Reality keys!"
  echo "🔎 Raw output:"
  echo "$KEYS"
  exit 1
fi

# === Get external IP (fallback to 127.0.0.1) ===
MY_IP=$(curl -s https://api.ipify.org || echo "127.0.0.1")

# === Update values in healthcheck.sh (if exists) ===
if [[ -f healthcheck.sh ]]; then
  sed -i "s/^UUID=.*/UUID=\"$UUID\"/" healthcheck.sh
  sed -i "s/^PRIVATE_KEY=.*/PRIVATE_KEY=\"$PRIVATE_KEY\"/" healthcheck.sh
  chmod +x healthcheck.sh
fi

# === Custom list of SNI websites ===
SNI_LIST=(
  "www.wikipedia.org"
  "www.bing.com"
  "www.amazon.com"
  "www.gooogle.com"
  "www.nfl.com"
)
DEST="${SNI_LIST[0]}:443"

# === Write config.json ===
cat > config.json <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 5443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "flow": ""
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "$DEST",
          "xver": 0,
          "serverNames": [
            "${SNI_LIST[0]}",
            "${SNI_LIST[1]}",
            "${SNI_LIST[2]}",
            "${SNI_LIST[3]}",
            "${SNI_LIST[4]}"
          ],
          "privateKey": "$PRIVATE_KEY",
          "shortIds": [""]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF

# === Restart Docker container ===
echo "🔁 Restarting Docker container with new config..."
docker compose down
docker compose up -d

# === Show connection info ===
echo ""
echo "✅ Reality configuration updated!"
echo "🧬 UUID: $UUID"
echo "🔐 Private Key: $PRIVATE_KEY"
echo "📡 Public Key:  $PUBLIC_KEY"
echo "🌐 Server IP:   $MY_IP"
echo ""

# === Generate VLESS link for client (using first SNI) ===
VLESS_LINK="vless://$UUID@$MY_IP:5443?encryption=none&flow=&type=tcp&security=reality&sni=${SNI_LIST[0]}&fp=chrome&pbk=$PUBLIC_KEY#RealityVPN"

echo "📲 VLESS link for Shadowrocket / v2rayN:"
echo "$VLESS_LINK"

# === Generate QR code (if available) ===
if command -v qrencode &> /dev/null; then
  echo ""
  echo "🧾 QR Code:"
  qrencode -t ANSIUTF8 "$VLESS_LINK"
else
  echo ""
  echo "ℹ️ Tip: install qrencode to generate QR code:"
  echo "    sudo apt install qrencode"
fi

# === Optional cleanup of legacy image ===
docker image rm -f teddysun/xray:latest 2>/dev/null

