import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:resto_core/resto_core.dart';

import 'order_editor_page.dart';
import 'payment_screen.dart';
import 'receipt.dart';
import 'shell.dart';

/// Semua pesanan aktif (dine-in, take away, online) + aksi cepat.
class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});
  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  List<Order>? _orders;
  String? _error;
  String _filter = 'all';

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
      if (mounted) setState(() { _orders = a; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  /// Kasir / Pengawas mengoreksi item pesanan yang sudah dikirim / dibayar.
  Future<void> _fixOrder(Order order) async {
    var o = order;
    final u = context.read<Session>().user!;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(tr('Koreksi ${o.title} · ${o.code}'), style: serifStyle(size: 20)),
            const SizedBox(height: 10),
            EditRuleBanner(user: u, order: o),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * .55),
              child: ListView(shrinkWrap: true, children: [
                for (final it in o.items)
                  SentItemRow(user: u, order: o, item: it, onChanged: () async {
                    final n = await api.order(o.id);
                    setSheet(() => o = n);
                  }),
              ]),
            ),
            const SizedBox(height: 8),
            KvRow('Total', rupiah(o.total), bold: true),
          ]),
        ),
      ),
    );
    _load();
  }

  Future<void> _actions(Order o) async {
    final u = context.read<Session>().user!;
    final act = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text('${o.title} · ${o.code}', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${rupiah(o.total)} · ${orderStatus[o.status]!.label}')),
          const Divider(height: 1),
          if (!o.isPaid && !o.isClosed)
            ListTile(leading: const Icon(Icons.add_circle_outline_rounded), title: Text(tr('Lihat / tambah item')), onTap: () => Navigator.pop(c, 'edit')),
          if (u.canEditOrder(o))
            ListTile(leading: const Icon(Icons.edit_note_rounded), title: Text(tr(o.isPaid ? 'Koreksi pesanan (Pengawas)' : 'Koreksi pesanan (Kasir)')),
                subtitle: Text(tr('Wajib alasan · dilaporkan ke Admin')), onTap: () => Navigator.pop(c, 'fix')),
          if (u.isCashier)
            ListTile(leading: const Icon(Icons.history_rounded), title: Text(tr('Riwayat Koreksi')), onTap: () => Navigator.pop(c, 'history')),
          if (o.items.any((i) => i.status == 'done'))
            ListTile(leading: const Icon(Icons.room_service_rounded), title: Text(tr('Tandai sudah diantar')), onTap: () => Navigator.pop(c, 'serve')),
          if (u.isCashier && !o.isPaid && o.status != 'cancelled')
            ListTile(leading: const Icon(Icons.point_of_sale_rounded), title: Text(tr('Bayar')), onTap: () => Navigator.pop(c, 'pay')),
          ListTile(leading: const Icon(Icons.print_rounded), title: Text(tr(o.isPaid ? 'Cetak struk' : 'Cetak bill')), onTap: () => Navigator.pop(c, 'print')),
          // batalkan pesanan = koreksi: setelah dikirim hanya Kasir, setelah dibayar hanya Pengawas
          if (u.canEditOrder(o) && !o.isClosed)
            ListTile(leading: const Icon(Icons.cancel_outlined, color: Color(0xFFDC2626)),
                title: Text(tr('Batalkan pesanan'), style: TextStyle(color: Color(0xFFDC2626))), onTap: () => Navigator.pop(c, 'cancel')),
        ]),
      ),
    );
    if (!mounted || act == null) return;
    switch (act) {
      case 'edit':
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderEditorPage(orderId: o.id)));
      case 'serve':
        await runSafe(context, () => api.patch('/api/orders/${o.id}/serve'), success: 'Ditandai sudah diantar');
      case 'pay':
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PaymentScreen(orderId: o.id)));
      case 'fix':
        await _fixOrder(o);
      case 'history':
        await showEditHistory(context, o);
      case 'print':
        await printBill(context, o.id);
      case 'cancel':
        final reason = await inputDialog(context, 'Batalkan ${o.code}', 'Alasan pembatalan (dilaporkan ke Admin)', okText: 'Batalkan');
        if (reason == null || !mounted) return;
        await runSafe(context, () => api.post('/api/orders/${o.id}/cancel', {'status': 'cancelled', 'reason': reason}), success: 'Pesanan dibatalkan');
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final all = _orders ?? [];
    final rows = switch (_filter) {
      'kitchen' => all.where((o) => o.status == 'confirmed' || o.status == 'preparing').toList(),
      'ready' => all.where((o) => o.status == 'ready').toList(),
      'online' => all.where((o) => o.source == 'customer_app').toList(),
      'unpaid' => all.where((o) => !o.isPaid).toList(),
      _ => all,
    };
    return Scaffold(
      appBar: AppBar(title: Text(tr('Pesanan Aktif')), actions: [
        const LiveDot(),
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
      ]),
      body: _error != null && _orders == null
          ? ErrorView(message: _error!, onRetry: _load)
          : _orders == null
              ? const LoadingView()
              : Column(children: [
                  SizedBox(
                    height: 54,
                    child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(12, 8, 12, 6), children: [
                      for (final f in const [('all', 'Semua'), ('kitchen', 'Di dapur'), ('ready', 'Siap'), ('online', 'Online'), ('unpaid', 'Belum bayar')])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(label: Text(tr(f.$2)), selected: _filter == f.$1, showCheckmark: false, onSelected: (_) => setState(() => _filter = f.$1)),
                        ),
                    ]),
                  ),
                  Expanded(
                    child: PullRefresh(
                      onRefresh: _load,
                      child: rows.isEmpty
                          ? ListView(children: [SizedBox(height: 100), EmptyView(icon: Icons.receipt_long_outlined, text: tr('Tidak ada pesanan'))])
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                              itemCount: rows.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (c, i) {
                                final o = rows[i];
                                final done = o.activeItems.where((x) => x.status == 'done' || x.status == 'served').length;
                                return AppCard(
                                  onTap: () => _actions(o),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Row(children: [
                                      Expanded(child: Text(o.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                                      if (o.source == 'customer_app') const Padding(padding: EdgeInsets.only(right: 6), child: Pill('Online', icon: Icons.phone_iphone_rounded)),
                                      StatusChip(orderStatus[o.status]!, small: true),
                                    ]),
                                    const SizedBox(height: 4),
                                    Text('${o.code} · ${sejak(o.createdAt)}${o.waiterName != null ? ' · ${o.waiterName}' : ''}',
                                        style: TextStyle(color: c.muted, fontSize: 12)),
                                    const SizedBox(height: 8),
                                    Text(o.activeItems.map((x) => '${x.qty}x ${x.name}').join(', '), maxLines: 2, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 10),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(99),
                                      child: LinearProgressIndicator(
                                        minHeight: 6,
                                        value: o.activeItems.isEmpty ? 0 : done / o.activeItems.length,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(children: [
                                      StatusChip(paymentStatus[o.paymentStatus]!, small: true),
                                      const Spacer(),
                                      Text(rupiah(o.total), style: TextStyle(fontWeight: FontWeight.w800, color: c.cs.primary)),
                                    ]),
                                  ]),
                                );
                              },
                            ),
                    ),
                  ),
                ]),
    );
  }
}
