import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'format.dart';
import 'models.dart';
import 'realtime.dart';
import 'remote_theme.dart';
import 'theme.dart';

/// State login + pengaturan aplikasi (server, tema). Dipakai lewat Provider.
class Session extends ChangeNotifier {
  Session({required this.appKey, required this.defaultServer}) {
    // admin mengganti tema → semua aplikasi langsung ikut berubah
    realtime.events.listen((e) {
      if (e.event == 'theme_changed') loadTheme();
      if (e.event == 'settings_changed') loadInfo(); // mis. admin mengganti mata uang
    });
  }

  /// customer | waiter | kasir | kitchen  (server mengecek role sesuai aplikasi)
  final String appKey;
  final String defaultServer;

  SharedPreferences? _prefs;
  String server = '';
  AppUser? user;
  RestoInfo? info;
  int themeIndex = 0;
  /// true bila member memilih tema sendiri (hanya bila admin mengizinkan)
  bool userPickedTheme = false;
  /// Tema dari admin (null bila server belum terjangkau → pakai tema lokal).
  RemoteTheme? remoteTheme;
  bool ready = false;
  final RealtimeService realtime = RealtimeService();

  bool get loggedIn => user != null && api.token != null;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    server = _prefs!.getString('server') ?? defaultServer;
    themeIndex = _prefs!.getInt('theme') ?? 0;
    userPickedTheme = _prefs!.getBool('theme_user') ?? false;
    try {
      final c = _prefs!.getString('currency'); // mata uang terakhir (saat offline)
      if (c != null) Currency.active = Currency.fromJson(Map<String, dynamic>.from(jsonDecode(c)));
    } catch (_) {}
    api.baseUrl = server;
    _restoreTheme();
    loadTheme();
    api.onUnauthorized = () {
      if (user != null) logout();
    };
    final t = _prefs!.getString('token');
    final u = _prefs!.getString('user');
    if (t != null && u != null) {
      api.token = t;
      try {
        user = AppUser.fromJson(jsonDecode(u));
        realtime.connect(server, t);
        refreshMe();
      } catch (_) {
        user = null;
      }
    }
    loadInfo();
    ready = true;
    notifyListeners();
  }

  // ---------------------------------------------------------------- tema dari admin
  String get _themeApp => appKey == 'resto' ? 'kasir' : appKey;

  /// Tema boleh dipilih sendiri oleh pengguna? (aplikasi Resto selalu mengikuti admin)
  bool get themeLocked => remoteTheme != null && !remoteTheme!.allowUser;

  /// Palet aktif: tema admin, kecuali member diizinkan & sudah memilih sendiri.
  AppPalette get palette {
    final r = remoteTheme;
    if (r != null && !(r.allowUser && userPickedTheme)) return r.palette;
    return paletteAt(themeIndex);
  }

  ThemeData get themeData => buildThemeFrom(palette);
  String get logoUrl => remoteTheme?.logoUrl ?? '';
  String get loginImageUrl => remoteTheme?.loginImageUrl ?? '';
  String get tagline => remoteTheme?.tagline ?? '';
  Color? get notifyColor => remoteTheme?.notifyColor;
  bool get notifySound => remoteTheme?.notifySound ?? true;

  void _restoreTheme() {
    final raw = _prefs?.getString('remote_theme');
    if (raw == null) return;
    try {
      remoteTheme = RemoteTheme.fromJson(Map<String, dynamic>.from(jsonDecode(raw)));
    } catch (_) {}
  }

  Future<void> loadTheme() async {
    try {
      final j = Map<String, dynamic>.from(await api.get('/api/theme', query: {'app': _themeApp}));
      remoteTheme = RemoteTheme.fromJson(j);
      await _prefs?.setString('remote_theme', jsonEncode(j)); // dipakai saat offline / buka ulang
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadInfo() async {
    try {
      info = await api.info();
      Currency.active = Currency.fromJson(info!.currency);
      await _prefs?.setString('currency', jsonEncode(info!.currency ?? {}));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshMe() async {
    try {
      final j = await api.get('/api/auth/me');
      user = AppUser.fromJson(Map<String, dynamic>.from(j));
      await _prefs?.setString('user', jsonEncode(user!.toJson()));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _setAuth(dynamic r) async {
    final token = r['token'] as String;
    api.token = token;
    user = AppUser.fromJson(Map<String, dynamic>.from(r['user']));
    await _prefs?.setString('token', token);
    await _prefs?.setString('user', jsonEncode(user!.toJson()));
    realtime.connect(server, token);
    loadInfo();
    loadTheme();
    notifyListeners();
  }

  Future<void> login(String login, String password) async {
    final r = await api.post('/api/auth/login', {'login': login.trim(), 'password': password, 'app': appKey});
    await _setAuth(r);
  }

  Future<void> register({required String name, required String phone, String? email,
      required String password, String? birthday}) async {
    final r = await api.post('/api/auth/register', {
      'name': name.trim(), 'phone': phone.trim(), 'email': (email ?? '').trim(),
      'password': password, 'birthday': birthday,
    });
    await _setAuth(r);
  }

  Future<void> logout() async {
    realtime.disconnect();
    api.token = null;
    user = null;
    await _prefs?.remove('token');
    await _prefs?.remove('user');
    notifyListeners();
  }

  /// Normalisasi alamat server, mis. "192.168.1.10:8000" → "http://192.168.1.10:8000"
  static String normalizeUrl(String url) {
    var u = url.trim();
    if (u.isEmpty) return u;
    if (!u.startsWith('http://') && !u.startsWith('https://')) u = 'http://$u';
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  Future<void> setServer(String url) async {
    server = normalizeUrl(url);
    api.baseUrl = server;
    await _prefs?.setString('server', server);
    if (api.token != null) realtime.connect(server, api.token!);
    loadInfo();
    loadTheme();
    notifyListeners();
  }

  Future<void> setTheme(int i) async {
    themeIndex = i;
    userPickedTheme = true;
    await _prefs?.setInt('theme', i);
    await _prefs?.setBool('theme_user', true);
    notifyListeners();
  }
}
