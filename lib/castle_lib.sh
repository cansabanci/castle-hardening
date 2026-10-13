#!/bin/bash
#
# lib/castle_lib.sh
#

castle_run() {
    local desc="$1"
    shift

    if [ "${DRY_RUN:-false}" = "true" ]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Yapılacak: $desc"
    else
        "$@"
    fi
}

castle_ensure_rule() {
    local etiket="$1"
    local aciklama="$2"
    local anchor="$3"
    local content="$4"
    local rules_file="/etc/ufw/before.rules"

    if grep -Fq -- "$etiket" "$rules_file" 2>/dev/null; then
        return 0
    fi

    if [ "${DRY_RUN:-false}" = "true" ]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Yapılacak: $aciklama"
    else
        sed -i "\|${anchor}|i # ${etiket}\n${content}" "$rules_file"
        echo "[*] $aciklama eklendi"
    fi
}

# "Anahtar Değer" biçimindeki konfigürasyon dosyalarında bir ayarı garanti eder.
#
# - Ayar, ilk "Match" bloğundan ÖNCE (global bölümde) yazılır. sshd_config'te
#   dosyanın sonuna eklenen bir ayar, sondaki Match bloğuna ait sayılır ve
#   global olarak uygulanmaz.
# - Global bölümdeki eski (yorumlu veya aktif) tanımlar tek bir satırla
#   değiştirilir; Match bloklarının içine dokunulmaz.
# - Anahtar karşılaştırması büyük/küçük harf duyarsızdır (sshd ve Apache gibi).
# - Anahtar ve değer awk'a ENVIRON ile verilir; regex'e hiç girmez, böylece
#   "|", "&", "\" gibi karakterler dosyayı bozamaz.
# - Dosya aynı dizinde geçici kopya üzerinden atomik olarak (mv) değiştirilir;
#   izinler ve sahiplik korunur.
castle_set_config_option() {
    local file="$1"
    local key="$2"
    local value="$3"

    if [ "${DRY_RUN:-false}" = "true" ]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Ayar: $key $value"
        return 0
    fi

    if [ ! -f "$file" ]; then
        echo -e "${RED}[!] $file bulunamadı, '$key' ayarlanamadı.${NC}" >&2
        return 1
    fi

    local tmp
    tmp="$(mktemp "${file}.castle.XXXXXX")" || return 1

    if CASTLE_KEY="$key" CASTLE_VALUE="$value" awk '
        BEGIN {
            k = tolower(ENVIRON["CASTLE_KEY"])
            line = ENVIRON["CASTLE_KEY"] " " ENVIRON["CASTLE_VALUE"]
        }
        {
            if (!in_match && $0 ~ /^[[:space:]]*[Mm][Aa][Tt][Cc][Hh][[:space:]]/) {
                if (!done) { print line; done = 1 }
                in_match = 1
            }
            if (!in_match) {
                t = $0
                sub(/^[[:space:]]*#?[[:space:]]*/, "", t)
                split(t, f, /[[:space:]]+/)
                if (tolower(f[1]) == k && t ~ /[[:space:]]/) {
                    if (!done) { print line; done = 1 }
                    next
                }
            }
            print
        }
        END { if (!done) print line }
    ' "$file" > "$tmp" \
        && chmod --reference="$file" "$tmp" \
        && chown --reference="$file" "$tmp" \
        && mv -f "$tmp" "$file"; then
        return 0
    fi

    rm -f "$tmp"
    echo -e "${RED}[!] $file içinde '$key' ayarlanamadı.${NC}" >&2
    return 1
}

castle_ensure_file() {
    local file="$1"
    local aciklama="$2"
    local content="$3"
    local mode="${4:-0644}"
    local owner="${5:-root:root}"

    if [ "${DRY_RUN:-false}" = "true" ]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Yapılacak: $aciklama"
        return 0
    fi

    # Geçici dosya hedefle AYNI dizinde oluşturulur: böylece mv atomiktir ve
    # yarım yazılmış bir dosya asla hedefin yerine geçmez.
    local tmp
    if ! tmp="$(mktemp "${file}.castle.XXXXXX" 2>/dev/null)"; then
        echo -e "${RED}[!] $aciklama başarısız: $(dirname "$file") dizinine yazılamıyor.${NC}" >&2
        return 1
    fi

    if printf '%s\n' "$content" > "$tmp" \
        && chown "$owner" "$tmp" \
        && chmod "$mode" "$tmp" \
        && mv -f "$tmp" "$file"; then
        echo "[*] $aciklama"
        return 0
    fi

    rm -f "$tmp"
    echo -e "${RED}[!] $aciklama başarısız.${NC}" >&2
    return 1
}

# Kullanım: castle_safe_service_reload <servis> <eylem> <test komutu...>
# Test komutu ZORUNLUDUR: konfigürasyon doğrulanmadan servis yeniden başlatılmaz.
castle_safe_service_reload() {
    if [ $# -lt 3 ]; then
        echo -e "${RED}[!] castle_safe_service_reload: '${1:-?}' için test komutu verilmedi, işlem reddedildi.${NC}" >&2
        return 1
    fi

    local service="$1"
    local action="$2"
    shift 2

    if [ "${DRY_RUN:-false}" = "true" ]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Yapılacak: $service test edilip $action edilecek"
        return 0
    fi

    if ! "$@"; then
        echo -e "${RED}[!] $service konfigürasyon testi başarısız! $action iptal edildi.${NC}" >&2
        return 1
    fi

    if ! systemctl "$action" "$service"; then
        echo -e "${RED}[!] $service $action başarısız oldu.${NC}" >&2
        return 1
    fi
    echo -e "${GREEN}[+] $service $action edildi.${NC}"
}

# Dosyanın Castle'a dokunulmadan önceki halini BİR KEZ yedekler
# (<dosya>.castle-orig). Sonraki çalıştırmalar bu yedeği ezmez; böylece araç
# kaç kez çalıştırılırsa çalıştırılsın rollback gerçek orijinale döner.
castle_backup_original() {
    local file="$1"
    local orig="${file}.castle-orig"

    [ -f "$file" ] || return 0
    [ -f "$orig" ] && return 0

    if [ "${DRY_RUN:-false}" = "true" ]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Orijinal yedek alınacak: $orig"
        return 0
    fi

    cp -p "$file" "$orig" && echo "[*] Orijinal yedek alındı: ${orig##*/}"
}

castle_restore_file() {
    local target_file="$1"
    local aciklama="$2"

    # Öncelik: Castle'dan önceki orijinal yedek. Zaman damgalı yedekler, ikinci
    # bir çalıştırmadan sonra zaten sertleştirilmiş dosyayı içerebilir; bu
    # yüzden sadece orijinal yedek yoksa en yenisine düşülür.
    local latest_backup=""
    if [ -f "${target_file}.castle-orig" ]; then
        latest_backup="${target_file}.castle-orig"
    elif [ -f "${target_file}.castle-backup" ]; then
        latest_backup="${target_file}.castle-backup"
    else
        latest_backup=$(ls -t "${target_file}.backup."* 2>/dev/null | head -n 1)
    fi

    if [ -z "$latest_backup" ] || [ ! -f "$latest_backup" ]; then
        echo -e "${YELLOW}[*] $target_file için geçerli bir yedek bulunamadı, atlanıyor.${NC}"
        return 0
    fi

    if [ "${DRY_RUN:-false}" = "true" ]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Geri Yüklenecek: $latest_backup -> $target_file"
    elif cp -p "$latest_backup" "$target_file"; then
        echo -e "${GREEN}[✓] $aciklama geri yüklendi (${latest_backup##*/})${NC}"
    else
        echo -e "${RED}[!] $aciklama geri yüklenemedi.${NC}" >&2
        return 1
    fi
}
