# 🏗️ Lab Blueprint

**Infraestrutura residencial de alto desempenho com Raspberry Pi + Orange Pi**

Este guia mostra como montar seu próprio laboratório caseiro com dois SBCs (Single Board Computers), orquestração Docker, túneis seguros, agentes automatizados, IA local e acesso do celular via Termux.

---

## 📦 Hardware

### Raspberry Pi 4 (Orquestrador)

| Item | Especificação |
|------|---------------|
| **Modelo** | Raspberry Pi 4 Model B (4GB ou 8GB) |
| **SO** | Raspberry Pi OS (Debian Trixie/Bookworm) |
| **Armazenamento** | SD Card 32GB (SO) + Pendrive 256GB (dados) |
| **Rede** | WiFi 5 (100Mbps) + Tailscale |
| **Função** | Orquestrador, monitor, gateway, DNS |

### Orange Pi Zero 2W (Workhorse)

| Item | Especificação |
|------|---------------|
| **Modelo** | Orange Pi Zero 2W (4GB RAM) |
| **SO** | Armbian / Ubuntu Server (aarch64) |
| **Armazenamento** | SATA3 256GB via porta M.2 |
| **Rede** | WiFi 5 (100Mbps) + Tailscale |
| **Função** | Builds pesados, IA local, armazenamento NFS, offload |

### Por que dois SBCs?

- **RPi**: Interface de rede, Docker estável, comunidade enorme, energia eficiente
- **Orange Pi**: SATA3 nativo (mais rápido que USB do RPi), mais RAM por menos $$
- **Divisão**: Um orquestra, o outro trabalha pesado — se um cair, o diagnóstico pelo outro é imediato

---

## 🌐 Networking

### Topologia

```
Internet
   │
   ├── Roteador (WiFi AP, client isolation ON)
   │       │
   │       ├── RPi 4 ── Tailscale ── Orange Pi
   │       │   (LAN: 192.168.1.10)    (LAN: 192.168.1.5)
   │       │                                 │
   │       └── Celular (Termux)              └── NFS export: /mnt/sata3/rpi
   │               │
   │               └── Tailscale ── RPi ── Orange Pi
```

### Tailscale (VPN Zero-Config)

```bash
# Instalar nos 3 dispositivos (RPi, Orange, Celular)
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up

# RPi IP:      100.X.X.X
# Orange IP:   100.X.X.X
# Celular:     conecta via Tailscale → acessa qualquer um
```

**Por que Tailscale?** WiFi com client isolation bloqueia tráfego TCP entre dispositivos na LAN. Tailscale cria uma rede mesh criptografada que contorna isso.

### Raspberry Pi Connect

Acesso remoto via browser (sem abrir portas):

```bash
# No RPi
sudo apt install rpi-connect
rpi-connect signin
# Acesse: https://connect.raspberrypi.com
```

Alternativa: **Tailscale Serve** para expor serviços locais sem Cloudflare:

```bash
tailscale serve --bg --https=443 localhost:8080
```

---

## 💾 Armazenamento Compartilhado (NFS)

O RPi monta o SATA3 do Orange Pi via NFS através do Tailscale.

### No Orange Pi (servidor)

```bash
# Instalar NFS server
sudo apt install nfs-kernel-server

# Exportar diretório
echo '/mnt/sata3/rpi 100.0.0.0/8(rw,sync,no_subtree_check,no_root_squash)' | sudo tee -a /etc/exports
sudo exportfs -a
```

### No RPi (cliente)

```bash
# Montar via Tailscale
sudo mkdir -p /mnt/nfs_sata3
echo '100.118.21.86:/mnt/sata3/rpi /mnt/nfs_sata3 nfs nolock,soft,intr,timeo=30 0 0' | sudo tee -a /etc/fstab
sudo mount -a
```

### Watchdog NFS

Script que verifica se o NFS responde e tenta remontar:

```bash
#!/bin/bash
# /home/opencode/scripts/nfs_watchdog.sh
mountpoint -q /mnt/nfs_sata3 || mount /mnt/nfs_sata3
```

---

## 🐳 Docker (no RPi)

### Containers essenciais

| Serviço | Função | Porta |
|---------|--------|-------|
| **Nextcloud** | Nuvem pessoal (arquivos, calendário, contatos) | 8082 |
| **Gitea** | Git self-hosted (repositórios privados) | 3001 |
| **Portainer** | Gerenciamento visual de containers | 9000 |
| **OmniRoute** | AI Gateway (proxy para múltiplos provedores) | 20128 |
| **Watchtower** | Atualização automática de containers | — |

### docker-compose exemplo

```yaml
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
```

---

## 🚇 Túneis (Acesso Público)

### Opção 1: Cloudflare Tunnel (recomendado)

