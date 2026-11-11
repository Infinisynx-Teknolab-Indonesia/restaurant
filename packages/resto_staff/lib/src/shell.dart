import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:resto_core/resto_core.dart';

import 'account_page.dart';
import 'cashier_page.dart';
import 'orders_page.dart';
import 'ready_page.dart';
import 'recap_page.dart';
import 'tables_page.dart';

/// Naik tiap ada event realtime → halaman yang mendengarkan akan reload.
final restoTick = ValueNotifier<int>(0);
final menuTick = ValueNotifier<int>(0);

class _Tab {
  final String key, label;
  final IconData icon, iconOn;
  final Widget page;
  const _Tab(this.key, this.label, this.icon, this.iconOn, this.page);
}

/// Jenis aplikasi staf: tiap mode punya aplikasi Android/iOS sendiri.
enum StaffMode { waiter, kasir }

class RestoShell extends StatefulWidget {
  const RestoShell({super.key, required this.mode});
  final StaffMode mode;
  @override
  State<RestoShell> createState() => _RestoShellState();
}

class _RestoShellState extends State<RestoShell> {
  int _i = 0;
  int _readyCount = 0, _unpaidCount = 0;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    final s = context.read<Session>();
    _sub = s.realtime.events.listen(_onEvent);
    _counts();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _counts() async {
    try {
      final a = await api.activeOrders();
      if (!mounted) return;
      setState(() {
        _readyCount = a.where((o) => o.status == 'ready').length;
        _unpaidCount = a.where((o) => !o.isPaid && o.status != 'cancelled').length;
      });
    } catch (_) {}
  }

  void _onEvent(RealtimeEvent e) {
    if (e.event == 'menu_changed') {
      menuTick.value++;
      return;
    }
    restoTick.value++;
    _counts();
    if (!mounted) return;
    final u = context.read<Session>().user!;
    final d = e.data;
    final where = d['table_number'] != null ? 'Meja ${d['table_number']}' : '${d['code'] ?? ''}';
    final waiterApp = widget.mode == StaffMode.waiter;
    if (e.event == 'order_ready' && waiterApp) {
      HapticFeedback.heavyImpact();
      if (context.read<Session>().notifySound) SystemSound.play(SystemSoundType.alert);
      showSnack(context, '🔔 $where siap diantar');
    } else if (e.event == 'order_new' && d['source'] == 'customer_app' && !waiterApp && u.isCashier) {
      if (context.read<Session>().notifySound) SystemSound.play(SystemSoundType.alert);
      showSnack(context, 'Pesanan online baru $where');
    } else if (e.event == 'order_paid' && !waiterApp && u.isCashier && d['source'] == 'customer_app') {
      showSnack(context, '$where dibayar online ${rupiah(d['total'])}');
    }
  }

  List<_Tab> _tabs(AppUser u) {
    // Aplikasi Waiter: Meja · Siap Antar · Pesanan · Akun
    if (widget.mode == StaffMode.waiter) {
      return const [
        _Tab('tables', 'Meja', Icons.table_restaurant_outlined, Icons.table_restaurant_rounded, TablesPage()),
        _Tab('ready', 'Siap Antar', Icons.room_service_outlined, Icons.room_service_rounded, ReadyPage()),
        _Tab('orders', 'Pesanan', Icons.receipt_long_outlined, Icons.receipt_long_rounded, OrdersPage()),
        _Tab('account', 'Akun', Icons.person_outline_rounded, Icons.person_rounded, AccountPage()),
      ];
    }
    // Aplikasi Kasir: Kasir · Meja · Pesanan · Rekap · Akun
    return const [
      _Tab('cashier', 'Kasir', Icons.point_of_sale_outlined, Icons.point_of_sale_rounded, CashierPage()),
      _Tab('tables', 'Meja', Icons.table_restaurant_outlined, Icons.table_restaurant_rounded, TablesPage()),
      _Tab('orders', 'Pesanan', Icons.receipt_long_outlined, Icons.receipt_long_rounded, OrdersPage()),
      _Tab('recap', 'Rekap', Icons.insights_outlined, Icons.insights_rounded, RecapPage()),
      _Tab('account', 'Akun', Icons.person_outline_rounded, Icons.person_rounded, AccountPage()),
    ];
  }

  Widget _icon(_Tab t, bool on) {
    final icon = Icon(on ? t.iconOn : t.icon);
    final n = t.key == 'ready' ? _readyCount : t.key == 'cashier' ? _unpaidCount : 0;
    return n > 0 ? Badge(label: Text('$n'), child: icon) : icon;
  }

  @override
  Widget build(BuildContext context) {
    final u = context.watch<Session>().user!;
    final tabs = _tabs(u);
    if (_i >= tabs.length) _i = 0;
    final body = IndexedStack(index: _i, children: [for (final t in tabs) t.page]);

    if (context.isWide) {
      final p = context.palette;
      return Scaffold(
        body: Row(children: [
          Container(
            color: p.side,
            child: SafeArea(
              right: false,
              child: NavigationRail(
                backgroundColor: p.side,
                selectedIndex: _i,
                onDestinationSelected: (v) => setState(() => _i = v),
                labelType: NavigationRailLabelType.all,
                indicatorColor: p.primary,
                selectedIconTheme: const IconThemeData(color: Colors.white),
                unselectedIconTheme: IconThemeData(color: Colors.white.withValues(alpha: .7)),
                selectedLabelTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                unselectedLabelTextStyle: TextStyle(color: Colors.white.withValues(alpha: .7), fontSize: 12),
                leading: Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: AppLogo(size: 42, icon: widget.mode == StaffMode.waiter ? Icons.room_service_rounded : Icons.point_of_sale_rounded)),
                trailing: const Padding(padding: EdgeInsets.only(top: 20), child: LiveDot(showLabel: false)),
                destinations: [
                  for (final t in tabs)
                    NavigationRailDestination(icon: _icon(t, false), selectedIcon: _icon(t, true), label: Text(tr(t.label))),
                ],
              ),
            ),
          ),
          Expanded(child: body),
        ]),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (v) => setState(() => _i = v),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          for (final t in tabs) NavigationDestination(icon: _icon(t, false), selectedIcon: _icon(t, true), label: tr(t.label)),
        ],
      ),
    );
  }
}
