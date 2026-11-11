import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'animations.dart';
import 'api.dart';
import 'format.dart';
import 'i18n.dart';
import 'session.dart';
import 'theme.dart';

// ---------------------------------------------------------------- input
InputDecoration deco(BuildContext context, String label, {IconData? icon, String? hint, Widget? suffix}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: context.borderColor),
  );
  return InputDecoration(
    labelText: tr(label),
    hintText: hint == null ? null : tr(hint),
    prefixIcon: icon == null ? null : Icon(icon, size: 20),
    suffixIcon: suffix,
    filled: true,
    fillColor: context.cs.surface,
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(borderSide: BorderSide(color: context.cs.primary, width: 1.6)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );
}

// ---------------------------------------------------------------- kartu
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap,
      this.color, this.borderColor, this.margin, this.animate = true});
  /// Muncul bertahap (fade + geser) saat pertama tampil.
  final bool animate;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color, borderColor;

  @override
  Widget build(BuildContext context) {
    Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? context.cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor ?? context.borderColor, width: borderColor == null ? 1 : 1.6),
        boxShadow: context.isDark
            ? null
            : const [
                BoxShadow(color: Color(0x0A281E0F), blurRadius: 2, offset: Offset(0, 1)),
                BoxShadow(color: Color(0x14281E0F), blurRadius: 24, spreadRadius: -8, offset: Offset(0, 10)),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
    if (onTap != null) card = Pressable(child: card);
    return animate ? FadeSlideIn(child: card) : card;
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.icon, this.trailing});
  final String title;
  final IconData? icon;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 10),
      child: Row(children: [
        if (icon != null) ...[Icon(icon, size: 20, color: context.gold), const SizedBox(width: 8)],
        Expanded(child: Text(tr(title), style: serifStyle(size: 18))),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.info, {super.key, this.small = false});
  final StatusInfo info;
  final bool small;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 10, vertical: small ? 3 : 5),
      decoration: BoxDecoration(color: info.color.withValues(alpha: .12), borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(info.icon, size: small ? 12 : 14, color: info.color),
        const SizedBox(width: 4),
        Text(info.label, style: TextStyle(color: info.color, fontWeight: FontWeight.w600, fontSize: small ? 11 : 12)),
      ]),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color, this.icon});
  final String text;
  final Color? color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final c = color ?? context.cs.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: .12), borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: c), const SizedBox(width: 4)],
        Text(tr(text), style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12)),
      ]),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.icon, required this.label, required this.value, this.sub});
  final IconData icon;
  final String label, value;
  final String? sub;
  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: context.gold.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.gold.withValues(alpha: .25)),
          ),
          child: Icon(icon, color: context.gold),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr(label), style: TextStyle(color: context.muted, fontSize: 12)),
            Text(value, style: serifStyle(size: 19)),
            if (sub != null) Text(tr(sub!), style: TextStyle(color: context.muted, fontSize: 11.5)),
          ]),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- state view
class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          PopIn(child: FloatY(child: Icon(icon, size: 60, color: context.gold.withValues(alpha: .55)))),
          const SizedBox(height: 10),
          Text(tr(text), textAlign: TextAlign.center, style: TextStyle(color: context.muted)),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ]),
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) => const SkeletonList();
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => EmptyView(
        icon: Icons.cloud_off_rounded,
        text: message,
        action: FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: Text(tr('Coba lagi'))),
      );
}

/// Gambar menu dari server; kalau kosong/gagal tampil ikon.
class MenuImage extends StatelessWidget {
  const MenuImage({super.key, required this.url, this.icon = Icons.bakery_dining_rounded, this.height, this.width, this.radius = 12});
  final String url;
  final IconData icon;
  final double? height, width;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final ph = Container(
      height: height, width: width,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [context.gold.withValues(alpha: .20), context.gold.withValues(alpha: .06)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, size: (height ?? 80) * .4, color: context.gold.withValues(alpha: .8)),
    );
    if (url.isEmpty) return ph;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(api.imageUrl(url), height: height, width: width, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => ph,
          frameBuilder: (_, child, frame, sync) => sync
              ? child
              : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: const Duration(milliseconds: 450), curve: Curves.easeOut, child: child)),
    );
  }
}

