import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:resto_core/resto_core.dart';

import 'receipt.dart';

/// Layar pembayaran kasir: Tunai / Kartu (EDC) / QRIS + member, poin, diskon, cetak struk.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.orderId});
  final int orderId;
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  Order? _o;
  String? _error;
  String _method = 'cash';
  final _cash = TextEditingController();
  final _ref = TextEditingController();
  Payment? _qris;
  bool _busy = false;
  Map<String, dynamic>? _member;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = context.read<Session>().realtime.events.listen((e) {
      if (e.event == 'order_paid' && e.data['id'] == widget.orderId && mounted && !_done) {
        _finished(null);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  bool _done = false;

  Future<void> _load() async {
    try {
      final o = await api.order(widget.orderId);
      if (!mounted) return;
      setState(() { _o = o; _error = null; });
      if (o.isPaid && !_done) _finished(null);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  int get _paid => Currency.active.parse(_cash.text);

  List<int> _quick(int total) {
    // nominal cepat sesuai pecahan uang: Rupiah 5rb–100rb, Dolar/Ringgit 1–100 (dalam sen)
    final idr = Currency.active.decimals == 0;
    final steps = idr ? [5000, 10000, 20000, 50000, 100000] : [100, 500, 1000, 2000, 5000, 10000];
    final s = <int>{total};
    for (final step in steps) {
      s.add(((total + step - 1) ~/ step) * step);
    }
    s.addAll(idr ? [100000, 200000] : [5000, 10000]);
    final l = s.where((v) => v >= total).toList()..sort();
    return l.take(6).toList();
  }

  Future<void> _attachMember() async {
    final phone = await inputDialog(context, 'Hubungkan Member', 'No. HP member', keyboard: TextInputType.phone, okText: 'Cari');
    if (phone == null || phone.isEmpty || !mounted) return;
    final r = await runSafe(context, () => api.patch('/api/orders/${widget.orderId}/member', {'phone': phone}));
    if (r == null || !mounted) return;
    setState(() { _member = Map<String, dynamic>.from(r['member']); _o = Order.fromJson(Map<String, dynamic>.from(r)); });
    showSnack(context, 'Member ${_member!['name']} terhubung (${_member!['points']} poin)');
  }

  Future<void> _voucher() async {
    final o = _o!;
    final ctl = TextEditingController(text: o.voucherCode);
    final res = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Voucher'), style: serifStyle(size: 22)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: ctl,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: deco(c, 'Kode voucher / dompet member / voucher cetak', icon: Icons.confirmation_number_outlined),
            onSubmitted: (v) => Navigator.pop(c, v.trim()),
          ),
          const SizedBox(height: 8),
          Text(tr('Voucher dari dompet member otomatis menghubungkan member ke pesanan. Voucher cetak bisa dipakai tanpa member. Semua syarat (minimal belanja, tanggal, jam, tier, kuota) dicek server.'),
              style: TextStyle(fontSize: 12, color: c.muted)),
        ]),
        actions: [
          if (o.hasVoucher)
            TextButton(onPressed: () => Navigator.pop(c, ''), child: Text(tr('Lepas Voucher'), style: TextStyle(color: Color(0xFFDC2626)))),
          TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('Batal'))),
          FilledButton(onPressed: () => Navigator.pop(c, ctl.text.trim()), child: Text(tr('Terapkan'))),
        ],
      ),
    );
    if (res == null || !mounted) return;
    if (res.isEmpty && !o.hasVoucher) return;
    final r = await runSafe(context, () => api.patch('/api/orders/${widget.orderId}/voucher', {'code': res}),
        success: res.isEmpty ? 'Voucher dilepas' : 'Voucher diterapkan');
    if (r != null && mounted) setState(() => _o = Order.fromJson(Map<String, dynamic>.from(r)));
  }

  Future<void> _discount() async {
    final o = _o!;
    final disc = TextEditingController(text: o.extraDiscount == 0 ? '' : Currency.active.input(o.extraDiscount));
    final pts = TextEditingController(text: o.pointsUsed == 0 ? '' : '${o.pointsUsed}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Diskon & Poin')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: disc, keyboardType: TextInputType.number, decoration: deco(c, '${tr('Diskon manual')} (${Currency.active.symbol})', icon: Icons.percent_rounded)),
          const SizedBox(height: 10),
          TextField(controller: pts, keyboardType: TextInputType.number, enabled: o.customerId != null,
              decoration: deco(c, o.customerId == null ? 'Poin (hubungkan member dulu)' : 'Tukar poin member', icon: Icons.stars_rounded)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Batal'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Terapkan'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final r = await runSafe(context, () => api.patch('/api/orders/${widget.orderId}/discount', {
          'extra_discount': Currency.active.parse(disc.text),
          'use_points': o.customerId == null ? null : (int.tryParse(pts.text) ?? 0),
        }));
    if (r != null && mounted) setState(() => _o = Order.fromJson(Map<String, dynamic>.from(r)));
  }

  Future<void> _pay() async {
    final o = _o!;
    if (_method == 'cash' && _paid < o.total) return showSnack(context, 'Uang diterima kurang dari total', error: true);
    if (_method == 'card' && _ref.text.trim().isEmpty) return showSnack(context, 'Isi kode approval / 4 digit kartu dari EDC', error: true);
    setState(() => _busy = true);
    try {
      final r = await api.post('/api/payments/checkout', {
        'order_id': o.id,
        'method': _method,
        'paid_amount': _method == 'cash' ? _paid : 0,
        'reference': _ref.text.trim(),
      });
      final p = Payment.fromJson(Map<String, dynamic>.from(r['payment']));
      if (!mounted) return;
      if (_method == 'qris') {
        setState(() => _qris = p);
      } else {
        _finished(p);
      }
    } catch (e) {
      if (mounted) showSnack(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmQris() async {
    if (!await confirmDialog(context, 'Konfirmasi QRIS', 'Pastikan dana ${rupiah(_qris!.amount)} sudah masuk di aplikasi merchant/bank Anda.', okText: 'Sudah Masuk')) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final r = await api.post('/api/payments/${_qris!.id}/confirm');
      if (mounted) _finished(Payment.fromJson(Map<String, dynamic>.from(r['payment'])));
    } catch (e) {
      if (mounted) showSnack(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finished(Payment? p) async {
    if (_done) return;
    _done = true;
    HapticFeedback.mediumImpact();
    final auto = await autoPrint();
    if (!mounted) return;
    if (auto) printBill(context, widget.orderId);
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        icon: const PopIn(child: Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 72)),
        title: Text(tr('Pembayaran Berhasil')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_o?.code ?? '', style: TextStyle(color: c.muted)),
          const SizedBox(height: 8),
          if (p != null) Text('${methodLabel[p.method] ?? p.method} · ${rupiah(p.amount)}', style: const TextStyle(fontSize: 16)),
          if (p != null && p.changeAmount > 0) ...[
            const SizedBox(height: 14),
            Text(tr('KEMBALIAN')),
            AnimatedNumber(value: p.changeAmount, format: rupiah, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Color(0xFF16A34A))),
          ],
        ]),
        actions: [
          TextButton.icon(onPressed: () => shareBill(c, widget.orderId), icon: const Icon(Icons.share_rounded), label: Text(tr('Bagikan'))),
          TextButton.icon(onPressed: () => printBill(c, widget.orderId), icon: const Icon(Icons.print_rounded), label: Text(tr('Cetak Struk'))),
          FilledButton(onPressed: () => Navigator.pop(c), child: Text(tr('Selesai'))),
        ],
      ),
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  // ---------------------------------------------------------------- UI
  Widget _bill(Order o) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(o.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          StatusChip(orderStatus[o.status]!, small: true),
        ]),
        Text('${o.code} · ${tanggalJam(o.createdAt)}${o.waiterName != null ? ' · ${o.waiterName}' : ''}',
            style: TextStyle(color: context.muted, fontSize: 12.5)),
        if (o.customerName.isNotEmpty) Text(tr('Pelanggan: ${o.customerName}'), style: TextStyle(color: context.muted, fontSize: 12.5)),
        const Divider(height: 22),
        for (final i in o.activeItems)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              SizedBox(width: 32, child: Text('${i.qty}x', style: const TextStyle(fontWeight: FontWeight.w700))),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(i.name),
                  if (i.editNote.isNotEmpty)
                    Text('✎ ${i.editNote}', style: const TextStyle(fontSize: 11, color: Color(0xFFD97706), fontWeight: FontWeight.w600)),
                ]),
              ),
              Text(uang(i.amount)),
              // Kasir boleh koreksi item yang sudah dikirim (wajib alasan, dilaporkan ke Admin)
              if (_qris == null && Provider.of<Session>(context, listen: false).user!.canEditOrder(o))
                IconButton(
                  tooltip: tr('Koreksi item'),
                  visualDensity: VisualDensity.compact,
                  onPressed: () async {
                    if (await showItemEditSheet(context, o, i)) _load();
                  },
                  icon: Icon(Icons.edit_rounded, size: 17, color: context.cs.primary),
                ),
            ]),
          ),
        const Divider(height: 22),
        KvRow('Subtotal', rupiah(o.subtotal)),
        if (o.voucherDiscount > 0) KvRow('Voucher ${o.voucherCode}', '-${rupiah(o.voucherDiscount)}', color: const Color(0xFF16A34A)),
        if (o.otherDiscount > 0) KvRow('Diskon${o.pointsUsed > 0 ? ' (${o.pointsUsed} poin)' : ''}', '-${rupiah(o.otherDiscount)}', color: const Color(0xFF16A34A)),
        if (o.service > 0) KvRow('Service', rupiah(o.service)),
        if (o.tax > 0) KvRow('Pajak PB1', rupiah(o.tax)),
        if (o.deliveryFee > 0) KvRow('Ongkir', rupiah(o.deliveryFee)),
        if (o.freeDelivery) const KvRow('Ongkir', 'GRATIS (voucher)', color: Color(0xFF16A34A)),
        const SizedBox(height: 6),
        KvRow('TOTAL', rupiah(o.total), bold: true, size: 22),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(
            onPressed: _qris != null ? null : _attachMember,
            icon: const Icon(Icons.card_membership_rounded),
            label: Text(tr(_member != null ? '${_member!['name']} · ${_member!['points']} poin' : (o.customerId != null ? 'Member terhubung' : 'Member'))),
          ),
          OutlinedButton.icon(
            onPressed: _qris != null ? null : _voucher,
            icon: const Icon(Icons.confirmation_number_outlined),
            label: Text(tr(o.hasVoucher ? 'Voucher ${o.voucherCode}' : 'Voucher')),
          ),
          OutlinedButton.icon(onPressed: _qris != null ? null : _discount, icon: const Icon(Icons.discount_rounded), label: Text(tr('Diskon / Poin'))),
          OutlinedButton.icon(onPressed: () => printBill(context, o.id), icon: const Icon(Icons.print_outlined), label: Text(tr('Cetak Bill'))),
        ]),
      ]),
    );
  }

  Widget _payPanel(Order o) {
    if (_qris != null) {
      return AppCard(
        child: Column(children: [
          Text(tr('Scan QRIS'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(rupiah(_qris!.amount), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: context.cs.primary)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: QrImageView(data: _qris!.qrString, size: 260, backgroundColor: Colors.white),
          ),
          const SizedBox(height: 10),
          Text(tr('Tunjukkan ke pelanggan. Setelah dana masuk, tekan konfirmasi.'), textAlign: TextAlign.center, style: TextStyle(color: context.muted)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity, height: 52,
            child: FilledButton.icon(onPressed: _busy ? null : _confirmQris, icon: const Icon(Icons.verified_rounded), label: Text(tr('Konfirmasi Pembayaran Masuk'))),
          ),
          TextButton(
            onPressed: () async {
              await runSafe(context, () => api.post('/api/payments/${_qris!.id}/cancel'));
              if (mounted) setState(() => _qris = null);
            },
            child: Text(tr('Ganti metode')),
          ),
        ]),
      );
    }
    final change = _paid - o.total;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'cash', label: Text(tr('Tunai')), icon: Icon(Icons.payments_rounded)),
            ButtonSegment(value: 'card', label: Text(tr('Kartu')), icon: Icon(Icons.credit_card_rounded)),
            // QRIS hanya untuk Rupiah
            if (Provider.of<Session>(context, listen: false).info?.qrisAvailable ?? true)
              ButtonSegment(value: 'qris', label: Text(tr('QRIS')), icon: Icon(Icons.qr_code_2_rounded)),
          ],
          selected: {_method},
          onSelectionChanged: (v) => setState(() => _method = v.first),
        ),
        const SizedBox(height: 16),
        if (_method == 'cash') ...[
          TextField(
            controller: _cash,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            onChanged: (_) => setState(() {}),
            decoration: deco(context, 'Uang diterima', icon: Icons.payments_outlined),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final v in _quick(o.total))
              ActionChip(
                label: Text(v == o.total ? tr('Uang pas') : uang(v)),
                onPressed: () => setState(() => _cash.text = Currency.active.input(v)),
              ),
          ]),
          const SizedBox(height: 14),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (change >= 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626)).withValues(alpha: .1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Text(tr(change >= 0 ? 'Kembalian' : 'Kurang'), style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(rupiah(change.abs()), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                  color: change >= 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626))),
            ]),
          ),
        ],
        if (_method == 'card') ...[
          Text(tr('Proses kartu di mesin EDC sebesar ${rupiah(o.total)}, lalu isi kode approval.'), style: TextStyle(color: context.muted)),
          const SizedBox(height: 12),
          TextField(controller: _ref, decoration: deco(context, 'Kode approval / 4 digit terakhir', icon: Icons.confirmation_number_outlined)),
        ],
        if (_method == 'qris')
          Text(tr('QRIS dinamis dengan nominal ${rupiah(o.total)} akan dibuat dari QRIS merchant di Pengaturan server.'),
              style: TextStyle(color: context.muted)),
        const SizedBox(height: 18),
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            onPressed: _busy ? null : _pay,
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(_method == 'qris' ? Icons.qr_code_2_rounded : Icons.check_circle_rounded),
            label: Text(tr(_method == 'qris' ? 'Tampilkan QRIS' : 'Bayar ${rupiah(o.total)}'), style: const TextStyle(fontSize: 17)),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final o = _o;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Pembayaran'))),
      body: _error != null && o == null
          ? ErrorView(message: _error!, onRetry: _load)
          : o == null
              ? const LoadingView()
              : context.isWide
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: PullRefresh(onRefresh: _load, child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: _bill(o)))),
                      SizedBox(width: 440, child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: _payPanel(o))),
                    ])
                  : PullRefresh(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: [_bill(o), const SizedBox(height: 14), _payPanel(o)])),
    );
  }
}
