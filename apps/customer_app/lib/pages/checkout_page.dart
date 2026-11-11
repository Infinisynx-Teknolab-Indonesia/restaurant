import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:resto_core/resto_core.dart';

import '../cart.dart';
import 'order_detail_page.dart';
import 'payment_page.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});
  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  String _type = 'takeaway';
  String _pay = 'online_qris'; // online_qris | online_card | counter
  final _table = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();
  bool _usePoints = false;
  double _points = 0;
  bool _busy = false;
  VoucherCheck? _vc;
  String? _vcError;
  bool _checking = false;
  String _checkSig = '';

  @override
  void initState() {
    super.initState();
    _address.text = context.read<Session>().user?.address ?? '';
  }

  String _sig(Cart cart) =>
      '${cart.voucherCode}|$_type|${cart.lines.map((l) => '${l.item.id}x${l.qty}').join(',')}';

  /// Dipanggil dari build: cek ulang voucher bila keranjang / tipe / kode berubah.
  void _maybeCheck(Cart cart) {
    final sig = _sig(cart);
    if (sig == _checkSig) return;
    _checkSig = sig;
    if (cart.voucherCode == null || cart.isEmpty) {
      _vc = null;
      _vcError = null;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _check(sig));
  }

  Future<void> _check(String sig) async {
    final cart = context.read<Cart>();
    final code = cart.voucherCode;
    if (code == null || !mounted) return;
    setState(() => _checking = true);
    try {
      final r = await api.post('/api/vouchers/check', {'code': code, 'items': cart.toPayload(), 'order_type': _type});
      if (!mounted || sig != _checkSig) return;
      setState(() {
        _vc = VoucherCheck.fromJson(Map<String, dynamic>.from(r));
        _vcError = _vc!.ok ? null : _vc!.message;
      });
    } catch (e) {
      if (!mounted || sig != _checkSig) return;
      setState(() {
        _vc = null;
        _vcError = '$e';
      });
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _pickVoucher() async {
    final cart = context.read<Cart>();
    final ctl = TextEditingController();
    List<WalletVoucher> wallet = [];
    List<Voucher> promo = [];
    try {
      final r = await Future.wait([api.get('/api/vouchers/my'), api.get('/api/vouchers/available')]);
      wallet = (r[0] as List).map((e) => WalletVoucher.fromJson(Map<String, dynamic>.from(e))).where((w) => w.isActive).toList();
      promo = ((r[1]['promo'] ?? []) as List).map((e) => Voucher.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      if (mounted) showSnack(context, '$e', error: true);
    }
    if (!mounted) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .8,
        maxChildSize: .95,
        builder: (c, sc) => ListView(controller: sc, padding: const EdgeInsets.fromLTRB(16, 0, 16, 28), children: [
          Text(tr('Pilih Voucher'), style: serifStyle(size: 22)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                controller: ctl,
                textCapitalization: TextCapitalization.characters,
                decoration: deco(c, 'Masukkan kode voucher', icon: Icons.confirmation_number_outlined),
                onSubmitted: (v) => Navigator.pop(c, v.trim()),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(height: 52, child: FilledButton(onPressed: () => Navigator.pop(c, ctl.text.trim()), child: Text(tr('Pakai')))),
          ]),
          if (wallet.isNotEmpty) ...[
            const SectionTitle('Voucher Saya', icon: Icons.account_balance_wallet_rounded),
            for (final w in wallet)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: VoucherTicket(
                  voucher: w.voucher,
                  code: w.code,
                  badge: cart.voucherCode == w.code ? 'Dipilih' : null,
                  footer: w.expiresAt != null ? 'Berlaku s/d ${tanggal(w.expiresAt)}' : null,
                  onTap: () => Navigator.pop(c, w.code),
                ),
              ),
          ],
          if (promo.isNotEmpty) ...[
            const SectionTitle('Promo Tersedia', icon: Icons.local_offer_rounded),
            for (final v in promo)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: VoucherTicket(
                  voucher: v,
                  code: v.code,
                  dim: v.blockedReason != null,
                  badge: cart.voucherCode == v.code ? 'Dipilih' : null,
                  footer: v.blockedReason ?? v.note,
                  onTap: v.blockedReason == null ? () => Navigator.pop(c, v.code) : null,
                ),
              ),
          ],
          if (wallet.isEmpty && promo.isEmpty)
            EmptyView(icon: Icons.local_offer_outlined, text: tr('Belum ada voucher yang tersedia')),
        ]),
      ),
    );
    if (picked != null && picked.isNotEmpty) cart.setVoucher(picked);
  }

  Future<void> _submit() async {
    final cart = context.read<Cart>();
    final s = context.read<Session>();
    if (cart.voucherCode != null && !(_vc?.ok ?? false)) {
      return showSnack(context, 'Voucher belum bisa dipakai${_vcError != null ? ': $_vcError' : ''}. Ganti atau hapus voucher dulu.', error: true);
    }
    if (_type == 'dine_in' && _table.text.trim().isEmpty) return showSnack(context, 'Isi nomor meja', error: true);
    if (_type == 'delivery' && _address.text.trim().isEmpty) return showSnack(context, 'Isi alamat pengantaran', error: true);
    setState(() => _busy = true);
    try {
      final order = await api.createOrder({
        'order_type': _type,
        'table_number': _type == 'dine_in' ? _table.text.trim() : null,
        'items': cart.toPayload(),
        'notes': _notes.text.trim(),
        'delivery_address': _type == 'delivery' ? _address.text.trim() : '',
        'use_points': _usePoints ? _points.round() : 0,
        'payment_mode': _pay == 'counter' ? 'counter' : 'online',
        'voucher_code': cart.voucherCode,
      });
      cart.clear();
      s.refreshMe();
      if (!mounted) return;
      final nav = Navigator.of(context);
      if (_pay == 'counter') {
        nav.pushReplacement(MaterialPageRoute(builder: (_) => OrderDetailPage(orderId: order.id)));
      } else {
        nav.pushReplacement(MaterialPageRoute(
            builder: (_) => PaymentPage(order: order, method: _pay == 'online_card' ? 'card' : 'qris')));
      }
    } catch (e) {
      if (mounted) showSnack(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // QRIS hanya untuk Rupiah: bila restoran memakai USD/SGD/MYR, pakai kartu
    if (_pay == 'online_qris' && !(Provider.of<Session>(context, listen: false).info?.qrisAvailable ?? true)) _pay = 'online_card';
    final cart = context.watch<Cart>();
    final s = context.watch<Session>();
    final info = s.info;
    final user = s.user!;
    _maybeCheck(cart);
    final bool vOk = cart.voucherCode != null && (_vc?.ok ?? false);
    final int vdisc = vOk ? math.min(_vc!.discount, cart.subtotal) : 0;
    final bool freeShip = vOk && _vc!.freeDelivery;
    final int pv = math.max(1, info?.pointValue ?? 100);
    final int maxPts = math.max(0, math.min(user.points, (cart.subtotal - vdisc) ~/ pv));
    final canPoints = info != null && maxPts >= info.minRedeem;
    if (_points > maxPts) _points = maxPts.toDouble();
    if (_points < (info?.minRedeem ?? 0) && canPoints) _points = info.minRedeem.toDouble();

    // estimasi total (perhitungan final dilakukan server)
    final sub = cart.subtotal;
    final int disc = _usePoints && canPoints ? math.min(_points.round() * pv, sub - vdisc) : 0;
    final taxable = sub - vdisc - disc;
    final int service = _type == 'dine_in' ? (taxable * (info?.servicePercent ?? 0) / 100).round() : 0;
    final int tax = ((taxable + service) * (info?.taxPercent ?? 0) / 100).round();
    final int fullOngkir = _type == 'delivery' ? (info?.deliveryFee ?? 0) : 0;
    final int ongkir = freeShip ? 0 : fullOngkir;
    final total = taxable + service + tax + ongkir;

    if (cart.isEmpty) {
      return Scaffold(appBar: AppBar(title: Text(tr('Keranjang'))),
          body: EmptyView(icon: Icons.shopping_bag_outlined, text: tr('Keranjang masih kosong')));
    }

    return Scaffold(
      appBar: AppBar(title: Text(tr('Keranjang & Checkout')), actions: [
        TextButton(onPressed: () async {
          if (await confirmDialog(context, 'Kosongkan keranjang?', 'Semua item akan dihapus.', okText: 'Kosongkan', danger: true)) {
            cart.clear();
          }
        }, child: Text(tr('Kosongkan'))),
      ]),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 120), children: [
            const SectionTitle('Pesanan', icon: Icons.shopping_bag_rounded),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                for (final l in cart.lines)
                  ListTile(
                    title: Text(l.item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(rupiah(l.item.price)),
                      InkWell(
                        onTap: () async {
                          final n = await inputDialog(context, 'Catatan', 'Catatan untuk dapur', initial: l.notes);
                          if (n != null) cart.setNotes(l.item.id, n);
                        },
                        child: Text(tr(l.notes.isEmpty ? '+ Tambah catatan' : '* ${l.notes}'),
                            style: TextStyle(color: context.cs.primary, fontSize: 12.5)),
                      ),
                    ]),
                    trailing: QtyStepper(qty: l.qty, onChanged: (v) => cart.setQty(l.item.id, v)),
                  ),
              ]),
            ),
            const SectionTitle('Tipe Pesanan', icon: Icons.room_service_rounded),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'takeaway', label: Text(tr('Ambil')), icon: Icon(Icons.shopping_bag_outlined)),
                ButtonSegment(value: 'delivery', label: Text(tr('Antar')), icon: Icon(Icons.delivery_dining_outlined)),
                ButtonSegment(value: 'dine_in', label: Text(tr('Makan di sini')), icon: Icon(Icons.table_restaurant_outlined)),
              ],
              selected: {_type},
              onSelectionChanged: (v) => setState(() => _type = v.first),
            ),
            const SizedBox(height: 12),
            if (_type == 'dine_in')
              TextField(controller: _table, keyboardType: TextInputType.number,
                  decoration: deco(context, 'Nomor Meja', icon: Icons.table_restaurant_rounded, hint: 'Lihat nomor di meja Anda')),
            if (_type == 'delivery')
              TextField(controller: _address, maxLines: 2,
                  decoration: deco(context, 'Alamat Pengantaran', icon: Icons.location_on_outlined)),
            const SizedBox(height: 12),
            TextField(controller: _notes, decoration: deco(context, 'Catatan pesanan (opsional)', icon: Icons.notes_rounded)),

            const SectionTitle('Voucher', icon: Icons.confirmation_number_rounded),
            AppCard(
              onTap: _pickVoucher,
              borderColor: cart.voucherCode == null ? null : (vOk ? const Color(0xFF16A34A) : const Color(0xFFDC2626)).withValues(alpha: .6),
              child: cart.voucherCode == null
                  ? Row(children: [
                      Icon(Icons.local_offer_outlined, color: context.gold),
                      const SizedBox(width: 12),
                      Expanded(child: Text(tr('Pakai voucher atau kode promo'), style: TextStyle(fontWeight: FontWeight.w600))),
                      Icon(Icons.chevron_right_rounded, color: context.muted),
                    ])
                  : Row(children: [
                      Icon(vOk ? Icons.check_circle_rounded : (_checking ? Icons.hourglass_top_rounded : Icons.error_outline_rounded),
                          color: vOk ? const Color(0xFF16A34A) : (_checking ? context.gold : const Color(0xFFDC2626))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_vc != null ? '${_vc!.voucher.name} · ${cart.voucherCode}' : cart.voucherCode!,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(
                            tr(_checking
                                ? 'Mengecek syarat voucher...'
                                : vOk
                                    ? (freeShip ? 'Gratis ongkir ${rupiah(fullOngkir)}' : 'Hemat ${rupiah(vdisc)}')
                                    : (_vcError ?? 'Voucher tidak bisa dipakai')),
                            style: TextStyle(fontSize: 12.5, color: vOk ? const Color(0xFF16A34A) : (_checking ? context.muted : const Color(0xFFDC2626))),
                          ),
                          if (_vc != null)
                            InkWell(
                              onTap: () => showVoucherSheet(context, _vc!.voucher, code: cart.voucherCode),
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(tr('Lihat Syarat & Ketentuan'), style: TextStyle(fontSize: 12, color: context.gold, fontWeight: FontWeight.w600)),
                              ),
                            ),
                        ]),
                      ),
                      IconButton(
                        tooltip: tr('Hapus voucher'),
                        onPressed: () => cart.setVoucher(null),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ]),
            ),

            const SectionTitle('Poin', icon: Icons.stars_rounded),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _usePoints && canPoints,
                  onChanged: canPoints ? (v) => setState(() => _usePoints = v) : null,
                  title: Text(tr('Pakai poin (${angka(user.points)} tersedia)')),
                  subtitle: Text(tr(canPoints
                      ? '1 poin = ${rupiah(pv)}'
                      : 'Minimal ${info?.minRedeem ?? 0} poin untuk ditukar')),
                ),
                if (_usePoints && canPoints && maxPts > info.minRedeem)
                  Slider(
                    value: _points,
                    min: info.minRedeem.toDouble(),
                    max: maxPts.toDouble(),
                    divisions: math.max(1, math.min(1000, maxPts - info.minRedeem)),
                    label: tr('${_points.round()} poin'),
                    onChanged: (v) => setState(() => _points = v),
                  ),
                if (_usePoints && canPoints)
                  Text(tr('Pakai ${_points.round()} poin = potongan ${rupiah(disc)}'),
                      style: TextStyle(color: context.cs.primary, fontWeight: FontWeight.w600)),
              ]),
            ),

            const SectionTitle('Pembayaran', icon: Icons.payments_rounded),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: RadioGroupCompat(
                value: _pay,
                onChanged: (v) => setState(() => _pay = v),
                options: [
                  // QRIS hanya tersedia bila mata uang restoran Rupiah (IDR)
                  if (Provider.of<Session>(context, listen: false).info?.qrisAvailable ?? true)
                    ('online_qris', Icons.qr_code_2_rounded, 'QRIS / E-Wallet', 'GoPay, OVO, DANA, ShopeePay, m-banking'),
                  ('online_card', Icons.credit_card_rounded, 'Kartu Kredit / Debit', 'Visa, Mastercard, JCB'),
                  ('counter', Icons.point_of_sale_rounded, 'Bayar di Kasir', 'Tunai, kartu, atau QRIS saat ambil/selesai makan'),
                ],
              ),
            ),

            const SectionTitle('Ringkasan', icon: Icons.receipt_rounded),
            AppCard(
              child: Column(children: [
                KvRow('Subtotal', rupiah(sub)),
                if (vdisc > 0) KvRow('Voucher ${cart.voucherCode}', '-${rupiah(vdisc)}', color: const Color(0xFF16A34A)),
                if (disc > 0) KvRow('Potongan poin', '-${rupiah(disc)}', color: const Color(0xFF16A34A)),
                if (service > 0) KvRow('Service ${info?.servicePercent}%', rupiah(service)),
                if (tax > 0) KvRow('Pajak ${info?.taxPercent}%', rupiah(tax)),
                if (ongkir > 0) KvRow('Ongkir', rupiah(ongkir)),
                if (freeShip && fullOngkir > 0) KvRow('Ongkir', 'GRATIS', color: const Color(0xFF16A34A)),
                const Divider(height: 20),
                KvRow('Total', rupiah(total), bold: true, size: 18),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(tr('Perkiraan; total final dihitung server saat pesanan dibuat.'), style: TextStyle(fontSize: 11.5, color: context.muted)),
                ),
              ]),
            ),
          ]),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_rounded),
              label: _busy
                  ? Text(tr('Memproses...'), style: TextStyle(fontSize: 16))
                  : AnimatedNumber(value: total, duration: const Duration(milliseconds: 600), format: (v) => tr('Pesan Sekarang · ${rupiah(v)}'), style: const TextStyle(fontSize: 16)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pilihan radio sederhana (tanpa bergantung API Radio yang berubah antar versi Flutter).
class RadioGroupCompat extends StatelessWidget {
  const RadioGroupCompat({super.key, required this.value, required this.onChanged, required this.options});
  final String value;
  final ValueChanged<String> onChanged;
  final List<(String, IconData, String, String)> options;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (final o in options)
        ListTile(
          onTap: () => onChanged(o.$1),
          leading: Icon(o.$2, color: value == o.$1 ? context.cs.primary : context.muted),
          title: Text(tr(o.$3), style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(tr(o.$4), style: const TextStyle(fontSize: 12)),
          trailing: Icon(value == o.$1 ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: value == o.$1 ? context.cs.primary : context.muted),
        ),
    ]);
  }
}
