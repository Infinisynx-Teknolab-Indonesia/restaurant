"""Generate folder android/ & ios/ untuk ke-4 aplikasi Flutter RestoBake dari template resmi Flutter
(flutter_tools/templates/app versi 3.32.8: AGP 8.7.3, Kotlin 2.1.0, Gradle 8.12), lengkap dengan:
  - applicationId / bundle id sendiri per aplikasi
  - izin INTERNET + HTTP lokal (server LAN) di Android, NSAppTransportSecurity + Local Network di iOS
  - nama & ikon aplikasi masing-masing
  - folder windows/ & web/ (untuk testing cepat di PC: flutter run -d windows / -d chrome)

Pemakaian (butuh salinan template Flutter + Pillow):
    python tools/gen_platforms.py <folder flutter/packages/flutter_tools/templates/app> [android,ios,windows,web]
Biasanya tidak perlu dijalankan lagi — hasilnya sudah ada di apps/*/android & apps/*/ios.
"""
import os
import re
import shutil
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = os.path.join(ROOT, "packages/resto_core/fonts/PlayfairDisplay_700Bold.ttf")
FONT2 = os.path.join(ROOT, "packages/resto_core/fonts/Inter_800ExtraBold.ttf")

APPS = [
    # folder, pubspec name, id, label, warna pita, tulisan pita, perlu browser
    ("customer_app", "restobake_customer", "com.restobake.customer", "RestoBake", "#7C3AED", "ORDER", True),
    ("waiter_app", "restobake_waiter", "com.restobake.waiter", "RB Waiter", "#2563EB", "WAITER", False),
    ("kasir_app", "restobake_kasir", "com.restobake.kasir", "RB Kasir", "#16A34A", "KASIR", False),
    ("kitchen_app", "restobake_kitchen", "com.restobake.kitchen", "RB Kitchen", "#EA580C", "KITCHEN", False),
]
VERS = {"agpVersion": "8.7.3", "kotlinVersion": "2.1.0", "gradleVersion": "8.12"}


def mustache(text, ctx):
    # section {{#x}}..{{/x}} dan {{^x}}..{{/x}}
    def sec(m):
        inv, key, body = m.group(1) == "^", m.group(2), m.group(3)
        on = bool(ctx.get(key))
        return body if on != inv else ""
    prev = None
    while prev != text:
        prev = text
        text = re.sub(r"\{\{([#^])(\w+)\}\}(.*?)\{\{/\2\}\}", sec, text, flags=re.S)
    return re.sub(r"\{\{(\w+)\}\}", lambda m: str(ctx.get(m.group(1), "")), text)


def icon(size, band_color, band_text, rounded=False):
    s = 1024
    im = Image.new("RGB", (s, s), "#111A2E")
    d = ImageDraw.Draw(im)
    for y in range(s):  # gradasi navy
        t = y / s
        c = tuple(int(a + (b - a) * t) for a, b in zip((0x2A, 0x3B, 0x66), (0x0D, 0x14, 0x24)))
        d.line([(0, y), (s, y)], fill=c)
    d.ellipse((s * .16, s * .08, s * .84, s * .76), outline="#C5A059", width=int(s * .028))
    f = ImageFont.truetype(FONT, int(s * .36))
    d.text((s / 2, s * .42), "RB", font=f, fill="#E2C88F", anchor="mm")
    d.rectangle((0, s * .78, s, s), fill=band_color)
    f2 = ImageFont.truetype(FONT2, int(s * (.12 if len(band_text) <= 6 else .105)))
    d.text((s / 2, s * .89), band_text, font=f2, fill="#FFFFFF", anchor="mm")
    if rounded:
        mask = Image.new("L", (s, s), 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, s, s), radius=int(s * .2), fill=255)
        out = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        out.paste(im, (0, 0), mask)
        im = out
    return im.resize((size, size), Image.LANCZOS)


ANDROID_ICONS = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
IOS_ICONS = {"20x20@1x": 20, "20x20@2x": 40, "20x20@3x": 60, "29x29@1x": 29, "29x29@2x": 58, "29x29@3x": 87,
             "40x40@1x": 40, "40x40@2x": 80, "40x40@3x": 120, "60x60@2x": 120, "60x60@3x": 180,
             "76x76@1x": 76, "76x76@2x": 152, "83.5x83.5@2x": 167, "1024x1024@1x": 1024}


