# Güvenli Kullanım

Bu notlar, Komut Tezgahı araçlarını kendi bilgisayarında çalıştırırken API anahtarlarını, hesap bilgilerini ve kişisel dosyalarını güvende tutman için hazırlanmıştır.

## Kişisel Bilgilerini Yerel Tut

Bu araçları kullanırken bazı dosyalara YouTube Data API anahtarı, kanal ID’si, çıktı klasörü veya benzeri ayarlar yazman gerekebilir. Bu bilgileri yalnızca kendi bilgisayarındaki yerel ayar dosyalarında tut.

Aşağıdaki bilgileri videolarda, ekran görüntülerinde, yorumlarda veya başkalarıyla paylaştığın dosyalarda görünür bırakma:

- Gerçek YouTube Data API anahtarları
- OAuth token dosyaları
- `client_secret` dosyaları
- Google hesabına ait kimlik/credential dosyaları
- Kişisel dosya yolları, e-posta adresleri veya telefon numaraları
- Sana ait özel çıktı dosyaları

## Örnek Ayar Dosyalarını Kullan

Bir araç klasöründe `config.example.json` varsa, bu dosya yalnızca örnek olarak verilmiştir.

Kullanım mantığı genellikle şöyledir:

1. `config.example.json` dosyasını kendi bilgisayarında `config.json` adıyla kopyala.
2. Gerçek API anahtarını veya kanal bilgini yalnızca bu yerel `config.json` dosyasına yaz.
3. Bu yerel dosyayı başkalarıyla paylaşma.

## API Anahtarını Yanlışlıkla Paylaşırsan

API anahtarının görünür olduğunu fark edersen, aynı anahtarı kullanmaya devam etme.

- Google Cloud Console üzerinden anahtarı iptal et veya yenile.
- Yeni anahtarı yalnızca kendi yerel ayar dosyana yaz.
- Eski anahtarın ekran görüntüsünde, videoda veya paylaşılan bir dosyada kalıp kalmadığını kontrol et.

## PowerShell ve BAT Dosyalarını Çalıştırmadan Önce

İnternet’ten indirdiğin `.ps1` ve `.bat` dosyalarını çalıştırmadan önce içeriğini mutlaka oku.

Bu repodaki araçlar mümkün olduğunca açık, okunabilir ve yönetici yetkisi gerektirmeyecek şekilde hazırlanır. Yine de herhangi bir komut dosyasını çalıştırmadan önce ne yaptığını anlamak iyi bir alışkanlıktır.
