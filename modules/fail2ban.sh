#!/bin/bash
#
# fail2ban.sh - Brute-force koruması modülü
# Çok deneme yapan IP'leri otomatik tespit edip banlar (IPS mantığı)
#

echo -e "${GREEN}[*] fail2ban modülü çalışıyor...${NC}"

# fail2ban kurulu mu, değilse kur
if ! command -v fail2ban-server &> /dev/null; then
    echo "[*] fail2ban kurulu değil, kuruluyor..."
    apt-get install fail2ban -y
fi

# Yerel yapılandırma dosyası oluştur (jail.local)
# NOT: jail.conf'a değil jail.local'a yazıyoruz — güncellemelerde ezilmesin
cat > /etc/fail2ban/jail.local << 'JAIL'
[DEFAULT]
# Ban süresi: 1 saat (geçici ban - false positive olursa masum kullanıcı geri döner)
bantime = 1h

# Bu süre içinde (10 dakika) yapılan denemeler sayılır
findtime = 10m

# Kaç başarısız denemeden sonra banlansın
maxretry = 5

# Banlama yöntemi: ufw ile entegre (bizim firewall'ımız)
banaction = ufw

# Whitelist - bu IP'ler ASLA banlanmaz (kendi IP'lerin, localhost)
ignoreip = 127.0.0.1/8 ::1

# SSH korumasını aç
[sshd]
enabled = true
port = ssh
maxretry = 5

[recidive]
enabled = true
logpath = /var/log/fail2ban.log
banaction = ufw
findtime = 1d
maxretry = 2
bantime = -1
JAIL

echo "[*] fail2ban yapılandırması oluşturuldu (jail.local)"

# fail2ban servisini başlat ve boot'ta otomatik aç
systemctl enable fail2ban 2>/dev/null
systemctl restart fail2ban

# Durumu kontrol et
sleep 2
if systemctl is-active --quiet fail2ban; then
    echo -e "${GREEN}[+] fail2ban aktif (SSH brute-force koruması açık).${NC}"
    echo "[*] Ban kuralları: 5 başarısız denemede 1 saat ban"
else
    echo -e "${RED}[!] fail2ban başlatılamadı, kontrol edin.${NC}"
fi
