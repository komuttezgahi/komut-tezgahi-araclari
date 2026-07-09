# YouTube Videolarını Excel'e Aktarma

Bu araç, bir YouTube kanalındaki herkese açık yüklemeleri YouTube Data API v3 üzerinden çekip Excel dosyasına aktarır.

Araç Windows üzerinde `.bat` ve `.ps1` dosyalarıyla çalışır. Python kurulumu gerektirmez.

## Ne İşe Yarar?

- Kanalın herkese açık videolarını uploads playlist üzerinden listeler.
- Video bilgilerini 50'lik paketler halinde YouTube Data API v3 ile çeker.
- Videoları istenirse eskiden yeniye, istenirse yeniden eskiye sıralar.
- Yayın tarihini seçilen zaman dilimine göre dönüştürür.
- Excel dosyasında üç sayfa oluşturur:
  - `All`: tüm public yüklemeler
  - `Long`: süre eşiğine göre muhtemel normal videolar
  - `Shorts`: süre eşiğine göre muhtemel Shorts, kısa veya süresi bilinmeyen videolar
- Video açıklamalarını ayrıca bir `.txt` dosyasına kaydeder.

## Gereksinimler

- Windows 10 veya Windows 11
- PowerShell
- Google hesabı
- YouTube Data API v3 API anahtarı
- XLSX çıktısı için Microsoft Excel masaüstü uygulaması

Microsoft Excel kurulu değilse araç API verilerini çekebilir ve açıklama TXT dosyasını oluşturabilir; fakat XLSX dosyası oluşturulamaz.

## Dosyalar

| Dosya | Açıklama |
| --- | --- |
| `config.json` | API anahtarı, kanal bilgisi ve çıktı ayarları |
| `kanal_videolarini_excele_aktar.bat` | Aracı çift tıklayarak çalıştırmak için BAT dosyası |
| `kanal_videolarini_excele_aktar.ps1` | Ana PowerShell scripti |
| `zaman_dilimlerini_listele.bat` | Windows zaman dilimi ID listesini üretir |
| `zaman_dilimlerini_listele.ps1` | Zaman dilimi listesini oluşturan PowerShell scripti |

## Kurulum

1. Bu klasördeki dosyaları bilgisayarınızda aynı klasöre indirin.
2. `config.json` dosyasını Not Defteri veya benzeri bir metin düzenleyiciyle açın.
3. Örnek değerleri kendi bilgilerinizle değiştirin.
4. Dosyayı kaydedin.
5. `kanal_videolarini_excele_aktar.bat` dosyasını çalıştırın.

## config.json Alanları

Örnek yapı:

```json
{
  "youtube_api_key": "YOUR_YOUTUBE_DATA_API_KEY_HERE",
  "channel_handle": "@example",
  "channel_id_fallback": "UC_EXAMPLE_CHANNEL_ID",
  "min_long_video_seconds": 181,
  "sort_oldest_to_newest": true,
  "output_folder": "outputs",
  "timezone": "Turkey Standard Time"
}
```

| Alan | Açıklama |
| --- | --- |
| `youtube_api_key` | YouTube Data API v3 API anahtarınız |
| `channel_handle` | Kanalın `@` ile başlayan handle değeri |
| `channel_id_fallback` | Handle ile bulunamazsa kullanılacak yedek kanal ID değeri |
| `min_long_video_seconds` | Normal video ayrımı için süre eşiği |
| `sort_oldest_to_newest` | `true` ise eskiden yeniye, `false` ise yeniden eskiye sıralar |
| `output_folder` | Çıktıların yazılacağı klasör |
| `timezone` | Yayın saatlerinin dönüştürüleceği Windows zaman dilimi ID'si |

`channel_handle` veya `channel_id_fallback` alanlarından en az biri gerçek kanal bilgisiyle doldurulmalıdır.

## Zaman Dilimi Seçme

Varsayılan değer:

```text
Turkey Standard Time
```

Başka bir zaman dilimi kullanmak için `zaman_dilimlerini_listele.bat` dosyasını çalıştırın. Aynı klasörde `zaman_dilimleri.txt` dosyası oluşur.

Bu dosyada satırlar şu biçimdedir:

```text
Turkey Standard Time | (UTC+03:00) İstanbul
```

`config.json` içindeki `timezone` alanına dikey çizginin solundaki ID değerini yazın.

## Çıktılar

