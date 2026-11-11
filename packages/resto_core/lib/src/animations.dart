import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Animasi bersama RestoBake. Semua otomatis mati bila HP diset "hapus animasi" (aksesibilitas).
bool reduceMotion(BuildContext context) => MediaQuery.of(context).disableAnimations;

/// Urutan per frame → kartu yang muncul bersamaan masuk bertahap (stagger) tanpa perlu index manual.
class _Stagger {
  static int _seq = 0;
  static bool _scheduled = false;
  static int next() {
    if (!_scheduled) {
      _scheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _seq = 0;
        _scheduled = false;
      });
    }
    return _seq++;
  }
}

/// Muncul dengan fade + geser + sedikit membesar. Jeda otomatis bertahap bila [delay] kosong.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.delay, this.offset = const Offset(0, .08),
      this.duration = const Duration(milliseconds: 560)});
  final Widget child;
  final Duration? delay;
  final Offset offset;
  final Duration duration;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  late final int _order = _Stagger.next();
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (reduceMotion(context)) {
      _c.value = 1;
      return;
    }
    final d = widget.delay ?? Duration(milliseconds: math.min(_order, 12) * 45);
    Future.delayed(d, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween(begin: widget.offset, end: Offset.zero).animate(_curve),
        child: ScaleTransition(scale: Tween(begin: .97, end: 1.0).animate(_curve), child: widget.child),
      ),
    );
  }
}

/// Efek ditekan: mengecil sedikit lalu memantul kembali. Tidak mengambil alih tap milik child.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.enabled = true, this.scale = .965});
  final Widget child;
  final bool enabled;
  final double scale;
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  void _set(bool v) {
    if (widget.enabled && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: Duration(milliseconds: _down ? 90 : 320),
        curve: _down ? Curves.easeOut : Curves.elasticOut,
        child: widget.child,
      ),
    );
  }
}

/// Angka berjalan naik (poin, total rupiah). Saat nilai berubah, beranimasi dari nilai lama.
class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({super.key, required this.value, required this.format, this.style,
      this.duration = const Duration(milliseconds: 1100)});
  final num value;
  final String Function(num v) format;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return Text(format(value), style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text(format(v.round()), style: style),
    );
  }
}

/// Muncul memantul (ikon sukses, badge keranjang).
class PopIn extends StatelessWidget {
  const PopIn({super.key, required this.child, this.delay = Duration.zero, this.duration = const Duration(milliseconds: 750)});
  final Widget child;
  final Duration delay;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return child;
    final total = duration + delay;
    final start = delay.inMilliseconds / total.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      builder: (_, t, c) {
        final k = t <= start ? 0.0 : (t - start) / (1 - start);
        final s = Curves.elasticOut.transform(k.clamp(0.0, 1.0));
        return Opacity(opacity: (k * 2).clamp(0.0, 1.0), child: Transform.scale(scale: s, child: c));
      },
      child: child,
    );
  }
}

/// Naik-turun pelan (ikon kosong, logo).
class FloatY extends StatefulWidget {
  const FloatY({super.key, required this.child, this.distance = 6, this.period = const Duration(milliseconds: 3200)});
  final Widget child;
  final double distance;
  final Duration period;
  @override
  State<FloatY> createState() => _FloatYState();
}

class _FloatYState extends State<FloatY> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period)..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, c) => Transform.translate(offset: Offset(0, -widget.distance * Curves.easeInOut.transform(_c.value)), child: c),
      child: widget.child,
    );
  }
}

/// Cahaya berdenyut di sekeliling child (pesanan baru di dapur).
class PulseGlow extends StatefulWidget {
  const PulseGlow({super.key, required this.child, required this.color, this.radius = 18, this.active = true});
  final Widget child;
  final Color color;
  final double radius;
  final bool active;
  @override
  State<PulseGlow> createState() => _PulseGlowState();
}

class _PulseGlowState extends State<PulseGlow> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active || reduceMotion(context)) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, c) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          boxShadow: [BoxShadow(color: widget.color.withValues(alpha: .15 + .35 * _c.value), blurRadius: 8 + 14 * _c.value, spreadRadius: 1 + 2 * _c.value)],
        ),
        child: c,
      ),
      child: widget.child,
    );
  }
}

/// Latar gradasi yang bergerak perlahan + bola cahaya mengambang (hero login, header).
class AnimatedGradientBox extends StatefulWidget {
  const AnimatedGradientBox({super.key, required this.colors, required this.glow, this.child, this.borderRadius,
      this.padding, this.width});
  final List<Color> colors;
  final Color glow;
  final Widget? child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final double? width;
  @override
  State<AnimatedGradientBox> createState() => _AnimatedGradientBoxState();
}

class _AnimatedGradientBoxState extends State<AnimatedGradientBox> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = still ? 0.0 : _c.value * 2 * math.pi;
        final a = Alignment(math.cos(t) * .9, math.sin(t) * .9);
        final g = Alignment(.9 + .25 * math.sin(t * 1.3), -.9 + .35 * math.cos(t));
        return Container(
          width: widget.width,
          padding: widget.padding,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(begin: a, end: -a, colors: widget.colors),
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: RadialGradient(center: g, radius: 1.0,
                colors: [widget.glow.withValues(alpha: .32), widget.glow.withValues(alpha: 0)]),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Kilau berjalan untuk skeleton loading.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});
  final Widget child;
  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? const Color(0xFF242D3F) : const Color(0xFFE9E3D8);
    final hi = dark ? const Color(0xFF34405A) : const Color(0xFFF7F3EC);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (r) => LinearGradient(
          begin: Alignment(-1.5 + 3 * _c.value, 0),
          end: Alignment(-.5 + 3 * _c.value, 0),
          colors: [base, hi, base],
        ).createShader(r),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = 8});
  final double? width;
  final double height, radius;
  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: const Color(0xFFE9E3D8), borderRadius: BorderRadius.circular(radius)),
      );
}

/// Kerangka daftar kartu selama data dimuat.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 5});
  final int count;
  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0x22000000))),
          child: Row(children: [
            const SkeletonBox(width: 52, height: 52, radius: 14),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SkeletonBox(width: 120 + (i % 3) * 40, height: 14),
                const SizedBox(height: 10),
                const SkeletonBox(height: 10),
                const SizedBox(height: 8),
                SkeletonBox(width: 90 + (i % 2) * 50, height: 10),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Transisi halaman: fade + geser halus (Android). iOS tetap gaya Cupertino (gesture kembali).
class FadeSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeSlidePageTransitionsBuilder();
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    final a = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    final out = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween(begin: const Offset(.08, 0), end: Offset.zero).animate(a),
        child: SlideTransition(
          position: Tween(begin: Offset.zero, end: const Offset(-.04, 0)).animate(out),
          child: child,
        ),
      ),
    );
  }
}
