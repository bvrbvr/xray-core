#!/bin/bash

# === Reality Health Check Script ===
# This script checks which of the SNI domains is reachable and updates the Xray config accordingly

XRAY_DIR="/root/xray-reality"
CONFIG_FILE="$XRAY_DIR/config.json"
XRAY_CONTAINER="xray-reality"

SNI_LIST=(
    "www.wikipedia.org"
    "www.bing.com"
    "www.amazon.com"
    "www.google.com"
    "www.nfl.com"
)

UUID="457457457457457457"
PRIVATE_KEY="55645645745745"

# Check which SNI responds on port 443
WORKING_SNI=""
for SNI in "${SNI_LIST[@]}"; do
    timeout 5 bash -c "</dev/tcp/$SNI/443" 2>/dev/null
    if [ $? -eq 0 ]; then
        WORKING_SNI=$SNI
        break
    fi
done

if [ -z "$WORKING_SNI" ]; then
    echo "No working SNI found. Aborting."
    exit 1
fi

echo "Working SNI detected: $WORKING_SNI"

# Create updated config.json
temp_config=$(mktemp)
cat > "$temp_config" <<EOF
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
          "dest": "$WORKING_SNI:443",
          "xver": 0,
          "serverNames": [
            "www.wikipedia.org",
            "www.bing.com",
            "www.amazon.com",
            "www.gooogle.com",
            "www.nfl.com"
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

# Replace config and restart Xray
mv "$temp_config" "$CONFIG_FILE"
docker restart "$XRAY_CONTAINER"
echo "Xray restarted with new SNI: $WORKING_SNI"
