#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # renk sıfırla
export GREEN RED YELLOW NC

usage() {
    echo "Castle Hardening Tool"
    echo "Kullanım: sudo ./harden.sh <--dry-run | --apply | --rollback [--dry-run]>"
    echo ""
    echo "Seçenekler:"
    echo "  --dry-run   Hiçbir değişiklik yapmadan ne yapılacağını gösterir"
    echo "  --apply     Değişiklikleri uygular"
    echo "  --rollback  Sistemi sıkılaştırma öncesindeki orijinal ayarlarına geri döndürür"
    echo "              (--dry-run ile birlikte kullanılırsa sadece simüle eder)"
    echo "  --help      Bu yardımı gösterir"
}

# ============================================
# Argümanlar
#
# Mod açıkça seçilmelidir. Bilinmeyen bir argüman (ör. "--dryrun" yazım
# hatası) sessizce yok sayılıp varsayılan "apply" ile canlı değişiklik
# yapılmasın diye hata verilir.
# ============================================

export MODE="HARDEN"
DRY_RUN=""

if [ $# -eq 0 ]; then
    usage
    exit 1
fi

for arg in "$@"; do
    case "$arg" in
        --dry-run)  DRY_RUN="true" ;;
        --apply)    [ "$DRY_RUN" = "true" ] || DRY_RUN="false" ;;
        --rollback) MODE="ROLLBACK" ;;
        --help|-h)  usage; exit 0 ;;
        *)
            echo -e "${RED}[!] Bilinmeyen seçenek: $arg${NC}" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [ "$MODE" = "HARDEN" ] && [ -z "$DRY_RUN" ]; then
    echo -e "${RED}[!] Mod seçilmedi: --dry-run veya --apply kullanın.${NC}" >&2
    exit 1
fi
DRY_RUN="${DRY_RUN:-false}"

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[!] Bu script root yetkisi gerektirir. 'sudo ./harden.sh' ile çalıştırın.${NC}"
    exit 1
fi

# ============================================
# Yapılandırma
#
# castle.conf root olarak "source" edilir, yani içindeki her satır root
# yetkisiyle çalışır. Bu yüzden yalnızca root'a aitse ve başkaları
# tarafından yazılamıyorsa yüklenir.
# ============================================

SCAN_MODE="IDS"
WHITELIST=""
SCAN_SECONDS=10
SCAN_HITCOUNT=10

CONFIG_FILE="${SCRIPT_DIR}/castle.conf"
if [ -f "$CONFIG_FILE" ]; then
    if [ "$(stat -c %u "$CONFIG_FILE")" != "0" ] || [ -n "$(find "$CONFIG_FILE" -perm /022)" ]; then
        echo -e "${RED}[!] $CONFIG_FILE root'a ait değil veya başkaları tarafından yazılabilir.${NC}" >&2
        echo -e "${RED}    Güvenlik için yüklenmedi. Düzeltmek için: sudo chown root:root castle.conf && sudo chmod 600 castle.conf${NC}" >&2
        exit 1
    fi
    # shellcheck source=castle.conf.example
    source "$CONFIG_FILE"
    echo "[*] Yapılandırma yüklendi: castle.conf"
else
    echo "[*] castle.conf bulunamadı, güvenli varsayılanlar kullanılıyor (SCAN_MODE=$SCAN_MODE)"
fi

# shellcheck source=lib/castle_lib.sh
source "${SCRIPT_DIR}/lib/castle_lib.sh"
export DRY_RUN
export MODE

export -f castle_run castle_ensure_rule castle_set_config_option castle_ensure_file castle_safe_service_reload castle_backup_original castle_restore_file

if [ "$MODE" = "ROLLBACK" ]; then
    echo -e "${YELLOW}=== Castle Hardening Tool [ROLLBACK] ===${NC}"
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${YELLOW}[!] DRY-RUN MODU: Geri alma simülasyonu yapılıyor, dosyalara dokunulmayacak.${NC}"
    fi
    echo "[*] Geri alma operasyonu başlıyor..."
else
    echo -e "${GREEN}=== Castle Hardening Tool ===${NC}"
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${YELLOW}[!] DRY-RUN MODU: Hiçbir değişiklik yapılmayacak, sadece gösterilecek.${NC}"
    fi
    echo "[*] Savunma başlıyor..."
fi

for module in firewall ssh fail2ban services waf audit; do
    # shellcheck source=/dev/null
    source "${SCRIPT_DIR}/modules/${module}.sh"
done

if [ "$MODE" = "ROLLBACK" ]; then
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${YELLOW}[!] DRY-RUN tamamlandı. Hiçbir geri alma işlemi GERÇEKLEŞMEDİ.${NC}"
    else
        echo -e "${GREEN}[+] Rollback tamamlandı. Sistem eski ayarlarına döndürüldü.${NC}"
    fi
else
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${YELLOW}[!] DRY-RUN tamamlandı. Hiçbir değişiklik YAPILMADI.${NC}"
        echo -e "${YELLOW}    Uygulamak için: sudo ./harden.sh --apply${NC}"
    else
        echo -e "${GREEN}[+] Savunma tamamlandı.${NC}"
    fi
fi
