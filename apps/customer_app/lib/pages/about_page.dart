import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:resto_core/resto_core.dart';
import 'package:url_launcher/url_launcher.dart';

import 'contact_page.dart';

/// Tentang Kami — isi diatur dari Admin › Pengaturan › Tentang & Hubungi Kami.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  Future<void> _open(BuildContext context, String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) showSnack(context, tr('Tidak bisa membuka tautan'), error: true);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final i = s.info;
    Widget row(IconData ic, String label, String value, {VoidCallback? onTap}) => ListTile(
          leading: Icon(ic, color: context.cs.primary),
          title: Text(tr(label), style: TextStyle(fontSize: 12.5, color: context.muted)),
          subtitle: Text(value, style: TextStyle(fontSize: 15, color: context.cs.onSurface, fontWeight: FontWeight.w600)),
          trailing: onTap == null ? null : const Icon(Icons.open_in_new_rounded, size: 18),
          onTap: onTap,
        );
    final wa = (i?.contactWhatsapp ?? '').replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^0'), '62');
    final ig = (i?.contactInstagram ?? '').replaceAll('@', '').trim();
    return Scaffold(
      appBar: AppBar(title: Text(tr('Tentang Kami'))),
      body: PullRefresh(
        onRefresh: () => context.read<Session>().loadInfo(),
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
          const SizedBox(height: 12),
          const Center(child: AppLogo(size: 96)),
          const SizedBox(height: 14),
          Center(child: Text(i?.name ?? 'RestoBake', textAlign: TextAlign.center, style: serifStyle(size: 24))),
          if ((s.tagline).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Center(child: Text(s.tagline, style: TextStyle(color: context.gold, letterSpacing: 2, fontSize: 12, fontWeight: FontWeight.w700))),
            ),
          if ((i?.aboutText ?? '').isNotEmpty) ...[
            const SizedBox(height: 18),
            AppCard(child: Text(i!.aboutText, style: const TextStyle(fontSize: 14.5, height: 1.55))),
          ],
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(children: [
              if ((i?.address ?? '').isNotEmpty)
                row(Icons.location_on_outlined, 'Alamat', i!.address,
                    onTap: () => _open(context, 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('${i.name} ${i.address}')}')),
              if ((i?.openHours ?? '').isNotEmpty) row(Icons.schedule_rounded, 'Jam Buka', i!.openHours),
              if ((i?.phone ?? '').isNotEmpty) row(Icons.call_outlined, 'Telepon', i!.phone, onTap: () => _open(context, 'tel:${i.phone.replaceAll(' ', '')}')),
              if (wa.isNotEmpty) row(Icons.chat_outlined, 'WhatsApp', i!.contactWhatsapp, onTap: () => _open(context, 'https://wa.me/$wa')),
              if (ig.isNotEmpty) row(Icons.camera_alt_outlined, 'Instagram', '@$ig', onTap: () => _open(context, 'https://instagram.com/$ig')),
            ]),
          ),
          if (i?.contactEnabled ?? false) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContactPage())),
              icon: const Icon(Icons.mail_outline_rounded),
              label: Text(tr('Hubungi Kami')),
            ),
          ],
        ]),
      ),
    );
  }
}