```bash
# Instalar cloudflared
sudo apt install cloudflared

# Autenticar
cloudflared tunnel login

# Criar túnel
cloudflared tunnel create meu-tunel

# Configurar DNS
cloudflared tunnel route dns meu-tunel app.meudominio.com

# Rodar como serviço
cloudflared service install
```

### Opção 2: Tailscale Funnel (público, sem Cloudflare)

```bash
# Expor porta HTTP para internet
tailscale funnel --bg 8080
# Acessa: https://<maquina>.ts.net:8080
```

### Opção 3: Serveo (sem instalação)

```bash
ssh -R 80:localhost:8080 serveo.net
```

---

## 🧠 Orange Pi como Workhorse

### Offload de tarefas pesadas

O script `orange_exec.sh` envia comandos via SSH para o Orange Pi:

```bash
#!/bin/bash
# /home/opencode/scripts/orange_exec.sh
ssh orange-heavy "$@"
```

**O que offloadar:**
- `npm run build`, `next build`, `tsc`
- `docker build`, compressão, migrações
- OCR em lote, transcrição de áudio
- Scans de rede demorados
- Qualquer coisa que eleve CPU/RAM do RPi por >5s

### IA Local com Ollama

```bash
# Instalar
curl -fsSL https://ollama.com/install.sh | sh

# Baixar modelo leve
ollama pull tinyllama

# API local
curl http://localhost:11434/api/generate -d '{
  "model": "tinyllama",
  "prompt": "O que é homelab?"
}'
```

Modelos recomendados para 4GB RAM:

| Modelo | Tamanho | Uso |
|--------|---------|-----|
| TinyLlama | 637MB | Assistente leve, respostas rápidas |
| Qwen2.5-Coder 3B | 1.7GB | Geração de código |
| Gemma 2 2B | 1.6GB | Texto geral |

---

## 🤖 Agentes Automatizados

### Arquitetura

```
RPi (Orquestrador)
├── 🤖 Telegram Bot (Go) → interface com usuário
├── 🤖 Scheduler → jobs agendados (manhã, tarde, noite)
├── 🤖 Watchdogs → healthcheck a cada 5min
├── 🤖 Backup → backup_conversation.sh, backup_local.sh
├── 🤖 Scanner → scan.py (rede a cada 30min)
├── 🤖 Jornal → jornal_pro.py (6h, 10h, 14h, 18h, 22h)
├── 🤖 Pesquisa → pesquisa.py (notícias a cada hora)
├── 🤖 Auditoria → auditoria_local.sh (diário)
└── 🤖 Triagem → triagem.sh (alertas)

Orange Pi (Worker)
└── 🤖 Healthcheck → responde ping do RPi
```

### Exemplo: Bot Watchdog

```bash
#!/bin/bash
# /home/opencode/scripts/bot_watchdog.sh
if ! systemctl is-active --quiet gobot; then
    echo "[WATCHDOG] Bot offline. Reiniciando..."
    systemctl restart gobot
    curl -s "https://api.telegram.org/bot$TOKEN/sendMessage" \
        -d "chat_id=$ADMIN&text=⚠️ Bot reiniciado pelo watchdog"
fi
```

---

## 📱 Termux (Controle do Celular)

Termux transforma seu Android em um terminal Linux completo para gerenciar o laboratório.

### Instalação

```bash
# 1. Instale Termux pelo F-Droid (NÃO pela Play Store)
# 2. Atualize
pkg update && pkg upgrade

# 3. Instale ferramentas essenciais
pkg install git openssh tailscale python nodejs-lts
```

### Conectar ao RPi/Orange Pi

```bash
# Via Tailscale (recomendado)
ssh opencode@100.127.136.6

# Via LAN (se não tiver client isolation)
ssh opencode@192.168.1.10
```

### Comandos úteis no Termux

```bash
# Status do lab
alias lab-status='ssh opencode@100.127.136.6 "docker ps --format \"table {{.Names}}\t{{.Status}}\t{{.Ports}}\""'

# Últimos logs
alias lab-logs='ssh opencode@100.127.136.6 "tail -20 /home/opencode/logs/*.log"'

# Espaço em disco
alias lab-df='ssh opencode@100.127.136.6 "df -h | grep -E \"(pendrive|nfs|sata|sd )\""'

# Bot status
alias bot-status='ssh opencode@100.127.136.6 "systemctl status gobot --no-pager -l | head -15"'

# Consultar IA no Orange
alias ia-chat='ssh root@192.168.1.5 "ia chat"'
```

### Script automático de conexão

```bash
#!/data/data/com.termux/files/usr/bin/bash
# ~/.termux/connect-lab.sh
echo "🔌 Conectando ao Laboratório..."
echo "1) RPi (orquestrador)"
echo "2) Orange Pi (workhorse)"
echo "3) Ambos (tmux)"
read -p "Escolha: " opt

case $opt in
  1) ssh opencode@100.127.136.6 ;;
  2) ssh root@192.168.1.5 ;;
  3) tmux new-session -s lab \; \
       send-keys "ssh opencode@100.127.136.6" C-m \; \
       split-window -h \; \
       send-keys "ssh root@192.168.1.5" C-m \;
esac
```

