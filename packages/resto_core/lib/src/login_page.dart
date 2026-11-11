import 'package:flutter/material.dart';

import 'i18n.dart';
import 'package:provider/provider.dart';

import 'animations.dart';
import 'api.dart';
import 'session.dart';
import 'theme.dart';
import 'widgets.dart';

/// Halaman login bergaya Archive Management (hero gradasi + kartu form).
/// Dipakai aplikasi Resto & Kitchen; aplikasi Customer menambahkan tombol daftar.
class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.appName,
    required this.subtitle,
    this.icon = Icons.bakery_dining_rounded,
    this.loginLabel = 'Username',
    this.loginHint,
    this.features = const [],
    this.footer,
  });

  final String appName, subtitle, loginLabel;
  final String? loginHint;
  final IconData icon;
  final List<(IconData, String)> features;
  final Widget? footer;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _login = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false, _hide = true;

  Future<void> _submit() async {
    if (_login.text.trim().isEmpty || _pass.text.isEmpty) {
      showSnack(context, '${tr('Isi')} ${tr(widget.loginLabel).toLowerCase()} ${tr('dan password')}', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<Session>().login(_login.text, _pass.text);
    } catch (e) {
      if (mounted) showSnack(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _hero(BuildContext context, {bool full = false}) {
    final p = context.palette;
    final sess = context.watch<Session>();
    final padding = EdgeInsets.fromLTRB(28, full ? 48 : MediaQuery.paddingOf(context).top + 24, 28, full ? 48 : 36);
    final radius = full ? null : const BorderRadius.vertical(bottom: Radius.circular(32));
    final child = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: full ? MainAxisAlignment.spaceBetween : MainAxisAlignment.start,
        children: [
          Row(children: [
            FloatY(child: AppLogo(size: 50, icon: widget.icon)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('RestoBake'), style: serifStyle(size: 20, color: Colors.white)),
              Text(tr('FOOD & BAKERY'), style: TextStyle(color: p.accent, fontSize: 10, letterSpacing: 3, fontWeight: FontWeight.w600)),
            ]),
            const Spacer(),
            if (!sess.themeLocked)
              IconButton(onPressed: () => showThemePicker(context), icon: const Icon(Icons.palette_outlined, color: Colors.white)),
            IconButton(onPressed: () => showServerDialog(context), icon: const Icon(Icons.dns_outlined, color: Colors.white)),
          ]),
          SizedBox(height: full ? 0 : 28),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 36),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, w, __) => Container(width: w, height: 2, color: p.accent, margin: const EdgeInsets.only(bottom: 14)),
            ),
            FadeSlideIn(
              delay: const Duration(milliseconds: 150),
              offset: const Offset(0, .3),
              child: Text(tr(widget.appName), style: serifStyle(size: full ? 44 : 32, color: Colors.white).copyWith(height: 1.1)),
            ),
            const SizedBox(height: 8),
            FadeSlideIn(
              delay: const Duration(milliseconds: 350),
              child: Text(tr(widget.subtitle), style: TextStyle(color: Colors.white.withValues(alpha: .85), height: 1.5)),
            ),
            // teks sambutan dari tema admin (mis. promo musiman)
            if (sess.tagline.isNotEmpty)
              FadeSlideIn(
                delay: const Duration(milliseconds: 450),
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: p.accent.withValues(alpha: .22), borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: p.accent.withValues(alpha: .6))),
                  child: Text(tr(sess.tagline), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
          ]),
          if (full && widget.features.isNotEmpty)
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (var i = 0; i < widget.features.length; i++)
                FadeSlideIn(
                  delay: Duration(milliseconds: 550 + i * 120),
                  child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: .12)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(widget.features[i].$1, color: p.accent, size: 18),
                    const SizedBox(width: 8),
                    Text(tr(widget.features[i].$2), style: const TextStyle(color: Colors.white)),
                  ]),
                ),
                ),
            ]),
        ],
    );
    // gambar latar login dari tema admin
    if (sess.loginImageUrl.isNotEmpty) {
      return Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: radius,
          color: p.side,
          image: DecorationImage(
            image: NetworkImage(api.imageUrl(sess.loginImageUrl)),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: .38), BlendMode.darken),
          ),
        ),
        child: child,
      );
    }
    return AnimatedGradientBox(
      width: double.infinity,
      padding: padding,
      borderRadius: radius,
      colors: [p.side, p.side2, p.dark ? p.side2 : p.primary],
      glow: p.accent,
      child: child,
    );
  }


  Widget _form(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: FadeSlideIn(
        delay: const Duration(milliseconds: 200),
        offset: const Offset(0, .04),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // pilihan bahasa: Indonesia / English / 中文
        const Align(alignment: Alignment.centerRight, child: LanguageSelector()),
        const SizedBox(height: 14),
        Text(tr('Selamat datang'), style: serifStyle(size: 30)),
        const SizedBox(height: 4),
        Text(tr('Silakan masuk untuk melanjutkan'), style: TextStyle(color: context.muted)),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(children: [
            Expanded(child: Container(height: 1, color: context.gold.withValues(alpha: .35))),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Icon(widget.icon, size: 18, color: context.gold)),
            Expanded(child: Container(height: 1, color: context.gold.withValues(alpha: .35))),
          ]),
        ),
        TextField(
          controller: _login,
          textInputAction: TextInputAction.next,
          decoration: deco(context, widget.loginLabel, icon: Icons.person_outline_rounded, hint: widget.loginHint),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _pass,
          obscureText: _hide,
          onSubmitted: (_) => _submit(),
          decoration: deco(context, 'Password', icon: Icons.lock_outline_rounded,
              suffix: IconButton(
                onPressed: () => setState(() => _hide = !_hide),
                icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              )),
        ),
        const SizedBox(height: 22),
        SizedBox(
          height: 50,
          child: FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.login_rounded),
            label: Text(tr(_busy ? 'Memproses...' : 'Masuk'), style: const TextStyle(fontSize: 16)),
            style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 2),
          ),
        ),
        if (widget.footer != null) ...[const SizedBox(height: 14), widget.footer!],
      ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (context.isWide) {
      return Scaffold(
        body: Row(children: [
          Expanded(flex: 11, child: _hero(context, full: true)),
          Expanded(flex: 10, child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(32), child: _form(context)))),
        ]),
      );
    }
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(children: [
          _hero(context),
          Padding(padding: const EdgeInsets.fromLTRB(24, 28, 24, 32), child: _form(context)),
        ]),
      ),
    );
  }
}
