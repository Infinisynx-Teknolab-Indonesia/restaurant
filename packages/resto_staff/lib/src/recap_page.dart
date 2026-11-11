import 'package:flutter/material.dart';
import 'package:resto_core/resto_core.dart';

import 'receipt.dart';
import 'shell.dart';

/// Rekap kasir hari ini (tutup shift).
class RecapPage extends StatefulWidget {
  const RecapPage({super.key});
  @override
  State<RecapPage> createState() => _RecapPageState();
}

class _RecapPageState extends State<RecapPage> {
  Map<String, dynamic>? _sum;
  List<Payment> _pays = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    restoTick.addListener(_load);
  }

  @override
  void dispose() {
    restoTick.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final r = await Future.wait([
        api.get('/api/payments-summary/today'),
        api.get('/api/payments', query: {'date_from': today, 'date_to': today, 'status': 'paid', 'size': 200}),
      ]);
      if (!mounted) return;
      setState(() {
        _sum = Map<String, dynamic>.from(r[0]);
        _pays = ((r[1]['items'] ?? []) as List).map((e) => Payment.fromJson(e)).toList();
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _sum;
    final by = s == null ? <String, dynamic>{} : Map<String, dynamic>.from(s['by_method'] ?? {});
    int amt(String m) => by[m] == null ? 0 : (by[m]['amount'] as num).toInt();
    int cnt(String m) => by[m] == null ? 0 : (by[m]['count'] as num).toInt();
    final cols = MediaQuery.sizeOf(context).width > 700 ? 4 : 2;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Rekap Hari Ini')), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))]),
      body: _error != null && s == null
          ? ErrorView(message: _error!, onRetry: _load)
          : s == null
              ? const LoadingView()
              : PullRefresh(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    AppCard(
                      color: context.cs.primary,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(tr('Total penerimaan ${tanggal(DateTime.now().toIso8601String())}'), style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 4),
                        AnimatedNumber(value: (s['total'] as num?) ?? 0, format: rupiah, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
                        Text(tr('${s['count']} transaksi'), style: const TextStyle(color: Colors.white70)),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: cols,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 2.1,
                      children: [
                        StatTile(icon: Icons.payments_rounded, label: tr('Tunai'), value: rupiah(amt('cash')), sub: '${cnt('cash')} trx'),
                        StatTile(icon: Icons.credit_card_rounded, label: tr('Kartu'), value: rupiah(amt('card')), sub: '${cnt('card')} trx'),
                        StatTile(icon: Icons.qr_code_2_rounded, label: tr('QRIS'), value: rupiah(amt('qris')), sub: '${cnt('qris')} trx'),
                        StatTile(icon: Icons.phone_iphone_rounded, label: tr('Online'), value: rupiah(amt('online')), sub: '${cnt('online')} trx'),
                      ],
                    ),
                    const SectionTitle('Transaksi', icon: Icons.receipt_rounded),
                    if (_pays.isEmpty) EmptyView(icon: Icons.receipt_outlined, text: tr('Belum ada transaksi hari ini')),
                    for (final p in _pays)
                      AppCard(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        onTap: () => printBill(context, p.orderId),
                        child: Row(children: [
                          Icon(switch (p.method) {
                            'cash' => Icons.payments_rounded,
                            'card' => Icons.credit_card_rounded,
                            _ => Icons.qr_code_2_rounded,
                          }, color: context.cs.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(p.orderCode ?? '#${p.orderId}', style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text('${methodLabel[p.method] ?? p.method}${p.reference.isNotEmpty ? ' · ${p.reference}' : ''}',
                                  style: TextStyle(fontSize: 12, color: context.muted)),
                            ]),
                          ),
                          Text(rupiah(p.amount), style: const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(width: 6),
                          Icon(Icons.print_outlined, size: 18, color: context.muted),
                        ]),
                      ),
                  ]),
                ),
    );
  }
}