class QtyStepper extends StatelessWidget {
  const QtyStepper({super.key, required this.qty, required this.onChanged, this.min = 0});
  final int qty, min;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    Widget b(IconData i, VoidCallback? f) => InkWell(
          onTap: f,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
                color: f == null ? context.borderColor : context.cs.primary.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(i, size: 18, color: f == null ? context.muted : context.cs.primary),
          ),
        );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      b(Icons.remove_rounded, qty > min ? () => onChanged(qty - 1) : null),
      SizedBox(width: 34, child: Text('$qty', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
      b(Icons.add_rounded, qty < 99 ? () => onChanged(qty + 1) : null),
    ]);
  }
}

class LiveDot extends StatelessWidget {
  const LiveDot({super.key, this.showLabel = true});
  final bool showLabel;
  @override
  Widget build(BuildContext context) {
    final rt = Provider.of<Session>(context, listen: false).realtime;
    return ValueListenableBuilder<bool>(
      valueListenable: rt.connected,
      builder: (_, on, __) => Row(mainAxisSize: MainAxisSize.min, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 9, height: 9,
          decoration: BoxDecoration(
            color: on ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
            shape: BoxShape.circle,
            boxShadow: on ? [const BoxShadow(color: Color(0x5516A34A), blurRadius: 0, spreadRadius: 3)] : null,
          ),
        ),
        if (showLabel) ...[const SizedBox(width: 6), Text(tr(on ? 'Live' : 'Offline'), style: const TextStyle(fontSize: 12))],
      ]),
    );
  }
}

// ---------------------------------------------------------------- dialog & snack
void showSnack(BuildContext context, String msg, {bool error = false}) {
  final m = ScaffoldMessenger.maybeOf(context);
  m?.hideCurrentSnackBar();
  m?.showSnackBar(SnackBar(
    content: Text(tr(msg)),
    behavior: SnackBarBehavior.floating,
    // warna notifikasi mengikuti tema dari admin
    backgroundColor: error ? const Color(0xFFDC2626) : Provider.of<Session?>(context, listen: false)?.notifyColor,
  ));
}

/// Jalankan aksi async dengan pesan error otomatis.
Future<T?> runSafe<T>(BuildContext context, Future<T> Function() fn, {String? success}) async {
  try {
    final r = await fn();
    if (success != null && context.mounted) showSnack(context, success);
    return r;
  } catch (e) {
    if (context.mounted) showSnack(context, '$e', error: true);
    return null;
  }
}

Future<bool> confirmDialog(BuildContext context, String title, String msg,
    {String okText = 'Ya', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(tr(title)),
      content: Text(tr(msg)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Batal'))),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)) : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(tr(okText)),
        ),
      ],
    ),
  );
  return r ?? false;
}

Future<String?> inputDialog(BuildContext context, String title, String label,
    {String initial = '', TextInputType keyboard = TextInputType.text, String okText = 'Simpan'}) {
  final ctl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(tr(title)),
      content: TextField(controller: ctl, autofocus: true, keyboardType: keyboard, decoration: deco(c, label),
          onSubmitted: (v) => Navigator.pop(c, v.trim())),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('Batal'))),
        FilledButton(onPressed: () => Navigator.pop(c, ctl.text.trim()), child: Text(tr(okText))),
      ],
    ),
  );
}

// ---------------------------------------------------------------- logo & header
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 44, this.icon = Icons.bakery_dining_rounded});
  final double size;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    // logo dari tema admin (Admin › Tema & Logo Aplikasi)
    final logo = Provider.of<Session?>(context)?.logoUrl ?? '';
    if (logo.isNotEmpty) {
      // logo apa pun bentuknya (persegi / melebar / transparan) tampil utuh, tidak terpotong
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * .28),
        child: Container(
          width: size, height: size,
          color: Colors.white,
          padding: EdgeInsets.all(size * .06),
          child: Image.network(api.imageUrl(logo), fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(icon, color: p.accent, size: size * .6)),
        ),
      );
    }
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Color.lerp(p.accent, Colors.white, .35)!, p.accent],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(size * .28),
        boxShadow: [BoxShadow(color: p.accent.withValues(alpha: .45), blurRadius: 18, spreadRadius: -6, offset: const Offset(0, 6))],
      ),
      child: Icon(icon, color: p.side, size: size * .55),
    );
  }
}