Araç çalışınca `output_folder` alanında belirtilen klasör oluşturulur. Varsayılan klasör:

```text
outputs
```

Oluşan dosyalar:

- `KANAL_ADI_eskiden_yeniye.xlsx`
- `KANAL_ADI_aciklamalar_eskiden_yeniye.txt`

Sıralama yeniden eskiye ayarlanırsa dosya adındaki ek `yeniden_eskiye` olur.

## Excel Sütunları

Excel dosyasında şu sütunlar bulunur:

| Sütun | Açıklama |
| --- | --- |
| `published_local_date` | Seçilen zaman dilimine göre yayın tarihi |
| `published_local_time` | Seçilen zaman dilimine göre yayın saati |
| `published_local_full` | Seçilen zaman dilimine göre tam yayın zamanı |
| `published_utc_full` | UTC yayın zamanı |
| `title` | Video başlığı |
| `video_id` | YouTube video ID değeri |
| `url` | Video bağlantısı |
| `duration_seconds` | Video süresi, saniye |
| `duration_hms` | Video süresi, saat/dakika/saniye formatı |
| `view_count` | Görüntülenme sayısı |
| `like_count` | Beğeni sayısı |
| `comment_count` | Yorum sayısı |
| `privacy_status` | Videonun gizlilik durumu |
| `made_for_kids` | Çocuklara yönelik olarak işaretlenip işaretlenmediği |
| `video_length_type` | Süreye göre muhtemel video tipi |
| `is_probably_long_video` | Süre eşiğine göre muhtemel normal video bilgisi |

## Shorts Ayrımı Hakkında

Bu araç YouTube'dan resmi bir "bu video Shorts'tur" alanı almaz. Ayrım süreye göre yapılır.

Varsayılan eşik:

```text
181 saniye
```

- 181 saniye ve üzeri: `muhtemel_normal_video`
- 181 saniyenin altı: `muhtemel_shorts_veya_kisa`
- Süresi alınamayanlar: `sure_bilinmiyor`

Bu nedenle `Shorts` sayfası kesin Shorts listesi değil, süreye göre muhtemel Shorts/kısa/bilinmeyen video listesidir.

## Kota Bilgisi

Bu araç şu YouTube Data API v3 çağrılarını kullanır:

- `channels.list`
- `playlistItems.list`
- `videos.list`

Bu çağrılar düşük kota maliyetlidir. Yaklaşık hesap:

```text
1 + 2 x tavan(video sayısı / 50)
```

Örnek:

- 100 video: yaklaşık 5 kota birimi
- 1.000 video: yaklaşık 41 kota birimi
- 10.000 video: yaklaşık 401 kota birimi
- 50.000 video: yaklaşık 2.001 kota birimi

Bu değerler yaklaşık hesaptır. Tekrar denemeler, hata durumları veya aynı API anahtarıyla yapılan başka işlemler toplam kullanımı etkileyebilir.

## Güvenlik

Gerçek API anahtarınızı kimseyle paylaşmayın.

Bu dosyaları herkese açık bir repoda paylaşacaksanız `config.json` içinde gerçek API anahtarı olmadığından emin olun. Örnek değer bırakmak güvenlidir; gerçek anahtar bırakmak güvenli değildir.

Yanlışlıkla gerçek API anahtarınızı paylaşırsanız Google Cloud Console üzerinden anahtarı iptal edin veya yenileyin.

## Sorun Giderme

### XLSX oluşmadı

Microsoft Excel masaüstü uygulaması kurulu olmayabilir. Bu script XLSX üretmek için Excel COM nesnesini kullanır.

### Kanal bulunamadı

`config.json` içindeki `channel_handle` veya `channel_id_fallback` değerini kontrol edin.

### API hatası alıyorum

Şunları kontrol edin:

- API anahtarı doğru mu?
- YouTube Data API v3 etkin mi?
- API anahtarı YouTube Data API v3 ile sınırlandırıldıysa doğru API seçildi mi?
- Kota dolmuş olabilir mi?

### Zaman dilimi bulunamadı

`zaman_dilimlerini_listele.bat` dosyasını çalıştırın ve `zaman_dilimleri.txt` içindeki ID değerlerinden birini `config.json` dosyasındaki `timezone` alanına yazın.

## Lisans

Bu dosyalar Komut Tezgahı kanalında anlatılan eğitim akışı için hazırlanmıştır. Repodaki genel lisans koşulları geçerlidir.
