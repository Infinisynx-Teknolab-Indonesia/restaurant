import 'package:flutter/material.dart';
import 'package:resto_core/resto_core.dart';

import 'order_editor_page.dart';
import 'shell.dart';

class TablesPage extends StatefulWidget {
  const TablesPage({super.key});
  @override
  State<TablesPage> createState() => _TablesPageState();
}

class _TablesPageState extends State<TablesPage> {
  List<DiningTable>? _tables;
  String? _error;
  String _area = '';

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
      final t = await api.tables();
      if (mounted) setState(() { _tables = t; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Color _color(String st) => switch (st) {
        'occupied' => const Color(0xFFD97706),
        'reserved' => const Color(0xFF0284C7),
        _ => const Color(0xFF16A34A),
      };

  Future<void> _open(DiningTable t) async {
    if (t.status == 'reserved') {
      final act = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (c) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(leading: const Icon(Icons.restaurant_rounded), title: Text(tr('Tamu datang, buat pesanan')), onTap: () => Navigator.pop(c, 'order')),
            ListTile(leading: const Icon(Icons.event_busy_rounded), title: Text(tr('Batalkan reservasi')), onTap: () => Navigator.pop(c, 'free')),
          ]),
        ),
      );
      if (act == 'free') {
        if (!mounted) return;
        await runSafe(context, () => api.patch('/api/tables/${t.id}/status', null, {'status': 'available'}));
        return _load();
      }
      if (act != 'order') return;
    }
    if (!mounted) return;
    final orderId = t.openOrders.isNotEmpty ? t.openOrders.first['id'] as int : null;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderEditorPage(table: t, orderId: orderId)));
    _load();
  }

  Future<void> _longPress(DiningTable t) async {
    if (t.status == 'occupied') return;
    final next = t.status == 'reserved' ? 'available' : 'reserved';
    if (await confirmDialog(context, 'Meja ${t.number}', next == 'reserved' ? 'Tandai meja sebagai reservasi?' : 'Kosongkan meja ini?')) {
      if (!mounted) return;
      await runSafe(context, () => api.patch('/api/tables/${t.id}/status', null, {'status': next}));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _tables ?? [];
    final areas = rows.map((t) => t.area).toSet().toList();
    final shown = rows.where((t) => _area.isEmpty || t.area == _area).toList();
    int cnt(String s) => rows.where((t) => t.status == s).length;
    final cols = (MediaQuery.sizeOf(context).width / 150).floor().clamp(3, 8);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Denah Meja')),
        actions: [
          const LiveDot(),
          const SizedBox(width: 8),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OrderEditorPage()));
          _load();
        },
        icon: const Icon(Icons.shopping_bag_rounded),
        label: Text(tr('Take Away')),
      ),
      body: _error != null && _tables == null
          ? ErrorView(message: _error!, onRetry: _load)
          : _tables == null
              ? const LoadingView()
              : PullRefresh(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), children: [
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      Pill('Kosong ${cnt('available')}', color: _color('available')),
                      Pill('Terisi ${cnt('occupied')}', color: _color('occupied')),
                      Pill('Reservasi ${cnt('reserved')}', color: _color('reserved')),
                    ]),
                    if (areas.length > 1) ...[
                      const SizedBox(height: 12),
                      SegmentedButton<String>(
                        segments: [
                          ButtonSegment(value: '', label: Text(tr('Semua'))),
                          for (final a in areas) ButtonSegment(value: a, label: Text(a)),
                        ],
                        selected: {_area},
                        onSelectionChanged: (v) => setState(() => _area = v.first),
                      ),
                    ],
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: shown.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .95),
                      itemBuilder: (c, i) {
                        final t = shown[i];
                        final col = _color(t.status);
                        final o = t.openOrders.isNotEmpty ? t.openOrders.first : null;
                        return GestureDetector(
                          onLongPress: () => _longPress(t),
                          child: AppCard(
                            onTap: () => _open(t),
                            borderColor: t.status == 'available' ? null : col,
                            color: t.status == 'available' ? null : col.withValues(alpha: .07),
                            padding: const EdgeInsets.all(10),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text(tr('MEJA'), style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: c.muted)),
                              Text(t.number, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Icon(Icons.chair_rounded, size: 13, color: c.muted),
                                const SizedBox(width: 3),
                                Text('${t.seats}', style: TextStyle(fontSize: 12, color: c.muted)),
                              ]),
                              const SizedBox(height: 6),
                              if (o != null) ...[
                                Text(rupiah(t.openTotal), style: TextStyle(fontWeight: FontWeight.w700, color: col, fontSize: 12.5)),
                                Text(sejak('${o['created_at']}'), style: TextStyle(fontSize: 10.5, color: c.muted)),
                              ] else
                                Text(tr(t.status == 'reserved' ? 'Reservasi' : 'Kosong'),
                                    style: TextStyle(color: col, fontWeight: FontWeight.w600, fontSize: 12)),
                            ]),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(tr('Tekan lama meja kosong untuk menandai reservasi.'), textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: context.muted)),
                  ]),
                ),
    );
  }
}
