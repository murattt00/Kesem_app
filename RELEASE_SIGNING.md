# Kesem — Release İmzalama (yayın anahtarı)

Play Store'a yüklemek için uygulamanın **kendi imza anahtarınla** imzalanması gerekir.
Bu bir kez yapılır. **Anahtarı kaybetme** — kaybedersen uygulamayı bir daha
güncelleyemezsin.

## 1) Anahtar deposunu (keystore) oluştur
Repo dışında bir klasör aç (ör. `C:\Users\user\keys`) ve orada terminalde çalıştır:

```bash
keytool -genkey -v -keystore C:\Users\user\keys\kesem-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

> `keytool` bulunamazsa Java ile birlikte gelir; tam yolu:
> `"C:\Program Files\Java\jdk-24\bin\keytool.exe"` (sürüm numarası farklı olabilir).

Komut sana şunları soracak:
- **Anahtar deposu şifresi** (storePassword) — belirle, not al
- Ad, kurum, şehir vb. — istediğini yaz (boş geçebilirsin)
- **Anahtar şifresi** (keyPassword) — aynı şifreyi kullanabilirsin

## 2) key.properties dosyasını doldur
`android/key.properties.example` dosyasını `android/key.properties` olarak
kopyala ve doldur:

```
storePassword=(1. adımdaki store şifren)
keyPassword=(1. adımdaki key şifren)
keyAlias=upload
storeFile=C:/Users/user/keys/kesem-upload.jks
```

## 3) Yayın paketini üret
```bash
flutter build appbundle --release --no-tree-shake-icons
```
Çıktı: `build/app/outputs/bundle/release/app-release.aab` → Play Console'a **bu AAB**
yüklenir.

## ⚠️ Güvenlik
- `key.properties` ve `.jks` dosyasını **paylaşma, repoya koyma.**
- `.jks` dosyasının **yedeğini** güvenli bir yerde sakla (bulut/USB).
- Şifreleri bir parola yöneticisine kaydet.

> `key.properties` yoksa uygulama otomatik olarak debug anahtarıyla imzalanır
> (geliştirme/telefon testi için sorun değil, ama Play Store'a yüklenemez).
