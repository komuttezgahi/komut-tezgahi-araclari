# Komut Tezgahı Araçları

Komut Tezgahı kanalında anlatılan yerel içerik, veri ve otomasyon araçlarının paylaşım deposu.

Buradaki dosyalar; YouTube kanal analizi, içerik üretim otomasyonu, PowerShell/BAT iş akışları, FFmpeg tabanlı video üretimi ve Excel çıktıları gibi süreçleri kendi bilgisayarında çalıştırmak isteyenler için hazırlanır.

## Ne Bulacaksınız?

- YouTube Data API v3 ile kanal ve video verisi çekme örnekleri
- Bir YouTube kanalındaki videoları Excel'e aktarma iş akışları
- Outlier video bulma ve kanal analizi denemeleri
- Script'i sese, PDF'i görsele ve ses/görsel paketini taslak videoya dönüştüren pipeline örnekleri
- PowerShell, BAT, FFmpeg ve Excel odaklı yerel üretim araçları

## Araç Klasörleri

```text
tools/
  kanal-videolari-excel/
  outlier-video-bulucu/
  scriptten-videoya/
  ffmpeg-video-pipeline/
```

Her araç klasöründe kurulum, kullanım, gerekli ayarlar ve örnek çıktı bilgileri yer alacak.

## Kullanım

1. İlgili `tools/` klasörüne girin.
2. Araç README dosyasındaki gereksinimleri okuyun.
3. Varsa `config.example.json` dosyasını kendi bilgisayarınızda `config.json` olarak kopyalayın.
4. Kendi API anahtarınızı veya kanal bilginizi bu yerel config dosyasına yazın.
5. BAT veya PowerShell dosyasını çalıştırın.

## Not

API anahtarınızı, token dosyalarınızı ve kişisel dosyalarınızı kimseyle paylaşmayın. Ayrıntılı kontrol listesi için `docs/guvenlik-notlari.md` dosyasına bakabilirsiniz.

## Kanal

YouTube: https://www.youtube.com/@komuttezgahi

## Lisans

Bu depo MIT lisansı ile paylaşılır. Detaylar için `LICENSE` dosyasına bakın.
