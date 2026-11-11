import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:resto_core/resto_core.dart';
import 'package:resto_staff/resto_staff.dart';

/// RestoBake Kasir — aplikasi Kasir: tagihan, bayar tunai / kartu / QRIS, cetak struk, koreksi pesanan, rekap.
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
  final session = Session(appKey: 'kasir', defaultServer: kDefaultServer)..init();
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
        title: tr('RestoBake Kasir'),
        debugShowCheckedModeBanner: false,
        scrollBehavior: const RestoScrollBehavior(),
        theme: s.themeData,
        home: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: !s.ready
              ? const Scaffold(body: Center(child: AppLogo(size: 72, icon: Icons.point_of_sale_rounded)))
              : s.loggedIn
                  ? const RestoShell(key: ValueKey('shell'), mode: StaffMode.kasir)
                  : LoginPage(
                      key: const ValueKey('login'),
                      appName: 'RestoBake Kasir',
                      subtitle: tr('Terima pembayaran tunai, kartu, atau QRIS, cetak struk, dan koreksi pesanan.'),
                      icon: Icons.point_of_sale_rounded,
                      loginLabel: 'Username',
                      loginHint: 'kasir1 / pengawas',
                      features: const [
                        (Icons.payments_rounded, 'Tunai · Kartu · QRIS'),
                        (Icons.print_rounded, 'Cetak struk'),
                        (Icons.edit_note_rounded, 'Koreksi pesanan'),
                      ],
                    ),
        ),
      ),
    );
  }
}
