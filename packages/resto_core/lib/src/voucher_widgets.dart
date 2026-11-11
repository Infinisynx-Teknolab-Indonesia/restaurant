import 'package:flutter/material.dart';

import 'i18n.dart';
import 'package:flutter/services.dart';

import 'format.dart';
import 'models.dart';
import 'animations.dart';
import 'theme.dart';
import 'widgets.dart';

Color hexColor(String hex, {Color fallback = const Color(0xFFC5A059)}) {
  var h = hex.replaceAll('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  return v == null ? fallback : Color(v);
}

const _dayShort = {'1': 'Sen', '2': 'Sel', '3': 'Rab', '4': 'Kam', '5': 'Jum', '6': 'Sab', '7': 'Min'};

/// Ringkasan syarat utama untuk chip di tiket.
List<(IconData, String)> voucherConditions(Voucher v) {
  final c = <(IconData, String)>[];
  if (v.minSpend > 0) c.add((Icons.shopping_bag_outlined, 'Min. ${rupiah(v.minSpend)}'));
  if (v.discountType == 'percent' && v.maxDiscount > 0) c.add((Icons.vertical_align_top_rounded, 'Maks ${rupiah(v.maxDiscount)}'));
  final days = v.days.split(',').where((e) => e.trim().isNotEmpty).toList();
  if (days.isNotEmpty && days.length < 7) c.add((Icons.date_range_rounded, days.map((d) => _dayShort[d.trim()] ?? d).join(', ')));
  if (v.timeStart.isNotEmpty && v.timeEnd.isNotEmpty) c.add((Icons.schedule_rounded, '${v.timeStart}–${v.timeEnd}'));
  final types = v.orderTypes.split(',').where((e) => e.trim().isNotEmpty).toList();
  if (types.isNotEmpty && types.length < 3) c.add((Icons.room_service_outlined, types.map((t) => orderTypeLabel[t] ?? t).join(', ')));
  if (v.categoryNames.isNotEmpty) c.add((Icons.category_outlined, v.categoryNames.join(', ')));
  if (v.minTier.isNotEmpty) c.add((Icons.military_tech_outlined, 'Tier ${v.minTier}+'));
  if (v.newMemberOnly) c.add((Icons.person_add_alt_rounded, 'Member baru'));
  if (v.channel == 'app') c.add((Icons.smartphone_rounded, 'Khusus aplikasi'));
  if (v.channel == 'pos') c.add((Icons.point_of_sale_rounded, 'Khusus di kasir'));
  return c;
}

class _TicketClipper extends CustomClipper<Path> {
  _TicketClipper(this.stub);
  final double stub;
  @override
  Path getClip(Size size) {
    final base = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)));
    final holes = Path()
      ..addOval(Rect.fromCircle(center: Offset(stub, 0), radius: 10))
      ..addOval(Rect.fromCircle(center: Offset(stub, size.height), radius: 10));
    return Path.combine(PathOperation.difference, base, holes);
  }

  @override
  bool shouldReclip(covariant _TicketClipper old) => old.stub != stub;
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.6;
    double y = 14;
    while (y < size.height - 14) {
      canvas.drawLine(Offset(0, y), Offset(0, y + 5), p);
      y += 9;
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter old) => old.color != color;
}

/// Kartu voucher berbentuk tiket (stub warna + lubang sobekan).
class VoucherTicket extends StatelessWidget {
  const VoucherTicket({
    super.key, required this.voucher, this.code, this.footer, this.trailing, this.onTap,
    this.dim = false, this.badge,
  });

  final Voucher voucher;
  final String? code;
  final String? footer;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool dim;
  final String? badge;

  static const double stubWidth = 104;

