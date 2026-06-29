#!/bin/bash
#
# firewall.sh - Firewall sertleştirme modülü
# ufw tabanlı, defense-in-depth yaklaşımı
#

echo -e "${GREEN}[*] Firewall modülü çalışıyor...${NC}"

if ! command -v ufw &> /dev/null; then
    echo "[*] ufw kurulu değil, kuruluyor..."
   run apt-get install ufw -y
fi

CURRENT_INCOMING=$(ufw status verbose 2>/dev/null | grep -oP 'Default: \K\w+' | head -1)
if [ "$CURRENT_INCOMING" != "deny" ]; then
    echo "[*] Default incoming politikası 'deny' yapılıyor (mevcut: ${CURRENT_INCOMING:-bilinmiyor})"
    run ufw default deny incoming
else
    echo "[*] Default deny zaten ayarlı, korunuyor."
fi

CURRENT_OUTGOING=$(ufw status verbose 2>/dev/null | grep "Default:" | grep -oP '\w+(?= \(outgoing\))' | head -1)
if [ "$CURRENT_OUTGOING" != "allow" ]; then
    echo "[*] Default outgoing politikasi 'allow' yapiliyor (mevcut: ${CURRENT_OUTGOING:-bilinmiyor})"
    run ufw default allow outgoing
else
    echo "[*] Default outgoing zaten 'allow', korunuyor."
fi

run ufw limit 22/tcp comment 'SSH rate limited'

run ufw allow 80/tcp comment 'HTTP'
run ufw allow 443/tcp comment 'HTTPS'

run ufw logging on



# ICMP (ping) flood koruması
if ! grep -q "icmp-flood-protection" /etc/ufw/before.rules; then
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Yapılacak: ICMP flood koruması"
    else
        sed -i '/# ok icmp codes for INPUT/i # icmp-flood-protection\n-A ufw-before-input -p icmp --icmp-type echo-request -m limit --limit 1/second --limit-burst 5 -j ACCEPT\n-A ufw-before-input -p icmp --icmp-type echo-request -j DROP' /etc/ufw/before.rules
        echo "[*] ICMP flood koruması eklendi"
    fi
fi

# Geçersiz paketleri düşür
if ! grep -q "drop-invalid-packets" /etc/ufw/before.rules; then
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Yapılacak: Geçersiz paket düşürme"
    else
        sed -i '/^# End required lines/i # drop-invalid-packets\n-A ufw-before-input -m conntrack --ctstate INVALID -j DROP' /etc/ufw/before.rules
        echo "[*] Geçersiz paket düşürme eklendi"
    fi
fi

# Port tarama tespiti 
if ! grep -q "port-scan-detection" /etc/ufw/before.rules; then
    if [ "$SCAN_MODE" = "IPS" ]; then
        SCAN_ACTION="DROP"
        echo "[*] Port tarama tespiti: IPS modu (tespit + engelle)"
    else
        SCAN_ACTION="RETURN"
        echo "[*] Port tarama tespiti: IDS modu (sadece tespit + log)"
    fi

    WHITELIST_RULES=""
    for ip in $WHITELIST; do
        WHITELIST_RULES="${WHITELIST_RULES}-A ufw-before-input -s ${ip} -j RETURN\n"
    done
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Yapılacak: Port tarama tespiti (mod: $SCAN_MODE)"
    else
        sed -i "/^# End required lines/i \\
# port-scan-detection\\
${WHITELIST_RULES}-A ufw-before-input -m conntrack --ctstate NEW -m recent --set --name PORTSCAN\\
-A ufw-before-input -m conntrack --ctstate NEW -m recent --update --seconds ${SCAN_SECONDS} --hitcount ${SCAN_HITCOUNT} --name PORTSCAN -j LOG --log-prefix \"[PORTSCAN] \"\\
-A ufw-before-input -m conntrack --ctstate NEW -m recent --update --seconds ${SCAN_SECONDS} --hitcount ${SCAN_HITCOUNT} --name PORTSCAN -j ${SCAN_ACTION}" /etc/ufw/before.rules
       echo "[*] Port tarama tespiti eklendi (mod: $SCAN_MODE)"
    fi
fi

# Tehlikeli port tespiti
if ! grep -q "dangerous-port-watch" /etc/ufw/before.rules; then
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Yapılacak: Tehlikeli port tespiti (Telnet/SMB/RDP)"
    else
        sed -i '/^# End required lines/i \
# dangerous-port-watch\
-A ufw-before-input -p tcp -m multiport --dports 23,135,139,445,3389 -j LOG --log-prefix "[DANGER-PORT] "\
-A ufw-before-input -p tcp -m multiport --dports 23,135,139,445,3389 -j DROP' /etc/ufw/before.rules
        echo "[*] Tehlikeli port tespiti eklendi (Telnet/SMB/RDP)"
    fi
fi

# SYN flood özel koruması
if ! grep -q "syn-flood-protection" /etc/ufw/before.rules; then
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Yapılacak: SYN flood koruması"
    else
        sed -i '/^# End required lines/i \
# syn-flood-protection\
-A ufw-before-input -p tcp --syn -m limit --limit 25/second --limit-burst 50 -j RETURN\
-A ufw-before-input -p tcp --syn -j DROP' /etc/ufw/before.rules
        echo "[*] SYN flood koruması eklendi"
    fi
fi

run ufw --force enable

echo -e "${GREEN}[+] Firewall yapılandırıldı (default deny + SSH rate limit).${NC}"
if [ "$DRY_RUN" != "true" ]; then
    ufw status verbose
fi
