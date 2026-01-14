import 'package:flutter/material.dart';

import '../../app/app_theme.dart';

class AppSectionCard extends StatelessWidget {
  const AppSectionCard({
    super.key,
    required this.child,
    this.padding,
    this.useShadow = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool useShadow;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.border),
        boxShadow: useShadow
            ? [
                BoxShadow(
                  color: tokens.shadow,
                  blurRadius: 18,
                  offset: const Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

class AppSectionTitle extends StatelessWidget {
  const AppSectionTitle({
    super.key,
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Text(
      title,
      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}
