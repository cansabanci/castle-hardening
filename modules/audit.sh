#!/bin/bash
#
# audit.sh - Güvenlik denetim modülü
# Sistemin güvenlik durumunu kontrol eder ve rapor üretir
#

echo -e "${GREEN}[*] Güvenlik denetim modülü çalışıyor...${NC}"

# Rapor dosyası
REPORT="/var/log/castle-audit-$(date +%Y%m%d_%H%M%S).txt"

# Sayaçlar
PASS=0
FAIL=0

# Bir kontrolü yapıp sonucu yazan yardımcı fonksiyon
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

# Rapor başlığı
echo "===== CASTLE GÜVENLİK DENETİM RAPORU =====" > "$REPORT"
echo "Tarih: $(date)" >> "$REPORT"
echo "Sistem: $(hostname)" >> "$REPORT"
echo "==========================================" >> "$REPORT"
echo "" >> "$REPORT"

echo ""
echo -e "${GREEN}--- Güvenlik Kontrolleri ---${NC}"

# 1. Firewall aktif mi?
if ufw status | grep -q "Status: active"; then
    check "Firewall (ufw) aktif" "OK"
else
    check "Firewall (ufw) aktif" "FAIL"
fi

# 2. SSH root login kapalı mı?
if grep -qE "^PermitRootLogin\s+no" /etc/ssh/sshd_config 2>/dev/null; then
    check "SSH root login kapalı" "OK"
else
    check "SSH root login kapalı" "FAIL"
fi

# 3. SSH boş şifre yasak mı?
if grep -qE "^PermitEmptyPasswords\s+no" /etc/ssh/sshd_config 2>/dev/null; then
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

# 5. Tehlikeli servisler kapalı mı? (telnet örneği)
if ! systemctl is-active --quiet telnet 2>/dev/null && ! systemctl is-active --quiet telnetd 2>/dev/null; then
    check "Telnet servisi kapalı" "OK"
else
    check "Telnet servisi kapalı" "FAIL"
fi

# 6. SSH deneme limiti var mı?
if grep -qE "^MaxAuthTries\s+[1-5]$" /etc/ssh/sshd_config 2>/dev/null; then
    check "SSH deneme limiti ayarlı" "OK"
else
    check "SSH deneme limiti ayarlı" "FAIL"
fi

# Açık portları rapora ekle
echo "" >> "$REPORT"
echo "--- Açık (Dinleyen) Portlar ---" >> "$REPORT"
ss -tulnp 2>/dev/null | grep LISTEN | awk '{print $5}' | sort -u >> "$REPORT"

# Özet skoru hesapla
TOTAL=$((PASS+FAIL))
echo ""
echo -e "${GREEN}--- Denetim Özeti ---${NC}"
echo -e "  Geçen kontroller: ${GREEN}${PASS}${NC} / ${TOTAL}"
echo -e "  Başarısız: ${RED}${FAIL}${NC} / ${TOTAL}"

# Güvenlik skoru (yüzde)
if [ "$TOTAL" -gt 0 ]; then
    SCORE=$((PASS * 100 / TOTAL))
    echo -e "  Güvenlik skoru: ${GREEN}${SCORE}%${NC}"
    echo "" >> "$REPORT"
    echo "GÜVENLİK SKORU: ${SCORE}% (${PASS}/${TOTAL})" >> "$REPORT"
fi

echo ""
echo -e "${GREEN}[+] Denetim tamamlandı. Rapor: ${REPORT}${NC}"
