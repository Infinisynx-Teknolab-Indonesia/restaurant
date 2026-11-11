import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:resto_core/resto_core.dart';

import 'home_shell.dart';

/// Katalog Hadiah: tukar poin dengan gift card (Amazon, Google Play), saldo e-wallet (GoPay, OVO),
/// merchandise, dll. Semua hadiah & stok diatur dari Admin › Hadiah Tukar Poin.
class RewardsPage extends StatefulWidget {
  const RewardsPage({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

IconData rewardIcon(String kind) => switch (kind) {
      'gift_card' => Icons.card_giftcard_rounded,
      'ewallet' => Icons.account_balance_wallet_rounded,
      'merch' => Icons.redeem_rounded,
      'experience' => Icons.celebration_rounded,
      _ => Icons.stars_rounded,
    };

class _RewardsPageState extends State<RewardsPage> {
  List<Reward>? _items;
  List<RewardRedemption> _mine = [];
  String? _error;
  String _kind = '';

  @override
  void initState() {
    super.initState();
    _load();
    rewardsTick.addListener(_load);
  }

  @override
  void dispose() {
    rewardsTick.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([api.get('/api/rewards'), api.get('/api/rewards/my')]);
      if (!mounted) return;
      setState(() {
        _items = (r[0] as List).map((e) => Reward.fromJson(Map<String, dynamic>.from(e))).toList();
        _mine = (r[1] as List).map((e) => RewardRedemption.fromJson(Map<String, dynamic>.from(e))).toList();
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _redeem(Reward r) async {
    final info = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(c).bottom),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            RewardCard(reward: r, big: true),
            const SizedBox(height: 14),
            if (r.description.isNotEmpty) Text(tr(r.description)),
            if (r.terms.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(tr('Syarat & Ketentuan'), style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(tr(r.terms), style: TextStyle(fontSize: 12.5, color: c.muted)),
            ],
            const SizedBox(height: 12),
            Row(children: [
              Icon(r.autoCode ? Icons.bolt_rounded : Icons.schedule_rounded, size: 18, color: c.cs.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  r.autoCode ? tr('Kode langsung muncul setelah ditukar') : tr('Diproses admin, Anda akan diberi notifikasi'),
                  style: TextStyle(fontSize: 12.5, color: c.cs.primary, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
            if (r.infoLabel.isNotEmpty) ...[
              const SizedBox(height: 14),
              TextField(controller: info, decoration: deco(c, '${tr(r.infoLabel)} *', icon: Icons.edit_note_rounded)),
            ],
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: r.canRedeem ? () => Navigator.pop(c, true) : null,
                icon: const Icon(Icons.stars_rounded),
                label: Text(r.canRedeem ? tr('Tukar ${angka(r.points)} poin') : tr(r.blockedReason)),
              ),
            ),
          ]),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    if (r.infoLabel.isNotEmpty && info.text.trim().isEmpty) {
      return showSnack(context, tr('${r.infoLabel} wajib diisi'), error: true);
    }
    final res = await runSafe(context, () => api.post('/api/rewards/${r.id}/redeem', {'info': info.text.trim()}));
    if (res == null || !mounted) return;
    final x = RewardRedemption.fromJson(Map<String, dynamic>.from(res));
    context.read<Session>().refreshMe();
    ordersTick.value++;
    _load();
    await showDialog(context: context, builder: (c) => RedemptionDialog(x: x, reward: r));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<Session>().user!;
    final items = _items;
    final kinds = {for (final r in items ?? <Reward>[]) r.kind: r.kindLabel};
    final list = (items ?? []).where((r) => _kind.isEmpty || r.kind == _kind).toList();
    final cols = MediaQuery.sizeOf(context).width > 700 ? 3 : 2;
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('Tukar Poin')),
          bottom: TabBar(tabs: [
            Tab(text: tr('Katalog Hadiah')),
            Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(tr('Hadiah Saya')),
              if (_mine.any((m) => m.open)) ...[
                const SizedBox(width: 6),
                Badge(label: Text('${_mine.where((m) => m.open).length}')),
              ],
            ])),
          ]),
        ),
        body: _error != null && items == null
            ? ErrorView(message: _error!, onRetry: _load)
            : items == null
                ? const LoadingView()
                : TabBarView(children: [
                    PullRefresh(
                      onRefresh: _load,
                      child: ListView(padding: const EdgeInsets.all(16), children: [
                        AppCard(
                          color: context.cs.primary,
                          child: Row(children: [
                            const Icon(Icons.stars_rounded, color: Color(0xFFFCD34D), size: 34),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(tr('Poin Anda'), style: const TextStyle(color: Colors.white70)),
                                AnimatedNumber(value: user.points, format: angka,
                                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                              ]),
                            ),
                            Text(tr('Tukar dengan gift card,\nsaldo e-wallet & hadiah'), textAlign: TextAlign.right,
                                style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ]),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(children: [
                            for (final e in {'': 'Semua', ...kinds}.entries)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(label: Text(tr(e.value)), selected: _kind == e.key,
                                    onSelected: (_) => setState(() => _kind = e.key)),
                              ),
                          ]),
                        ),
                        const SizedBox(height: 12),
                        if (list.isEmpty) EmptyView(icon: Icons.redeem_rounded, text: tr('Belum ada hadiah tersedia')),
                        GridView.count(
                          crossAxisCount: cols,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: .78,
                          children: [for (final r in list) RewardCard(reward: r, userPoints: user.points, onTap: () => _redeem(r))],
                        ),
                      ]),
                    ),
                    PullRefresh(
                      onRefresh: _load,
                      child: _mine.isEmpty
                          ? ListView(children: [
                              const SizedBox(height: 80),
                              EmptyView(icon: Icons.card_giftcard_rounded, text: tr('Belum ada hadiah yang ditukar')),
                            ])
                          : ListView(padding: const EdgeInsets.all(16), children: [
                              for (final m in _mine)
                                AppCard(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  onTap: () => showDialog(context: context, builder: (_) => RedemptionDialog(x: m)),
                                  child: Row(children: [
                                    Container(
                                      width: 46, height: 46,
                                      decoration: BoxDecoration(color: hexColor(m.color), borderRadius: BorderRadius.circular(12)),
                                      child: Icon(rewardIcon(m.kind), color: Colors.white),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(m.rewardName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                        Text('${tanggalJam(m.createdAt)} · -${angka(m.points)} ${tr('poin')}',
                                            style: TextStyle(fontSize: 12, color: context.muted)),
                                        if (m.done && m.code.isNotEmpty)
                                          Text(m.code, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                                        if (m.adminNote.isNotEmpty)
                                          Text(m.adminNote, style: TextStyle(fontSize: 12, color: context.muted)),
                                      ]),
                                    ),
                                    _StatusPill(m.status),
                                  ]),
                                ),
                            ]),
                    ),
                  ]),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);
  final String status;
  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'completed' => ('Selesai', const Color(0xFF16A34A)),
      'rejected' => ('Ditolak', const Color(0xFFDC2626)),
      'processing' => ('Diproses', const Color(0xFF0284C7)),
      _ => ('Menunggu', const Color(0xFFD97706)),
    };
    return Pill(label, color: color);
  }
}

