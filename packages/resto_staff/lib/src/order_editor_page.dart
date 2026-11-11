import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:resto_core/resto_core.dart';

import 'payment_screen.dart';
import 'shell.dart';

class _Draft {
  final MenuItem item;
  int qty;
  String notes;
  _Draft(this.item, this.qty, this.notes);
}

/// Waiter mengambil pesanan: pilih menu → kirim ke dapur.
/// Bisa untuk meja (dine-in) atau take away; juga menambah item ke pesanan meja yang masih terbuka.
class OrderEditorPage extends StatefulWidget {
  const OrderEditorPage({super.key, this.table, this.orderId});
  final DiningTable? table;
  final int? orderId;
  @override
  State<OrderEditorPage> createState() => _OrderEditorPageState();
}

class _OrderEditorPageState extends State<OrderEditorPage> {
  List<MenuCategory> _cats = [];
  Order? _order;
  bool _loading = true, _sending = false;
  String? _error;
  int _cat = 0;
  String _q = '';
  final Map<int, _Draft> _draft = {};
  final _customer = TextEditingController();
  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    restoTick.addListener(_reloadOrder);
    menuTick.addListener(_load);
  }

  @override
  void dispose() {
    restoTick.removeListener(_reloadOrder);
    menuTick.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final cats = await api.menu();
      Order? o;
      final id = _order?.id ?? widget.orderId;
      if (id != null) o = await api.order(id);
      if (!mounted) return;
      setState(() { _cats = cats; _order = o; _loading = false; _error = null; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  Future<void> _reloadOrder() async {
    final id = _order?.id;
    if (id == null) return;
    try {
      final o = await api.order(id);
      if (mounted) setState(() => _order = o);
    } catch (_) {}
  }

  int get _draftCount => _draft.values.fold(0, (s, d) => s + d.qty);
  int get _draftTotal => _draft.values.fold(0, (s, d) => s + d.item.price * d.qty);

  void _add(MenuItem m) {
    setState(() {
      final d = _draft[m.id];
      if (d == null) {
        _draft[m.id] = _Draft(m, 1, '');
      } else {
        d.qty++;
      }
    });
  }

  /// Langkah 1: waiter cek ulang pesanan (masih bisa ubah jumlah, catatan, hapus) sebelum benar-benar dikirim.
  Future<void> _send() async {
    if (_draft.isEmpty) return showSnack(context, 'Pilih menu dulu', error: true);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(builder: (c, setSheet) {
        void upd(VoidCallback f) {
          setSheet(f);
          setState(() {});
        }
        final title = tr(widget.table != null ? 'Meja ${widget.table!.number}' : (_order?.title ?? 'Take Away'));
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(c).bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Icon(Icons.fact_check_rounded),
              const SizedBox(width: 8),
              Expanded(child: Text(tr('Cek Ulang Pesanan'), style: serifStyle(size: 20))),
              Pill(title, color: c.cs.primary),
            ]),
            const SizedBox(height: 6),
            Text(tr('Periksa lagi bersama tamu. Setelah dikirim, perubahan hanya bisa dilakukan Kasir.'),
                style: TextStyle(fontSize: 12.5, color: c.muted)),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * .45),
              child: ListView(shrinkWrap: true, children: [
                for (final d in _draft.values.toList())
                  FadeSlideIn(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: c.borderColor)),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(d.item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(rupiah(d.item.price * d.qty), style: TextStyle(fontSize: 12, color: c.muted)),
                            InkWell(
                              onTap: () async {
                                final n = await inputDialog(c, 'Catatan ${d.item.name}', 'Catatan untuk dapur', initial: d.notes);
                                if (n != null) upd(() => d.notes = n);
                              },
                              child: Text(tr(d.notes.isEmpty ? '+ catatan' : '* ${d.notes}'), style: TextStyle(fontSize: 12, color: c.cs.primary)),
                            ),
                          ]),
                        ),
                        QtyStepper(qty: d.qty, onChanged: (v) => upd(() {
                          if (v <= 0) {
                            _draft.remove(d.item.id);
                          } else {
                            d.qty = v;
                          }
                        })),
                        IconButton(
                          tooltip: tr('Hapus'),
                          onPressed: () => upd(() => _draft.remove(d.item.id)),
                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
                        ),
                      ]),
                    ),
                  ),
              ]),
            ),
            if (_draft.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(tr('Pesanan kosong'), textAlign: TextAlign.center, style: TextStyle(color: c.muted))),
            const Divider(height: 20),
            Row(children: [
              Expanded(child: Text(tr('$_draftCount item'), style: TextStyle(color: c.muted))),
              AnimatedNumber(value: _draftTotal, format: rupiah, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(c, false),
                  icon: const Icon(Icons.edit_rounded),
                  label: Text(tr('Ubah Lagi')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _draft.isEmpty ? null : () => Navigator.pop(c, true),
                  icon: const Icon(Icons.send_rounded),
                  label: Text(tr('Pesan & Kirim ke Dapur')),
                ),
              ),
            ]),
          ]),
        );
      }),
    );
    if (ok == true && mounted) await _doSend();
  }

  /// Langkah 2: kirim ke dapur & kasir. Setelah ini waiter tidak bisa mengubah item yang sudah dikirim.
  Future<void> _doSend() async {
    if (_draft.isEmpty) return;
    setState(() => _sending = true);
    final lines = _draft.values.map((d) => {'menu_item_id': d.item.id, 'qty': d.qty, 'notes': d.notes}).toList();
    try {
      final o = _order;
      Order res;
      if (o != null && !o.isPaid && !o.isClosed) {
        res = Order.fromJson(Map<String, dynamic>.from(await api.post('/api/orders/${o.id}/items', lines)));
      } else {
        res = await api.createOrder({
          'order_type': widget.table == null ? 'takeaway' : 'dine_in',
          'table_id': widget.table?.id,
          'items': lines,
          'customer_name': _customer.text.trim(),
          'notes': _notes.text.trim(),
        });
      }
      if (!mounted) return;
      setState(() { _order = res; _draft.clear(); });
      showSnack(context, '✓ Pesanan dikirim ke dapur');
    } catch (e) {
      if (mounted) showSnack(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _serve() async {
    await runSafe(context, () => api.patch('/api/orders/${_order!.id}/serve'), success: 'Ditandai sudah diantar');
    _reloadOrder();
  }

  Future<void> _moveTable() async {
    final tables = await runSafe(context, () => api.tables());
    if (tables == null || !mounted) return;
    final free = tables.where((t) => t.status == 'available').toList();
    final picked = await showDialog<DiningTable>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text(tr('Pindah ke meja')),
        children: [
          if (free.isEmpty) Padding(padding: EdgeInsets.all(16), child: Text(tr('Tidak ada meja kosong'))),
          for (final t in free)
            SimpleDialogOption(onPressed: () => Navigator.pop(c, t), child: Text(tr('Meja ${t.number} · ${t.area} · ${t.seats} kursi'))),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    await runSafe(context, () => api.post('/api/orders/${_order!.id}/move-table', {'table_id': picked.id}), success: 'Pindah ke meja ${picked.number}');
    _reloadOrder();
  }

  // ------------------------------------------------------------ UI menu
  Widget _menu() {
    final items = _cats.expand((c) => c.items).where((i) =>
        (_cat == 0 || i.categoryId == _cat) && (_q.isEmpty || i.name.toLowerCase().contains(_q.toLowerCase()))).toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: TextField(onChanged: (v) => setState(() => _q = v), decoration: deco(context, 'Cari menu', icon: Icons.search_rounded)),
      ),
      SizedBox(
        height: 50,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), children: [
          Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(tr('Semua')), selected: _cat == 0, showCheckmark: false, onSelected: (_) => setState(() => _cat = 0))),
          for (final c in _cats)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(avatar: Icon(categoryIcon(c.icon), size: 16), label: Text(c.name), selected: _cat == c.id,
                  showCheckmark: false, onSelected: (_) => setState(() => _cat = c.id)),
            ),
        ]),
      ),
      Expanded(
        child: LayoutBuilder(builder: (c, box) {
          final cols = (box.maxWidth / 170).floor().clamp(2, 6);
          return PullRefresh(
            onRefresh: _load,
            child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
            itemCount: items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.25),
            itemBuilder: (c, i) {
              final m = items[i];
              final q = _draft[m.id]?.qty ?? 0;
              return AppCard(
                onTap: () => _add(m),
                padding: const EdgeInsets.all(12),
                borderColor: q > 0 ? c.cs.primary : null,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(categoryIcon(_cats.firstWhere((x) => x.id == m.categoryId, orElse: () => _cats.first).icon), color: c.cs.primary, size: 22),
                    const Spacer(),
                    if (q > 0) CircleAvatar(radius: 12, backgroundColor: c.cs.primary,
                        child: Text('$q', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                  ]),
                  const Spacer(),
                  Text(m.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.2)),
                  const SizedBox(height: 4),
                  Text(rupiah(m.price), style: TextStyle(color: c.cs.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                ]),
              );
            },
          ),
          );
        }),
      ),
    ]);
  }

  // ------------------------------------------------------------ UI panel pesanan
  Widget _panel() {
    final o = _order;
    final user = context.watch<Session>().user!;
    return Column(children: [
      Expanded(
        child: PullRefresh(
          onRefresh: _load,
          child: ListView(padding: const EdgeInsets.all(14), children: [
          if (o != null) ...[
            Row(children: [
              Expanded(child: Text(o.code, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
              StatusChip(orderStatus[o.status]!, small: true),
              const SizedBox(width: 6),
              StatusChip(paymentStatus[o.paymentStatus]!, small: true),
            ]),
            const SizedBox(height: 10),
            EditRuleBanner(user: user, order: o),
            for (final it in o.items) SentItemRow(user: user, order: o, item: it, onChanged: _reloadOrder),
            KvRow('Total pesanan', rupiah(o.total), bold: true),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (o.status == 'ready')
                FilledButton.tonalIcon(onPressed: _serve, icon: const Icon(Icons.room_service_rounded), label: Text(tr('Sudah Diantar'))),
              if (user.isCashier)
                OutlinedButton.icon(onPressed: () => showEditHistory(context, o), icon: const Icon(Icons.history_rounded), label: Text(tr('Riwayat Koreksi'))),
              if (o.orderType == 'dine_in' && !o.isClosed)
                OutlinedButton.icon(onPressed: _moveTable, icon: const Icon(Icons.swap_horiz_rounded), label: Text(tr('Pindah Meja'))),
              if (user.isCashier && !o.isPaid && !o.isClosed)
                FilledButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PaymentScreen(orderId: o.id)));
                    _reloadOrder();
                  },
                  icon: const Icon(Icons.point_of_sale_rounded),
                  label: Text(tr('Bayar')),
                ),
            ]),
            const Divider(height: 28),
          ],
          Text(tr(o == null ? 'Pesanan baru' : 'Tambahan pesanan'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (o == null && widget.table == null) ...[
            TextField(controller: _customer, decoration: deco(context, 'Nama pelanggan', icon: Icons.person_outline_rounded)),
            const SizedBox(height: 8),
          ],
          if (_draft.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(tr('Ketuk menu untuk menambahkan'), textAlign: TextAlign.center, style: TextStyle(color: context.muted)),
            ),
          for (final d in _draft.values.toList())
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d.item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    InkWell(
                      onTap: () async {
                        final n = await inputDialog(context, 'Catatan ${d.item.name}', 'Catatan untuk dapur', initial: d.notes);
                        if (n != null) setState(() => d.notes = n);
                      },
                      child: Text(tr(d.notes.isEmpty ? '+ catatan' : '* ${d.notes}'), style: TextStyle(fontSize: 12, color: context.cs.primary)),
                    ),
                  ]),
                ),
                QtyStepper(qty: d.qty, onChanged: (v) => setState(() {
                  if (v <= 0) {
                    _draft.remove(d.item.id);
                  } else {
                    d.qty = v;
                  }
                })),
              ]),
            ),
          if (o == null && _draft.isNotEmpty)
            TextField(controller: _notes, decoration: deco(context, 'Catatan pesanan', icon: Icons.notes_rounded)),
        ]),
        ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _sending || _draft.isEmpty ? null : _send,
              icon: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded),
              label: Text(tr(_draft.isEmpty ? 'Cek & Kirim ke Dapur' : 'Cek & Kirim · $_draftCount item · ${rupiah(_draftTotal)}')),
            ),
          ),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final title = tr(widget.table != null ? 'Meja ${widget.table!.number}' : (_order?.title ?? 'Take Away'));
    if (_loading) return Scaffold(appBar: AppBar(title: Text(title)), body: const LoadingView());
    if (_error != null) return Scaffold(appBar: AppBar(title: Text(title)), body: ErrorView(message: _error!, onRetry: _load));

    if (context.isWide) {
      return Scaffold(
        appBar: AppBar(title: Text(title), actions: const [LiveDot(), SizedBox(width: 16)]),
        body: Row(children: [
          Expanded(flex: 3, child: _menu()),
          VerticalDivider(width: 1, color: context.borderColor),
          SizedBox(width: 400, child: _panel()),
        ]),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          bottom: TabBar(tabs: [
            Tab(text: tr('Menu')),
            Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(tr('Pesanan')),
              if (_draftCount > 0) ...[const SizedBox(width: 6), Badge(label: Text('$_draftCount'))],
            ])),
          ]),
        ),
        body: TabBarView(children: [_menu(), _panel()]),
      ),
    );
  }
}
