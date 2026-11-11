import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:resto_core/resto_core.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'kitchen_board.dart';

/// Ganti dengan alamat server Anda (bisa juga diubah dari layar login).
const kLanServer = 'http://192.168.1.10:8000';

/// Saat dites di PC: Chrome → server di host yang sama (port 8000), Windows → localhost; HP/tablet → [kLanServer].
String get kDefaultServer => kIsWeb
    ? 'http://${Uri.base.host.isEmpty ? 'localhost' : Uri.base.host}:8000'
    : defaultTargetPlatform == TargetPlatform.windows
        ? 'http://localhost:8000'
        : kLanServer;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Lang.instance.load(); // bahasa tersimpan: Indonesia / English / 中文
  WakelockPlus.enable(); // layar dapur tetap menyala
  final session = Session(appKey: 'kitchen', defaultServer: kDefaultServer)..init();
  runApp(ChangeNotifierProvider.value(value: session, child: const KitchenApp()));
}

class KitchenApp extends StatelessWidget {
  const KitchenApp({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    return ListenableBuilder(
      listenable: Lang.instance,
      builder: (context, _) => MaterialApp(
        key: ValueKey(Lang.instance.code),
      title: tr('RestoBake Kitchen'),
      debugShowCheckedModeBanner: false,
        scrollBehavior: const RestoScrollBehavior(),
      theme: s.themeData,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: !s.ready
            ? const Scaffold(body: Center(child: AppLogo(size: 72, icon: Icons.soup_kitchen_rounded)))
            : s.loggedIn
                ? const KitchenBoard(key: ValueKey('board'))
                : LoginPage(
                    key: ValueKey('login'),
                    appName: 'Kitchen Display',
                    subtitle: tr('Pesanan dari waiter dan aplikasi customer langsung muncul di layar dapur secara realtime.'),
                    icon: Icons.soup_kitchen_rounded,
                    loginLabel: 'Username',
                    loginHint: 'kitchen1',
                    features: [
                      (Icons.notifications_active_rounded, 'Notifikasi pesanan'),
                      (Icons.timer_rounded, 'Timer per pesanan'),
                      (Icons.inventory_2_rounded, 'Tandai menu habis'),
                    ],
                  ),
      ),
    ),
    );
  }
}
