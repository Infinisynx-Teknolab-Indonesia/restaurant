# RestoBake Kasir

| | |
|---|---|
| Untuk | **Kasir & Pengawas** |
| Perangkat | Tablet / HP Android & iPad / iPhone |
| Nama di HP | **RB Kasir** |
| Application ID / Bundle ID | `com.restobake.kasir` |
| Akun contoh | `kasir1` / `kasir123` · Pengawas: `pengawas` / `pengawas123` |

**Fitur:** Daftar tagihan, bayar **Tunai / Kartu (EDC) / QRIS**, hubungkan member & tukar poin, voucher, diskon, cetak bill & struk (58/80 mm), **koreksi pesanan** (wajib alasan, dilaporkan ke Admin), rekap kasir harian. Akun Pengawas bisa mengoreksi pesanan yang sudah dibayar & refund.

Folder ini adalah project Flutter **lengkap & berdiri sendiri** (sudah ada `android/` dan `ios/`, ikon, izin internet & HTTP lokal).
Kode bersama ada di `../../packages/resto_core` dan `../../packages/resto_staff` — jangan pindahkan folder ini keluar dari `RestoBake/`.

## Instalasi

Butuh **Flutter 3.27+** (cek: `flutter --version`), Android Studio (untuk Android) atau Xcode di macOS (untuk iOS).

```bat
cd RestoBake\apps\kasir_app
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
`flutter create --org com.restobake --project-name restobake_kasir --platforms=android,ios .`
lalu jalankan `python ..\..\setup_flutter.py` dari folder RestoBake untuk memasang ulang izin internet, HTTP lokal & nama aplikasi.
