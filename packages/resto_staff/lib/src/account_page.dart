import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:resto_core/resto_core.dart';

import 'receipt.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  List<dynamic> _att = [];
  int _paper = 58;
  bool _auto = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await paperWidth();
    final a = await autoPrint();
    List<dynamic> att = [];
    try {
      att = await api.get('/api/attendance/me') as List;
    } catch (_) {}
    if (mounted) setState(() { _paper = p; _auto = a; _att = att; });
  }

  Future<void> _absen() async {
    final r = await runSafe(context, () => api.post('/api/attendance/check'));
    if (r != null && mounted) {
      showSnack(context, '${r['message']} · ${jam(r['check_out'] ?? r['check_in'])}');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final u = s.user!;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final todayAtt = _att.cast<Map>().where((a) => a['date'] == today).firstOrNull;
    final absenLabel = todayAtt == null ? 'Absen Masuk' : (todayAtt['check_out'] == null ? 'Absen Pulang' : 'Sudah absen hari ini');

    return Scaffold(
      appBar: AppBar(title: Text(tr('Akun'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: PullRefresh(
            onRefresh: () async {
              final s = context.read<Session>();
              await Future.wait([_load(), s.refreshMe(), s.loadInfo(), s.loadTheme()]);
            },
            child: ListView(padding: const EdgeInsets.all(16), children: [
            AppCard(
              child: Row(children: [
                CircleAvatar(radius: 28, backgroundColor: context.cs.primary.withValues(alpha: .15),
                    child: Text(u.name[0].toUpperCase(), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.cs.primary))),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(u.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    Text('${roleLabel[u.role]}${u.position != null ? ' · ${u.position}' : ''}', style: TextStyle(color: context.muted)),
                  ]),
                ),
                const LiveDot(),
              ]),
            ),
            const SectionTitle('Absensi', icon: Icons.fingerprint_rounded),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (todayAtt != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(tr('Masuk ${jam(todayAtt['check_in'])}${todayAtt['check_out'] != null ? ' · Pulang ${jam(todayAtt['check_out'])}' : ''}')),
                  ),
                FilledButton.icon(
                  onPressed: todayAtt != null && todayAtt['check_out'] != null ? null : _absen,
                  icon: const Icon(Icons.fingerprint_rounded),
                  label: Text(tr(absenLabel)),
                ),
                if (_att.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  for (final a in _att.take(7).cast<Map>())
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(children: [
                        Expanded(child: Text(tanggal('${a['date']}'))),
                        Text('${jam(a['check_in'])} – ${a['check_out'] == null ? '...' : jam(a['check_out'])}', style: TextStyle(color: context.muted)),
                      ]),
                    ),
                ],
              ]),
            ),
            if (u.isCashier) ...[
              const SectionTitle('Printer Struk', icon: Icons.print_rounded),
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr('Lebar kertas')),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    segments: [ButtonSegment(value: 58, label: Text(tr('58 mm'))), ButtonSegment(value: 80, label: Text(tr('80 mm')))],
                    selected: {_paper},
                    onSelectionChanged: (v) async {
                      await setPaperWidth(v.first);
                      setState(() => _paper = v.first);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _auto,
                    onChanged: (v) async {
                      await setAutoPrint(v);
                      setState(() => _auto = v);
                    },
                    title: Text(tr('Cetak struk otomatis setelah bayar')),
                  ),
                  Text(tr('Printer thermal Bluetooth/Wi-Fi perlu terpasang di layanan cetak Android (mis. aplikasi "RawBT" / plugin printer pabrikan) atau AirPrint di iOS.'),
                      style: TextStyle(fontSize: 12, color: context.muted)),
                ]),
              ),
            ],
            const SectionTitle('Pengaturan', icon: Icons.settings_rounded),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(children: [
                ListTile(leading: const Icon(Icons.translate_rounded), title: Text(tr('Bahasa')),
                    subtitle: Text(Lang.options[Lang.instance.code]!), trailing: const LanguageButton()),
                ListTile(leading: const Icon(Icons.palette_outlined), title: Text(tr('Tema Tampilan')),
                    subtitle: Text(s.themeLocked ? tr('Diatur Admin · ${s.palette.name}') : s.palette.name), onTap: () => showThemePicker(context)),
                ListTile(leading: const Icon(Icons.dns_outlined), title: Text(tr('Alamat Server')),
                    subtitle: Text(s.server), onTap: () => showServerDialog(context)),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
                  title: Text(tr('Keluar'), style: TextStyle(color: Color(0xFFDC2626))),
                  onTap: () async {
                    if (await confirmDialog(context, 'Keluar?', 'Anda akan keluar dari aplikasi Resto.', okText: 'Keluar')) {
                      await s.logout();
                    }
                  },
                ),
              ]),
            ),
          ]),
          ),
        ),
      ),
    );
  }
}
