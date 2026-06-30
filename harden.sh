#!/bin/bash

SCAN_MODE="IDS"

WHITELIST=""

SCAN_SECONDS=10
SCAN_HITCOUNT=10

CONFIG_FILE="$(dirname "$0")/castle.conf"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    echo "[*] Yapılandırma yüklendi: castle.conf"
else
    echo "[*] castle.conf bulunamadı, güvenli varsayılanlar kullanılıyor (SCAN_MODE=$SCAN_MODE)"
fi

# ============================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # renk sıfırla
export GREEN RED YELLOW NC

DRY_RUN="false"
for arg in "$@"; do
    case "$arg" in
        --dry-run)
            DRY_RUN="true"
            ;;
        --apply)
            DRY_RUN="false"
            ;;
        --help|-h)
            echo "Castle Hardening Tool"
            echo "Kullanım: sudo ./harden.sh [SEÇENEK]"
            echo ""
            echo "Seçenekler:"
            echo "  --dry-run   Hiçbir değişiklik yapmadan ne yapılacağını gösterir"
            echo "  --apply     Değişiklikleri uygular (varsayılan)"
            echo "  --help      Bu yardımı gösterir"
            exit 0
            ;;
    esac
done


source "$(dirname "$0")/lib/castle_lib.sh"
export DRY_RUN
export -f run ensure_rule set_config_option ensure_file safe_service_reload

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[!] Bu script root yetkisi gerektirir. 'sudo ./harden.sh' ile çalıştırın.${NC}"
  exit 1
fi

echo -e "${GREEN}=== Castle Hardening Tool ===${NC}"
if [ "$DRY_RUN" = "true" ]; then
    echo -e "${YELLOW}[!] DRY-RUN MODU: Hiçbir değişiklik yapılmayacak, sadece gösterilecek.${NC}"
fi
echo "[*] Savunma başlıyor..."

source ./modules/firewall.sh
source ./modules/ssh.sh
source ./modules/fail2ban.sh
source ./modules/services.sh
source ./modules/waf.sh
source ./modules/audit.sh

if [ "$DRY_RUN" = "true" ]; then
    echo -e "${YELLOW}[!] DRY-RUN tamamlandı. Hiçbir değişiklik YAPILMADI.${NC}"
    echo -e "${YELLOW}    Uygulamak için: sudo ./harden.sh --apply${NC}"
else
    echo -e "${GREEN}[+] Savunma tamamlandı.${NC}"
fi