  @override
  Widget build(BuildContext context) {
    final v = voucher;
    final c = hexColor(v.color);
    final conds = voucherConditions(v);
    final kindLabel = v.kind == 'points' ? 'Tukar Poin' : v.kind == 'gift' ? 'Hadiah' : 'Promo';
    final kindIcon = v.kind == 'points' ? Icons.stars_rounded : v.kind == 'gift' ? Icons.redeem_rounded : Icons.sell_rounded;
    return FadeSlideIn(
      child: Pressable(
      enabled: onTap != null,
      child: Opacity(
      opacity: dim ? .55 : 1,
      child: PhysicalShape(
        clipper: _TicketClipper(stubWidth),
        color: context.cs.surface,
        elevation: context.isDark ? 0 : 3,
        shadowColor: const Color(0x33281E0F),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(
                  width: stubWidth,
                  padding: const EdgeInsets.fromLTRB(10, 16, 12, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Color.lerp(c, Colors.white, .22)!, c, Color.lerp(c, Colors.black, .25)!],
                    ),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(v.bigLabel, style: serifStyle(size: 28, color: Colors.white)),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(v.smallLabel, maxLines: 1,
                          style: const TextStyle(color: Colors.white70, fontSize: 9.5, letterSpacing: 1.6, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 10),
                    // label jenis voucher: mengecil otomatis bila terjemahannya panjang (mis. "Redeem Points")
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: .18), borderRadius: BorderRadius.circular(99)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(kindIcon, size: 11, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(tr(kindLabel), maxLines: 1, style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                  ]),
                ),
                SizedBox(width: 1, child: CustomPaint(painter: _DashPainter(c.withValues(alpha: .45)))),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: Text(v.name, style: serifStyle(size: 16.5), maxLines: 2, overflow: TextOverflow.ellipsis)),
                        if (badge != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: c.withValues(alpha: .14), borderRadius: BorderRadius.circular(99)),
                            child: Text(tr(badge!), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color.lerp(c, Colors.black, .25))),
                          ),
                        ],
                      ]),
                      if (v.description.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(v.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: context.muted)),
                      ],
                      if ((code ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: c.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: c.withValues(alpha: .55), width: 1.2),
                          ),
                          child: Text(code!, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, letterSpacing: 1.4, fontSize: 12.5,
                              color: Color.lerp(c, context.cs.onSurface, .35))),
                        ),
                      ],
                      if (conds.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(spacing: 5, runSpacing: 5, children: [
                          for (final x in conds.take(4))
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(color: context.borderColor.withValues(alpha: .6), borderRadius: BorderRadius.circular(7)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(x.$1, size: 12, color: context.gold),
                                const SizedBox(width: 3),
                                Text(tr(x.$2), style: const TextStyle(fontSize: 10.5)),
                              ]),
                            ),
                        ]),
                      ],
                      if (footer != null || trailing != null) ...[
                        const SizedBox(height: 8),
                        Row(children: [
                          if (footer != null) Expanded(child: Text(tr(footer!), style: TextStyle(fontSize: 11, color: context.muted))),
                          if (footer == null) const Spacer(),
                          if (trailing != null) trailing!,
                        ]),
                      ],
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    ),
    ),
    );
  }
}

/// Bottom sheet detail voucher + Syarat & Ketentuan lengkap.
Future<T?> showVoucherSheet<T>(BuildContext context, Voucher v, {String? code, String? expiresAt, List<Widget> actions = const []}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .75,
      maxChildSize: .95,
      builder: (c, sc) => ListView(controller: sc, padding: const EdgeInsets.fromLTRB(20, 0, 20, 28), children: [
        VoucherTicket(voucher: v, code: code),
        if ((code ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code!));
              showSnack(c, 'Kode $code disalin');
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: Text(tr('Salin kode $code')),
          ),
        ],
        if (expiresAt != null) ...[
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.hourglass_bottom_rounded, size: 16, color: c.gold),
            const SizedBox(width: 6),
            Text(tr('Berlaku sampai ${tanggalJam(expiresAt)}'), style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
        ],
        if (v.note != null) ...[
          const SizedBox(height: 10),
          Text(v.note!, style: TextStyle(color: c.gold, fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 20),
        Text(tr('Syarat & Ketentuan'), style: serifStyle(size: 19)),
        const SizedBox(height: 10),
        for (var i = 0; i < v.allTerms.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 22, height: 22,
                margin: const EdgeInsets.only(right: 10, top: 1),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.gold.withValues(alpha: .15), shape: BoxShape.circle),
                child: Text('${i + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.gold)),
              ),
              Expanded(child: Text(v.allTerms[i], style: const TextStyle(height: 1.45))),
            ]),
          ),
        if (actions.isNotEmpty) ...[const SizedBox(height: 14), ...actions],
      ]),
    ),
  );
}
