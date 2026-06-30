#!/bin/bash
#
# ssh.sh

echo -e "${GREEN}[*] SSH sertleştirme modülü çalışıyor...${NC}"

SSHD_CONFIG="/etc/ssh/sshd_config"

if [ ! -f "$SSHD_CONFIG" ]; then
    echo -e "${RED}[!] SSH sunucusu kurulu değil, modül atlanıyor.${NC}"
    return 0
fi

run "sshd_config yedeklenecek" cp "$SSHD_CONFIG" "${SSHD_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"


set_config_option "$SSHD_CONFIG" "PermitRootLogin" "no"

set_config_option "$SSHD_CONFIG" "PermitEmptyPasswords" "no"

set_config_option "$SSHD_CONFIG" "MaxAuthTries" "3"

set_config_option "$SSHD_CONFIG" "LoginGraceTime" "30"

set_config_option "$SSHD_CONFIG" "ClientAliveInterval" "300"
set_config_option "$SSHD_CONFIG" "ClientAliveCountMax" "2"

set_config_option "$SSHD_CONFIG" "X11Forwarding" "no"

set_config_option "$SSHD_CONFIG" "Protocol" "2"

set_config_option "$SSHD_CONFIG" "AllowTcpForwarding" "no"
set_config_option "$SSHD_CONFIG" "AllowAgentForwarding" "no"
set_config_option "$SSHD_CONFIG" "PermitTunnel" "no"
set_config_option "$SSHD_CONFIG" "GatewayPorts" "no"

set_config_option "$SSHD_CONFIG" "IgnoreRhosts" "yes"
set_config_option "$SSHD_CONFIG" "HostbasedAuthentication" "no"

set_config_option "$SSHD_CONFIG" "StrictModes" "yes"

set_config_option "$SSHD_CONFIG" "MaxSessions" "4"
set_config_option "$SSHD_CONFIG" "MaxStartups" "10:30:60"

set_config_option "$SSHD_CONFIG" "UseDNS" "no"

ensure_file "/etc/ssh/castle_banner" "SSH uyarı banner'ı oluşturuldu" \
"***************************************************************
  YETKISIZ ERISIM YASAKTIR
  Bu sistem sadece yetkili kullanicilar icindir.
  Tum baglantilar loglanmakta ve izlenmektedir.
***************************************************************"
set_config_option "$SSHD_CONFIG" "Banner" "/etc/ssh/castle_banner"

echo -e "${GREEN}[+] SSH sertleştirildi (root login kapalı, deneme limiti, timeout).${NC}"
echo -e "${RED}[!] NOT: Key authentication için ek adım gerekir. Önce SSH key'inizi${NC}"
echo -e "${RED}    yüklediğinizden emin olmadan 'PasswordAuthentication no' YAPMAYIN!${NC}"

# Config'i test et + servisi güvenli reload et (hata olursa SSH'a dokunmaz)
safe_service_reload "ssh" "sshd -t" "restart"