### Notificações Push no Celular

Via Telegram Bot — qualquer alerta do laboratório chega como mensagem no seu Telegram:

```
📊 Relatório Diário — Laboratório

✅ Containers: 6/6 online
✅ Disco RPi: 47% usado (11G livre)
✅ Disco Orange: 20% usado (161G livre)
✅ Uptime RPi: 12d 4h
⚠️ NFS: 3 tentativas de remontagem nas últimas 24h
```

---

## 🧩 Agentes Customizáveis

### Tipos de Agente

| Tipo | Descrição | Exemplo |
|------|-----------|---------|
| **Monitor** | Verifica serviço, alerta se cair | watchdog, healthcheck |
| **Scheduler** | Executa ação em horário fixo | jornal, pesquisa, versículo |
| **Worker** | Processa dados sob demanda | OCR, IA, build |
| **Orquestrador** | Coordena outros agentes | main.go do bot |
| **Auditor** | Gera relatórios periódicos | auditoria_local.sh |

### Paradigma: "Um agente, uma responsabilidade"

Cada script faz UMA coisa e faz bem. A composição é feita por:

1. **Cron** — agenda execução
2. **Bot do Telegram** — interface unificada
3. **Watchdog** — garante que está rodando

### Exemplo: Criar um novo agente

```bash
#!/bin/bash
# /home/opencode/scripts/meu_agente.sh

NOME="Meu Agente"
LOG="/home/opencode/logs/meu_agente.log"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] $NOME: iniciando" >> "$LOG"

# --- lógica aqui ---
echo "Olá, mundo!" >> "$LOG"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] $NOME: concluído" >> "$LOG"
```

Adicionar ao cron:
```cron
*/30 * * * * /home/opencode/scripts/meu_agente.sh
```

---

## 💿 Backup (Regra dos 3)

| Cópia | Local | Frequência | Retenção |
|-------|-------|-----------|----------|
| **1ª** | SD Card (local) | 5min (conversas) | 24h |
| **2ª** | Pendrive 256GB (USB RPi) | 4h (Docker) | 7 dias |
| **3ª** | Google Drive (rclone) | Diário 05:30 | 30 dias |
| **Extra** | Orange Pi SATA3 (NFS) | 3h (offload) | 7 dias |

### Script de backup Docker

```bash
#!/bin/bash
# /home/opencode/scripts/backup_local.sh
BACKUP_DIR="/mnt/nfs_sata3/backups/docker"
DATE=$(date +%Y%m%d_%H%M%S)

for vol in $(docker volume ls -q); do
    docker run --rm -v $vol:/data -v $BACKUP_DIR:/backup \
        alpine tar czf "/backup/${vol}_${DATE}.tgz" -C /data .
done

# Limpar backups com mais de 7 dias
find $BACKUP_DIR -name "*.tgz" -mtime +7 -delete
```

---

## 🚀 Deploy Rápido

### setup.sh

```bash
#!/bin/bash
set -euo pipefail
echo "🚀 Iniciando setup do Laboratório..."

# 1. Atualizar sistema
sudo apt update && sudo apt upgrade -y

# 2. Instalar Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# 3. Instalar Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# 4. Instalar ferramentas
sudo apt install -y git curl wget htop tmux nfs-common

# 5. Criar diretórios
mkdir -p /home/$USER/{scripts,logs,backups}

echo "✅ Setup concluído! Reinicie o shell com: exec \$SHELL -l"
```

---

## 📚 Glossário

| Termo | Significado |
|-------|-------------|
| **SBC** | Single Board Computer (RPi, Orange Pi) |
| **Tailscale** | VPN mesh zero-config baseada em WireGuard |
| **Client Isolation** | Recurso de WiFi que bloqueia comunicação entre dispositivos na mesma LAN |
| **NFS** | Network File System — compartilha diretórios pela rede |
| **Offload** | Delegar tarefa pesada para outra máquina |
| **Workhorse** | Máquina que faz o trabalho braçal |
| **Orquestrador** | Máquina que coordena as demais |
| **Termux** | Terminal Linux para Android |
| **Watchdog** | Script que monitora e reinicia serviços |
| **Scheduler** | Agendador de tarefas (cron) |

---

## 📜 Licença

MIT — Use, modifique, compartilhe. Só não venda como seu sem alterar.

---

**Feito com ☕ e 🧠 por Miguel F. Araujo — Código bom resolve problema real, roda em produção, tem documentação, backup, manutenção e pode ser explicado para quem vai usar.**