/// Kartu hadiah bergaya gift card (warna merek dari admin).
class RewardCard extends StatelessWidget {
  const RewardCard({super.key, required this.reward, this.userPoints, this.onTap, this.big = false});
  final Reward reward;
  final int? userPoints;
  final VoidCallback? onTap;
  final bool big;
  @override
  Widget build(BuildContext context) {
    final r = reward;
    final c = hexColor(r.color, fallback: const Color(0xFF1F2D4F));
    final head = Container(
      height: big ? 150 : 112,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c, Color.lerp(c, Colors.black, .45)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: big ? BorderRadius.circular(18) : const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Stack(children: [
        Positioned(right: -18, top: -24, child: Icon(rewardIcon(r.kind), size: big ? 120 : 90, color: Colors.white.withValues(alpha: .14))),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (r.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(api.imageUrl(r.imageUrl), width: 28, height: 28, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(rewardIcon(r.kind), color: Colors.white)),
              )
            else
              Icon(rewardIcon(r.kind), color: Colors.white, size: 22),
            const SizedBox(width: 6),
            Expanded(child: Text(r.brand, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5))),
          ]),
          const Spacer(),
          Text(r.valueLabel.isEmpty ? r.name : r.valueLabel,
              style: serifStyle(size: big ? 30 : 22, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ]),
    );
    if (big) return head;
    final enough = userPoints == null || userPoints! >= r.points;
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Opacity(
        opacity: r.canRedeem ? 1 : .6,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          head,
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                const Spacer(),
                Row(children: [
                  const Icon(Icons.stars_rounded, size: 18, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 4),
                  Text(angka(r.points), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  Text(' ${tr('poin')}', style: TextStyle(fontSize: 12, color: context.muted)),
                ]),
                const SizedBox(height: 2),
                Text(
                  r.canRedeem ? (r.available != null ? tr('Sisa ${r.available}') : tr('Tersedia')) : tr(r.blockedReason),
                  style: TextStyle(fontSize: 11.5, color: r.canRedeem && enough ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      fontWeight: FontWeight.w600),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Hasil / detail penukaran: tampilkan kode gift card (bisa disalin) atau status proses.
class RedemptionDialog extends StatelessWidget {
  const RedemptionDialog({super.key, required this.x, this.reward});
  final RewardRedemption x;
  final Reward? reward;
  @override
  Widget build(BuildContext context) {
    final done = x.done;
    return AlertDialog(
      icon: PopIn(child: Icon(done ? Icons.celebration_rounded : x.status == 'rejected' ? Icons.cancel_rounded : Icons.schedule_rounded,
          size: 56, color: done ? context.gold : x.status == 'rejected' ? const Color(0xFFDC2626) : const Color(0xFF0284C7))),
      title: Text(tr(done ? tr('Berhasil ditukar!') : x.status == 'rejected' ? tr('Penukaran ditolak') : tr('Penukaran sedang diproses')),
          textAlign: TextAlign.center, style: serifStyle(size: 22)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(x.rewardName, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
        Text('-${angka(x.points)} ${tr('poin')}', style: TextStyle(color: context.muted)),
        const SizedBox(height: 14),
        if (done && x.code.isNotEmpty)
          FadeSlideIn(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: context.gold, width: 1.5),
                borderRadius: BorderRadius.circular(12),
                color: context.gold.withValues(alpha: .08),
              ),
              child: Column(children: [
                Text(tr('KODE'), style: TextStyle(fontSize: 11, letterSpacing: 2, color: context.muted)),
                const SizedBox(height: 4),
                SelectableText(x.code, textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.w800)),
                if (x.pin.isNotEmpty) Text(tr('PIN: ${x.pin}'), style: const TextStyle(fontFamily: 'monospace')),
              ]),
            ),
          ),
        if (!done && x.status != 'rejected')
          Text(tr('Admin akan memproses hadiah Anda. Anda akan mendapat notifikasi saat selesai.'), textAlign: TextAlign.center),
        if (x.info.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(x.info, style: TextStyle(color: context.muted))),
        if (x.adminNote.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(x.adminNote, textAlign: TextAlign.center)),
        if (x.status == 'rejected') Padding(padding: const EdgeInsets.only(top: 8), child: Text(tr('Poin sudah dikembalikan.'), style: TextStyle(color: context.muted))),
      ]),
      actions: [
        if (done && x.code.isNotEmpty)
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: x.pin.isEmpty ? x.code : '${x.code} PIN ${x.pin}'));
              showSnack(context, tr('Kode disalin'));
            },
            icon: const Icon(Icons.copy_rounded),
            label: Text(tr('Salin kode')),
          ),
        FilledButton(onPressed: () => Navigator.pop(context), child: Text(tr('Tutup'))),
      ],
    );
  }
}
