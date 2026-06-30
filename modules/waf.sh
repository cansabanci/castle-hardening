#!/bin/bash
#
# waf.sh


MODSEC_CONF="/etc/modsecurity/modsecurity.conf"
CRS_SETUP="/etc/modsecurity/crs/crs-setup.conf"

# Web sunucusu tespiti
WEB_SERVER=""
if systemctl list-unit-files 2>/dev/null | grep -q -- "apache2"; then
    WEB_SERVER="apache2"
elif systemctl list-unit-files 2>/dev/null | grep -q -- "nginx"; then
    WEB_SERVER="nginx"
fi

if [ -z "$WEB_SERVER" ]; then
    echo -e "${RED}[!] Web sunucusu (Apache/Nginx) bulunamadı. WAF atlanıyor.${NC}"
    return 0
fi

if [ "$WEB_SERVER" != "apache2" ]; then
    echo -e "${RED}[!] Şu an sadece Apache destekleniyor. $WEB_SERVER atlanıyor.${NC}"
    return 0
fi

# ==============================================================================
# ROLLBACK MODU
# ==============================================================================
if [ "${MODE:-HARDEN}" = "ROLLBACK" ]; then
    echo -e "${YELLOW}[*] WAF sertleştirmesi geri alınıyor...${NC}"

    # 1. CRS Konfigürasyonunu yedekten geri yükle
    if [ -f "$CRS_SETUP" ]; then
        castle_restore_file "$CRS_SETUP" "OWASP CRS orijinal konfigürasyonu"
    fi

    # 2. ModSecurity temel konfigürasyonunu
    if [ -f "$MODSEC_CONF" ]; then
        castle_restore_file "$MODSEC_CONF" "ModSecurity temel konfigürasyonu"
    fi

    if castle_safe_service_reload "apache2" "restart" apache2ctl -t; then
        echo -e "${GREEN}[✓] WAF konfigürasyonları başarıyla eski haline döndürüldü.${NC}"
    fi

# ==============================================================================
# HARDEN  MODU
# ==============================================================================
else
    echo -e "${GREEN}[*] WAF modülü çalışıyor...${NC}"
    echo "[*] Web sunucusu tespit edildi: $WEB_SERVER"

    # ModSecurity Paket Kurulumu
    if ! apache2ctl -M 2>/dev/null | grep -q -- "security2_module"; then
        castle_run "ModSecurity kurulacak" apt-get install libapache2-mod-security2 -y
        castle_run "ModSecurity Apache modülü etkinleştirilecek" a2enmod security2
    fi

    # OWASP CRS Kurulumu
    if [ ! -d "/usr/share/modsecurity-crs/rules" ]; then
        castle_run "OWASP CRS kurulacak" apt-get install modsecurity-crs -y
    fi

    # ModSecurity Temel Yapılandırması
    if [ ! -f "$MODSEC_CONF" ]; then
        castle_run "ModSecurity config örnekten oluşturulacak" \
            cp /etc/modsecurity/modsecurity.conf-recommended "$MODSEC_CONF"
    fi

    # Gelecekte geri dönebilme
    castle_run "ModSecurity ana config yedeklenecek" cp "$MODSEC_CONF" "${MODSEC_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
    castle_set_config_option "$MODSEC_CONF" "SecRuleEngine" "On"

    # OWASP CRS Kurulumu ve Paranoia Level Ayarı
    if [ -f "$CRS_SETUP" ]; then
        [ -f "${CRS_SETUP}.castle-backup" ] || cp "$CRS_SETUP" "${CRS_SETUP}.castle-backup"
        castle_run "CRS config yedeklenecek" cp "$CRS_SETUP" "${CRS_SETUP}.backup.$(date +%Y%m%d_%H%M%S)"

        sed -i '/^[[:space:]]*setvar:tx.paranoia_level/d' "$CRS_SETUP"

        castle_run "CRS paranoia level 2 ayarlanacak" \
            sed -i 's/^#\?[[:space:]]*setvar:tx.paranoia_level=[0-9]/    setvar:tx.paranoia_level=2/' "$CRS_SETUP"
    fi

    if castle_safe_service_reload "apache2" "restart" apache2ctl -t; then
        castle_run "WAF başarı mesajı gösteriliyor" echo -e "${GREEN}[+] WAF aktif (ModSecurity + OWASP CRS, paranoia 2).${NC}"
    fi
fi
