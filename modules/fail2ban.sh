#!/bin/bash
#
# fail2ban.sh

echo -e "${GREEN}[*] fail2ban modülü çalışıyor...${NC}"

if ! command -v fail2ban-server &> /dev/null; then
    run "fail2ban paketi kurulacak" apt-get install fail2ban -y
fi

JAIL_DIR="/etc/fail2ban/jail.d"
CASTLE_JAIL="${JAIL_DIR}/castle-sshd.local"
mkdir -p "$JAIL_DIR"

# Mevcut Castle config'i varsa yedekle (kullanıcının jail.local'ı korunur)
if [ -f "$CASTLE_JAIL" ]; then
    run "Mevcut fail2ban config yedeklenecek" cp "$CASTLE_JAIL" "${CASTLE_JAIL}.backup.$(date +%Y%m%d_%H%M%S)"
fi

SSH_PORT=$(sshd -T 2>/dev/null | awk '/^port / {print $2}' | head -1)
SSH_PORT=${SSH_PORT:-22}
echo "[*] SSH portu tespit edildi: $SSH_PORT"

CASTLE_JAIL_CONTENT="[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5
banaction = ufw
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled = true
port = ${SSH_PORT}
maxretry = 5

[recidive]
enabled = true
logpath = /var/log/fail2ban.log
banaction = ufw
findtime = 600
maxretry = 2
bantime = 3600"

ensure_file "$CASTLE_JAIL" "fail2ban yapılandırması yazıldı (jail.d/castle-sshd.local)" "$CASTLE_JAIL_CONTENT"

run "fail2ban boot'ta etkinleştirilecek" systemctl enable fail2ban

safe_service_reload "fail2ban" "fail2ban-client -t" "reload"
