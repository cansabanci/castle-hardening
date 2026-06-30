#!/bin/bash
#
# audit.sh


echo -e "${GREEN}[*] Güvenlik denetim modülü çalışıyor...${NC}"

# Rapor dosyası tanımı
if [ "${DRY_RUN:-false}" = "true" ]; then
    REPORT="/tmp/castle-audit-dryrun.txt"
else
    REPORT="/var/log/castle-audit-$(date +%Y%m%d_%H%M%S).txt"
fi

# Sayaçlar
PASS=0
FAIL=0

# ==============================================================================
# DİNAMİK BAŞARI/HATA MESAJI
# ==============================================================================
check() {
    local condition="$1"        # "OK" veya "FAIL"
    local pass_description="$2" # Başarılıysa basılacak cümle
    local fail_description="$3" # Başarısızsa basılacak cümle

    if [ "$condition" = "OK" ]; then
        echo -e "  ${GREEN}[✓]${NC} $pass_description"
        echo "[PASS] $pass_description" >> "$REPORT"
        PASS=$((PASS+1))
    else
        # Başarısızsa artık kafa karıştırmayan olumsuz cümleyi basıyoruz!
        echo -e "  ${RED}[✗]${NC} $fail_description"
        echo "[FAIL] $fail_description" >> "$REPORT"
        FAIL=$((FAIL+1))
    fi
}

# Rapor Başlangıç Bilgileri
echo "===== CASTLE GÜVENLİK DENETİM RAPORU =====" > "$REPORT"
echo "Tarih: $(date)" >> "$REPORT"
echo "Sistem: $(hostname)" >> "$REPORT"
echo "Mod: ${DRY_RUN:+"DRY-RUN (Simülasyon)"}" >> "$REPORT"
[ "${DRY_RUN:-false}" != "true" ] || echo "NOT: Bu rapor dry-run modunda üretilmiştir, değişiklikler henüz gerçek sisteme uygulanmamıştır." >> "$REPORT"
echo "==========================================" >> "$REPORT"
echo "" >> "$REPORT"

echo ""
echo -e "${GREEN}--- Güvenlik Kontrolleri ---${NC}"

# ==============================================================================
# GÜVENLİK KONTROLLERİ
# ==============================================================================

# 1. Firewall aktif mi?
if ufw status 2>/dev/null | grep -Fq -- "Status: active"; then
    check "OK" "Firewall (ufw) aktif" "Firewall (ufw) AKTİF DEĞİL"
else
    check "FAIL" "Firewall (ufw) aktif" "Firewall (ufw) AKTİF DEĞİL"
fi

# 2. SSH root login kapalı mı?
if grep -qE "^[[:space:]]*PermitRootLogin[[:space:]]+no" /etc/ssh/sshd_config 2>/dev/null; then
    check "OK" "SSH root login kapalı" "SSH ROOT LOGIN AÇIK (GÜVENSİZ)"
else
    check "FAIL" "SSH root login kapalı" "SSH ROOT LOGIN AÇIK (GÜVENSİZ)"
fi

# 3. SSH boş şifre yasak mı?
if grep -qE "^[[:space:]]*PermitEmptyPasswords[[:space:]]+no" /etc/ssh/sshd_config 2>/dev/null; then
    check "OK" "SSH boş şifre yasak" "SSH BOŞ ŞİFREYE İZİN VERİLİYOR (GÜVENSİZ)"
else
    check "FAIL" "SSH boş şifre yasak" "SSH BOŞ ŞİFREYE İZİN VERİLİYOR (GÜVENSİZ)"
fi

# 4. fail2ban çalışıyor mu?
if systemctl is-active --quiet fail2ban 2>/dev/null; then
    check "OK" "fail2ban aktif (brute-force koruması)" "fail2ban AKTİF DEĞİL"
else
    check "FAIL" "fail2ban aktif (brute-force koruması)" "fail2ban AKTİF DEĞİL"
fi

# 5. Tehlikeli servisler kapalı mı?
if ! systemctl is-active --quiet telnet 2>/dev/null && ! systemctl is-active --quiet telnetd 2>/dev/null; then
    check "OK" "Telnet servisi kapalı" "TELNET SERVİSİ AÇIK (TEHLİKELİ)"
else
    check "FAIL" "Telnet servisi kapalı" "TELNET SERVİSİ AÇIK (TEHLİKELİ)"
fi

# 6. SSH deneme limiti var mı?
if grep -qE "^[[:space:]]*MaxAuthTries[[:space:]]+[1-5]" /etc/ssh/sshd_config 2>/dev/null; then
    check "OK" "SSH deneme limiti ayarlı" "SSH DENEME LİMİTİ AYARLANMAMIŞ"
else
    check "FAIL" "SSH deneme limiti ayarlı" "SSH DENEME LİMİTİ AYARLANMAMIŞ"
fi

# Açık portları güvenli şekilde rapora bağlama
echo "" >> "$REPORT"
echo "--- Açık (Dinleyen) Portlar ---" >> "$REPORT"
ss -tulnp 2>/dev/null | grep LISTEN | awk '{print $5}' | sort -u >> "$REPORT"

# Özet Skoru Hesaplama
TOTAL=$((PASS+FAIL))
echo ""
echo -e "${GREEN}--- Denetim Özeti ---${NC}"
echo -e "  Geçen kontroller: ${GREEN}${PASS}${NC} / ${TOTAL}"
echo -e "  Başarısız: ${RED}${FAIL}${NC} / ${TOTAL}"

if [ "$TOTAL" -gt 0 ]; then
    SCORE=$((PASS * 100 / TOTAL))
    echo -e "  Güvenlik skoru: ${GREEN}${SCORE}%${NC}"
    echo "" >> "$REPORT"
    echo "GÜVENLİK SKORU: ${SCORE}% (${PASS}/${TOTAL})" >> "$REPORT"
fi

echo ""

if [ "${DRY_RUN:-false}" = "true" ]; then
    echo -e "${YELLOW}[!] DRY-RUN modunda olunduğu için kalıcı rapor basılmadı.${NC}"
    rm -f "$REPORT"
else
    echo -e "${GREEN}[+] Denetim tamamlandı. Rapor başarıyla üretildi: ${REPORT}${NC}"
fi
