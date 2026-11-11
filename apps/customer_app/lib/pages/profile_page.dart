import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:resto_core/resto_core.dart';

import 'about_page.dart';
import 'contact_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> _edit(BuildContext context) async {
    final s = context.read<Session>();
    final u = s.user!;
    final name = TextEditingController(text: u.name);
    final email = TextEditingController(text: u.email ?? '');
    final phone = TextEditingController(text: u.phone ?? '');
    final address = TextEditingController(text: u.address ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Ubah Profil')),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: deco(c, 'Nama', icon: Icons.person_outline_rounded)),
            const SizedBox(height: 10),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: deco(c, 'No. HP', icon: Icons.phone_iphone_rounded)),
            const SizedBox(height: 10),
            TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: deco(c, 'Email', icon: Icons.mail_outline_rounded)),
            const SizedBox(height: 10),
            TextField(controller: address, maxLines: 2, decoration: deco(c, 'Alamat pengantaran', icon: Icons.location_on_outlined)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Batal'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Simpan'))),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await runSafe(context, () async {
      await api.put('/api/auth/me', {'name': name.text.trim(), 'phone': phone.text.trim(), 'email': email.text.trim(), 'address': address.text.trim()});
      await s.refreshMe();
    }, success: 'Profil diperbarui');
  }

  Future<void> _password(BuildContext context) async {
    final old = TextEditingController();
    final nw = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Ganti Password')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: old, obscureText: true, decoration: deco(c, 'Password lama', icon: Icons.lock_outline_rounded)),
          const SizedBox(height: 10),
          TextField(controller: nw, obscureText: true, decoration: deco(c, 'Password baru', icon: Icons.lock_reset_rounded)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Batal'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Simpan'))),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await runSafe(context, () => api.post('/api/auth/change-password', {'old_password': old.text, 'new_password': nw.text}),
        success: 'Password diganti');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final u = s.user!;
    Widget tile(IconData i, String t, VoidCallback f, {String? sub, Color? color}) => ListTile(
          leading: Icon(i, color: color ?? context.cs.primary),
          title: Text(tr(t), style: TextStyle(color: color, fontWeight: FontWeight.w500)),
          subtitle: sub == null ? null : Text(sub),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: f,
        );
    return Scaffold(
      body: PullRefresh(
        onRefresh: () async {
          final s = context.read<Session>();
          await Future.wait([s.refreshMe(), s.loadInfo(), s.loadTheme()]);
        },
        child: ListView(padding: EdgeInsets.zero, children: [
        GradientHeader(
          padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 24, 20, 28),
          child: Row(children: [
            CircleAvatar(radius: 32, backgroundColor: Colors.white24,
                child: Text(u.name.isEmpty ? '?' : u.name[0].toUpperCase(),
                    style: const TextStyle(fontSize: 26, color: Colors.white, fontWeight: FontWeight.w800))),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u.name, style: serifStyle(size: 24, color: Colors.white)),
                Text(u.phone ?? u.email ?? '', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
                Pill('Member ${u.tier}', color: Colors.white, icon: Icons.military_tech_rounded),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(children: [
                tile(Icons.edit_rounded, 'Ubah Profil', () => _edit(context)),
                tile(Icons.lock_reset_rounded, 'Ganti Password', () => _password(context)),
              ]),
            ),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(children: [
                ListTile(leading: Icon(Icons.translate_rounded, color: context.cs.primary), title: Text(tr('Bahasa')),
                    subtitle: Text(Lang.options[Lang.instance.code]!), trailing: const LanguageButton()),
                tile(Icons.info_outline_rounded, 'Tentang Kami', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AboutPage()))),
                if (s.info?.contactEnabled ?? false)
                  tile(Icons.mail_outline_rounded, 'Hubungi Kami', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContactPage()))),
              ]),
            ),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: tile(Icons.logout_rounded, 'Keluar', () async {
                if (await confirmDialog(context, 'Keluar?', 'Anda perlu login lagi untuk memesan.', okText: 'Keluar')) {
                  await s.logout();
                }
              }, color: const Color(0xFFDC2626)),
            ),
          ]),
        ),
      ]),
      ),
    );
  }
}
