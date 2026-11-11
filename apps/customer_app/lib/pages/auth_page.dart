import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:resto_core/resto_core.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LoginPage(
      appName: 'Pesan & Nikmati',
      subtitle: tr('Pesan roti, kue & makanan favoritmu. Kumpulkan poin di setiap transaksi.'),
      loginLabel: 'No. HP atau Email',
      loginHint: '08xxxxxxxxxx',
      features: const [
        (Icons.delivery_dining_rounded, 'Pesan online'),
        (Icons.confirmation_number_rounded, 'Poin & voucher'),
        (Icons.qr_code_2_rounded, 'Bayar QRIS'),
      ],
      footer: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(tr('Belum punya akun?')),
        TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterPage())),
          child: Text(tr('Daftar Member')),
        ),
      ]),
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  DateTime? _birthday;
  bool _busy = false;

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty) {
      return showSnack(context, 'Nama dan No. HP wajib diisi', error: true);
    }
    if (_pass.text.length < 6) return showSnack(context, 'Password minimal 6 karakter', error: true);
    if (_pass.text != _pass2.text) return showSnack(context, 'Konfirmasi password tidak sama', error: true);
    setState(() => _busy = true);
    try {
      await context.read<Session>().register(
            name: _name.text,
            phone: _phone.text,
            email: _email.text,
            password: _pass.text,
            birthday: _birthday?.toIso8601String().substring(0, 10),
          );
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) showSnack(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Daftar Member'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(padding: const EdgeInsets.all(20), children: [
            AppCard(
              color: context.cs.primary.withValues(alpha: .08),
              child: Row(children: [
                Icon(Icons.card_giftcard_rounded, color: context.cs.primary),
                const SizedBox(width: 12),
                Expanded(child: Text(tr('Daftar gratis & langsung kumpulkan poin dari setiap pesanan.'))),
              ]),
            ),
            const SizedBox(height: 18),
            TextField(controller: _name, textCapitalization: TextCapitalization.words,
                decoration: deco(context, 'Nama Lengkap', icon: Icons.person_outline_rounded)),
            const SizedBox(height: 12),
            TextField(controller: _phone, keyboardType: TextInputType.phone,
                decoration: deco(context, 'No. HP', icon: Icons.phone_iphone_rounded, hint: '08xxxxxxxxxx')),
            const SizedBox(height: 12),
            TextField(controller: _email, keyboardType: TextInputType.emailAddress,
                decoration: deco(context, 'Email (opsional)', icon: Icons.mail_outline_rounded)),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: DateTime(2000),
                    firstDate: DateTime(1940), lastDate: DateTime.now());
                if (d != null) setState(() => _birthday = d);
              },
              child: InputDecorator(
                decoration: deco(context, 'Tanggal Lahir (opsional)', icon: Icons.cake_outlined),
                child: Text(tr(_birthday == null ? 'Pilih tanggal' : tanggal(_birthday!.toIso8601String()))),
              ),
            ),
            const SizedBox(height: 12),
            TextField(controller: _pass, obscureText: true,
                decoration: deco(context, 'Password', icon: Icons.lock_outline_rounded)),
            const SizedBox(height: 12),
            TextField(controller: _pass2, obscureText: true, onSubmitted: (_) => _submit(),
                decoration: deco(context, 'Ulangi Password', icon: Icons.lock_outline_rounded)),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(tr(_busy ? 'Mendaftar...' : 'Daftar Sekarang'), style: const TextStyle(fontSize: 16)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
