import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Perilaku scroll semua aplikasi RestoBake:
/// * daftar selalu bisa ditarik (walau isinya pendek / kosong) → "tarik untuk refresh" selalu jalan
/// * di Windows / Chrome layar bisa digeser & ditarik pakai mouse dan touchpad (bawaan Flutter hanya sentuhan)
class RestoScrollBehavior extends MaterialScrollBehavior {
  const RestoScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.unknown,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      AlwaysScrollableScrollPhysics(parent: super.getScrollPhysics(context));
}

/// Tarik ke bawah untuk memuat ulang + tombol F5 / Ctrl+R (keyboard PC).
class PullRefresh extends StatefulWidget {
  const PullRefresh({super.key, required this.onRefresh, required this.child});
  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  State<PullRefresh> createState() => _PullRefreshState();
}

class _PullRefreshState extends State<PullRefresh> {
  final _key = GlobalKey<RefreshIndicatorState>();

  void _run() => _key.currentState?.show();

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.f5): _run,
          const SingleActivator(LogicalKeyboardKey.keyR, control: true): _run,
        },
        child: Focus(
          autofocus: true,
          child: RefreshIndicator(key: _key, onRefresh: widget.onRefresh, child: widget.child),
        ),
      );
}
