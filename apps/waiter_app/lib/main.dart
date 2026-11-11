import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:resto_core/resto_core.dart';
import 'package:resto_staff/resto_staff.dart';

/// RestoBake Waiter — aplikasi Waiter (pelayan): pesan per meja, cek ulang, kirim ke dapur, antar pesanan.
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
  final session = Session(appKey: 'waiter', defaultServer: kDefaultServer)..init();
  runApp(ChangeNotifierProvider.value(value: session, child: const StaffApp()));
}

class StaffApp extends StatelessWidget {
  const StaffApp({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    return ListenableBuilder(
      listenable: Lang.instance,
      builder: (context, _) => MaterialApp(
        key: ValueKey(Lang.instance.code),
        title: tr('RestoBake Waiter'),
        debugShowCheckedModeBanner: false,
        scrollBehavior: const RestoScrollBehavior(),
        theme: s.themeData,
        home: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: !s.ready
              ? const Scaffold(body: Center(child: AppLogo(size: 72, icon: Icons.room_service_rounded)))
              : s.loggedIn
                  ? const RestoShell(key: ValueKey('shell'), mode: StaffMode.waiter)
                  : LoginPage(
                      key: const ValueKey('login'),
                      appName: 'RestoBake Waiter',
                      subtitle: tr('Ambil pesanan dari meja, cek ulang bersama tamu, lalu kirim langsung ke dapur.'),
                      icon: Icons.room_service_rounded,
                      loginLabel: 'Username',
                      loginHint: 'waiter1',
                      features: const [
                        (Icons.table_restaurant_rounded, 'Pesan per meja'),
                        (Icons.fact_check_rounded, 'Cek ulang sebelum kirim'),
                        (Icons.notifications_active_rounded, 'Notifikasi siap antar'),
                      ],
                    ),
        ),
      ),
    );
  }
}
