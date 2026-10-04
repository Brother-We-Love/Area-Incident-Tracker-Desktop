import 'package:flutter/material.dart';

/// Progress (0..1) of a staggered CSS-style animation driven by [t] (0..1)
/// over [totalMs]: starts after [delayMs], runs for [durMs].
double stagger(double t, int totalMs, int delayMs, int durMs, {Curve curve = Curves.easeInOut}) {
  final v = ((t * totalMs) - delayMs) / durMs;
  return curve.transform(v.clamp(0.0, 1.0));
}

/// Owns a one-shot entrance controller and rebuilds children with its value.
class Entrance extends StatefulWidget {
  const Entrance({super.key, required this.totalMs, required this.builder});
  final int totalMs;
  final Widget Function(BuildContext context, double t) builder;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: Duration(milliseconds: widget.totalMs))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      AnimatedBuilder(animation: _c, builder: (context, _) => widget.builder(context, _c.value));
}

class LoadingBlock extends StatelessWidget {
  const LoadingBlock({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5))),
      );
}
