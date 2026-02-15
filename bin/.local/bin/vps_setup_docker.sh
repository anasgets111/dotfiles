#!/usr/bin/env bash
set -eu

# ==============================================================================
# BLUEPRINT: SacredCube Communication Stack (VoceChat + Caddy)
# TARGET: Fresh VPS (Ubuntu/Debian) | 1GB RAM
# FEATURES:
#   - Internal Bridge Networking
# ==============================================================================

# OS Detection
if ! command -v apt-get &>/dev/null; then
    echo "Error: This script requires apt-get (Debian/Ubuntu based system)"
    exit 1
fi

# --- 1. CONFIGURATION ---
DOMAIN_CHAT="${1:-sacredcube.duckdns.org}"
APP_DIR="$HOME/sacredcube"

# --- 2. SYSTEM PREP ---
echo "🛠️  Preparing System..."

# Install Docker (if missing)
if ! command -v docker &> /dev/null; then
    echo "📦 Installing Docker..."
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker "$USER"
fi

# --- 3. DIRECTORY SETUP ---
echo "📂 Creating Directories at $APP_DIR..."
mkdir -p "$APP_DIR"/{data/{vocechat,client},caddy_{data,config}}

CURRENT_UID=$(id -u)
CURRENT_GID=$(id -g)

# --- 4. CONFIG GENERATION ---
cd "$APP_DIR"

# Caddyfile (Reverse Proxy)
cat <<EOF > Caddyfile
$DOMAIN_CHAT {
    reverse_proxy vocechat:3000
}
EOF

# Docker Compose
cat <<EOF > docker-compose.yml
services:
  vocechat:
    image: privoce/vocechat-server:latest
    container_name: vocechat
    restart: unless-stopped
    user: "$CURRENT_UID:$CURRENT_GID"
    volumes:
      - ./data/vocechat:/home/vocechat-server/data
      - ./data/client:/home/vocechat-server/client
    networks:
      - sacred_net

  caddy:
    image: caddy:latest
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - ./caddy_data:/data
      - ./caddy_config:/config
    networks:
      - sacred_net

networks:
  sacred_net:
    driver: bridge
EOF

# --- 5. PORT CHECK ---
echo "🔍 Checking port availability..."
if ss -tlnp | grep -q ':80\|:443'; then
    echo "❌ Error: Ports 80 or 443 are already in use"
    ss -tlnp | grep ':80\|:443'
    exit 1
fi

# --- 6. LAUNCH ---
echo "🚀 Launching Services..."

echo "ℹ️  Note: Added user to docker group. Log out and back in to use docker without sudo."
sudo docker compose up -d

echo -e "✅ DEPLOYMENT COMPLETE\nURL: https://$DOMAIN_CHAT"
