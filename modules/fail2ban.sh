#!/bin/bash
#
# fail2ban.sh - Brute-force koruması modülü

echo -e "${GREEN}[*] fail2ban modülü çalışıyor...${NC}"

if ! command -v fail2ban-server &> /dev/null; then
    echo "[*] fail2ban kurulu değil, kuruluyor..."
    run apt-get install fail2ban -y
fi

JAIL_DIR="/etc/fail2ban/jail.d"
CASTLE_JAIL="${JAIL_DIR}/castle-sshd.local"
mkdir -p "$JAIL_DIR"

if [ -f "$CASTLE_JAIL" ] && [ "$DRY_RUN" != "true" ]; then
    cp "$CASTLE_JAIL" "${CASTLE_JAIL}.backup.$(date +%Y%m%d_%H%M%S)"
fi

SSH_PORT=$(sshd -T 2>/dev/null | awk '/^port / {print $2}' | head -1)
SSH_PORT=${SSH_PORT:-22}
echo "[*] SSH portu tespit edildi: $SSH_PORT"

if [ "$DRY_RUN" = "true" ]; then
    echo -e "  ${YELLOW}[DRY-RUN]${NC} Yapılacak: fail2ban config yazılacak (jail.d/castle-sshd.local, SSH port: $SSH_PORT)"
    echo -e "  ${YELLOW}[DRY-RUN]${NC} Yapılacak: fail2ban enable + config test + reload"
else

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
findtime = 600
maxretry = 2
bantime = 3600
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
fi
