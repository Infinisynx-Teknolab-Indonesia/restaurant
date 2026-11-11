import 'package:flutter/material.dart';
import 'package:resto_core/resto_core.dart';

import 'home_shell.dart';
import 'order_detail_page.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});
  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  List<Order>? _orders;
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
      final o = await api.myOrders();
      if (mounted) setState(() { _orders = o; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Widget _list(List<Order> rows, String emptyText) {
    if (rows.isEmpty) {
      return ListView(children: [const SizedBox(height: 80), EmptyView(icon: Icons.receipt_long_outlined, text: emptyText)]);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (c, i) {
        final o = rows[i];
        return AppCard(
          onTap: () => Navigator.of(c).push(MaterialPageRoute(builder: (_) => OrderDetailPage(orderId: o.id))).then((_) => _load()),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(o.code, style: const TextStyle(fontWeight: FontWeight.w800))),
              StatusChip(orderStatus[o.status]!, small: true),
            ]),
            const SizedBox(height: 4),
            Text('${orderTypeLabel[o.orderType]}${o.tableNumber != null ? ' · Meja ${o.tableNumber}' : ''} · ${tanggalJam(o.createdAt)}',
                style: TextStyle(color: c.muted, fontSize: 12.5)),
            const SizedBox(height: 8),
            Text(o.activeItems.map((x) => '${x.qty}x ${x.name}').join(', '), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
            Row(children: [
              StatusChip(paymentStatus[o.paymentStatus]!, small: true),
              const Spacer(),
              Text(rupiah(o.total), style: TextStyle(fontWeight: FontWeight.w800, color: c.cs.primary, fontSize: 16)),
            ]),
          ]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _orders ?? [];
    final active = rows.where((o) => !o.isClosed).toList();
    final history = rows.where((o) => o.isClosed).toList();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('Pesanan Saya')),
          actions: const [Padding(padding: EdgeInsets.only(right: 16), child: LiveDot())],
          bottom: TabBar(tabs: [Tab(text: tr('Aktif (${active.length})')), Tab(text: tr('Riwayat'))]),
        ),
        body: _error != null && _orders == null
            ? ErrorView(message: _error!, onRetry: _load)
            : _orders == null
                ? const LoadingView()
                : TabBarView(children: [
                    PullRefresh(onRefresh: _load, child: _list(active, 'Belum ada pesanan aktif')),
                    PullRefresh(onRefresh: _load, child: _list(history, 'Belum ada riwayat pesanan')),
                  ]),
      ),
    );
  }
}
