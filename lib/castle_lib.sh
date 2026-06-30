#!/bin/bash
#

run() {
    local desc="$1"
    shift
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Yapılacak: $desc"
    else
        "$@"
    fi
}

ensure_rule() {
    local etiket="$1"
    local aciklama="$2"
    local anchor="$3"
    local content="$4"
    local rules_file="/etc/ufw/before.rules"

    if grep -q "$etiket" "$rules_file" 2>/dev/null; then
        return 0
    fi

    if [ "$DRY_RUN" = "true" ]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Yapılacak: $aciklama"
    else
        sed -i "/${anchor}/i # ${etiket}\n${content}" "$rules_file"
        echo "[*] $aciklama eklendi"
    fi
}

set_config_option() {
    local file="$1"
    local key="$2"
    local value="$3"
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Ayar: $key $value"
        return 0
    fi
    if grep -qE "^#?\s*${key}\s" "$file"; then
        sed -i "s|^#\?\s*${key}\s.*|${key} ${value}|" "$file"
    else
        echo "${key} ${value}" >> "$file"
    fi
}

ensure_file() {
    local file="$1"
    local aciklama="$2"
    local content="$3"
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Yapılacak: $aciklama"
        return 0
    fi
    printf '%s\n' "$content" > "$file"
    echo "[*] $aciklama"
}

safe_service_reload() {
    local service="$1"
    local test_cmd="$2"
    local action="${3:-reload}"

    if [ "$DRY_RUN" = "true" ]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Yapılacak: $service test edilip $action edilecek"
        return 0
    fi

    # Test komutu varsa çalıştır (config geçerli mi?)
    if [ -n "$test_cmd" ]; then
        if ! $test_cmd 2>/dev/null; then
            echo -e "${RED}[!] $service config hatası! Değişiklik uygulanmadı.${NC}"
            return 1
        fi
    fi

    systemctl "$action" "$service" 2>/dev/null || systemctl restart "$service" 2>/dev/null
    echo -e "${GREEN}[+] $service servisi $action edildi.${NC}"
    return 0
}
