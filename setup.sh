#!/bin/bash
set -euo pipefail

echo "🚀 Setup inicial do Laboratório"
echo "================================"

# 1. Sistema
echo "[1/6] Atualizando sistema..."
sudo apt update && sudo apt upgrade -y

# 2. Docker
echo "[2/6] Instalando Docker..."
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker "$USER"
echo "  ✅ Docker instalado (faça logout/login para usar sem sudo)"

# 3. Tailscale
echo "[3/6] Instalando Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh
echo "  ✅ Tailscale instalado. Execute: sudo tailscale up"

# 4. Ferramentas
echo "[4/6] Instalando ferramentas..."
sudo apt install -y git curl wget htop tmux nfs-common net-tools

# 5. Diretórios
echo "[5/6] Criando diretórios..."
mkdir -p "$HOME"/{scripts,logs,backups,data}

# 6. Docker Compose base
echo "[6/6] Criando docker-compose base..."
if [ ! -f "docker-compose.yml" ]; then
  cat > docker-compose.yml << 'DOCKERCOMPOSE'
version: "3.9"
services:
  portainer:
    image: portainer/portainer-ce:latest
    restart: unless-stopped
    ports:
      - "9000:9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data

volumes:
  portainer_data:
DOCKERCOMPOSE
  echo "  ✅ docker-compose.yml criado"
fi

echo ""
echo "🎉 Setup concluído!"
echo ""
echo "Próximos passos:"
echo "  1. sudo tailscale up         # Conectar Tailscale"
echo "  2. docker compose up -d      # Subir Portainer"
echo "  3. Acesse http://localhost:9000"
echo "  4. Leia o README.md para configuração completa"
echo ""
