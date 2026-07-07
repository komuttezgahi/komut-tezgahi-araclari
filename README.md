# Komut Tezgahı Araçları

Komut Tezgahı kanalında paylaşılan yerel içerik, veri ve otomasyon araçları için ana depo.

Bu repo, YouTube kanal analizi, içerik üretim otomasyonu, PowerShell/BAT iş akışları, FFmpeg tabanlı video üretimi ve Excel çıktıları gibi konularda paylaşılacak araçları toplamak için oluşturuldu.

## Ne Bulacaksınız?

- YouTube Data API v3 ile kanal ve video verisi çekme araçları
- Bir YouTube kanalındaki videolari Excel'e aktarma iş akışları
- Outlier video bulma ve kanal analizi denemeleri
- Script'i sese, PDF'i görsele ve ses/görsel paketini taslak videoya dönüştüren pipeline örnekleri
- PowerShell, BAT, FFmpeg ve Excel odaklı yerel üretim araçları

## Planlanan Araç Klasörleri

```text
tools/
  kanal-videolari-excel/
  outlier-video-bulucu/
  scriptten-videoya/
  ffmpeg-video-pipeline/
```

İlk araçlar video yayınlandıkça bu klasörlere eklenecek. Her araç kendi README dosyasında kurulum, kullanım, gerekli ayarlar ve örnek çıktı bilgilerini taşıyacak.

## Güvenlik Notu

Bu repoda gerçek API anahtarı, token, client secret, kanal hesabına ait özel dosyalar veya kişisel veri bulunmamalıdır.

Araçları kullanırken kendi bilgisayarınızda config.json veya benzeri yerel ayar dosyası oluşturabilirsiniz; fakat bu dosyalar repoya yüklenmemelidir. Örnek ayarlar için config.example.json dosyalarını kullanın.

## Genel Kullanım Mantığı

1. İlgili araç klasörüne girin.
2. README dosyasındaki gereksinimleri okuyun.
3. config.example.json dosyasını kopyalayıp kendi yerel config dosyanızı oluşturun.
4. Kendi API anahtarınızı veya kanal bilginizi yerel config dosyanıza ekleyin.
5. BAT veya PowerShell dosyasını çalıştırın.

## Kanal

YouTube: https://www.youtube.com/@komuttezgahi

## Lisans

Bu depo MIT lisansı ile paylaşılır. Detaylar için LICENSE dosyasına bakın.
