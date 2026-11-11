import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:resto_core/resto_core.dart';

/// Hubungi Kami — pesan langsung terkirim ke email restoran (SMTP diatur Admin) dan tersimpan di Admin › Pesan Masuk.
class ContactPage extends StatefulWidget {
  const ContactPage({super.key});
  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _email, _phone;
  final _message = TextEditingController();
  String _topic = 'Pertanyaan';
  bool _sending = false;

  static const topics = ['Pertanyaan', 'Soal pesanan', 'Pesanan khusus / acara', 'Kritik & saran', 'Kerja sama', 'Lainnya'];

  @override
  void initState() {
    super.initState();
    final u = context.read<Session>().user;
    _name = TextEditingController(text: u?.name ?? '');
    _email = TextEditingController(text: u?.email ?? '');
    _phone = TextEditingController(text: u?.phone ?? '');
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _message]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      final r = await api.post('/api/contact', {
        'name': _name.text.trim(), 'email': _email.text.trim(), 'phone': _phone.text.trim(),
        'subject': tr(_topic), 'message': _message.text.trim(),
      });
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          icon: const Icon(Icons.mark_email_read_rounded, size: 46, color: Color(0xFF16A34A)),
          title: Text(tr('Pesan Terkirim')),
          content: Text(tr('${r['message'] ?? 'Terima kasih! Pesan Anda sudah terkirim, kami akan segera membalas.'}'), textAlign: TextAlign.center),
          actions: [FilledButton(onPressed: () => Navigator.pop(c), child: Text(tr('OK')))],
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showSnack(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String? req(String? v) => (v ?? '').trim().isEmpty ? tr('Wajib diisi') : null;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Hubungi Kami'))),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
          AppCard(
            color: context.cs.primary.withValues(alpha: .06),
            child: Row(children: [
              Icon(Icons.support_agent_rounded, color: context.cs.primary, size: 30),
              const SizedBox(width: 12),
              Expanded(child: Text(tr('Kirim pertanyaan, pesanan khusus, atau kritik & saran. Pesan langsung masuk ke email kami.'),
                  style: const TextStyle(height: 1.4))),
            ]),
          ),
          const SizedBox(height: 16),
          TextFormField(controller: _name, validator: req, textCapitalization: TextCapitalization.words,
              decoration: deco(context, 'Nama', icon: Icons.person_outline_rounded)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _email, keyboardType: TextInputType.emailAddress,
            decoration: deco(context, 'Email (untuk balasan)', icon: Icons.mail_outline_rounded),
            validator: (v) {
              final t = (v ?? '').trim();
              if (t.isEmpty && _phone.text.trim().isEmpty) return tr('Isi email atau nomor HP agar kami bisa membalas');
              if (t.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) return tr('Format email salah');
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(controller: _phone, keyboardType: TextInputType.phone,
              decoration: deco(context, 'No. HP / WhatsApp (opsional)', icon: Icons.phone_iphone_rounded)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(tr('Topik'), style: TextStyle(color: context.muted, fontSize: 13)),
          ),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in topics)
              ChoiceChip(label: Text(tr(t)), selected: _topic == t, showCheckmark: false, onSelected: (_) => setState(() => _topic = t)),
          ]),
          const SizedBox(height: 12),
          TextFormField(
            controller: _message, minLines: 5, maxLines: 10, maxLength: 3000,
            decoration: deco(context, 'Isi pesan', icon: Icons.edit_note_rounded),
            validator: (v) => (v ?? '').trim().length < 5 ? tr('Pesan terlalu pendek') : null,
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded),
            label: Text(tr(_sending ? 'Mengirim...' : 'Kirim Pesan')),
          ),
        ]),
      ),
    );
  }
}
