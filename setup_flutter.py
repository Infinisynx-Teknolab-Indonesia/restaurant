"""Siapkan ke-4 aplikasi Flutter RestoBake (opsional — folder android/, ios/, windows/ & web/ sudah disertakan).

Jalankan dari folder RestoBake:
    D:\\python3.12\\python.exe setup_flutter.py

Untuk setiap aplikasi (customer_app, waiter_app, kasir_app, kitchen_app):
  1. Bila folder android/, ios/, windows/ atau web/ belum ada (mis. Anda menghapusnya karena beda versi Gradle):
     flutter create --platforms=...  (hanya platform yang hilang; tidak menimpa lib/ dan pubspec.yaml)
  2. Pastikan izin INTERNET + HTTP lokal (usesCleartextTraffic) di AndroidManifest
  3. Pastikan HTTP lokal di iOS Info.plist (NSAppTransportSecurity) + nama aplikasi
  4. flutter pub get
"""
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
APPS = [
    # folder, nama paket pubspec, org, label aplikasi
    ("customer_app", "restobake_customer", "com.restobake", "RestoBake"),
    ("waiter_app", "restobake_waiter", "com.restobake", "RB Waiter"),
    ("kasir_app", "restobake_kasir", "com.restobake", "RB Kasir"),
    ("kitchen_app", "restobake_kitchen", "com.restobake", "RB Kitchen"),
]
WIN = sys.platform.startswith("win")


def run(cmd, cwd):
    print("  >", " ".join(cmd))
    r = subprocess.run(cmd, cwd=cwd, shell=WIN)
    if r.returncode != 0:
        sys.exit(f"Perintah gagal: {' '.join(cmd)}")


def patch_android(app_dir: Path, label: str, needs_browser: bool):
    mf = app_dir / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
    if not mf.exists():
        print("  ! AndroidManifest.xml tidak ditemukan, lewati")
        return
    s = mf.read_text(encoding="utf-8")
    if "android.permission.INTERNET" not in s:
        s = s.replace("<application", '<uses-permission android:name="android.permission.INTERNET"/>\n    <application', 1)
    if "usesCleartextTraffic" not in s:
        s = s.replace("<application", '<application\n        android:usesCleartextTraffic="true"', 1)
    s = re.sub(r'android:label="[^"]*"', f'android:label="{label}"', s, count=1)
    if needs_browser and 'android:scheme="https"' not in s:
        intents = ('\n        <intent>\n            <action android:name="android.intent.action.VIEW"/>\n'
                   '            <data android:scheme="https"/>\n        </intent>\n        <intent>\n'
                   '            <action android:name="android.intent.action.VIEW"/>\n'
                   '            <data android:scheme="http"/>\n        </intent>')
        if "<queries>" in s:
            s = s.replace("<queries>", "<queries>" + intents, 1)
        else:
            s = s.replace("</manifest>", f"    <queries>{intents}\n    </queries>\n</manifest>")
    mf.write_text(s, encoding="utf-8")
    print("  ✓ AndroidManifest diperbarui")


def patch_ios(app_dir: Path, label: str):
    pl = app_dir / "ios" / "Runner" / "Info.plist"
    if not pl.exists():
        print("  ! Info.plist tidak ditemukan, lewati")
        return
    s = pl.read_text(encoding="utf-8")
    if "NSAppTransportSecurity" not in s:
        s = s.replace("<dict>", "<dict>\n\t<key>NSAppTransportSecurity</key>\n\t<dict>\n"
                      "\t\t<key>NSAllowsArbitraryLoads</key>\n\t\t<true/>\n\t</dict>", 1)
    s = re.sub(r"(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)", rf"\g<1>{label}\g<2>", s, count=1)
    pl.write_text(s, encoding="utf-8")
    print("  ✓ Info.plist diperbarui")


def main():
    if not shutil.which("flutter"):
        sys.exit("Flutter tidak ditemukan di PATH. Install Flutter SDK terlebih dahulu.")
    for pkg in ("resto_core", "resto_staff"):
        run(["flutter", "pub", "get"], ROOT / "packages" / pkg)
    for folder, name, org, label in APPS:
        d = ROOT / "apps" / folder
        print(f"\n=== {folder} ===")
        missing = [p for p in ("android", "ios", "windows", "web") if not (d / p).exists()]
        if missing:
            run(["flutter", "create", "--org", org, "--project-name", name, "--platforms=" + ",".join(missing), "."], d)
        t = d / "test" / "widget_test.dart"
        if t.exists():
            t.unlink()  # test bawaan merujuk MyApp yang tidak ada
        patch_android(d, label, needs_browser=(folder == "customer_app"))
        patch_ios(d, label)
        run(["flutter", "pub", "get"], d)
    print("\nSelesai. Contoh menjalankan:")
    print("  cd apps\\kasir_app && flutter run -d chrome     (test cepat di browser)")
    print("  cd apps\\kasir_app && flutter run -d windows    (butuh Visual Studio C++)")
    print("  cd apps\\kasir_app && flutter run              (HP/tablet yang terhubung)")


if __name__ == "__main__":
    main()
