import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:resto_core/resto_core.dart';

import 'cart.dart';
import 'pages/auth_page.dart';
import 'pages/home_shell.dart';

/// Ganti dengan alamat server Anda (bisa juga diubah dari dalam aplikasi).
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
  final session = Session(appKey: 'customer', defaultServer: kDefaultServer)..init();
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: session),
      ChangeNotifierProvider(create: (_) => Cart()),
    ],
    child: const CustomerApp(),
  ));
}

class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    return ListenableBuilder(
      listenable: Lang.instance,
      builder: (context, _) => MaterialApp(
        key: ValueKey(Lang.instance.code),
      title: tr('RestoBake'),
      debugShowCheckedModeBanner: false,
        scrollBehavior: const RestoScrollBehavior(),
      theme: s.themeData,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: !s.ready
            ? const _Splash()
            : s.loggedIn
                ? const HomeShell(key: ValueKey('home'))
                : const AuthPage(key: ValueKey('auth')),
      ),
    ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: AppLogo(size: 72)));
}
