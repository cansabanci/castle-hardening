#  Castle Hardening Tool

**Defense-in-depth** yaklaşımıyla Linux sunucularını sertleştiren, modüler bir güvenlik otomasyon aracı.

Tek komutla 6 savunma katmanını uygular: firewall, SSH sertleştirme, brute-force koruması, servis sertleştirme, web uygulama güvenlik duvarı (WAF) ve güvenlik denetimi.

##  Özellikler

Castle, saldırı yüzeyini katman katman daraltır. Her modül belirli saldırı türlerini hedefler:

| Katman | Modül | Kapattığı Saldırılar |
|--------|-------|---------------------|
| 1 | **Firewall** (ufw) | Port tarama, exploit, ICMP/SYN flood, port scan (IDS/IPS modlu) |
| 2 | **SSH Sertleştirme** | Root brute-force, tünelleme, zayıf kripto, oturum istismarı |
| 3 | **fail2ban** | SSH/servis brute-force (otomatik IP ban) |
| 4 | **Servis Sertleştirme** | Gereksiz/tehlikeli servisler (Telnet, FTP, rsh...) |
| 5 | **WAF** (ModSecurity + OWASP CRS) | SQLi, XSS, LFI, command injection |
| 6 | **Güvenlik Denetimi** | Tüm katmanları doğrular, skor + rapor üretir |

##  Kurulum ve Kullanım

```bash
# Projeyi klonla
git clone https://github.com/cansabanci/castle-hardening.git
cd castle-hardening

# Çalıştırılabilir yap
chmod +x harden.sh modules/*.sh

# Root yetkisiyle çalıştır
sudo ./harden.sh
```

Araç idempotenttir — birden fazla kez güvenle çalıştırılabilir.

## ⚙️ Yapılandırma

`harden.sh` içindeki YAPILANDIRMA bölümünden ayarları değiştirebilirsiniz:

```bash
SCAN_MODE="IDS"        # "IDS" (sadece tespit) veya "IPS" (tespit + engelle)
WHITELIST=""           # Asla engellenmeyecek IP'ler (örn: "192.168.1.10")
SCAN_SECONDS=10        # Port tarama tespit penceresi (saniye)
SCAN_HITCOUNT=10       # Tarama eşiği (bu sayıda bağlantı = tarama)
```

##  Gereksinimler

- Linux (Debian/Ubuntu/Kali tabanlı)
- Root yetkisi
- WAF katmanı için: Apache web sunucusu (opsiyonel — yoksa otomatik atlanır)



##  Proje Yapısı

castle-hardening/

├── harden.sh              # Ana script (modülleri çağırır)

├── README.md

└── modules/

├── firewall.sh        # Katman 1

├── ssh.sh             # Katman 2

├── fail2ban.sh        # Katman 3

├── services.sh        # Katman 4

├── waf.sh             # Katman 5

└── audit.sh           # Katman 6


## ⚠️ Uyarı

Bu araç sistemde önemli güvenlik değişiklikleri yapar (SSH ayarları, firewall kuralları). Üretim sistemlerinde çalıştırmadan önce test ortamında deneyin. SSH key authentication'a geçmeden `PasswordAuthentication no` yapmayın — kendinizi sistemden kilitleyebilirsiniz.

## 📜 Lisans

MIT License

## 👤 Yazar

**Can Sabancı** — [GitHub](https://github.com/cansabanci) · [LinkedIn](www.linkedin.com/in/can-sabancı-540ba026a)


