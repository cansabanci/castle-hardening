[sshd]
enabled = true
port = ${SSH_PORT}
maxretry = 5#!/bin/bash
#
# fail2ban.sh - Brute-force koruması modülü
# Çok deneme yapan IP'leri otomatik tespit edip banlar (IPS mantığı)
#

echo -e "${GREEN}[*] fail2ban modülü çalışıyor...${NC}"

if ! command -v fail2ban-server &> /dev/null; then
    echo "[*] fail2ban kurulu değil, kuruluyor..."
    apt-get install fail2ban -y
fi

JAIL_DIR="/etc/fail2ban/jail.d"
CASTLE_JAIL="${JAIL_DIR}/castle-sshd.local"
mkdir -p "$JAIL_DIR"

if [ -f "$CASTLE_JAIL" ]; then
    cp "$CASTLE_JAIL" "${CASTLE_JAIL}.backup.$(date +%Y%m%d_%H%M%S)"
fi

SSH_PORT=$(sshd -T 2>/dev/null | awk '/^port / {print $2}' | head -1)
SSH_PORT=${SSH_PORT:-22}
echo "[*] SSH portu tespit edildi: $SSH_PORT"

cat > "$CASTLE_JAIL" << JAIL

[DEFAULT]
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
findtime = 1d
maxretry = 2
bantime = -1
JAIL

echo "[*] fail2ban yapılandırması yazıldı (jail.d/castle-sshd.local)"

systemctl enable fail2ban 2>/dev/null

echo "[*] fail2ban yapılandırması test ediliyor..."
if fail2ban-client -t &>/dev/null; then
    echo -e "${GREEN}[+] fail2ban yapılandırması geçerli.${NC}"
    systemctl reload fail2ban 2>/dev/null || systemctl restart fail2ban
    echo -e "${GREEN}[+] fail2ban yeniden yüklendi (reload).${NC}"
    echo "[*] Ban kuralları: 5 başarısız denemede 1 saat ban"
else
    echo -e "${RED}[!] fail2ban yapılandırma hatası! Değişiklik uygulanmadı.${NC}"
    return 1
fi