def render_tree(src, dst, ctx, ident_path):
    for base, _, files in os.walk(src):
        rel = os.path.relpath(base, src)
        for fn in files:
            if fn.endswith(".iml.tmpl") or fn.endswith(".iml"):
                continue
            rp = os.path.normpath(os.path.join(rel, fn)).replace("androidIdentifier", ident_path)
            sp = os.path.join(base, fn)
            if rp.endswith(".img.tmpl") or rp.endswith(".copy.tmpl"):
                continue  # gambar dibuat sendiri (ikon & launch image)
            if rp.endswith(".tmpl"):
                rp = rp[:-5]
            out = os.path.join(dst, rp)
            os.makedirs(os.path.dirname(out), exist_ok=True)
            if fn.endswith(".png"):
                shutil.copyfile(sp, out)
                continue
            text = open(sp, encoding="utf-8").read()
            open(out, "w", encoding="utf-8", newline="\n").write(mustache(text, ctx) if sp.endswith(".tmpl") else text)


def patch_android(adir, label, browser):
    mf = os.path.join(adir, "app/src/main/AndroidManifest.xml")
    s = open(mf, encoding="utf-8").read()
    s = s.replace('<manifest xmlns:android="http://schemas.android.com/apk/res/android">',
                  '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n'
                  '    <!-- RestoBake: akses server (LAN / internet) -->\n'
                  '    <uses-permission android:name="android.permission.INTERNET"/>\n'
                  '    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>', 1)
    s = re.sub(r'android:label="[^"]*"', f'android:label="{label}"', s, count=1)
    # server lokal memakai http://192.168.x.x → izinkan cleartext
    s = s.replace('android:icon="@mipmap/ic_launcher">', 'android:icon="@mipmap/ic_launcher"\n        android:usesCleartextTraffic="true">', 1)
    if browser:
        s = s.replace("<queries>", "<queries>\n        <!-- buka halaman pembayaran (url_launcher) -->\n"
                      "        <intent>\n            <action android:name=\"android.intent.action.VIEW\"/>\n"
                      "            <data android:scheme=\"https\"/>\n        </intent>\n"
                      "        <intent>\n            <action android:name=\"android.intent.action.VIEW\"/>\n"
                      "            <data android:scheme=\"http\"/>\n        </intent>", 1)
    open(mf, "w", encoding="utf-8", newline="\n").write(s)
    for k, px in ANDROID_ICONS.items():
        p = os.path.join(adir, f"app/src/main/res/mipmap-{k}/ic_launcher.png")
        os.makedirs(os.path.dirname(p), exist_ok=True)
        icon(px, *ICON_ARGS).save(p)


def patch_ios(idir, label):
    pl = os.path.join(idir, "Runner/Info.plist")
    s = open(pl, encoding="utf-8").read()
    s = re.sub(r"(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)", rf"\g<1>{label}\g<2>", s, count=1)
    s = re.sub(r"(<key>CFBundleName</key>\s*<string>)[^<]*(</string>)", rf"\g<1>{label}\g<2>", s, count=1)
    extra = ("\t<key>NSAppTransportSecurity</key>\n\t<dict>\n\t\t<key>NSAllowsArbitraryLoads</key>\n\t\t<true/>\n"
             "\t\t<key>NSAllowsLocalNetworking</key>\n\t\t<true/>\n\t</dict>\n"
             "\t<key>NSLocalNetworkUsageDescription</key>\n\t<string>Terhubung ke server RestoBake di jaringan lokal restoran.</string>\n"
             "\t<key>NSBonjourServices</key>\n\t<array>\n\t\t<string>_http._tcp</string>\n\t</array>\n")
    s = s.replace("<dict>\n", "<dict>\n" + extra, 1)
    open(pl, "w", encoding="utf-8", newline="\n").write(s)
    aset = os.path.join(idir, "Runner/Assets.xcassets/AppIcon.appiconset")
    for k, px in IOS_ICONS.items():
        icon(px, *ICON_ARGS).save(os.path.join(aset, f"Icon-App-{k}.png"))
    li = os.path.join(idir, "Runner/Assets.xcassets/LaunchImage.imageset")
    for n in ("LaunchImage.png", "LaunchImage@2x.png", "LaunchImage@3x.png"):
        Image.new("RGBA", (1, 1), (0, 0, 0, 0)).save(os.path.join(li, n))


ICON_ARGS = ()
# ukuran jendela Windows: customer & waiter seperti HP, kasir & kitchen seperti tablet/layar kasir
WIN_SIZE = {"customer_app": (430, 900), "waiter_app": (430, 900), "kasir_app": (1280, 800), "kitchen_app": (1280, 800)}


