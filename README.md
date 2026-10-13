# Castle Hardening Tool

[![CI](https://github.com/cansabanci/castle-hardening/actions/workflows/ci.yml/badge.svg)](https://github.com/cansabanci/castle-hardening/actions/workflows/ci.yml)

Debian/Ubuntu sunucularını derinlemesine savunma (defense-in-depth) yaklaşımıyla sıkılaştıran modüler bir Bash aracı. Tek komutla altı savunma katmanını kurar, her değişikliği önce simülasyon modunda gösterir ve sistemi Castle'dan önceki orijinal ayarlarına geri döndürebilir.

## Savunma katmanları

| # | Modül | Ne yapar |
| --- | --- | --- |
| 1 | Firewall (UFW) | Varsayılan olarak gelen trafiği reddeder; SSH (gerçek portu `sshd -T` ile bulunur), HTTP ve HTTPS'e izin verir. ICMP ve SYN flood sınırlaması, geçersiz paket düşürme, port tarama tespiti (IDS/IPS), Telnet/SMB/RDP portlarını loglayıp düşürme |
| 2 | SSH | Root girişini ve boş parolayı kapatır, deneme ve oturum sınırları, tünelleme ve yönlendirmeyi kapatır, uyarı banner'ı ekler. Ayarlar `Match` bloklarından önce, global bölüme yazılır |
| 3 | Fail2ban | SSH kaba kuvvet denemelerini UFW üzerinden engeller; tekrar edenler için `recidive` jail'i |
| 4 | Servisler | Telnet, rsh, vsftpd, tftp, avahi, cups gibi gereksiz servisleri durdurur; rollback için önceki durumlarını kaydeder |
| 5 | WAF | Apache üzerinde ModSecurity + OWASP CRS; IDS modunda `DetectionOnly`, IPS modunda `On`; paranoia seviyesi ayarlanabilir |
| 6 | Denetim | sshd'nin gerçekte uyguladığı ayarları (`sshd -T`) ve servis durumlarını kontrol eder, güvenlik skoru ve rapor üretir |

## Kullanım

```bash
git clone https://github.com/cansabanci/castle-hardening.git
cd castle-hardening

# 1. Önce simülasyon: sisteme hiçbir şekilde dokunmadan ne yapılacağını gösterir
sudo ./harden.sh --dry-run

# 2. Uygula
sudo ./harden.sh --apply

# 3. Geri al (önce --dry-run ile simüle edilebilir)
sudo ./harden.sh --rollback --dry-run
sudo ./harden.sh --rollback
```

Mod açıkça seçilmelidir. Argümansız veya bilinmeyen bir argümanla (ör. `--dryrun` yazım hatası) çalıştırıldığında araç hiçbir şey yapmadan çıkar.

**Önemli:** SSH modülü `PasswordAuthentication` ayarına bilerek dokunmaz. Anahtar tabanlı girişi kendiniz test etmeden parola girişini kapatmayın; aksi halde sunucuya erişiminizi kaybedebilirsiniz.

### Örnek dry-run çıktısı

SSH ve web sunucusu kurulu olmayan bir test ortamından, kısaltılmış:

```text
=== Castle Hardening Tool ===
[!] DRY-RUN MODU: Hiçbir değişiklik yapılmayacak, sadece gösterilecek.
[*] Firewall modülü çalışıyor...
  [DRY-RUN] Yapılacak: Default incoming politikası 'deny' yapılacak
  [DRY-RUN] Yapılacak: SSH (22) rate-limit kuralı eklenecek
  [DRY-RUN] Yapılacak: ICMP flood koruması
  [DRY-RUN] Yapılacak: Port tarama tespiti (mod: IDS)
  [DRY-RUN] Yapılacak: ufw etkinleştirilecek
[*] fail2ban modülü çalışıyor...
  [DRY-RUN] Yapılacak: fail2ban yapılandırması yazıldı (jail.d/castle-sshd.local)
  [DRY-RUN] Yapılacak: fail2ban test edilip reload-or-restart edilecek
[!] Web sunucusu (Apache/Nginx) bulunamadı. WAF atlanıyor.

--- Güvenlik Kontrolleri ---
  [✗] Firewall (ufw) AKTİF DEĞİL
  [-] SSH sunucusu bulunamadı veya ayarları okunamadı, SSH kontrolleri atlandı
  [✗] fail2ban AKTİF DEĞİL
  [✓] Telnet servisi kapalı

[!] DRY-RUN tamamlandı. Hiçbir değişiklik YAPILMADI.
```

## Yapılandırma

```bash
cp castle.conf.example castle.conf
sudo chown root:root castle.conf && sudo chmod 600 castle.conf
```

| Ayar | Varsayılan | Açıklama |
| --- | --- | --- |
| `SCAN_MODE` | `IDS` | Port tarama tespiti: `IDS` sadece loglar, `IPS` engeller |
| `WAF_MODE` | `SCAN_MODE` | `IDS` = `SecRuleEngine DetectionOnly`, `IPS` = `SecRuleEngine On` |
| `PARANOIA_LEVEL` | `2` | OWASP CRS paranoia seviyesi (1–4) |
| `WHITELIST` | boş | Asla engellenmeyecek IP'ler, boşlukla ayrılmış |
| `SCAN_SECONDS` / `SCAN_HITCOUNT` | `10` / `10` | Port tarama penceresi ve eşiği |

`castle.conf` root olarak çalıştırıldığı için, root'a ait değilse veya başkaları tarafından yazılabiliyorsa araç onu yüklemeyi reddeder.

Yeni bir kurulumda önerilen yol: WAF'ı önce `IDS` modunda çalıştırıp `/var/log/apache2/modsec_audit.log` üzerinden yanlış pozitifleri ayıklamak, sonra `IPS` moduna geçmek.

## Güvenlik tasarımı

- **Merkezi değişiklik kapısı:** Sistemi değiştiren komutlar `castle_run` ve kütüphane fonksiyonlarından geçer; dry-run kararı tek bir yerde verilir.
- **Doğrulanmadan yeniden başlatma yok:** `castle_safe_service_reload` test komutu olmadan çalışmaz (`sshd -t`, `apache2ctl -t`, `fail2ban-client -t`). Test başarısız olursa SSH ve WAF konfigürasyonları bu çalıştırmadan önceki haline döner; bozuk bir dosya bir sonraki yeniden başlatmayı engelleyemez.
- **Atomik dosya yazımı:** Konfigürasyonlar aynı dizindeki geçici bir kopyaya yazılıp `mv` ile yerine konur; izin ve sahiplik korunur.
- **Gerçek orijinale rollback:** Her dosyanın Castle'dan önceki hali bir kez `*.castle-orig` olarak saklanır ve sonraki çalıştırmalarda ezilmez.
- **Güvenli durum dosyaları:** Root olarak tahmin edilebilir `/tmp` yollarına yazılmaz; durum kaydı `/var/lib/castle` (0700) altında tutulur.

## Testler

```bash
bash tests/test_lib.sh
```

Root gerektirmeyen birim testleri, kütüphane fonksiyonlarını geçici bir dizinde çalıştırır: `Match` bloğu davranışı, idempotency, özel karakterler, atomik yazma, güvenli reload ve rollback. GitHub Actions her push'ta `bash -n`, ShellCheck ve bu testleri çalıştırır.

## Güvenlik incelemesi (Ekim 2026)

Aracın kendi kodunu güvenlik ve sağlamlık açısından gözden geçirdim. ShellCheck bu hataların neredeyse hiçbirini yakalamadı; çoğu sözdizimi değil, sistemin davranışıyla ilgili mantık hatalarıydı. Her biri ayrı bir commit ile düzeltildi:

| Bulgu | Etki |
| --- | --- |
| Firewall SSH'a yalnızca 22/tcp için izin veriyordu | SSH başka portta çalışıyorsa `ufw enable` sonrası sunucuya erişim kayboluyordu |
| sshd ayarları dosyanın sonuna ekleniyordu | Sonda bir `Match` bloğu varsa ayar sadece o blokta geçerli oluyordu |
| Durum kaydı root olarak `/tmp` altında sabit bir isme yazılıyordu | Symlink saldırısıyla keyfi dosya sıfırlama (CWE-59) |
| `castle.conf` izin kontrolü olmadan root olarak çalıştırılıyordu | Dosyaya yazabilen bir kullanıcı için yetki yükseltme |
| Bilinmeyen argümanlar yok sayılıyordu, varsayılan mod "apply" idi | `--dryrun` yazım hatası canlı değişiklik yapıyordu |
| Rollback en yeni yedeği kullanıyordu | İkinci çalıştırmadan sonra sistem orijinale değil sertleştirilmiş hale dönüyordu |
| WAF modülü dry-run'da dosya değiştiriyordu; paranoia ayarı geçersiz bir satır bırakıyordu | Simülasyon sözünün ihlali; paranoia seviyesi fiilen uygulanmıyordu |
| `castle_safe_service_reload` test komutu olmadan da çalışıyordu | Konfigürasyon doğrulanmadan restart |
| Denetim sshd_config'i grep'liyordu | `Match` bloğu içindeki bir satır yanlışlıkla "geçti" sayılıyordu |

## Bilinen sınırlamalar

- Yalnızca Debian/Ubuntu (`apt`) ve WAF için yalnızca Apache desteklenir.
- Özel firewall kuralları yalnızca IPv4 (`before.rules`) için eklenir; IPv6 (`before6.rules`) kapsanmaz.
- Port tarama tespiti tüm yeni bağlantıları sayar. Yoğun bir web sunucusunda `IPS` modu meşru istemcileri de engelleyebilir; bu durumda `IDS` modunu veya `WHITELIST`'i kullanın.
- SYN flood sınırı (saniyede 25, burst 50) yoğun trafikli sunucular için düşük olabilir.

## Proje yapısı

```text
castle-hardening/
├── harden.sh            # Giriş noktası: argümanlar, yapılandırma, modülleri çalıştırma
├── castle.conf.example  # Örnek yapılandırma
├── lib/
│   └── castle_lib.sh    # castle_run, atomik yazma, güvenli reload, yedekleme ve geri yükleme
├── modules/
│   ├── firewall.sh      # Katman 1: UFW
│   ├── ssh.sh           # Katman 2: SSH
│   ├── fail2ban.sh      # Katman 3: Fail2ban
│   ├── services.sh      # Katman 4: Gereksiz servisler
│   ├── waf.sh           # Katman 5: ModSecurity + OWASP CRS
│   └── audit.sh         # Katman 6: Denetim ve rapor
└── tests/
    └── test_lib.sh      # Birim testleri
```

## Uyarı

Bu araç güvenlik duvarı, SSH ve web sunucusu yapılandırmasını değiştirir. Üretim ortamında çalıştırmadan önce bir test sanal makinesinde `--dry-run` ve `--apply` ile deneyin ve sunucuya alternatif bir erişim yolunuz (konsol) olduğundan emin olun.

## Lisans

MIT

## Yazar

**Can Sabancı** · [GitHub](https://github.com/cansabanci) · [LinkedIn](https://www.linkedin.com/in/can-sabancı-540ba026a/)
