#!/bin/bash
#
# services.sh


SERVICE_LOG="/tmp/castle_service_states.log"

DANGEROUS_SERVICES=(
    "telnet" "telnetd" "rsh-server" "rlogin" "vsftpd" 
    "tftpd" "xinetd" "nis" "rpcbind" "avahi-daemon" "cups"
)

# ==============================================================================
# ROLLBACK  MODU
# ==============================================================================
if [ "${MODE:-HARDEN}" = "ROLLBACK" ]; then
    echo -e "${YELLOW}[*] Servis sertleştirmesi geri alınıyor...${NC}"

    if [ -f "$SERVICE_LOG" ]; then
        echo "[*] Daha önce durdurulan servisler tekrar etkinleştiriliyor..."
        while IFS=: read -r service was_enabled; do
            if [ "$was_enabled" = "enabled" ]; then
                castle_run "$service tekrar etkinleştiriliyor ve başlatılıyor" systemctl enable --now "$service"
            else
                echo "  [-] $service daha önce de kapalıydı, işlem yapılmadı."
            fi
        done < "$SERVICE_LOG"
        castle_run "Servis log dosyası temizleniyor" rm -f "$SERVICE_LOG"
    else
        echo -e "${YELLOW}[!] Servis durum kaydı bulunamadı. Servislere müdahale edilmedi.${NC}"
    fi

# ==============================================================================
# HARDEN  MODU
# ==============================================================================
else
    echo -e "${GREEN}[*] Servis sertleştirme modülü çalışıyor...${NC}"

    > "$SERVICE_LOG"
    DISABLED_COUNT=0

    for service in "${DANGEROUS_SERVICES[@]}"; do
        if systemctl list-unit-files 2>/dev/null | grep -q -- "^${service}"; then

            IS_ENABLED=$(systemctl is-enabled "$service" 2>/dev/null)

            if systemctl is-active --quiet "$service" 2>/dev/null; then
                castle_run "$service durdurulacak ve devre dışı bırakılacak" systemctl disable --now "$service"
                echo "${service}:${IS_ENABLED}" >> "$SERVICE_LOG"
                DISABLED_COUNT=$((DISABLED_COUNT+1))
            fi
        fi
    done

    if [ "$DISABLED_COUNT" -eq 0 ]; then
        echo "[*] Kapatılacak tehlikeli servis bulunamadı (sistem zaten temiz)"
        rm -f "$SERVICE_LOG"
    else
        echo -e "${GREEN}[+] ${DISABLED_COUNT} tehlikeli servis kapatıldı.${NC}"
    fi
fi

castle_run "Aktif dinleyen (açık) servisler listeleniyor" \
    ss -tulnp 2>/dev/null | grep LISTEN | awk '{print "    " $1 " " $5}' | sort -u

echo -e "${GREEN}[+] Servis sertleştirme tamamlandı.${NC}"
