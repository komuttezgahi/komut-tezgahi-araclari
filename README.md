# Komut Tezgahi Araclari

Komut Tezgahi kanalinda paylasilan yerel icerik, veri ve otomasyon araclari icin ana depo.

Bu repo; YouTube kanal analizi, icerik uretim otomasyonu, PowerShell/BAT is akislari, FFmpeg tabanli video uretimi ve Excel ciktilari gibi konularda paylasilacak araclari toplamak icin olusturuldu.

## Ne Bulacaksiniz?

- YouTube Data API v3 ile kanal ve video verisi cekme araclari
- Bir YouTube kanalindaki videolari Excel'e aktarma is akislari
- Outlier video bulma ve kanal analizi denemeleri
- Script'i sese, PDF'i gorsele ve ses/gorsel paketini taslak videoya donusturen pipeline ornekleri
- PowerShell, BAT, FFmpeg ve Excel odakli yerel uretim araclari

## Planlanan Arac Klasorleri

```text
tools/
  kanal-videolari-excel/
  outlier-video-bulucu/
  scriptten-videoya/
  ffmpeg-video-pipeline/
```

Ilk araclar video yayinlandikca bu klasorlere eklenecek. Her arac kendi README dosyasinda kurulum, kullanim, gerekli ayarlar ve ornek cikti bilgilerini tasiyacak.

## Guvenlik Notu

Bu repoda gercek API anahtari, token, client secret, kanal hesabina ait ozel dosyalar veya kisisel veri bulunmamalidir.

Araclari kullanirken kendi bilgisayarinizda config.json veya benzeri yerel ayar dosyasi olusturabilirsiniz; fakat bu dosyalar repoya yuklenmemelidir. Ornek ayarlar icin config.example.json dosyalarini kullanin.

## Genel Kullanim Mantigi

1. Ilgili arac klasorune girin.
2. README dosyasindaki gereksinimleri okuyun.
3. config.example.json dosyasini kopyalayip kendi yerel config dosyanizi olusturun.
4. Kendi API anahtarinizi veya kanal bilginizi yerel config dosyaniza ekleyin.
5. BAT veya PowerShell dosyasini calistirin.

## Kanal

YouTube: https://www.youtube.com/@komuttezgahi

## Lisans

Bu depo MIT lisansi ile paylasilir. Detaylar icin LICENSE dosyasina bakin.
