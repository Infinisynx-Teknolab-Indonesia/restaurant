import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'animations.dart';
import 'session.dart';

/// Font dibundel di paket resto_core (tidak butuh internet).
const kSans = 'packages/resto_core/Inter';
const kSerif = 'packages/resto_core/PlayfairDisplay';

/// Tema "Elegant Bakery" — sama dengan Admin Server:
/// Royal, Espresso, Emerald, Rosé, Midnight. Semua beraksen emas.
class AppPalette {
  final String name;
  final Color primary, side, side2, accent, bg;
  final bool dark;
  const AppPalette(this.name, this.primary, this.side, this.side2, this.accent, this.bg, {this.dark = false});
}

const palettes = <AppPalette>[
  AppPalette('Royal', Color(0xFF1F2D4F), Color(0xFF111A2E), Color(0xFF1A2540), Color(0xFFC5A059), Color(0xFFF6F3EE)),
  AppPalette('Espresso', Color(0xFF4A2F20), Color(0xFF22160F), Color(0xFF2E1F16), Color(0xFFC08A4A), Color(0xFFF7F2EC)),
  AppPalette('Emerald', Color(0xFF14463A), Color(0xFF0C2620), Color(0xFF123129), Color(0xFFBF9B52), Color(0xFFF3F5F1)),
  AppPalette('Rosé', Color(0xFF6B2737), Color(0xFF2A1219), Color(0xFF371922), Color(0xFFC9927A), Color(0xFFF8F3F2)),
  AppPalette('Midnight', Color(0xFFC5A059), Color(0xFF0A0D14), Color(0xFF121826), Color(0xFFD4B06A), Color(0xFF0E121B), dark: true),
];

AppPalette paletteAt(int i) => palettes[i.clamp(0, palettes.length - 1)];

ThemeData buildTheme(int index) => buildThemeFrom(paletteAt(index));

/// Bangun ThemeData dari palet mana pun (palet bawaan atau tema dari admin).
ThemeData buildThemeFrom(AppPalette p) {
  final brightness = p.dark ? Brightness.dark : Brightness.light;
  var scheme = ColorScheme.fromSeed(
    seedColor: p.primary,
    primary: p.primary,
    secondary: p.accent,
    tertiary: p.accent,
    brightness: brightness,
  );
  scheme = p.dark
      ? scheme.copyWith(surface: const Color(0xFF161D2B), onSurface: const Color(0xFFE8EBF1), onPrimary: const Color(0xFF141008))
      : scheme.copyWith(surface: Colors.white, onSurface: const Color(0xFF1B1F2A), onPrimary: Colors.white);

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    fontFamily: kSans,
    scaffoldBackgroundColor: p.bg,
    visualDensity: VisualDensity.standard,
    splashFactory: InkRipple.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeSlidePageTransitionsBuilder(),
      TargetPlatform.windows: FadeSlidePageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
  );
  // Judul memakai serif (Playfair Display) agar terasa elegan; isi tetap Inter.
  final t = base.textTheme;
  TextStyle? serif(TextStyle? s, {FontWeight w = FontWeight.w700}) =>
      s?.copyWith(fontFamily: kSerif, fontWeight: w, letterSpacing: 0);
  return base.copyWith(
    textTheme: t.copyWith(
      displayLarge: serif(t.displayLarge),
      displayMedium: serif(t.displayMedium),
      displaySmall: serif(t.displaySmall),
      headlineLarge: serif(t.headlineLarge),
      headlineMedium: serif(t.headlineMedium),
      headlineSmall: serif(t.headlineSmall),
      titleLarge: serif(t.titleLarge),
    ),
  );
}

extension PaletteX on BuildContext {
  AppPalette get palette => watch<Session>().palette;
  ColorScheme get cs => Theme.of(this).colorScheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get gold => Theme.of(this).colorScheme.secondary;
  Color get muted => isDark ? const Color(0xFF8A93A6) : const Color(0xFF7A7F8C);
  Color get borderColor => isDark ? const Color(0xFF242D3F) : const Color(0xFFEBE5DA);
  bool get isWide => MediaQuery.sizeOf(this).width >= 840;
}

/// Gaya teks serif siap pakai (angka besar, judul kartu).
TextStyle serifStyle({double size = 20, Color? color, FontWeight weight = FontWeight.w700}) =>
    TextStyle(fontFamily: kSerif, fontSize: size, fontWeight: weight, color: color);