/// Header gradasi gaya hero login admin.
class GradientHeader extends StatelessWidget {
  const GradientHeader({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 24), this.radius = 28});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnimatedGradientBox(
      width: double.infinity,
      padding: padding,
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(radius)),
      colors: [p.side, p.side2, p.dark ? p.side2 : p.primary],
      glow: p.accent,
      child: DefaultTextStyle(style: const TextStyle(color: Colors.white), child: IconTheme(data: const IconThemeData(color: Colors.white), child: child)),
    );
  }
}

// ---------------------------------------------------------------- pengaturan
Future<void> showThemePicker(BuildContext context) {
  final sess = Provider.of<Session>(context, listen: false);
  if (sess.themeLocked) {
    // tema diatur dari Admin › Tema & Logo Aplikasi
    showSnack(context, tr('Tema diatur oleh Admin: ${sess.remoteTheme!.name}'));
    return Future.value();
  }
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (c) {
      final s = c.watch<Session>();
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('Tema Tampilan'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Wrap(spacing: 14, runSpacing: 14, children: [
            for (var i = 0; i < palettes.length; i++)
              GestureDetector(
                onTap: () => s.setTheme(i),
                child: Column(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [palettes[i].side, palettes[i].side, palettes[i].accent, palettes[i].accent],
                          stops: const [0, .5, .5, 1], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      shape: BoxShape.circle,
                      border: Border.all(color: s.themeIndex == i ? c.gold : c.borderColor, width: s.themeIndex == i ? 3 : 1),
                    ),
                    child: s.themeIndex == i ? const Icon(Icons.check_rounded, color: Colors.white) : null,
                  ),
                  const SizedBox(height: 6),
                  Text(palettes[i].name, style: const TextStyle(fontSize: 12)),
                ]),
              ),
          ]),
        ]),
      );
    },
  );
}

Future<void> showServerDialog(BuildContext context) async {
  final s = context.read<Session>();
  final ctl = TextEditingController(text: s.server);
  String? status;
  bool testing = false;
  await showDialog(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setSt) => AlertDialog(
        title: Text(tr('Alamat Server')),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: ctl, keyboardType: TextInputType.url,
              decoration: deco(c, 'URL Server', icon: Icons.dns_rounded, hint: 'http://192.168.1.10:8000')),
          const SizedBox(height: 8),
          Text(tr('Gunakan IP LAN PC server (bukan localhost). Contoh: http://192.168.1.10:8000'),
              style: TextStyle(fontSize: 12, color: c.muted)),
          if (status != null) ...[const SizedBox(height: 10), Text(tr(status!), style: const TextStyle(fontWeight: FontWeight.w600))],
        ]),
        actions: [
          TextButton(
            onPressed: testing
                ? null
                : () async {
                    setSt(() => testing = true);
                    final old = api.baseUrl;
                    api.baseUrl = Session.normalizeUrl(ctl.text);
                    final ok = await api.ping();
                    api.baseUrl = old;
                    setSt(() {
                      testing = false;
                      status = ok ? '✓ Server terhubung' : '✗ Gagal terhubung ke server';
                    });
                  },
            child: Text(tr(testing ? 'Menguji...' : 'Tes Koneksi')),
          ),
          TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('Batal'))),
          FilledButton(
            onPressed: () async {
              await s.setServer(ctl.text);
              if (c.mounted) Navigator.pop(c);
            },
            child: Text(tr('Simpan')),
          ),
        ],
      ),
    ),
  );
}

/// Baris info kiri-kanan untuk ringkasan total.
class KvRow extends StatelessWidget {
  const KvRow(this.label, this.value, {super.key, this.bold = false, this.color, this.size});
  final String label, value;
  final bool bold;
  final Color? color;
  final double? size;
  @override
  Widget build(BuildContext context) {
    final st = TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500, fontSize: size ?? (bold ? 16 : 14), color: color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Text(tr(label), style: bold ? st : st.copyWith(color: color ?? context.muted))),
        Text(tr(value), style: st),
      ]),
    );
  }
}
