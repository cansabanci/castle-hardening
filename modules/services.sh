#!/bin/bash
#
# services.sh


# Durum kaydı /tmp yerine root'a ait kalıcı bir dizinde tutulur:
# - /tmp herkese yazılabilir; root'un tahmin edilebilir bir adla oraya yazması
#   symlink saldırısına açıktır (ör. dosya /etc/shadow'a link verilmişse
#   "> dosya" onu sıfırlar).
# - /tmp yeniden başlatmada silinir; rollback kaydı kaybolurdu.
STATE_DIR="/var/lib/castle"
SERVICE_LOG="${STATE_DIR}/service_states.log"

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

    if [ "${DRY_RUN:-false}" != "true" ]; then
        install -d -m 0700 -o root -g root "$STATE_DIR"
        : > "$SERVICE_LOG"
    fi
    DISABLED_COUNT=0

    for service in "${DANGEROUS_SERVICES[@]}"; do
        if systemctl list-unit-files 2>/dev/null | grep -q -- "^${service}\.service"; then

            IS_ENABLED=$(systemctl is-enabled "$service" 2>/dev/null)

            if systemctl is-active --quiet "$service" 2>/dev/null; then
                castle_run "$service durdurulacak ve devre dışı bırakılacak" systemctl disable --now "$service"
                [ "${DRY_RUN:-false}" = "true" ] || echo "${service}:${IS_ENABLED}" >> "$SERVICE_LOG"
                DISABLED_COUNT=$((DISABLED_COUNT+1))
            fi
        fi
    done

    if [ "$DISABLED_COUNT" -eq 0 ]; then
        echo "[*] Kapatılacak tehlikeli servis bulunamadı (sistem zaten temiz)"
        [ "${DRY_RUN:-false}" = "true" ] || rm -f "$SERVICE_LOG"
    else
        echo -e "${GREEN}[+] ${DISABLED_COUNT} tehlikeli servis kapatıldı.${NC}"
    fi
fi

# Salt okunur bir listeleme; castle_run'a gerek yok. (Önceden pipe castle_run'ın
# dışında kaldığı için dry-run'da çıktı filtrelenip boş görünüyordu.)
echo "[*] Aktif dinleyen (açık) servisler:"
ss -tulnp 2>/dev/null | grep LISTEN | awk '{print "    " $1 " " $5}' | sort -u

echo -e "${GREEN}[+] Servis sertleştirme tamamlandı.${NC}"
