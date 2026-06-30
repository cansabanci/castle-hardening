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

# Bir kontrolü yapıp sonucu yazan ve raporlayan iç fonksiyon
check() {
    local description="$1"
    local condition="$2"  # "OK" veya "FAIL"

    if [ "$condition" = "OK" ]; then
        echo -e "  ${GREEN}[✓]${NC} $description"
        echo "[PASS] $description" >> "$REPORT"
        PASS=$((PASS+1))
    else
        echo -e "  ${RED}[✗]${NC} $description"
        echo "[FAIL] $description" >> "$REPORT"
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

# 1. Firewall aktif mi?
if ufw status 2>/dev/null | grep -Fq -- "Status: active"; then
    check "Firewall (ufw) aktif" "OK"
else
    check "Firewall (ufw) aktif" "FAIL"
fi

# 2. SSH root login kapalı mı?
if grep -qE "^[[:space:]]*PermitRootLogin[[:space:]]+no" /etc/ssh/sshd_config 2>/dev/null; then
    check "SSH root login kapalı" "OK"
else
    check "SSH root login kapalı" "FAIL"
fi

# 3. SSH boş şifre yasak mı?
if grep -qE "^[[:space:]]*PermitEmptyPasswords[[:space:]]+no" /etc/ssh/sshd_config 2>/dev/null; then
    check "SSH boş şifre yasak" "OK"
else
    check "SSH boş şifre yasak" "FAIL"
fi

# 4. fail2ban çalışıyor mu?
if systemctl is-active --quiet fail2ban 2>/dev/null; then
    check "fail2ban aktif (brute-force koruması)" "OK"
else
    check "fail2ban aktif (brute-force koruması)" "FAIL"
fi

# 5. Tehlikeli servisler kapalı mı?
if ! systemctl is-active --quiet telnet 2>/dev/null && ! systemctl is-active --quiet telnetd 2>/dev/null; then
    check "Telnet servisi kapalı" "OK"
else
    check "Telnet servisi kapalı" "FAIL"
fi

# 6. SSH deneme limiti var mı?
if grep -qE "^[[:space:]]*MaxAuthTries[[:space:]]+[1-5]" /etc/ssh/sshd_config 2>/dev/null; then
    check "SSH deneme limiti ayarlı" "OK"
else
    check "SSH deneme limiti ayarlı" "FAIL"
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
