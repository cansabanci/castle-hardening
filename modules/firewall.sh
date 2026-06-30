#!/bin/bash
#
# firewall.sh

# ==============================================================================
# ROLLBACK MODU
# ==============================================================================
if [ "${MODE:-HARDEN}" = "ROLLBACK" ]; then
    echo -e "${YELLOW}[*] Firewall sertleştirmesi geri alınıyor...${NC}"

    castle_run "UFW kuralları ve özel zincirler sıfırlanıyor" ufw --force reset

    castle_run "UFW pasif hale getiriliyor" ufw --force disable

    echo -e "${GREEN}[✓] Firewall başarıyla fabrika ayarlarına döndürüldü ve kapatıldı.${NC}"

# ==============================================================================
# HARDEN MODU
# ==============================================================================
else
    echo -e "${GREEN}[*] Firewall modülü çalışıyor...${NC}"

    if ! command -v ufw &> /dev/null; then
        castle_run "ufw paketi kurulacak" apt-get install ufw -y
    fi

    CURRENT_INCOMING=$(ufw status verbose 2>/dev/null | grep -oP 'Default: \K\w+' | head -1)
    if [ "$CURRENT_INCOMING" != "deny" ]; then
        castle_run "Default incoming politikası 'deny' yapılacak" ufw default deny incoming
    else
        echo "[*] Default deny zaten ayarlı, korunuyor."
    fi

    CURRENT_OUTGOING=$(ufw status verbose 2>/dev/null | grep "Default:" | grep -oP '\w+(?= \(outgoing\))' | head -1)
    if [ "$CURRENT_OUTGOING" != "allow" ]; then
        castle_run "Default outgoing politikası 'allow' yapılacak" ufw default allow outgoing
    else
        echo "[*] Default outgoing zaten 'allow', korunuyor."
    fi

    # Standart Servis İzinleri
    castle_run "SSH (22) rate-limit kuralı eklenecek" ufw limit 22/tcp comment 'SSH rate limited'
    castle_run "HTTP (80) izin kuralı eklenecek" ufw allow 80/tcp comment 'HTTP'
    castle_run "HTTPS (443) izin kuralı eklenecek" ufw allow 443/tcp comment 'HTTPS'
    castle_run "ufw loglama açılacak" ufw logging on

    # ICMP (ping) flood koruması
    castle_ensure_rule "icmp-flood-protection" "ICMP flood koruması" \
        "# ok icmp codes for INPUT" \
        "-A ufw-before-input -p icmp --icmp-type echo-request -m limit --limit 1/second --limit-burst 5 -j ACCEPT\n-A ufw-before-input -p icmp --icmp-type echo-request -j DROP"

    # Geçersiz paketleri düşür
    castle_ensure_rule "drop-invalid-packets" "Geçersiz paket düşürme" \
        "# End required lines" \
        "-A ufw-before-input -m conntrack --ctstate INVALID -j DROP"

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

    # Port Tarama Tespiti
    castle_ensure_rule "port-scan-detection" "Port tarama tespiti (mod: $SCAN_MODE)" \
        "# End required lines" \
        "${WHITELIST_RULES}-A ufw-before-input -m conntrack --ctstate NEW -m recent --set --name PORTSCAN\n-A ufw-before-input -m conntrack --ctstate NEW -m recent --update --seconds ${SCAN_SECONDS} --hitcount ${SCAN_HITCOUNT} --name PORTSCAN -j LOG --log-prefix \"[PORTSCAN] \"\n-A ufw-before-input -m conntrack --ctstate NEW -m recent --update --seconds ${SCAN_SECONDS} --hitcount ${SCAN_HITCOUNT} --name PORTSCAN -j ${SCAN_ACTION}"

    # Tehlikeli port tespiti (Telnet/SMB/RDP)
    castle_ensure_rule "dangerous-port-watch" "Tehlikeli port tespiti (Telnet/SMB/RDP)" \
        "# End required lines" \
        "-A ufw-before-input -p tcp -m multiport --dports 23,135,139,445,3389 -j LOG --log-prefix \"[DANGER-PORT] \"\n-A ufw-before-input -p tcp -m multiport --dports 23,135,139,445,3389 -j DROP"

    # SYN flood özel koruması
    castle_ensure_rule "syn-flood-protection" "SYN flood koruması" \
        "# End required lines" \
        "-A ufw-before-input -p tcp --syn -m limit --limit 25/second --limit-burst 50 -j RETURN\n-A ufw-before-input -p tcp --syn -j DROP"

    castle_run "ufw etkinleştirilecek" ufw --force enable

    echo -e "${GREEN}[+] Firewall yapılandırıldı (default deny + SSH rate limit).${NC}"
    if [ "$DRY_RUN" != "true" ]; then
        ufw status verbose
    fi
fi
