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

castle_set_config_option() {
    local file="$1"
    local key="$2"
    local value="$3"

    if [ "${DRY_RUN:-false}" = "true" ]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Ayar: $key $value"
        return 0
    fi

    if grep -qE "^[[:space:]]*#?[[:space:]]*${key}[[:space:]]" "$file" 2>/dev/null; then
        sed -i "s|^[[:space:]]*#\?[[:space:]]*${key}[[:space:]].*|${key} ${value}|" "$file"
    else
        echo "${key} ${value}" >> "$file"
    fi
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

    local tmp
    tmp="$(mktemp /tmp/castle_file.XXXXXX)"

    printf '%s\n' "$content" > "$tmp"

    install -o "${owner%:*}" -g "${owner#*:}" -m "$mode" "$tmp" "$file"

    rm -f "$tmp"
    echo "[*] $aciklama"
}

castle_safe_service_reload() {
    local service="$1"
    local action="${2:-reload}"
    shift 2

    if [ "${DRY_RUN:-false}" = "true" ]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Yapılacak: $service test edilip $action edilecek"
        return 0
    fi

    if [ $# -gt 0 ]; then
        if ! "$@"; then
            echo -e "${RED}[!] $service konfigürasyon testi başarısız! $action iptal edildi.${NC}"
            return 1
        fi
    fi

    systemctl "$action" "$service"
    echo -e "${GREEN}[+] $service $action edildi.${NC}"
}

castle_restore_file() {
    local target_file="$1"
    local aciklama="$2"

    local latest_backup
    latest_backup=$(ls -t "${target_file}.backup."* 2>/dev/null | head -n 1)

    if [ -z "$latest_backup" ] && [ -f "${target_file}.castle-backup" ]; then
        latest_backup="${target_file}.castle-backup"
    fi

    if [ -z "$latest_backup" ] || [ ! -f "$latest_backup" ]; then
        echo -e "${YELLOW}[*] $target_file için geçerli bir yedek bulunamadı, atlanıyor.${NC}"
        return 0
    fi

    if [ "${DRY_RUN:-false}" = "true" ]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Geri Yüklenecek: $latest_backup -> $target_file"
    else
        cp "$latest_backup" "$target_file"
        echo -e "${GREEN}[✓] $aciklama geri yüklendi (${latest_backup##*/})${NC}"
    fi
}
