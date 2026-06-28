#!/bin/bash
# Castle Hardening Tool


# Port tarama tespiti modu:
#   "IDS"
#   "IPS"
SCAN_MODE="IPS"

WHITELIST=""

SCAN_SECONDS=10
SCAN_HITCOUNT=10

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
