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
