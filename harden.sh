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
NC='\033[0m' # renk sıfırla

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[!] Bu script root yetkisi gerektirir. 'sudo ./harden.sh' ile çalıştırın.${NC}"
  exit 1
fi

echo -e "${GREEN}=== Castle Hardening Tool ===${NC}"
echo "[*] Savunma başlıyor..."

source ./modules/firewall.sh
source ./modules/ssh.sh
source ./modules/fail2ban.sh
source ./modules/services.sh
source ./modules/waf.sh
source ./modules/audit.sh

echo -e "${GREEN}[+] Savunma tamamlandı.${NC}"
