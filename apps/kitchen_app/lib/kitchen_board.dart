import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:resto_core/resto_core.dart';

/// Kitchen Display System: kolom Baru → Dimasak → Siap.
class KitchenBoard extends StatefulWidget {
  const KitchenBoard({super.key});
  @override
  State<KitchenBoard> createState() => _KitchenBoardState();
}

class _KitchenBoardState extends State<KitchenBoard> {
  List<Order>? _orders;
  String? _error;
  String _station = '';
  bool _sound = true;
  bool _flash = false;
  StreamSubscription? _sub;
  Timer? _clock, _poll;
  final Set<int> _known = {};

  @override
  void initState() {
    super.initState();
    _load(first: true);
    _sub = context.read<Session>().realtime.events.listen((e) {
      if (e.event == 'order_new' || e.event == 'order_items_added') _alert();
      if (e.event.startsWith('order')) _load();
    });
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    // cadangan bila websocket terputus
    _poll = Timer.periodic(const Duration(seconds: 45), (_) => _load());
  }

  @override
  void dispose() {
    _sub?.cancel();
    _clock?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  void _alert() {
    if (_sound) {
      if (context.read<Session>().notifySound) SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();
    }
    setState(() => _flash = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _flash = false);
    });
  }

  Future<void> _load({bool first = false}) async {
    try {
      final o = await api.kitchenOrders(station: _station);
      if (!mounted) return;
      final ids = o.map((x) => x.id).toSet();
      if (!first && ids.difference(_known).isNotEmpty && !_flash) _alert();
      _known
        ..clear()
        ..addAll(ids);
      setState(() { _orders = o; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _itemTap(OrderItem it) async {
    final next = switch (it.status) { 'queued' => 'cooking', 'cooking' => 'done', _ => 'queued' };
    await runSafe(context, () => api.patch('/api/kitchen/items/${it.id}', {'status': next}));
    _load();
  }

  Future<void> _orderAction(Order o, String action) async {
    await runSafe(context, () => api.patch('/api/kitchen/orders/${o.id}/$action', null, {'station': _station}),
        success: action == 'done' ? '${o.title} siap diantar' : null);
    _load();
  }

  String _column(Order o) {
    final s = o.items.where((i) => !i.isVoid).map((i) => i.status).toSet();
    if (s.every((x) => x == 'done' || x == 'served')) return 'ready';
    if (s.contains('cooking') || s.contains('done')) return 'cooking';
    return 'new';
  }

  // ---------------------------------------------------------------- UI
  Widget _card(Order o) {
    final mins = DateTime.now().difference(parseDate(o.createdAt) ?? DateTime.now()).inMinutes;
    final col = _column(o);
    final head = col == 'ready'
        ? const Color(0xFF7C3AED)
        : mins >= 20
            ? const Color(0xFFDC2626)
            : mins >= 10
                ? const Color(0xFFD97706)
                : const Color(0xFF16A34A);
    return PulseGlow(
      active: col == 'new' && mins < 3,
      color: const Color(0xFF0284C7),
      child: AppCard(
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          color: head,
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                Text('${o.code}${o.source == 'customer_app' ? ' · 📱 Online' : o.waiterName != null ? ' · ${o.waiterName}' : ''}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
              ]),
            ),
            const Icon(Icons.timer_outlined, color: Colors.white, size: 18),
            const SizedBox(width: 4),
            Text(tr('$mins mnt'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
          ]),
        ),
        if (o.notes.isNotEmpty)
          Container(
            color: const Color(0xFFFEF3C7),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Text('📝 ${o.notes}', style: const TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.w600)),
          ),
        for (final it in o.items)
          InkWell(
            onTap: it.isVoid ? null : () => _itemTap(it),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.borderColor))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 34,
                  child: Text('${it.qty}x', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.cs.primary)),
                ),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(it.name, style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      decoration: it.status == 'done' || it.isVoid ? TextDecoration.lineThrough : null,
                      color: it.status == 'done' || it.isVoid ? context.muted : null,
                    )),
                    if (it.notes.isNotEmpty)
                      Text('⚠ ${it.notes}', style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
                    // koreksi dari kasir/pengawas: dapur harus tahu (mis. jumlah berubah / item dibatalkan)
                    if (it.editNote.isNotEmpty)
                      PulseGlow(
                        color: it.isVoid ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                        radius: 6,
                        child: Container(
                          margin: const EdgeInsets.only(top: 3),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (it.isVoid ? const Color(0xFFDC2626) : const Color(0xFFD97706)).withValues(alpha: .14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('✎ ${it.editNote}', style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700,
                            color: it.isVoid ? const Color(0xFFDC2626) : const Color(0xFFB45309))),
                        ),
                      ),
                    Text(stationLabel[it.station] ?? it.station, style: TextStyle(fontSize: 11, color: context.muted)),
                  ]),
                ),
                StatusChip(itemStatus[it.status]!, small: true),
              ]),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: col == 'ready'
              ? Row(children: [
                  const Icon(Icons.room_service_rounded, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(tr('Menunggu diantar waiter'), style: TextStyle(fontWeight: FontWeight.w600))),
                  TextButton(onPressed: () => _orderAction(o, 'start'), child: Text(tr('Kembalikan'))),
                ])
              : Row(children: [
                  if (col == 'new')
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => _orderAction(o, 'start'),
                        icon: const Icon(Icons.local_fire_department_rounded),
                        label: Text(tr('Mulai Masak')),
                      ),
                    ),
                  if (col == 'new') const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _orderAction(o, 'done'),
                      icon: const Icon(Icons.check_rounded),
                      label: Text(tr('Selesai')),
                    ),
                  ),
                ]),
        ),
      ]),
    ),
    );
  }

  Widget _columnView(String title, IconData icon, Color color, List<Order> rows) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        margin: const EdgeInsets.fromLTRB(6, 10, 6, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(tr(title), style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 16))),
          CircleAvatar(radius: 14, backgroundColor: color,
              child: Text('${rows.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13))),
        ]),
      ),
      Expanded(
        child: PullRefresh(
          onRefresh: _load,
          child: rows.isEmpty
              ? ListView(children: [const SizedBox(height: 60), Center(child: Text(tr('Kosong'), style: TextStyle(color: context.muted)))])
              : ListView(padding: const EdgeInsets.symmetric(horizontal: 6), children: [for (final o in rows) _card(o)]),
        ),
      ),
    ]);
  }

  Future<void> _menu() async {
    final s = context.read<Session>();
    final v = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.person_rounded), title: Text(s.user!.name), subtitle: Text(roleLabel[s.user!.role] ?? '')),
          const Divider(height: 1),
          ListTile(leading: const Icon(Icons.inventory_2_rounded), title: Text(tr('Stok Menu (tandai habis)')), onTap: () => Navigator.pop(c, 'stock')),
          ListTile(leading: const Icon(Icons.fingerprint_rounded), title: Text(tr('Absen masuk / pulang')), onTap: () => Navigator.pop(c, 'absen')),
          ListTile(leading: const Icon(Icons.palette_outlined), title: Text(tr('Tema Tampilan')), onTap: () => Navigator.pop(c, 'theme')),
          ListTile(leading: const Icon(Icons.dns_outlined), title: Text(tr('Alamat Server')), subtitle: Text(s.server), onTap: () => Navigator.pop(c, 'server')),
          ListTile(leading: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626)), title: Text(tr('Keluar'), style: TextStyle(color: Color(0xFFDC2626))),
              onTap: () => Navigator.pop(c, 'logout')),
        ]),
      ),
    );
    if (!mounted) return;
    switch (v) {
      case 'stock':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StockPage()));
      case 'absen':
        final r = await runSafe(context, () => api.post('/api/attendance/check'));
        if (r != null && mounted) showSnack(context, '${r['message']}');
      case 'theme':
        showThemePicker(context);
      case 'server':
        showServerDialog(context);
      case 'logout':
        if (await confirmDialog(context, 'Keluar?', 'Layar dapur akan kembali ke halaman login.', okText: 'Keluar')) s.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _orders ?? [];
    final news = rows.where((o) => _column(o) == 'new').toList();
    final cooking = rows.where((o) => _column(o) == 'cooking').toList();
    final ready = rows.where((o) => _column(o) == 'ready').toList();
    final now = TimeOfDay.now();

    final appBar = AppBar(
      backgroundColor: _flash ? const Color(0xFFDC2626) : context.palette.side,
      foregroundColor: Colors.white,
      titleSpacing: 12,
      title: Row(children: [
        const AppLogo(size: 34, icon: Icons.soup_kitchen_rounded),
        const SizedBox(width: 10),
        Text(tr(_flash ? '🔔 PESANAN BARU!' : 'Kitchen Display'), style: const TextStyle(fontWeight: FontWeight.w800)),
      ]),
      actions: [
        const LanguageButton(color: Colors.white),
        if (context.isWide)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SegmentedButton<String>(
              style: SegmentedButton.styleFrom(foregroundColor: Colors.white, selectedForegroundColor: Colors.white,
                  selectedBackgroundColor: context.palette.primary, side: const BorderSide(color: Colors.white38)),
              segments: [
                ButtonSegment(value: '', label: Text(tr('Semua'))),
                ButtonSegment(value: 'kitchen', label: Text(tr('Dapur'))),
                ButtonSegment(value: 'bakery', label: Text(tr('Bakery'))),
                ButtonSegment(value: 'bar', label: Text(tr('Bar'))),
              ],
              selected: {_station},
              onSelectionChanged: (v) {
                setState(() => _station = v.first);
                _load();
              },
            ),
          )
        else
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list_rounded),
            onSelected: (v) {
              setState(() => _station = v);
              _load();
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: '', child: Text(tr('Semua station'))),
              PopupMenuItem(value: 'kitchen', child: Text(tr('Dapur'))),
              PopupMenuItem(value: 'bakery', child: Text(tr('Bakery'))),
              PopupMenuItem(value: 'bar', child: Text(tr('Bar'))),
            ],
          ),
        Center(child: Text('${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
        const SizedBox(width: 10),
        const LiveDot(showLabel: false),
        IconButton(
          tooltip: tr(_sound ? 'Suara aktif' : 'Suara mati'),
          onPressed: () => setState(() => _sound = !_sound),
          icon: Icon(_sound ? Icons.volume_up_rounded : Icons.volume_off_rounded),
        ),
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        IconButton(onPressed: _menu, icon: const Icon(Icons.more_vert_rounded)),
      ],
    );

    if (_error != null && _orders == null) {
      return Scaffold(appBar: appBar, body: ErrorView(message: _error!, onRetry: _load));
    }
    if (_orders == null) return Scaffold(appBar: appBar, body: const LoadingView());

    final c1 = _columnView('Baru', Icons.fiber_new_rounded, const Color(0xFF0284C7), news);
    final c2 = _columnView('Dimasak', Icons.local_fire_department_rounded, const Color(0xFFEA580C), cooking);
    final c3 = _columnView('Siap Antar', Icons.room_service_rounded, const Color(0xFF7C3AED), ready);

    if (context.isWide) {
      return Scaffold(
        appBar: appBar,
        body: Padding(
          padding: const EdgeInsets.all(6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: c1),
            Expanded(child: c2),
            Expanded(child: c3),
          ]),
        ),
      );
    }
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: appBar.backgroundColor,
          foregroundColor: Colors.white,
          title: appBar.title,
          titleSpacing: 12,
          actions: appBar.actions,
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [Tab(text: tr('Baru (${news.length})')), Tab(text: tr('Dimasak (${cooking.length})')), Tab(text: tr('Siap (${ready.length})'))],
          ),
        ),
        body: TabBarView(children: [c1, c2, c3]),
      ),
    );
  }
}

