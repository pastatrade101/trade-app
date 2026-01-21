import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/utils/role_helpers.dart';
import '../../../core/widgets/firestore_error_widget.dart';
import 'revenue_screen.dart';

class TraderAdminRevenueShell extends ConsumerWidget {
  const TraderAdminRevenueShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(currentUserProvider);
    return profileState.when(
      data: (profile) {
        if (profile == null) {
          return const _RevenueLoadingScaffold();
        }
        if (!isAdminOrTraderAdmin(profile.role)) {
          return const Scaffold(
            body: Center(child: Text('Access denied.')),
          );
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Revenue')),
          body: const RevenueScreen(),
        );
      },
      loading: () => const _RevenueLoadingScaffold(),
      error: (error, stack) => Scaffold(
        body: Center(
          child: FirestoreErrorWidget(
            error: error,
            stackTrace: stack,
            title: 'Unable to load profile',
          ),
        ),
      ),
    );
  }
}

class _RevenueLoadingScaffold extends StatelessWidget {
  const _RevenueLoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