def patch_windows(wdir, folder, label):
    mc = os.path.join(wdir, "runner/main.cpp")
    s = open(mc, encoding="utf-8").read()
    w, h = WIN_SIZE[folder]
    s = re.sub(r"Win32Window::Size size\(\d+, \d+\);", f"Win32Window::Size size({w}, {h});", s)
    s = re.sub(r'window\.Create\(L"[^"]*"', f'window.Create(L"{label}"', s)
    open(mc, "w", encoding="utf-8", newline="\n").write(s)
    rc = os.path.join(wdir, "runner/Runner.rc")
    s = open(rc, encoding="utf-8").read()
    s = re.sub(r'VALUE "FileDescription", "[^"]*"', f'VALUE "FileDescription", "{label}"', s)
    s = re.sub(r'VALUE "ProductName", "[^"]*"', f'VALUE "ProductName", "{label}"', s)
    s = s.replace('"com.example"', '"RestoBake"')
    open(rc, "w", encoding="utf-8", newline="\n").write(s)
    ico = os.path.join(wdir, "runner/resources/app_icon.ico")
    os.makedirs(os.path.dirname(ico), exist_ok=True)
    icon(256, *ICON_ARGS).save(ico, sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])


def make_web(app, label):
    """Folder web/ minimal (index.html, manifest, ikon) — untuk testing di Chrome: flutter run -d chrome."""
    w = os.path.join(app, "web")
    os.makedirs(os.path.join(w, "icons"), exist_ok=True)
    open(os.path.join(w, "index.html"), "w", encoding="utf-8", newline="\n").write(f"""<!DOCTYPE html>
<html>
<head>
  <base href="$FLUTTER_BASE_HREF">
  <meta charset="UTF-8">
  <meta content="IE=Edge" http-equiv="X-UA-Compatible">
  <meta name="description" content="{label} — RestoBake">
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black">
  <meta name="apple-mobile-web-app-title" content="{label}">
  <link rel="apple-touch-icon" href="icons/Icon-192.png">
  <link rel="icon" type="image/png" href="favicon.png"/>
  <title>{label}</title>
  <link rel="manifest" href="manifest.json">
</head>
<body>
  <script src="flutter_bootstrap.js" async></script>
</body>
</html>
""")
    import json
    json.dump({"name": label, "short_name": label, "start_url": ".", "display": "standalone",
               "background_color": "#111A2E", "theme_color": "#111A2E", "description": f"{label} — RestoBake",
               "orientation": "portrait-primary", "prefer_related_applications": False,
               "icons": [{"src": "icons/Icon-192.png", "sizes": "192x192", "type": "image/png"},
                         {"src": "icons/Icon-512.png", "sizes": "512x512", "type": "image/png"},
                         {"src": "icons/Icon-maskable-192.png", "sizes": "192x192", "type": "image/png", "purpose": "maskable"},
                         {"src": "icons/Icon-maskable-512.png", "sizes": "512x512", "type": "image/png", "purpose": "maskable"}]},
              open(os.path.join(w, "manifest.json"), "w", encoding="utf-8"), indent=2)
    icon(32, *ICON_ARGS).save(os.path.join(w, "favicon.png"))
    for n in (192, 512):
        icon(n, *ICON_ARGS).save(os.path.join(w, f"icons/Icon-{n}.png"))
        icon(n, *ICON_ARGS).save(os.path.join(w, f"icons/Icon-maskable-{n}.png"))


def main():
    global ICON_ARGS
    tpl = sys.argv[1]
    only = set((sys.argv[2] if len(sys.argv) > 2 else "android,ios,windows,web").split(","))
    for folder, name, ident, label, color, band, browser in APPS:
        app = os.path.join(ROOT, "apps", folder)
        ICON_ARGS = (color, band)
        ctx = dict(VERS, projectName=name, titleCaseProjectName=label, androidIdentifier=ident, iosIdentifier=ident,
                   androidSdkVersion="21", withPlatformChannelPluginHook=False, withSwiftPackageManager=False,
                   hasIosDevelopmentTeam=False, iosDevelopmentTeam="", pluginClass="", pluginProjectName="",
                   organization="com.restobake", year="2026")
        for p in only:
            shutil.rmtree(os.path.join(app, p), ignore_errors=True)
        ipath = ident.replace(".", "/")
        if "android" in only:
            render_tree(os.path.join(tpl, "android.tmpl"), os.path.join(app, "android"), ctx, ipath)
            render_tree(os.path.join(tpl, "android-kotlin.tmpl"), os.path.join(app, "android"), ctx, ipath)
            patch_android(os.path.join(app, "android"), label, browser)
        if "ios" in only:
            render_tree(os.path.join(tpl, "ios.tmpl"), os.path.join(app, "ios"), ctx, ipath)
            render_tree(os.path.join(tpl, "ios-swift.tmpl"), os.path.join(app, "ios"), ctx, ipath)
            patch_ios(os.path.join(app, "ios"), label)
        if "web" in only:
            make_web(app, label)
        if "windows" in only:
            render_tree(os.path.join(tpl, "windows.tmpl"), os.path.join(app, "windows"), ctx, ipath)
            patch_windows(os.path.join(app, "windows"), folder, label)
        icon(512, color, band).save(os.path.join(app, "icon.png"))  # pratinjau ikon
        print("✓", folder, ident)


if __name__ == "__main__":
    main()
