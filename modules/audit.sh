#!/bin/bash
#
# audit.sh


echo -e "${GREEN}[*] Güvenlik denetim modülü çalışıyor...${NC}"

# Rapor dosyası tanımı
# Dry-run raporu mktemp ile oluşturulur (tahmin edilebilir bir /tmp adına root
# olarak yazmak symlink saldırısına açıktır). Rapor açık portları içerdiği için
# yalnızca root okuyabilir (umask 077).
if [ "${DRY_RUN:-false}" = "true" ]; then
    REPORT="$(mktemp /tmp/castle-audit-dryrun.XXXXXX)"
else
    REPORT="/var/log/castle-audit-$(date +%Y%m%d_%H%M%S).txt"
    (umask 077; : > "$REPORT")
fi

# sshd'nin GERÇEKTE uyguladığı ayarlar (Match/Include dahil). sshd_config'i
# grep'lemek yanıltıcıdır: bir satır dosyada olsa da bir Match bloğunun
# içindeyse global olarak geçerli değildir.
SSHD_EFFECTIVE="$(sshd -T 2>/dev/null)"
sshd_effective() {   # sshd_effective <anahtar> <değer-regex>
    printf '%s\n' "$SSHD_EFFECTIVE" | grep -qiE "^$1[[:space:]]+$2\$"
}

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
if [ "${DRY_RUN:-false}" = "true" ]; then
    echo "Mod: DRY-RUN (Simülasyon)" >> "$REPORT"
else
    echo "Mod: APPLY" >> "$REPORT"
fi
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

if [ -z "$SSHD_EFFECTIVE" ]; then
    # sshd yok veya ayarları okunamıyor: SSH kontrolleri "başarısız" sayılırsa
    # SSH çalışmayan bir sunucuda yanlış alarm (false positive) üretir.
    echo -e "  ${YELLOW}[-]${NC} SSH sunucusu bulunamadı veya ayarları okunamadı, SSH kontrolleri atlandı"
    echo "[SKIP] SSH kontrolleri (sshd -T okunamadı)" >> "$REPORT"
else
    # 2. SSH root login kapalı mı?
    if sshd_effective permitrootlogin no; then
        check "OK" "SSH root login kapalı" "SSH ROOT LOGIN AÇIK (GÜVENSİZ)"
    else
        check "FAIL" "SSH root login kapalı" "SSH ROOT LOGIN AÇIK (GÜVENSİZ)"
    fi

    # 3. SSH boş şifre yasak mı?
    if sshd_effective permitemptypasswords no; then
        check "OK" "SSH boş şifre yasak" "SSH BOŞ ŞİFREYE İZİN VERİLİYOR (GÜVENSİZ)"
    else
        check "FAIL" "SSH boş şifre yasak" "SSH BOŞ ŞİFREYE İZİN VERİLİYOR (GÜVENSİZ)"
    fi

    # 6. SSH deneme limiti var mı?
    if sshd_effective maxauthtries "[1-5]"; then
        check "OK" "SSH deneme limiti ayarlı" "SSH DENEME LİMİTİ AYARLANMAMIŞ"
    else
        check "FAIL" "SSH deneme limiti ayarlı" "SSH DENEME LİMİTİ AYARLANMAMIŞ"
    fi
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
