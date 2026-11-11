import 'package:flutter/material.dart';
import 'package:resto_core/resto_core.dart';

import 'order_editor_page.dart';
import 'payment_screen.dart';
import 'shell.dart';

/// Antrian tagihan yang belum dibayar.
class CashierPage extends StatefulWidget {
  const CashierPage({super.key});
  @override
  State<CashierPage> createState() => _CashierPageState();
}

class _CashierPageState extends State<CashierPage> {
  List<Order>? _orders;
  String? _error;
  String _q = '';
  String _type = '';

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
      final a = await api.activeOrders();
      if (mounted) {
        setState(() {
          _orders = a.where((o) => !o.isPaid && o.status != 'cancelled').toList();
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _openPay(Order o) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PaymentScreen(orderId: o.id)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final rows = (_orders ?? []).where((o) {
      if (_type.isNotEmpty && o.orderType != _type) return false;
      if (_q.isEmpty) return true;
      final q = _q.toLowerCase();
      return o.code.toLowerCase().contains(q) || o.customerName.toLowerCase().contains(q) || (o.tableNumber ?? '').contains(q);
    }).toList();
    final total = rows.fold<int>(0, (s, o) => s + o.total);
    final cols = (MediaQuery.sizeOf(context).width / 340).floor().clamp(1, 4);

    return Scaffold(
      appBar: AppBar(title: Text(tr('Kasir')), actions: [
        const LiveDot(),
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OrderEditorPage()));
          _load();
        },
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: Text(tr('Transaksi Baru')),
      ),
      body: _error != null && _orders == null
          ? ErrorView(message: _error!, onRetry: _load)
          : _orders == null
              ? const LoadingView()
              : PullRefresh(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), children: [
                    Row(children: [
                      Expanded(child: StatTile(icon: Icons.receipt_long_rounded, label: tr('Belum dibayar'), value: '${rows.length} tagihan')),
                      const SizedBox(width: 12),
                      Expanded(child: StatTile(icon: Icons.payments_rounded, label: tr('Nilai tagihan'), value: rupiah(total))),
                    ]),
                    const SizedBox(height: 12),
                    TextField(onChanged: (v) => setState(() => _q = v),
                        decoration: deco(context, 'Cari kode / meja / nama', icon: Icons.search_rounded)),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, children: [
                      for (final t in const [('', 'Semua'), ('dine_in', 'Dine In'), ('takeaway', 'Take Away'), ('delivery', 'Delivery')])
                        ChoiceChip(label: Text(tr(t.$2)), selected: _type == t.$1, showCheckmark: false, onSelected: (_) => setState(() => _type = t.$1)),
                    ]),
                    const SizedBox(height: 12),
                    if (rows.isEmpty)
                      EmptyView(icon: Icons.task_alt_rounded, text: tr('Semua tagihan sudah dibayar 🎉'))
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: rows.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 170),
                        itemBuilder: (c, i) {
                          final o = rows[i];
                          return AppCard(
                            onTap: () => _openPay(o),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Icon(o.tableNumber != null ? Icons.table_restaurant_rounded : Icons.shopping_bag_rounded, color: c.cs.primary),
                                const SizedBox(width: 8),
                                Expanded(child: Text(o.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                                StatusChip(orderStatus[o.status]!, small: true),
                              ]),
                              const SizedBox(height: 4),
                              Text('${o.code} · ${sejak(o.createdAt)}', style: TextStyle(color: c.muted, fontSize: 12)),
                              if (o.customerName.isNotEmpty || o.source == 'customer_app')
                                Text('${o.source == 'customer_app' ? '📱 ' : ''}${o.customerName}', style: TextStyle(color: c.muted, fontSize: 12)),
                              const Spacer(),
                              Text(tr('${o.activeItems.length} item'), style: TextStyle(color: c.muted, fontSize: 12)),
                              Row(children: [
                                Expanded(child: Text(rupiah(o.total), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.cs.primary))),
                                FilledButton(onPressed: () => _openPay(o), child: Text(tr('Bayar'))),
                              ]),
                            ]),
                          );
                        },
                      ),
                  ]),
                ),
    );
  }
}
