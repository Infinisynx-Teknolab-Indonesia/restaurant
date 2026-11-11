import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:resto_core/resto_core.dart';

import 'home_shell.dart';
import 'rewards_page.dart';

class LoyaltyPage extends StatefulWidget {
  const LoyaltyPage({super.key});
  @override
  State<LoyaltyPage> createState() => _LoyaltyPageState();
}

class _LoyaltyPageState extends State<LoyaltyPage> {
  LoyaltyInfo? _l;
  List<Voucher> _points = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    ordersTick.addListener(_load);
  }

  @override
  void dispose() {
    ordersTick.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([api.get('/api/loyalty/me'), api.get('/api/vouchers/available')]);
      if (!mounted) return;
      setState(() {
        _l = LoyaltyInfo.fromJson(Map<String, dynamic>.from(r[0]));
        _points = ((r[1]['points'] ?? []) as List).map((e) => Voucher.fromJson(Map<String, dynamic>.from(e))).toList();
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _redeem(Voucher v) async {
    if (!await confirmDialog(context, 'Tukar ${v.name}?',
        '${angka(v.pointsCost)} poin akan dipakai. Voucher masuk ke dompet "Voucher Saya"${v.validityDays > 0 ? ' dan berlaku ${v.validityDays} hari' : ''}.',
        okText: 'Tukar Poin')) {
      return;
    }
    if (!mounted) return;
    final res = await runSafe(context, () => api.post('/api/vouchers/${v.id}/redeem'));
    if (res == null || !mounted) return;
    final w = WalletVoucher.fromJson(Map<String, dynamic>.from(res));
    context.read<Session>().refreshMe();
    ordersTick.value++; // segarkan dompet voucher
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        icon: Icon(Icons.celebration_rounded, size: 48, color: c.gold),
        title: Text(tr('Berhasil ditukar!'), style: serifStyle(size: 22)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 320, child: VoucherTicket(voucher: w.voucher, code: w.code)),
          const SizedBox(height: 12),
          if (w.expiresAt != null) Text(tr('Berlaku sampai ${tanggal(w.expiresAt)}'), style: TextStyle(color: c.muted)),
        ]),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: w.code));
              Navigator.pop(c);
            },
            child: Text(tr('Salin kode')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(c);
              HomeShell.goTab(context, 2);
            },
            child: Text(tr('Lihat Voucher Saya')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = _l;
    final user = context.watch<Session>().user!;
    final tierColor = {'Gold': const Color(0xFFD4A017), 'Silver': const Color(0xFF94A3B8)}[l?.tier] ?? const Color(0xFFB45309);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Poin & Tier'))),
      body: _error != null && l == null
          ? ErrorView(message: _error!, onRetry: _load)
          : l == null
              ? const LoadingView()
              : PullRefresh(
                  onRefresh: _load,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: ListView(padding: const EdgeInsets.all(16), children: [
                        // kartu member
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            gradient: LinearGradient(colors: [context.palette.side, context.palette.primary, tierColor],
                                begin: Alignment.topLeft, end: Alignment.bottomRight, stops: const [0, .55, 1]),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              const Icon(Icons.bakery_dining_rounded, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(tr('MEMBER CARD'), style: TextStyle(color: Colors.white70, letterSpacing: 2, fontSize: 12)),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(color: tierColor, borderRadius: BorderRadius.circular(99)),
                                child: Text(l.tier.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                              ),
                            ]),
                            const SizedBox(height: 22),
                            AnimatedNumber(value: l.points, format: angka, style: serifStyle(size: 46, color: Colors.white)),
                            Text(tr('poin aktif'), style: TextStyle(color: Colors.white70)),
                            const SizedBox(height: 18),
                            Text(user.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                            Text(user.phone ?? '', style: const TextStyle(color: Colors.white70, letterSpacing: 1.5)),
                          ]),
                        ),
                        const SizedBox(height: 12),
                        if (l.nextTier != null)
                          AppCard(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(tr('${angka(l.pointsToNext)} poin lagi menuju ${l.nextTier}'), style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: LinearProgressIndicator(
                                  minHeight: 8,
                                  value: l.lifetimePoints / (l.lifetimePoints + l.pointsToNext).clamp(1, 1 << 30),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(tr('Dapat 1 poin setiap belanja ${rupiah(l.pointsPerAmount)} · 1 poin = ${rupiah(l.pointValue)}'),
                                  style: TextStyle(fontSize: 12, color: context.muted)),
                            ]),
                          ),
                        // Katalog hadiah: gift card Amazon / Google Play, saldo e-wallet, merchandise (diatur admin)
                        const SizedBox(height: 12),
                        AppCard(
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RewardsPage())),
                          child: Row(children: [
                            Container(
                              width: 52, height: 52,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFFFF9900), Color(0xFF7C3AED)]),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(tr('Tukar Poin dengan Hadiah'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                                Text(tr('Gift card Amazon, Google Play, saldo GoPay / OVO, merchandise & lainnya'),
                                    style: TextStyle(fontSize: 12.5, color: context.muted)),
                              ]),
                            ),
                            const Icon(Icons.chevron_right_rounded),
                          ]),
                        ),
                        const SectionTitle('Tukar Poin dengan Voucher', icon: Icons.redeem_rounded),
                        if (_points.isEmpty) EmptyView(icon: Icons.redeem_rounded, text: tr('Belum ada voucher tukar poin')),
                        for (final v in _points)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: VoucherTicket(
                              voucher: v,
                              dim: v.blockedReason != null,
                              footer: v.blockedReason ?? (l.points >= v.pointsCost
                                  ? 'Poin Anda cukup'
                                  : 'Kurang ${angka(v.pointsCost - l.points)} poin'),
                              trailing: FilledButton.tonalIcon(
                                onPressed: v.blockedReason == null && l.points >= v.pointsCost ? () => _redeem(v) : null,
                                icon: const Icon(Icons.stars_rounded, size: 16),
                                label: Text(angka(v.pointsCost)),
                                style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                              ),
                              onTap: () => showVoucherSheet(context, v, actions: [
                                SizedBox(
                                  height: 50,
                                  child: FilledButton.icon(
                                    onPressed: v.blockedReason == null && l.points >= v.pointsCost
                                        ? () {
                                            Navigator.pop(context);
                                            _redeem(v);
                                          }
                                        : null,
                                    icon: const Icon(Icons.stars_rounded),
                                    label: Text(tr('Tukar ${angka(v.pointsCost)} poin')),
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        const SectionTitle('Riwayat Poin', icon: Icons.history_rounded),
                        AppCard(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: l.history.isEmpty
                              ? Padding(padding: EdgeInsets.all(16), child: Text(tr('Belum ada transaksi poin')))
                              : Column(children: [
                                  for (final t in l.history.take(30))
                                    ListTile(
                                      dense: true,
                                      leading: Icon(t.points > 0 ? Icons.add_circle_rounded : Icons.remove_circle_rounded,
                                          color: t.points > 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
                                      title: Text(t.note),
                                      subtitle: Text(tanggalJam(t.createdAt)),
                                      trailing: Text('${t.points > 0 ? '+' : ''}${t.points}',
                                          style: TextStyle(fontWeight: FontWeight.w800,
                                              color: t.points > 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626))),
                                    ),
                                ]),
                        ),
                        const SizedBox(height: 20),
                      ]),
                    ),
                  ),
                ),
    );
  }
}
