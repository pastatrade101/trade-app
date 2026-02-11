import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';

class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.step,
    this.totalSteps = 3,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.actions,
  });

  final int step;
  final int totalSteps;
  final String title;
  final String subtitle;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final actionWidgets = <Widget>[];
    for (var i = 0; i < actions.length; i += 1) {
      actionWidgets.add(actions[i]);
      if (i != actions.length - 1) {
        actionWidgets.add(const SizedBox(height: 8));
      }
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StepIndicator(step: step, total: totalSteps),
              const SizedBox(height: 24),
              Text(
                title,
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: textTheme.bodyMedium?.copyWith(color: tokens.mutedText),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: body,
                ),
              ),
              const SizedBox(height: 16),
              ...actionWidgets,
            ],
          ),
        ),
      ),
    );
  }
}

class StepIndicator extends StatelessWidget {
  const StepIndicator({
    super.key,
    required this.step,
    this.total = 3,
  });

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          'Step $step of $total',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            children: List.generate(total, (index) {
              final isActive = index < step;
              return Expanded(
                child: Container(
                  height: 6,
                  margin: EdgeInsets.only(right: index == total - 1 ? 0 : 6),
                  decoration: BoxDecoration(
                    color: isActive
                        ? colorScheme.primary
                        : colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
