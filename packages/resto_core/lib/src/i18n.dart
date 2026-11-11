import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'i18n_data.dart';

/// Bahasa aplikasi: Indonesia (default), English, 中文.
/// Teks sumber di kode tetap Bahasa Indonesia; `tr()` menerjemahkan saat ditampilkan.
class Lang extends ChangeNotifier {
  Lang._();
  static final Lang instance = Lang._();

  static const options = <String, String>{'id': 'Bahasa Indonesia', 'en': 'English', 'zh': '中文'};
  static const flags = <String, String>{'id': '🇮🇩', 'en': '🇬🇧', 'zh': '🇨🇳'};

  String code = 'id';

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final c = p.getString('rb_lang');
      if (c != null && options.containsKey(c) && c != code) {
        code = c;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> set(String c) async {
    if (!options.containsKey(c) || c == code) return;
    code = c;
    notifyListeners();
    try {
      (await SharedPreferences.getInstance()).setString('rb_lang', c);
    } catch (_) {}
  }
}

class _Tpl {
  final RegExp re;
  final List<String> out;
  final int weight;
  _Tpl(this.re, this.out, this.weight);
}

List<_Tpl>? _tpls;

List<_Tpl> _templates() {
  if (_tpls != null) return _tpls!;
  final list = <_Tpl>[];
  kTr.forEach((k, v) {
    if (!k.contains('{}')) return;
    final parts = k.split('{}').map(RegExp.escape).toList();
    list.add(_Tpl(RegExp('^${parts.join('(.+?)')}\$', dotAll: true), v, k.replaceAll('{}', '').length));
  });
  list.sort((a, b) => b.weight.compareTo(a.weight));
  return _tpls = list;
}

String _fill(String pattern, List<String> groups) {
  var i = 0;
  return pattern.replaceAllMapped('{}', (_) => i < groups.length ? groups[i++] : '');
}

/// Terjemahkan teks (Bahasa Indonesia → bahasa aktif). Aman dipanggil berulang.
String tr(String s) {
  final c = Lang.instance.code;
  if (c == 'id' || s.trim().isEmpty) return s;
  final idx = c == 'en' ? 0 : 1;
  final hit = kTr[s] ?? kTr[s.trim()];
  if (hit != null) return hit[idx];
  // sudah berupa hasil terjemahan (tr dipanggil dua kali) → jangan diterjemahkan ulang
  if (_translated(idx).contains(s.trim())) return s;
  for (final t in _templates()) {
    final m = t.re.firstMatch(s);
    if (m == null) continue;
    final groups = [for (var g = 1; g <= m.groupCount; g++) _part(m.group(g) ?? '', idx)];
    return _fill(t.out[idx], groups);
  }
  var out = s;
  for (final p in kPhrases) {
    if (!out.contains(p[0])) continue;
    // hanya kata utuh: "poin" tidak boleh mengganti bagian dari "points"
    out = out.replaceAllMapped(_phraseRe(p[0]), (_) => p[idx + 1]);
  }
  return out;
}

final _done = <int, Set<String>>{};
Set<String> _translated(int idx) => _done[idx] ??= {for (final v in kTr.values) v[idx]};

final _reCache = <String, RegExp>{};
RegExp _phraseRe(String w) => _reCache[w] ??=
    RegExp('(?<![A-Za-z\u00C0-\u024F])${RegExp.escape(w)}(?![A-Za-z\u00C0-\u024F])');

String _part(String g, int idx) => kTr[g]?[idx] ?? (g.length > 1 && g.length < 60 ? tr(g) : g);

/// Tombol ganti bahasa (ikon 🌐) untuk AppBar / halaman akun.
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key, this.color});
  final Color? color;
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        tooltip: tr('Bahasa'),
        icon: Icon(Icons.translate_rounded, color: color),
        initialValue: Lang.instance.code,
        onSelected: Lang.instance.set,
        itemBuilder: (_) => [
          for (final e in Lang.options.entries)
            PopupMenuItem(value: e.key, child: Text('${Lang.flags[e.key]}  ${e.value}')),
        ],
      );
}

/// Pilihan bahasa berbentuk tombol segmen (untuk halaman login / pengaturan).
class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Lang.instance,
        builder: (context, _) => SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            for (final e in Lang.options.entries)
              ButtonSegment(value: e.key, label: Text(e.key == 'id' ? 'ID' : e.key == 'en' ? 'EN' : '中文')),
          ],
          selected: {Lang.instance.code},
          onSelectionChanged: (s) => Lang.instance.set(s.first),
        ),
      );
}
