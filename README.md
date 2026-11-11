# RestoBake — APLIKASI FLUTTER (Android, iOS + Windows/Chrome untuk testing)

Paket ini berisi **4 aplikasi HP** RestoBake. Simpan/ekstrak di folder Flutter Anda (terpisah dari server Eclipse).
Server ada di paket **RestoBake-Server** — jalankan dulu servernya, lalu isi alamatnya di aplikasi (mis. `http://192.168.1.10:8000`).

```
RestoBake-Flutter/
├── apps/                       4 APLIKASI (masing-masing project Flutter lengkap, buka satu per satu)
│   ├── customer_app/           📱 RestoBake   — pelanggan: pesan online, bayar, voucher, poin, tukar hadiah
│   │   ├── android/  ios/      folder platform (sudah jadi, ikon & izin internet)
│   │   ├── windows/  web/      untuk TEST CEPAT di PC: flutter run -d windows / -d chrome
│   │   ├── lib/main.dart       kDefaultServer = alamat server
│   │   └── README.md           cara install & build APK / iOS
│   ├── waiter_app/             📱 RB Waiter   — pelayan: pesan per meja, cek ulang, kirim ke dapur
│   ├── kasir_app/              📱 RB Kasir    — kasir & pengawas: bayar, struk, koreksi, rekap
│   └── kitchen_app/            📱 RB Kitchen  — layar dapur (tablet)
├── packages/                   kode bersama — JANGAN dipisah dari apps/ (dipakai lewat path ../../packages)
│   ├── resto_core/             API, login, tema dari admin, 3 bahasa, widget
│   └── resto_staff/            layar bersama Waiter & Kasir
├── i18n/                       kamus 3 bahasa → python i18n/build.py
├── tools/gen_platforms.py      pembuat folder android/ios (sudah dijalankan)
└── setup_flutter.py            opsional: flutter pub get semua aplikasi sekaligus
```

Di Android Studio / VS Code: **Open** folder satu aplikasi, mis. `apps/kasir_app` (bukan folder RestoBake-Flutter-nya).

## 3. Aplikasi Android & iOS (Flutter)

Setiap aplikasi punya **folder sendiri** di `apps/` dan bisa di-install terpisah di perangkat masing-masing:

| Folder | Nama di HP | Untuk | Perangkat | ID aplikasi | Login contoh |
|---|---|---|---|---|---|
| `apps/customer_app` | **RestoBake** | Pelanggan / member | HP Android & iPhone | `com.restobake.customer` | `081234567890` / `member123` |
| `apps/waiter_app` | **RB Waiter** | Waiter | HP Android & iPhone | `com.restobake.waiter` | `waiter1` / `waiter123` |
| `apps/kasir_app` | **RB Kasir** | Kasir & Pengawas | Tablet/HP Android, iPad/iPhone | `com.restobake.kasir` | `kasir1` / `kasir123`, `pengawas` / `pengawas123` |
| `apps/kitchen_app` | **RB Kitchen** | Dapur / bakery / bar | Tablet Android & iPad | `com.restobake.kitchen` | `kitchen1` / `kitchen123` |

Server juga membatasi akun per aplikasi: akun waiter tidak bisa login di aplikasi Kasir, dan sebaliknya (Manager/Admin bisa semua).

Butuh **Flutter 3.27 atau lebih baru**. Folder `android/` dan `ios/` sudah disertakan (ikon, nama, izin internet & HTTP lokal) — cukup:

```bat
cd RestoBake\apps\kasir_app          REM atau customer_app / waiter_app / kitchen_app
flutter pub get
flutter run                          REM debug ke HP/tablet yang terhubung
flutter build apk --release          REM APK Android → build\app\outputs\flutter-apk\app-release.apk
flutter build ipa                    REM iOS (di macOS/Xcode)
```

Ganti alamat server default di `lib/main.dart` tiap aplikasi (`kDefaultServer`), atau ubah dari dalam aplikasi (ikon server di layar login / menu Akun). Gunakan IP LAN, contoh `http://192.168.1.10:8000` — **bukan** `localhost`.
Panduan lengkap per aplikasi ada di `README.md` di masing-masing folder. Opsional: `D:\python3.12\python.exe setup_flutter.py` menjalankan `pub get` untuk semua aplikasi sekaligus dan membuat ulang folder android/ios/windows/web bila Anda menghapusnya.

## Test cepat di PC (tanpa HP)

Folder `windows/` dan `web/` sudah disertakan, jadi semua aplikasi bisa dicoba langsung di komputer:

```bat
cd D:\flutter\resto\apps\kasir_app
flutter pub get
flutter run -d chrome        REM paling mudah: buka di Google Chrome (tidak perlu Visual Studio)
flutter run -d windows       REM aplikasi desktop Windows (butuh Visual Studio 2022 + "Desktop development with C++")
```

* Saat server jalan di PC yang sama, isi alamat server `http://localhost:8000` (ikon server di layar login).
  Untuk HP/tablet tetap pakai IP LAN, mis. `http://192.168.1.10:8000`.
* Jendela Windows: Customer & Waiter berukuran seperti HP, Kasir & Kitchen seperti tablet.
* `flutter doctor` menunjukkan apa yang belum terpasang (Visual Studio untuk Windows, Android SDK untuk APK).
* Pesan `N packages have newer versions incompatible with dependency constraints` hanya info, **bukan error**.

## Akun default (otomatis dibuat saat server pertama jalan)

| Aplikasi | Username | Password |
|---|---|---|
| Admin Panel | `admin` | `admin123` |
| Admin / semua aplikasi | `manager` | `manager123` |
| Resto (Pengawas / Supervisor) | `pengawas` | `pengawas123` |
| Resto (Kasir) | `kasir1` | `kasir123` |
| Resto (Waiter) | `waiter1`, `waiter2` | `waiter123` |
| Kitchen | `kitchen1`, `baker1` | `kitchen123` |
| Customer | `081234567890` | `member123` |

**Segera ganti password admin** lewat Admin › Pengaturan › Ganti Password.


## Tema, logo & bahasa
* Warna, logo, gambar login dan notifikasi aplikasi **diatur dari server** (Admin › Tema & Logo Aplikasi) dan berubah otomatis di HP.
* Bahasa Indonesia / English / 中文: pilih di halaman login atau menu Akun/Profil (Kitchen: ikon 🌐).
