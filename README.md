Castle Hardening Tool 🏰

Defense-in-depth (Derinlemesine Savunma) yaklaşımıyla Linux sunucularını sertleştiren, kurumsal standartlarda yazılmış modüler bir güvenlik otomasyon aracıdır. 

Tek bir komutla sisteminizde 6 farklı savunma katmanını devreye sokar, olası bir olumsuzlukta ise **tek komutla tüm sistemi milimetrik olarak eski orijinal haline döndürebilir (Rollback)**.

---

## 🔥 Temel Özellikler

* **Katmanlı Savunma:** Saldırı yüzeyini katman katman daraltır.
* **Tam Idempotency:** Sistem yapılandırmasını bozmadan, üst üste güvenle sonsuz kez çalıştırılabilir.
* **Güvenli Rollback (P0.6):** Yapılan tüm değişiklikleri zaman damgalı (`timestamp`) yedeklerle tek adımda geri alır, sistemde asla çöp bırakmaz.
* **Dinamik Güvenlik Denetimi:** Kontrol edilen servislerin anlık durumuna göre akıllı ve dinamik raporlama yapar.

---

## 🛡️ Savunma Katmanları ve Engellediği Saldırılar

| Katman | Modül | Engellediği / Tespit Ettiği Saldırılar |
| :--- | :--- | :--- |
| **1** | **Firewall (UFW)** | Port tarama, Exploit denemeleri, ICMP/SYN Flood (IDS/IPS Modlu) |
| **2** | **SSH Sertleştirme** | Root Brute-Force, Tünelleme istismarları, Zayıf Kripto, Oturum Kesişmeleri |
| **3** | **Fail2Ban** | SSH/Servis Brute-Force saldırıları (Otomatik akıllı IP ban) |
| **4** | **Servis Sertleştirme** | Gereksiz/Tehlikeli eski protokoller (Telnet, FTP, rsh, rclogin...) |
| **5** | **WAF (ModSecurity)** | OWASP Top 10 (SQLi, XSS, LFI, Command Injection) - Paranoia Level 2 |
| **6** | **Güvenlik Denetimi** | Tüm katmanların atomik doğrulaması, Güvenlik Skoru + Kalıcı Raporlama |

---

## 🚀 Kurulum ve Kullanım

```bash
1. Projeyi Klonlayın ve Klasöre Geçin
git clone [https://github.com/cansabanci/castle-hardening.git](https://github.com/cansabanci/castle-hardening.git)
cd castle-hardening

# Çalıştırılabilir yap
chmod +x harden.sh modules/*.sh

# 1. DRY-RUN MODE (Simülasyon - Sisteme dokunmadan ne yapacağını gösterir)
sudo ./harden.sh --dry-run

# 2. APPLY MODE (Canlı Mod - Tüm güvenlik zırhlarını sisteme giydirir)
sudo ./harden.sh --apply

# 3. ROLLBACK MODE (Geri Alma - Sistemi sıkılaştırma öncesindeki orijinal haline döndürür)
sudo ./harden.sh --rollback

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
- WAF katmanı için: Web sunucusu (opsiyonel — yoksa otomatik atlanır)



##  Proje Yapısı

castle-hardening/
├── harden.sh           # Ana yönetim merkezi (Parametreleri parse eder ve modülleri çağırır)
├── castle.conf         # Merkezi konfigürasyon dosyası
├── README.md           # Dokümantasyon
├── lib/
│   └── castle_lib.sh   # POSIX uyumlu, atomik dosya yazma ve yedekleme kütüphanesi
└── modules/
    ├── firewall.sh     # Katman 1: Ağ ve Port Güvenliği
    ├── ssh.sh          # Katman 2: Uzaktan Erişim Sertleştirme
    ├── fail2ban.sh     # Katman 3: Brute-Force Engelleyici
    ├── services.sh     # Katman 4: Servis ve Port Sıkılaştırma
    ├── waf.sh          # Katman 5: Web Uygulama Güvenlik Duvarı (OWASP CRS)
    └── audit.sh        # Katman 6: Dinamik Doğrulama ve Raporlama


## ⚠️ Uyarı

Bu araç sistem genelinde kritik konfigürasyon değişiklikleri yapar. Üretim (Production) ortamlarında çalıştırmadan önce kesinlikle bir test labında simüle edilmelidir. SSH modülü anahtar tabanlı kimlik doğrulamayı (Key Authentication) zorunlu kılacak altyapıyı hazırlar; kendi anahtarınızı sunucuya eklemeden bağlantı izinlerini tamamen kapatmamanız (kendinizi sistem dışı bırakmamanız) önemle tavsiye edilir.

## 📜 Lisans

MIT License

## 👤 Yazar

**Can Sabancı** — [GitHub](https://github.com/cansabanci) · [LinkedIn](www.linkedin.com/in/can-sabancı-540ba026a)


