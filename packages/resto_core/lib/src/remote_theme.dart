import 'package:flutter/material.dart';

import 'theme.dart';

/// Tema yang diatur dari Admin › Tema & Logo Aplikasi (GET /api/theme?app=...).
/// Warna, logo, gambar login, teks sambutan, warna & bunyi notifikasi — berubah realtime
/// saat admin mengganti tema (event WebSocket "theme_changed").
class RemoteTheme {
  final String key, name, logoUrl, loginImageUrl, tagline;
  final AppPalette palette;
  final Color notifyColor;
  final bool notifySound, allowUser;
  const RemoteTheme({required this.key, required this.name, required this.logoUrl, required this.loginImageUrl,
      required this.tagline, required this.palette, required this.notifyColor, required this.notifySound,
      required this.allowUser});

  static Color _c(dynamic v, Color fb) {
    final s = '${v ?? ''}'.replaceAll('#', '').trim();
    if (s.length != 6) return fb;
    final n = int.tryParse(s, radix: 16);
    return n == null ? fb : Color(0xFF000000 | n);
  }

  factory RemoteTheme.fromJson(Map<String, dynamic> j) {
    final c = Map<String, dynamic>.from(j['colors'] ?? {});
    final def = palettes.first;
    final primary = _c(c['primary'], def.primary);
    final side = _c(c['side'], def.side);
    final texts = Map<String, dynamic>.from(j['texts'] ?? {});
    return RemoteTheme(
      key: '${j['key'] ?? ''}',
      name: '${j['name'] ?? ''}',
      logoUrl: '${j['logo_url'] ?? ''}',
      loginImageUrl: '${j['login_image_url'] ?? ''}',
      tagline: '${texts['tagline'] ?? ''}',
      palette: AppPalette('${j['name'] ?? 'Admin'}', primary, side, _c(c['side2'], side), _c(c['accent'], def.accent),
          _c(c['background'], def.bg), dark: c['dark'] == true),
      notifyColor: _c(c['notify'], primary),
      notifySound: j['notify_sound'] != false,
      allowUser: j['allow_user'] == true,
    );
  }
}
