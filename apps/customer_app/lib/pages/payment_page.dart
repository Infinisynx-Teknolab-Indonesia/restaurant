import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:resto_core/resto_core.dart';
import 'package:url_launcher/url_launcher.dart';

import 'order_detail_page.dart';

/// Pembayaran online: QRIS (tampil QR) atau Kartu (buka halaman payment gateway).
class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key, required this.order, required this.method});
  final Order order;
  final String method; // qris | card
  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  Payment? _p;
  String? _error;
  Timer? _poll;
  StreamSubscription? _sub;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _create();
    _sub = context.read<Session>().realtime.events.listen((e) {
      if ((e.event == 'payment_paid' && e.data['order_id'] == widget.order.id) ||
          (e.event == 'order_paid' && e.data['id'] == widget.order.id)) {
        _success();
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() { _error = null; _p = null; });
    try {
      final j = await api.post('/api/payments/online', {'order_id': widget.order.id, 'method': widget.method});
      final p = Payment.fromJson(Map<String, dynamic>.from(j));
      if (!mounted) return;
      setState(() => _p = p);
      _poll?.cancel();
      _poll = Timer.periodic(const Duration(seconds: 4), (_) => _check());
      if (widget.method == 'card' && p.payUrl.isNotEmpty) _open(p.payUrl);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _check() async {
    if (_p == null || _done) return;
    try {
      final p = await api.payment(_p!.id);
      if (p.isPaid) _success();
    } catch (_) {}
  }

  void _success() {
    if (_done || !mounted) return;
    _done = true;
    _poll?.cancel();
    context.read<Session>().refreshMe();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        icon: const PopIn(child: Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 64)),
        title: Text(tr('Pembayaran Berhasil')),
        content: Text(tr('Pesanan Anda sudah diteruskan ke dapur.')),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(c);
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => OrderDetailPage(orderId: widget.order.id)));
            },
            child: Text(tr('Lihat Pesanan')),
          ),
        ],
      ),
    );
  }

  Future<void> _open(String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) showSnack(context, 'Tidak bisa membuka halaman pembayaran', error: true);
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return Scaffold(
      appBar: AppBar(title: Text(tr(widget.method == 'qris' ? 'Bayar dengan QRIS' : 'Bayar dengan Kartu'))),
      body: _error != null
          ? ErrorView(message: _error!, onRetry: _create)
          : p == null
              ? const LoadingView()
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: PullRefresh(
                      onRefresh: _check,
                      child: ListView(padding: const EdgeInsets.all(20), children: [
                      AppCard(
                        child: Column(children: [
                          Text(tr('Pesanan ${widget.order.code}'), style: TextStyle(color: context.muted)),
                          const SizedBox(height: 6),
                          Text(rupiah(p.amount), style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: context.cs.primary)),
                          const SizedBox(height: 18),
                          if (p.qrString.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: context.borderColor)),
                              child: QrImageView(data: p.qrString, size: 240, backgroundColor: Colors.white),
                            ),
                            const SizedBox(height: 12),
                            Text(tr('Scan dengan aplikasi e-wallet atau m-banking'), textAlign: TextAlign.center),
                          ] else
                            const Icon(Icons.credit_card_rounded, size: 80),
                          const SizedBox(height: 16),
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            const SizedBox(width: 10),
                            Text(tr('Menunggu pembayaran...'), style: TextStyle(color: context.muted)),
                          ]),
                        ]),
                      ),
                      const SizedBox(height: 16),
                      if (p.payUrl.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () => _open(p.payUrl),
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: Text(tr(widget.method == 'card' ? 'Buka Halaman Pembayaran Kartu' : 'Bayar lewat halaman web')),
                        ),
                      const SizedBox(height: 8),
                      TextButton.icon(onPressed: _check, icon: const Icon(Icons.refresh_rounded), label: Text(tr('Saya sudah bayar, cek status'))),
                      if (p.gateway == 'simulator')
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(tr('Mode simulator aktif (testing). Buka halaman web lalu tekan "Bayar Sekarang".'),
                              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: context.muted)),
                        ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () => Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => OrderDetailPage(orderId: widget.order.id))),
                        child: Text(tr('Bayar nanti')),
                      ),
                    ]),
                    ),
                  ),
                ),
    );
  }
}
