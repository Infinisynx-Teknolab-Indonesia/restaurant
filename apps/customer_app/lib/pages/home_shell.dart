import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:resto_core/resto_core.dart';

import 'loyalty_page.dart';
import 'menu_page.dart';
import 'orders_page.dart';
import 'profile_page.dart';
import 'vouchers_page.dart';

/// Naik setiap ada event pesanan milik customer → halaman pesanan reload.
final ordersTick = ValueNotifier<int>(0);
/// Naik saat katalog hadiah / status penukaran berubah.
final rewardsTick = ValueNotifier<int>(0);
final menuTick = ValueNotifier<int>(0);

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  static void goTab(BuildContext context, int i) => context.findAncestorStateOfType<_HomeShellState>()?.setTab(i);
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  StreamSubscription? _sub;

  void setTab(int i) => setState(() => _tab = i);

  @override
  void initState() {
    super.initState();
    final s = context.read<Session>();
    _sub = s.realtime.events.listen((e) {
      if (e.event == 'menu_changed') menuTick.value++;
      if (e.event == 'rewards_changed') rewardsTick.value++;
      if (e.event == 'reward_update') {
        // admin memproses penukaran hadiah → beri tahu member
        rewardsTick.value++;
        s.refreshMe();
        final name = '${e.data['reward_name'] ?? ''}';
        final st = '${e.data['status']}';
        if (mounted) {
          showSnack(context, st == 'completed' ? 'Hadiah $name sudah dikirim! Cek Hadiah Saya.'
              : st == 'rejected' ? 'Penukaran $name ditolak, poin dikembalikan' : 'Hadiah $name sedang diproses');
        }
        return;
      }
      if (!e.event.startsWith('order') && e.event != 'payment_paid') return;
      ordersTick.value++;
      if (e.data['customer_id'] != s.user?.id) return;
      final st = '${e.data['status']}';
      final code = '${e.data['code'] ?? ''}';
      String? msg;
      if (e.event == 'order_paid') msg = 'Pembayaran $code berhasil. Terima kasih!';
      if (e.event == 'order_ready') msg = 'Pesanan $code sudah siap!';
      if (e.event == 'order_updated' && st == 'preparing') msg = 'Pesanan $code sedang dimasak';
      if (e.event == 'order_updated' && st == 'cancelled') msg = 'Pesanan $code dibatalkan';
      if (msg != null && mounted) showSnack(context, msg);
      if (e.event == 'order_paid') s.refreshMe();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const pages = [MenuPage(), OrdersPage(), VouchersPage(), LoyaltyPage(), ProfilePage()];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: setTab,
        destinations: [
          NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront_rounded), label: tr('Menu')),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded), label: tr('Pesanan')),
          NavigationDestination(icon: Icon(Icons.confirmation_number_outlined), selectedIcon: Icon(Icons.confirmation_number_rounded), label: tr('Voucher')),
          NavigationDestination(icon: Icon(Icons.stars_outlined), selectedIcon: Icon(Icons.stars_rounded), label: tr('Poin')),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: tr('Akun')),
        ],
      ),
    );
  }
}
