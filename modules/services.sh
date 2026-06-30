#!/bin/bash
#
# services.sh

echo -e "${GREEN}[*] Servis sertleştirme modülü çalışıyor...${NC}"

DANGEROUS_SERVICES=(
    "telnet"         # Şifresiz uzak erişim
    "telnetd"
    "rsh-server"     # Eski güvensiz uzak shell
    "rlogin"
    "vsftpd"         # FTP (şifresiz dosya aktarımı)
    "tftpd"          # Trivial FTP
    "xinetd"         # Eski servis yöneticisi
    "nis"            # Eski ağ bilgi servisi
    "rpcbind"        # RPC (uzaktan prosedür çağrısı)
    "avahi-daemon"   # Ağ keşif servisi (mDNS)
    "cups"           # Yazıcı servisi
)

DISABLED_COUNT=0

for service in "${DANGEROUS_SERVICES[@]}"; do
    if systemctl list-unit-files 2>/dev/null | grep -q -- "^${service}"; then
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            castle_run "$service durdurulacak ve devre dışı bırakılacak" \
                systemctl disable --now "$service"
            DISABLED_COUNT=$((DISABLED_COUNT+1))
        fi
    fi
done

if [ "$DISABLED_COUNT" -eq 0 ]; then
    echo "[*] Kapatılacak tehlikeli servis bulunamadı (sistem zaten temiz)"
else
    echo -e "${GREEN}[+] ${DISABLED_COUNT} tehlikeli servis kapatıldı.${NC}"
fi

castle_run "Aktif dinleyen (açık) servisler listeleniyor" \
    ss -tulnp 2>/dev/null | grep LISTEN | awk '{print "    " $1 " " $5}' | sort -u

echo -e "${GREEN}[+] Servis sertleştirme tamamlandı.${NC}"
