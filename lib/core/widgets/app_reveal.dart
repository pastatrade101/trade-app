import 'package:flutter/material.dart';

class AppReveal extends StatelessWidget {
  const AppReveal({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 400),
    this.curve = Curves.easeOutCubic,
    this.offset = const Offset(0, 12),
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration duration;
  final Curve curve;
  final Offset offset;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (delay == Duration.zero) {
      return _RevealBody(
        duration: duration,
        curve: curve,
        offset: offset,
        child: child,
      );
    }
    return FutureBuilder<void>(
      future: Future<void>.delayed(delay),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Opacity(opacity: 0, child: child);
        }
        return _RevealBody(
          duration: duration,
          curve: curve,
          offset: offset,
          child: child,
        );
      },
    );
  }
}

class _RevealBody extends StatelessWidget {
  const _RevealBody({
    required this.duration,
    required this.curve,
    required this.offset,
    required this.child,
  });

  final Duration duration;
  final Curve curve;
  final Offset offset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: curve,
      child: child,
      builder: (context, value, child) {
        final dx = offset.dx * (1 - value);
        final dy = offset.dy * (1 - value);
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(dx, dy),
            child: child,
          ),
        );
      },
    );
  }
}
