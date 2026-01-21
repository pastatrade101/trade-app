import 'package:flutter/material.dart';

import '../../app/app_theme.dart';

class AppShimmer extends StatefulWidget {
  const AppShimmer({
    super.key,
    required this.child,
    this.enabled = true,
    this.period = const Duration(milliseconds: 1400),
    this.baseColor,
    this.highlightColor,
  });

  final Widget child;
  final bool enabled;
  final Duration period;
  final Color? baseColor;
  final Color? highlightColor;

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.period)
      ..repeat();
  }

  @override
  void didUpdateWidget(covariant AppShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) {
      _controller
        ..duration = widget.period
        ..repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    final tokens = AppThemeTokens.of(context);
    final base = widget.baseColor ?? tokens.surfaceAlt;
    final highlight = widget.highlightColor ??
        Color.lerp(base, Colors.white, 0.6) ??
        base;

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final slide = _controller.value * 2 - 1;
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1 + slide, -0.3),
              end: Alignment(1 + slide, 0.3),
              colors: [base, highlight, base],
              stops: const [0.25, 0.5, 0.75],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
    );
  }
}

class AppShimmerBox extends StatelessWidget {
  const AppShimmerBox({
    super.key,
    required this.height,
    this.width,
    this.radius = 16,
    this.margin,
  });

  final double height;
  final double? width;
  final double radius;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: AppShimmer(
        child: Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            color: tokens.surfaceAlt,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: tokens.border),
          ),
        ),
      ),
    );
  }
}
