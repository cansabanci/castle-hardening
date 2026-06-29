#!/bin/bash
#
# waf.sh - Web Application Firewall modülü (ModSecurity + OWASP CRS)
# Koşullu: web sunucusu varsa kurar/yapılandırır, yoksa atlar
#

echo -e "${GREEN}[*] WAF modülü çalışıyor...${NC}"

WEB_SERVER=""
if systemctl list-unit-files 2>/dev/null | grep -q "apache2"; then
    WEB_SERVER="apache2"
elif systemctl list-unit-files 2>/dev/null | grep -q "nginx"; then
    WEB_SERVER="nginx"
fi

if [ -z "$WEB_SERVER" ]; then
    echo -e "${RED}[!] Web sunucusu (Apache/Nginx) bulunamadı. WAF atlanıyor.${NC}"
    echo "[*] Not: Web sunucusu kurulu bir sistemde bu modül ModSecurity+CRS kurar."
    return 0
fi

echo "[*] Web sunucusu tespit edildi: $WEB_SERVER"

if [ "$WEB_SERVER" != "apache2" ]; then
    echo -e "${RED}[!] Şu an sadece Apache destekleniyor. $WEB_SERVER için manuel kurulum gerekir.${NC}"
    return 0
fi

if ! apache2ctl -M 2>/dev/null | grep -q "security2_module"; then
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Yapılacak: ModSecurity kurulacak + etkinleştirilecek"
    else
        echo "[*] ModSecurity kuruluyor..."
        apt-get install libapache2-mod-security2 -y
        a2enmod security2
    fi
fi

if [ ! -d "/usr/share/modsecurity-crs/rules" ]; then
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Yapılacak: OWASP CRS kurulacak"
    else
        echo "[*] OWASP Core Rule Set kuruluyor..."
        apt-get install modsecurity-crs -y
    fi
fi

if [ "$DRY_RUN" = "true" ]; then
    echo -e "  ${YELLOW}[DRY-RUN]${NC} Yapılacak: ModSecurity engelleme modu (SecRuleEngine On)"
    echo -e "  ${YELLOW}[DRY-RUN]${NC} Yapılacak: CRS paranoia level 2 ayarlanacak"
else
    MODSEC_CONF="/etc/modsecurity/modsecurity.conf"
    if [ ! -f "$MODSEC_CONF" ]; then
        cp /etc/modsecurity/modsecurity.conf-recommended "$MODSEC_CONF" 2>/dev/null
    fi

    if [ -f "$MODSEC_CONF" ]; then
        sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/' "$MODSEC_CONF"
        echo "[*] ModSecurity engelleme modu aktif (SecRuleEngine On)"
    fi
    CRS_SETUP="/etc/modsecurity/crs/crs-setup.conf"
    if [ -f "$CRS_SETUP" ]; then
        cp "$CRS_SETUP" "${CRS_SETUP}.castle-backup" 2>/dev/null
        if grep -q "setvar:tx.paranoia_level" "$CRS_SETUP"; then
            sed -i 's/^#\?\s*setvar:tx.paranoia_level=[0-9]/    setvar:tx.paranoia_level=2/' "$CRS_SETUP"
            echo "[*] CRS paranoia level 2 ayarlandı (dengeli koruma)"
        fi
    fi
fi

if [ "$DRY_RUN" = "true" ]; then
    echo -e "  ${YELLOW}[DRY-RUN]${NC} Yapılacak: Apache config test edilip restart edilecek"
elif apache2ctl -t 2>/dev/null; then
    systemctl restart apache2
    echo -e "${GREEN}[+] WAF aktif (ModSecurity + OWASP CRS, paranoia 2).${NC}"
    echo "[*] Web saldırıları (SQLi/XSS/LFI) artık denetleniyor."
else
    echo -e "${RED}[!] Apache config hatası! WAF ayarları gözden geçirilmeli.${NC}"
fi
