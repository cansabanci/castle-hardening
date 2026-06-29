#!/bin/bash
#
# ssh.sh - SSH sertleştirme modülü
# Güvenli/kademeli yaklaşım — kullanıcıyı sistemden kilitlemez
#

echo -e "${GREEN}[*] SSH sertleştirme modülü çalışıyor...${NC}"

SSHD_CONFIG="/etc/ssh/sshd_config"

# SSH kurulu mu kontrol et
if [ ! -f "$SSHD_CONFIG" ]; then
    echo -e "${RED}[!] SSH sunucusu kurulu değil, modül atlanıyor.${NC}"
    return 0
fi

# Yedek al (her zaman! geri dönebilmek için)
if [ "$DRY_RUN" = "true" ]; then
    echo -e "  ${YELLOW}[DRY-RUN]${NC} Yapılacak: sshd_config yedeklenecek"
else
    cp "$SSHD_CONFIG" "${SSHD_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    echo "[*] sshd_config yedeklendi"
fi

# Bir ayarı güvenli şekilde set eden yardımcı fonksiyon
# Ayar varsa değiştirir, yoksa ekler (idempotent)
set_ssh_option() {
    local key="$1"
    local value="$2"
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} SSH ayarı: $key $value"
        return
    fi
    if grep -qE "^#?\s*${key}\s" "$SSHD_CONFIG"; then
        sed -i "s|^#\?\s*${key}\s.*|${key} ${value}|" "$SSHD_CONFIG"
    else
        echo "${key} ${value}" >> "$SSHD_CONFIG"
    fi
}

# 1. Root ile direkt SSH girişini yasakla
# Saldırgan root'a doğrudan brute-force yapamaz
set_ssh_option "PermitRootLogin" "no"

# 2. Boş şifre ile girişi yasakla
set_ssh_option "PermitEmptyPasswords" "no"

# 3. Maksimum kimlik doğrulama denemesi (brute-force yavaşlatma)
set_ssh_option "MaxAuthTries" "3"

# 4. Bağlantı zaman aşımı (asılı kalan bağlantıları kes)
set_ssh_option "LoginGraceTime" "30"

# 5. Boşta kalan oturumu otomatik kapat
set_ssh_option "ClientAliveInterval" "300"
set_ssh_option "ClientAliveCountMax" "2"

# 6. X11 forwarding kapat (gereksiz, saldırı yüzeyi)
set_ssh_option "X11Forwarding" "no"

# 7. Protokol 2 zorla (eski güvensiz protokol 1 yasak)
set_ssh_option "Protocol" "2"

# 8. Tünelleme ve forwarding kapat (pivoting + veri sızdırma engeli)
set_ssh_option "AllowTcpForwarding" "no"
set_ssh_option "AllowAgentForwarding" "no"
set_ssh_option "PermitTunnel" "no"
set_ssh_option "GatewayPorts" "no"

# 9. Eski/zayıf kimlik doğrulama yöntemlerini kapat
set_ssh_option "IgnoreRhosts" "yes"
set_ssh_option "HostbasedAuthentication" "no"

# 10. Strict mode — yanlış izinli key dosyalarını reddet
set_ssh_option "StrictModes" "yes"

# 11. Bağlantı sınırları (brute-force/DoS koruması)
set_ssh_option "MaxSessions" "4"
set_ssh_option "MaxStartups" "10:30:60"

# 12. Gereksiz DNS sorgusunu kapat
set_ssh_option "UseDNS" "no"

# 13. Yasal uyarı banner'ı oluştur ve ayarla
if [ "$DRY_RUN" = "true" ]; then
    echo -e "  ${YELLOW}[DRY-RUN]${NC} Yapılacak: SSH uyarı banner'ı oluşturulacak"
else
    cat > /etc/ssh/castle_banner << 'BANNER'
***************************************************************
  YETKISIZ ERISIM YASAKTIR
  Bu sistem sadece yetkili kullanicilar icindir.
  Tum baglantilar loglanmakta ve izlenmektedir.
***************************************************************
BANNER
fi
set_ssh_option "Banner" "/etc/ssh/castle_banner"

echo -e "${GREEN}[+] SSH sertleştirildi (root login kapalı, deneme limiti, timeout).${NC}"
echo -e "${RED}[!] NOT: Key authentication için ek adım gerekir. Önce SSH key'inizi${NC}"
echo -e "${RED}    yüklediğinizden emin olmadan 'PasswordAuthentication no' YAPMAYIN!${NC}"

# Yapılandırmayı test et (hatalıysa SSH'ı yeniden başlatma!)
if [ "$DRY_RUN" = "true" ]; then
    echo -e "  ${YELLOW}[DRY-RUN]${NC} Yapılacak: sshd config test edilip SSH servisi reload edilecek"
elif sshd -t 2>/dev/null; then
    echo "[*] sshd config geçerli, servis yeniden başlatılıyor..."
    systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null
    echo -e "${GREEN}[+] SSH servisi yeniden başlatıldı.${NC}"
else
    echo -e "${RED}[!] sshd config hatası! Değişiklikler uygulanmadı, yedekten dönülüyor.${NC}"
    cp "${SSHD_CONFIG}.backup."* "$SSHD_CONFIG" 2>/dev/null
fi