/// Dapur bisa menandai menu habis / tersedia lagi.
class StockPage extends StatefulWidget {
  const StockPage({super.key});
  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  List<MenuItem>? _items;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await api.get('/api/menu/items') as List;
      if (mounted) setState(() => _items = r.map((e) => MenuItem.fromJson(e)).toList());
    } catch (e) {
      if (mounted) showSnack(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = (_items ?? []).where((i) => _q.isEmpty || i.name.toLowerCase().contains(_q.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(title: Text(tr('Stok Menu'))),
      body: _items == null
          ? const LoadingView()
          : Column(children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(onChanged: (v) => setState(() => _q = v), decoration: deco(context, 'Cari menu', icon: Icons.search_rounded)),
              ),
              Expanded(
                child: PullRefresh(
                  onRefresh: _load,
                  child: ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (c, i) {
                    final m = rows[i];
                    return SwitchListTile(
                      value: m.isAvailable,
                      title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${m.categoryName} · ${stationLabel[m.station] ?? m.station}${m.stock != null ? ' · stok ${m.stock}' : ''}'),
                      secondary: Icon(m.isAvailable ? Icons.check_circle_rounded : Icons.block_rounded,
                          color: m.isAvailable ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
                      onChanged: (v) async {
                        await runSafe(context, () => api.patch('/api/menu/items/${m.id}/availability', null, {'available': v}),
                            success: v ? '${m.name} tersedia lagi' : '${m.name} ditandai HABIS');
                        _load();
                      },
                    );
                  },
                ),
                ),
              ),
            ]),
    );
  }
}
