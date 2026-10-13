#!/bin/bash
#
# tests/test_lib.sh
#
# lib/castle_lib.sh fonksiyonları için root gerektirmeyen birim testleri.
# Gerçek sistem dosyalarına dokunmaz; her şey geçici bir dizinde çalışır.
#
# Kullanım: bash tests/test_lib.sh

set -u

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/castle_lib.sh
source "$ROOT_DIR/lib/castle_lib.sh"

# Kütüphane fonksiyonlarının kullandığı ortam değişkenleri
export RED='' GREEN='' YELLOW='' NC=''
export DRY_RUN="false"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASSED=0
FAILED=0

ok()   { echo "  [PASS] $1"; PASSED=$((PASSED+1)); }
fail() { echo "  [FAIL] $1"; FAILED=$((FAILED+1)); }

assert_eq() {
    if [ "$1" = "$2" ]; then ok "$3"; else fail "$3 (beklenen: '$2', gelen: '$1')"; fi
}

# ------------------------------------------------------------------------------
echo "castle_set_config_option"
# ------------------------------------------------------------------------------

cfg="$WORK/sshd_config"
cat > "$cfg" <<'EOF'
Port 22
#PermitRootLogin prohibit-password
X11Forwarding yes

Match User deploy
    X11Forwarding yes
    PermitRootLogin yes
EOF

castle_set_config_option "$cfg" "PermitRootLogin" "no"
castle_set_config_option "$cfg" "X11Forwarding" "no"
castle_set_config_option "$cfg" "MaxAuthTries" "3"

match_line=$(grep -n '^Match' "$cfg" | cut -d: -f1)
last_global_set=$(grep -nE '^(PermitRootLogin no|X11Forwarding no|MaxAuthTries 3)$' "$cfg" | tail -1 | cut -d: -f1)

if [ -n "$last_global_set" ] && [ "$last_global_set" -lt "$match_line" ]; then
    ok "Yeni ayarlar Match bloğundan önce (global bölümde) yazıldı"
else
    fail "Ayarlar Match bloğunun içine düştü"; cat "$cfg"
fi

assert_eq "$(grep -c '^PermitRootLogin no$' "$cfg")" "1" "Global PermitRootLogin tek satır"
assert_eq "$(grep -c 'prohibit-password' "$cfg")" "0" "Yorumlu eski tanım temizlendi"
assert_eq "$(sed -n '/^Match/,$p' "$cfg" | grep -c 'PermitRootLogin yes')" "1" "Match bloğunun içine dokunulmadı"

# İkinci çalıştırmada dosya değişmemeli (idempotency)
before="$(md5sum < "$cfg")"
castle_set_config_option "$cfg" "PermitRootLogin" "no"
castle_set_config_option "$cfg" "MaxAuthTries" "3"
assert_eq "$(md5sum < "$cfg")" "$before" "Tekrar çalıştırmak dosyayı değiştirmiyor"

# Özel karakterler regex'e girmemeli
castle_set_config_option "$cfg" "Banner" '/etc/a|b&c\d'
assert_eq "$(grep -c '^Banner /etc/a|b&c\\d$' "$cfg")" "1" "Değerdeki | & \\ karakterleri dosyayı bozmadı"

# Büyük/küçük harf duyarsızlığı
printf 'permitemptypasswords yes\n' > "$cfg"
castle_set_config_option "$cfg" "PermitEmptyPasswords" "no"
assert_eq "$(cat "$cfg")" "PermitEmptyPasswords no" "Küçük harfli eski tanım değiştirildi"

# İzinler korunmalı
printf 'A 1\n' > "$cfg"; chmod 600 "$cfg"
castle_set_config_option "$cfg" "A" "2"
assert_eq "$(stat -c %a "$cfg")" "600" "Dosya izinleri korundu"
assert_eq "$(find "$WORK" -name 'sshd_config.castle.*' | wc -l)" "0" "Geride geçici dosya kalmadı"

# ------------------------------------------------------------------------------
echo "castle_ensure_file"
# ------------------------------------------------------------------------------

target="$WORK/banner"
castle_ensure_file "$target" "test" "merhaba" "0640" "$(id -un):$(id -gn)" > /dev/null
assert_eq "$(cat "$target")" "merhaba" "İçerik yazıldı"
assert_eq "$(stat -c %a "$target")" "640" "İzin uygulandı"
assert_eq "$(find "$WORK" -name 'banner.castle.*' | wc -l)" "0" "Geride geçici dosya kalmadı"

if castle_ensure_file "$WORK/yok/dizin/dosya" "test" "x" "0644" "$(id -un):$(id -gn)" 2>/dev/null; then
    fail "Var olmayan dizine yazma başarılı sayıldı"
else
    ok "Var olmayan dizine yazma hata döndürdü"
fi

# ------------------------------------------------------------------------------
echo "castle_safe_service_reload"
# ------------------------------------------------------------------------------

if castle_safe_service_reload "ssh" 2>/dev/null; then
    fail "Test komutu olmadan çağrı kabul edildi"
else
    ok "Tek argümanla çağrı reddedildi"
fi

if castle_safe_service_reload "ssh" "restart" 2>/dev/null; then
    fail "Test komutu olmadan restart kabul edildi"
else
    ok "Test komutu olmadan restart reddedildi"
fi

if castle_safe_service_reload "ssh" "restart" false 2>/dev/null; then
    fail "Başarısız test komutuna rağmen devam edildi"
else
    ok "Başarısız test komutu restart'ı durdurdu"
fi

# ------------------------------------------------------------------------------
echo "castle_restore_file"
# ------------------------------------------------------------------------------

orig="$WORK/app.conf"
printf 'orijinal\n' > "$orig"
castle_backup_original "$orig" > /dev/null
printf 'sertlestirilmis-1\n' > "$orig"
castle_backup_original "$orig" > /dev/null   # ikinci çalıştırma orijinal yedeği EZMEMELİ
printf 'sertlestirilmis-2\n' > "$orig"
castle_restore_file "$orig" "test" > /dev/null
assert_eq "$(cat "$orig")" "orijinal" "Rollback, ilk çalıştırmadan önceki orijinal hali geri yükledi"

# ------------------------------------------------------------------------------
echo ""
echo "Sonuç: $PASSED geçti, $FAILED başarısız"
[ "$FAILED" -eq 0 ]
