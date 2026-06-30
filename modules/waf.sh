#!/bin/bash
#
# waf.sh

echo -e "${GREEN}[*] WAF modülü çalışıyor...${NC}"

# Web sunucusu tespiti
WEB_SERVER=""
if systemctl list-unit-files 2>/dev/null | grep -q -- "apache2"; then
    WEB_SERVER="apache2"
elif systemctl list-unit-files 2>/dev/null | grep -q -- "nginx"; then
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
MODSEC_CONF="/etc/modsecurity/modsecurity.conf"
if [ ! -f "$MODSEC_CONF" ]; then
    castle_run "ModSecurity config örnekten oluşturulacak" \
        cp /etc/modsecurity/modsecurity.conf-recommended "$MODSEC_CONF"
fi

castle_set_config_option "$MODSEC_CONF" "SecRuleEngine" "On"

# OWASP CRS Kurulumu ve Paranoia Level Ayarı
CRS_SETUP="/etc/modsecurity/crs/crs-setup.conf"
if [ -f "$CRS_SETUP" ]; then
    # Eğer daha önce yedek alınmadıysa ilk seferde yedekle
    [ -f "${CRS_SETUP}.castle-backup" ] || cp "$CRS_SETUP" "${CRS_SETUP}.castle-backup"

    # Önce eğer varsa eski bozuk çıplak tanımları temizle (idempotency kuralı)
    sed -i '/^[[:space:]]*setvar:tx.paranoia_level/d' "$CRS_SETUP"

    # Orijinal SecAction bloğundaki satırı kurallara uygun şekilde 2'ye çekiyoruz
    castle_run "CRS paranoia level 2 ayarlanacak" \
        sed -i 's/^#\?[[:space:]]*setvar:tx.paranoia_level=[0-9]/    setvar:tx.paranoia_level=2/' "$CRS_SETUP"
fi

if castle_safe_service_reload "apache2" "restart" apache2ctl -t; then
    castle_run "WAF başarı mesajı gösteriliyor" echo -e "${GREEN}[+] WAF aktif (ModSecurity + OWASP CRS, paranoia 2).${NC}"
fi
