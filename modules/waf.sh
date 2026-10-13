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

    # WAF modu: IDS = DetectionOnly (sadece logla), IPS = On (engelle).
    # Ayrıca belirtilmezse SCAN_MODE'u izler. Yeni kurulumda önerilen yol:
    # önce IDS ile çalıştırıp yanlış pozitifleri ayıklamak, sonra IPS'e geçmek.
    WAF_MODE="${WAF_MODE:-$SCAN_MODE}"
    if [ "$WAF_MODE" = "IPS" ]; then
        SEC_RULE_ENGINE="On"
    else
        SEC_RULE_ENGINE="DetectionOnly"
    fi

    PARANOIA_LEVEL="${PARANOIA_LEVEL:-2}"
    case "$PARANOIA_LEVEL" in
        1|2|3|4) ;;
        *)
            echo -e "${RED}[!] Geçersiz PARANOIA_LEVEL='$PARANOIA_LEVEL' (1-4 olmalı). WAF atlanıyor.${NC}"
            return 0
            ;;
    esac

    # ModSecurity Temel Yapılandırması
    if [ ! -f "$MODSEC_CONF" ]; then
        castle_run "ModSecurity config örnekten oluşturulacak" \
            cp /etc/modsecurity/modsecurity.conf-recommended "$MODSEC_CONF"
    fi

    # Rollback için orijinaller (bir kez) + bu çalıştırmanın yedekleri
    STAMP="$(date +%Y%m%d_%H%M%S)"
    castle_backup_original "$MODSEC_CONF"
    castle_run "ModSecurity ana config yedeklenecek" cp -p "$MODSEC_CONF" "${MODSEC_CONF}.backup.${STAMP}"

    castle_set_config_option "$MODSEC_CONF" "SecRuleEngine" "$SEC_RULE_ENGINE"

    # OWASP CRS Paranoia Level
    #
    # crs-setup.conf'taki paranoia ayarı çok satırlı, yorumlu bir SecAction
    # bloğudur. Bloğun içinden tek bir satırın yorumunu kaldırmak geçersiz bir
    # Apache yapılandırması üretir. Bunun yerine Castle'a ait, işaretlenmiş tek
    # satırlık bir SecAction dosyanın sonuna yazılır (her çalıştırmada yenilenir).
    # CRS 3.x "tx.paranoia_level", CRS 4.x "tx.blocking_paranoia_level" kullanır;
    # ikisi de ayarlanır.
    if [ -f "$CRS_SETUP" ]; then
        castle_backup_original "$CRS_SETUP"
        castle_run "CRS config yedeklenecek" cp -p "$CRS_SETUP" "${CRS_SETUP}.backup.${STAMP}"

        if [ "${DRY_RUN:-false}" = "true" ]; then
            echo -e "  ${YELLOW}[DRY-RUN]${NC} Yapılacak: CRS paranoia level $PARANOIA_LEVEL ayarlanacak"
        else
            crs_tmp="$(mktemp "${CRS_SETUP}.castle.XXXXXX")"
            # Önceki Castle bloğunu ve eski sürümlerin bıraktığı başıboş satırı temizle
            awk '
                /^# >>> castle: paranoia level/ { skip = 1; next }
                /^# <<< castle/                 { skip = 0; next }
                skip { next }
                /^[[:space:]]*setvar:tx\.paranoia_level=[0-9]/ { next }
                /^[[:space:]]*$/ { blanks++; next }
                { while (blanks > 0) { print ""; blanks-- } print }
            ' "$CRS_SETUP" > "$crs_tmp"

            if grep -vE '^[[:space:]]*#' "$crs_tmp" | grep -q 'id:900000'; then
                rm -f "$crs_tmp"
                echo -e "${YELLOW}[!] crs-setup.conf'ta zaten aktif bir paranoia ayarı (id:900000) var; dokunulmadı.${NC}"
            else
                {
                    printf '\n# >>> castle: paranoia level\n'
                    printf 'SecAction "id:900000,phase:1,nolog,pass,t:none,setvar:tx.paranoia_level=%s,setvar:tx.blocking_paranoia_level=%s"\n' \
                        "$PARANOIA_LEVEL" "$PARANOIA_LEVEL"
                    printf '# <<< castle\n'
                } >> "$crs_tmp"
                chmod --reference="$CRS_SETUP" "$crs_tmp"
                chown --reference="$CRS_SETUP" "$crs_tmp"
                mv -f "$crs_tmp" "$CRS_SETUP"
                echo "[*] CRS paranoia level $PARANOIA_LEVEL ayarlandı"
            fi
        fi
    fi

    if castle_safe_service_reload "apache2" "restart" apache2ctl -t; then
        if [ "${DRY_RUN:-false}" != "true" ]; then
            echo -e "${GREEN}[+] WAF aktif: ModSecurity + OWASP CRS, mod: $WAF_MODE (SecRuleEngine $SEC_RULE_ENGINE), paranoia $PARANOIA_LEVEL.${NC}"
        fi
    elif [ "${DRY_RUN:-false}" != "true" ]; then
        # Bozuk WAF konfigürasyonu Apache'nin bir sonraki başlangıcını da
        # engeller; bu çalıştırmadan önceki hale dön.
        [ -f "${MODSEC_CONF}.backup.${STAMP}" ] && cp -p "${MODSEC_CONF}.backup.${STAMP}" "$MODSEC_CONF"
        [ -f "${CRS_SETUP}.backup.${STAMP}" ] && cp -p "${CRS_SETUP}.backup.${STAMP}" "$CRS_SETUP"
        echo -e "${RED}[!] WAF konfigürasyonu bu çalıştırmadan önceki haline geri döndürüldü.${NC}"
    fi
fi
