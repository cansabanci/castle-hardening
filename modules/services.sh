#!/bin/bash
#
# services.sh - Servis sertleştirme modülü

echo -e "${GREEN}[*] Servis sertleştirme modülü çalışıyor...${NC}"

DANGEROUS_SERVICES=(
    "telnet"        # şifresiz uzak erişim (SSH varken gereksiz + tehlikeli)
    "telnetd"
    "rsh-server"    # eski güvensiz uzak shell
    "rlogin"
    "vsftpd"        # FTP - şifresiz, gerekmiyorsa kapat
    "tftpd"         # trivial FTP - çok güvensiz
    "xinetd"        # eski servis yöneticisi
    "nis"           # eski ağ bilgi servisi
    "rpcbind"       # RPC - sık saldırı hedefi
    "avahi-daemon"  # ağ keşif servisi (gereksiz bilgi sızdırır)
    "cups"          # yazıcı servisi (sunucuda gereksiz)
)

DISABLED_COUNT=0

for service in "${DANGEROUS_SERVICES[@]}"; do
    if systemctl list-unit-files | grep -q "^${service}"; then
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            if [ "$DRY_RUN" = "true" ]; then
                echo -e "  ${YELLOW}[DRY-RUN]${NC} Yapılacak: $service durdurulacak ve devre dışı bırakılacak"
            else
                systemctl stop "$service" 2>/dev/null
                systemctl disable "$service" 2>/dev/null
                echo "[*] Kapatıldı: $service"
           fi
           DISABLED_COUNT=$((DISABLED_COUNT+1))
    fi
  fi
done

if [ "$DISABLED_COUNT" -eq 0 ]; then
    echo "[*] Kapatılacak tehlikeli servis bulunamadı (sistem zaten temiz)"
else
    echo -e "${GREEN}[+] ${DISABLED_COUNT} tehlikeli servis kapatıldı.${NC}"
fi

# Çalışan tüm dinleyen servisleri raporla (kullanıcı görsün)
echo "[*] Şu an dinleyen (açık) servisler:"
ss -tulnp 2>/dev/null | grep LISTEN | awk '{print "    " $1 " " $5}' | sort -u

echo -e "${GREEN}[+] Servis sertleştirme tamamlandı.${NC}"
