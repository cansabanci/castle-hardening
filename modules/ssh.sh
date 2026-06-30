#!/bin/bash
#
# ssh.sh - SSH Güvenliği ve Sertleştirme Modülü
#

echo -e "${GREEN}[*] SSH sertleştirme modülü çalışıyor...${NC}"

SSHD_CONFIG="/etc/ssh/sshd_config"

if [ ! -f "$SSHD_CONFIG" ]; then
    echo -e "${RED}[!] SSH sunucusu kurulu değil, modül atlanıyor.${NC}"
    return 0
fi

castle_run "sshd_config yedeklenecek" cp "$SSHD_CONFIG" "${SSHD_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"

castle_set_config_option "$SSHD_CONFIG" "PermitRootLogin" "no"
castle_set_config_option "$SSHD_CONFIG" "PermitEmptyPasswords" "no"
castle_set_config_option "$SSHD_CONFIG" "MaxAuthTries" "3"
castle_set_config_option "$SSHD_CONFIG" "LoginGraceTime" "30"

castle_set_config_option "$SSHD_CONFIG" "ClientAliveInterval" "300"
castle_set_config_option "$SSHD_CONFIG" "ClientAliveCountMax" "2"

castle_set_config_option "$SSHD_CONFIG" "X11Forwarding" "no"
castle_set_config_option "$SSHD_CONFIG" "Protocol" "2"
castle_set_config_option "$SSHD_CONFIG" "AllowTcpForwarding" "no"
castle_set_config_option "$SSHD_CONFIG" "AllowAgentForwarding" "no"
castle_set_config_option "$SSHD_CONFIG" "PermitTunnel" "no"
castle_set_config_option "$SSHD_CONFIG" "GatewayPorts" "no"

castle_set_config_option "$SSHD_CONFIG" "IgnoreRhosts" "yes"
castle_set_config_option "$SSHD_CONFIG" "HostbasedAuthentication" "no"
castle_set_config_option "$SSHD_CONFIG" "StrictModes" "yes"

castle_set_config_option "$SSHD_CONFIG" "MaxSessions" "4"
castle_set_config_option "$SSHD_CONFIG" "MaxStartups" "10:30:60"
castle_set_config_option "$SSHD_CONFIG" "UseDNS" "no"

castle_ensure_file "/etc/ssh/castle_banner" "SSH uyarı banner'ı oluşturuldu" \
"***************************************************************
  YETKISIZ ERISIM YASAKTIR
  Bu sistem sadece yetkili kullanicilar icindir.
  Tum baglantilar loglanmakta ve izlenmektedir.
***************************************************************" "0644" "root:root"

castle_set_config_option "$SSHD_CONFIG" "Banner" "/etc/ssh/castle_banner"

echo -e "${GREEN}[+] SSH sertleştirildi (root login kapalı, deneme limiti, timeout).${NC}"
echo -e "${RED}[!] NOT: Key authentication için ek adım gerekir. Önce SSH key'inizi${NC}"
echo -e "${RED}    yüklediğinizden emin olmadan 'PasswordAuthentication no' YAPMAYIN!${NC}"

castle_safe_service_reload "ssh" "restart" sshd -t
