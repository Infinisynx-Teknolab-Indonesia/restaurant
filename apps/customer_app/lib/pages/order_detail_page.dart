import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:resto_core/resto_core.dart';

import 'payment_page.dart';

class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({super.key, required this.orderId});
  final int orderId;
  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  Order? _o;
  String? _error;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = context.read<Session>().realtime.events.listen((e) {
      if (e.data['id'] == widget.orderId || e.data['order_id'] == widget.orderId) _load();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final o = await api.order(widget.orderId);
      if (mounted) setState(() { _o = o; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _cancel() async {
    if (!await confirmDialog(context, 'Batalkan pesanan?', 'Poin yang dipakai akan dikembalikan.', okText: 'Batalkan', danger: true)) return;
    if (!mounted) return;
    await runSafe(context, () => api.post('/api/orders/${widget.orderId}/cancel', {'status': 'cancelled', 'reason': 'Dibatalkan customer'}),
        success: 'Pesanan dibatalkan');
    _load();
  }

  Future<void> _showBill() async {
    final txt = await runSafe(context, () => api.get('/api/orders/${widget.orderId}/bill.txt', query: {'width': 34}));
    if (txt == null || !mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
        child: Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Text('$txt', style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, color: Colors.black)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final o = _o;
    return Scaffold(
      appBar: AppBar(title: Text(tr(o?.code ?? 'Pesanan')), actions: [
        if (o != null) IconButton(onPressed: _showBill, icon: const Icon(Icons.receipt_long_rounded), tooltip: tr('Struk')),
      ]),
      body: _error != null && o == null
          ? ErrorView(message: _error!, onRetry: _load)
          : o == null
              ? const LoadingView()
              : PullRefresh(
                  onRefresh: _load,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: ListView(padding: const EdgeInsets.all(16), children: [
                        _StatusHeader(order: o),
                        const SizedBox(height: 14),
                        if (o.status != 'cancelled') _Timeline(order: o),
                        const SectionTitle('Detail', icon: Icons.info_outline_rounded),
                        AppCard(
                          child: Column(children: [
                            KvRow('Tipe', orderTypeLabel[o.orderType] ?? o.orderType),
                            if (o.tableNumber != null) KvRow('Meja', o.tableNumber!),
                            if (o.deliveryAddress.isNotEmpty) KvRow('Alamat', o.deliveryAddress),
                            KvRow('Waktu', tanggalJam(o.createdAt)),
                            KvRow('Pembayaran', paymentStatus[o.paymentStatus]?.label ?? o.paymentStatus),
                            if (o.notes.isNotEmpty) KvRow('Catatan', o.notes),
                          ]),
                        ),
                        const SectionTitle('Item', icon: Icons.restaurant_menu_rounded),
                        AppCard(
                          child: Column(children: [
                            for (final i in o.items)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('${i.qty}x', style: TextStyle(fontWeight: FontWeight.w700, color: context.cs.primary)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(i.name, style: TextStyle(fontWeight: FontWeight.w600,
                                          decoration: i.isVoid ? TextDecoration.lineThrough : null)),
                                      if (i.notes.isNotEmpty) Text('* ${i.notes}', style: TextStyle(fontSize: 12, color: context.muted)),
                                      const SizedBox(height: 4),
                                      StatusChip(itemStatus[i.status]!, small: true),
                                    ]),
                                  ),
                                  Text(rupiah(i.amount)),
                                ]),
                              ),
                            const Divider(height: 24),
                            KvRow('Subtotal', rupiah(o.subtotal)),
                            if (o.voucherDiscount > 0) KvRow('Voucher ${o.voucherCode}', '-${rupiah(o.voucherDiscount)}', color: const Color(0xFF16A34A)),
                            if (o.otherDiscount > 0) KvRow('Diskon / poin', '-${rupiah(o.otherDiscount)}', color: const Color(0xFF16A34A)),
                            if (o.service > 0) KvRow('Service', rupiah(o.service)),
                            if (o.tax > 0) KvRow('Pajak', rupiah(o.tax)),
                            if (o.deliveryFee > 0) KvRow('Ongkir', rupiah(o.deliveryFee)),
                            if (o.freeDelivery) const KvRow('Ongkir', 'GRATIS (voucher)', color: Color(0xFF16A34A)),
                            KvRow('Total', rupiah(o.total), bold: true, size: 18),
                            if (o.pointsEarned > 0)
                              Padding(padding: const EdgeInsets.only(top: 8),
                                  child: Pill('+${o.pointsEarned} poin didapat', icon: Icons.stars_rounded, color: const Color(0xFFD97706))),
                          ]),
                        ),
                        const SizedBox(height: 20),
                        if (!o.isPaid && !o.isClosed) ...[
                          FilledButton.icon(
                            onPressed: () => Navigator.of(context).pushReplacement(
                                MaterialPageRoute(builder: (_) => PaymentPage(order: o, method: 'qris'))),
                            icon: const Icon(Icons.qr_code_2_rounded),
                            label: Text(tr('Bayar Sekarang (QRIS)')),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).pushReplacement(
                                MaterialPageRoute(builder: (_) => PaymentPage(order: o, method: 'card'))),
                            icon: const Icon(Icons.credit_card_rounded),
                            label: Text(tr('Bayar dengan Kartu')),
                          ),
                        ],
                        if (!o.isPaid && !o.isClosed && o.items.every((i) => i.status == 'queued' || i.isVoid))
                          TextButton.icon(
                            onPressed: _cancel,
                            icon: const Icon(Icons.cancel_outlined, color: Color(0xFFDC2626)),
                            label: Text(tr('Batalkan Pesanan'), style: TextStyle(color: Color(0xFFDC2626))),
                          ),
                      ]),
                    ),
                  ),
                ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.order});
  final Order order;
  @override
  Widget build(BuildContext context) {
    final st = orderStatus[order.status]!;
    return AppCard(
      color: st.color.withValues(alpha: .08),
      borderColor: st.color.withValues(alpha: .4),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(color: st.color, borderRadius: BorderRadius.circular(14)),
          child: Icon(st.icon, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(st.label, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: st.color)),
            Text(tr(_hint(order)), style: TextStyle(color: context.muted, fontSize: 13)),
          ]),
        ),
      ]),
    );
  }

  String _hint(Order o) {
    switch (o.status) {
      case 'pending':
        return 'Selesaikan pembayaran agar pesanan diproses';
      case 'confirmed':
        return 'Pesanan diterima, menunggu dapur';
      case 'preparing':
        return 'Dapur sedang menyiapkan pesanan Anda';
      case 'ready':
        return o.orderType == 'takeaway' ? 'Silakan ambil di kasir' : 'Pesanan segera diantar';
      case 'served':
        return o.isPaid ? 'Selamat menikmati!' : 'Silakan bayar di kasir';
      case 'completed':
        return 'Terima kasih sudah berbelanja';
      default:
        return '';
    }
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.order});
  final Order order;
  @override
  Widget build(BuildContext context) {
    const steps = ['confirmed', 'preparing', 'ready', 'served', 'completed'];
    const labels = ['Diterima', 'Dimasak', 'Siap', 'Diantar', 'Selesai'];
    final idx = steps.indexOf(order.status);
    return AppCard(
      child: Row(children: [
        for (var i = 0; i < steps.length; i++) ...[
          Expanded(
            child: Column(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 30, height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= idx ? context.cs.primary : context.borderColor,
                ),
                child: Icon(i < idx ? Icons.check_rounded : orderStatus[steps[i]]!.icon, size: 16,
                    color: i <= idx ? Colors.white : context.muted),
              ),
              const SizedBox(height: 6),
              Text(labels[i], style: TextStyle(fontSize: 11, fontWeight: i == idx ? FontWeight.w700 : FontWeight.w400)),
            ]),
          ),
        ],
      ]),
    );
  }
}
