import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:resto_core/resto_core.dart';

import '../cart.dart';
import 'checkout_page.dart';
import 'home_shell.dart';

/// Voucher: promo yang tersedia + dompet voucher milik member (hasil tukar poin / hadiah).
class VouchersPage extends StatefulWidget {
  const VouchersPage({super.key});
  @override
  State<VouchersPage> createState() => _VouchersPageState();
}

class _VouchersPageState extends State<VouchersPage> {
  List<Voucher>? _promo;
  List<WalletVoucher> _wallet = [];
  String? _error;
  final _code = TextEditingController();

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
      final r = await Future.wait([api.get('/api/vouchers/available'), api.get('/api/vouchers/my')]);
      if (!mounted) return;
      setState(() {
        _promo = ((r[0]['promo'] ?? []) as List).map((e) => Voucher.fromJson(Map<String, dynamic>.from(e))).toList();
        _wallet = (r[1] as List).map((e) => WalletVoucher.fromJson(Map<String, dynamic>.from(e))).toList();
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  void _use(String code) {
    final cart = context.read<Cart>();
    cart.setVoucher(code);
    Navigator.of(context).popUntil((r) => r.isFirst);
    if (cart.isEmpty) {
      showSnack(context, 'Voucher $code dipilih. Tambahkan menu ke keranjang, voucher dipakai otomatis saat checkout.');
      HomeShell.goTab(context, 0);
    } else {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CheckoutPage()));
    }
  }

  Widget _useButton(String code, {bool enabled = true}) => SizedBox(
        height: 50,
        child: FilledButton.icon(
          onPressed: enabled ? () => _use(code) : null,
          icon: const Icon(Icons.shopping_bag_rounded),
          label: Text(tr('Pakai di Keranjang')),
        ),
      );

  Widget _promoTab() {
    final rows = _promo ?? [];
    final selected = context.watch<Cart>().voucherCode;
    return PullRefresh(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          child: Row(children: [
            Icon(Icons.confirmation_number_outlined, color: context.gold),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(hintText: tr('Punya kode voucher?'), border: InputBorder.none),
              ),
            ),
            FilledButton(
              onPressed: () {
                if (_code.text.trim().isEmpty) return;
                _use(_code.text.trim());
                _code.clear();
              },
              child: Text(tr('Pakai')),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty) EmptyView(icon: Icons.local_offer_outlined, text: tr('Belum ada promo saat ini')),
        for (final v in rows)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: VoucherTicket(
              voucher: v,
              code: v.code,
              dim: v.blockedReason != null,
              badge: selected == v.code ? 'Dipilih' : (v.remaining != null && v.remaining! <= 10 ? 'Sisa ${v.remaining}' : null),
              footer: v.blockedReason ?? v.note ?? (v.endAt != null ? 'Berlaku s/d ${tanggal(v.endAt)}' : 'Lihat S&K'),
              trailing: Icon(Icons.chevron_right_rounded, color: context.muted),
              onTap: () => showVoucherSheet(context, v, code: v.code, actions: [
                if (v.blockedReason != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(v.blockedReason!, style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
                  ),
                _useButton(v.code, enabled: v.blockedReason == null),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _walletTab() {
    final active = _wallet.where((w) => w.isActive).toList();
    final past = _wallet.where((w) => !w.isActive).toList();
    final selected = context.watch<Cart>().voucherCode;
    Widget tile(WalletVoucher w) => Padding(
          padding: const EdgeInsets.only(top: 14),
          child: VoucherTicket(
            voucher: w.voucher,
            code: w.code,
            dim: !w.isActive,
            badge: selected == w.code ? 'Dipilih' : (w.status == 'used' ? 'Terpakai' : w.status == 'expired' ? 'Kedaluwarsa' : (w.source == 'gift' ? 'Hadiah' : null)),
            footer: w.isActive
                ? (w.expiresAt != null ? 'Berlaku s/d ${tanggal(w.expiresAt)}' : 'Tanpa batas waktu')
                : (w.status == 'used' ? 'Dipakai ${tanggal(w.usedAt)}' : 'Berakhir ${tanggal(w.expiresAt)}'),
            trailing: Icon(Icons.chevron_right_rounded, color: context.muted),
            onTap: () => showVoucherSheet(context, w.voucher, code: w.code, expiresAt: w.isActive ? w.expiresAt : null,
                actions: [if (w.isActive) _useButton(w.code)]),
          ),
        );
    return PullRefresh(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        if (_wallet.isEmpty) ...[
          const SizedBox(height: 60),
          EmptyView(
            icon: Icons.account_balance_wallet_outlined,
            text: tr('Dompet voucher masih kosong.\nTukar poin Anda dengan voucher di menu Poin.'),
            action: FilledButton.tonalIcon(
              onPressed: () => HomeShell.goTab(context, 3),
              icon: const Icon(Icons.stars_rounded),
              label: Text(tr('Tukar Poin')),
            ),
          ),
        ],
        for (final w in active) tile(w),
        if (past.isNotEmpty) ...[
          const SectionTitle('Riwayat', icon: Icons.history_rounded),
          for (final w in past.take(20)) tile(w),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _wallet.where((w) => w.isActive).length;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('Voucher')),
          bottom: TabBar(tabs: [
            Tab(text: tr('Promo')),
            Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(tr('Voucher Saya')),
              if (activeCount > 0) ...[const SizedBox(width: 6), Badge(label: Text('$activeCount'))],
            ])),
          ]),
        ),
        body: _error != null && _promo == null
            ? ErrorView(message: _error!, onRetry: _load)
            : _promo == null
                ? const LoadingView()
                : TabBarView(children: [_promoTab(), _walletTab()]),
      ),
    );
  }
}
