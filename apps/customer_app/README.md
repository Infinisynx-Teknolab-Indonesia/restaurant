# RestoBake (Pelanggan)

| | |
|---|---|
| Untuk | **Pelanggan / member** |
| Perangkat | HP Android & iPhone |
| Nama di HP | **RestoBake** |
| Application ID / Bundle ID | `com.restobake.customer` |
| Akun contoh | No. HP `081234567890` · password `member123` (atau daftar akun baru dari aplikasi) |

**Fitur:** Lihat menu makanan & minuman, keranjang, voucher & poin, pesan online (Ambil / Antar / Makan di sini), bayar QRIS / kartu / di kasir, lacak status pesanan realtime.

Folder ini adalah project Flutter **lengkap & berdiri sendiri** (sudah ada `android/` dan `ios/`, ikon, izin internet & HTTP lokal).
Kode bersama ada di `../../packages/resto_core` — jangan pindahkan folder ini keluar dari `RestoBake/`.

## Instalasi

Butuh **Flutter 3.27+** (cek: `flutter --version`), Android Studio (untuk Android) atau Xcode di macOS (untuk iOS).

```bat
cd RestoBake\apps\customer_app
flutter pub get
```

1. **Alamat server** — ubah `kLanServer` di `lib/main.dart` (di Chrome/Windows otomatis `localhost:8000`), atau langsung dari aplikasi (ikon server di layar login).
   Pakai IP LAN PC/VPS server, contoh `http://192.168.1.10:8000` — **bukan** `localhost`. HP harus satu Wi-Fi dengan server (versi PC).
2. **Jalankan ke HP** (USB debugging aktif): `flutter run`
3. **APK Android:** `flutter build apk --release` → `build\app\outputs\flutter-apk\app-release.apk` (kirim/instal ke HP).
   Untuk Play Store: `flutter build appbundle --release` (atur signing key di `android/app/build.gradle.kts`).
4. **iOS (macOS):** `flutter build ios --release` lalu buka `ios/Runner.xcworkspace` di Xcode → pilih Team (Signing) → Archive.

## Kalau build Android error versi Gradle/AGP
Folder `android/` dibuat dari template Flutter 3.32 (AGP 8.7.3, Kotlin 2.1.0, Gradle 8.12). Jika Flutter Anda meminta versi lain:
hapus folder `android` (dan/atau `ios`) lalu jalankan
`flutter create --org com.restobake --project-name restobake_customer --platforms=android,ios .`
lalu jalankan `python ..\..\setup_flutter.py` dari folder RestoBake untuk memasang ulang izin internet, HTTP lokal & nama aplikasi.
