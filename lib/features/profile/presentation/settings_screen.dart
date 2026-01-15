import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation.dart';
import '../../../app/providers.dart';
import '../../../core/widgets/app_section_card.dart';
import '../../../core/widgets/app_toast.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const String _testTraderUid = 'ZBUVtvpHzrT4MkgpPbVSFb2bCJw1';

  bool _notifySignals = true;
  bool _toggleLoading = false;
  bool _initialized = false;
  bool _testLoading = false;
  bool _signOutLoading = false;

  Future<void> _toggleNotifications(bool value) async {
    if (_toggleLoading) {
      return;
    }
    final user = ref.read(currentUserProvider).value;
    if (user == null) {
      return;
    }
    setState(() {
      _toggleLoading = true;
      _notifySignals = value;
    });
    try {
      if (value) {
        await ref.read(notificationServiceProvider).ensurePermission();
      }
      await ref.read(userRepositoryProvider).setUserFields(
        user.uid,
        {'notifyNewSignals': value},
      );
      if (mounted) {
        AppToast.success(
          context,
          value
              ? 'Notifications enabled.'
              : 'Notifications paused.',
        );
      }
    } catch (error) {
      if (mounted) {
        AppToast.error(context, 'Unable to update notification settings.');
      }
    } finally {
      if (mounted) {
        setState(() => _toggleLoading = false);
      }
    }
  }

  Future<void> _sendTestSignalNotification() async {
    if (_testLoading) {
      return;
    }
    final user = ref.read(currentUserProvider).value;
    if (user == null) {
      return;
    }
    setState(() => _testLoading = true);
    try {
      await ref.read(notificationServiceProvider).sendTestNotification(
            traderUid: _testTraderUid,
          );
      if (mounted) {
        AppToast.success(context, 'Test signal notification sent.');
      }
    } catch (_) {
      if (mounted) {
        AppToast.error(context, 'Unable to send test notification.');
      }
    } finally {
      if (mounted) {
        setState(() => _testLoading = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final user = ref.watch(currentUserProvider).value;
    final isAdmin = user?.role == 'admin';
    if (!_initialized && user != null) {
      _notifySignals = user.notifyNewSignals ?? true;
      _initialized = true;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSectionTitle(title: 'Appearance'),
                const SizedBox(height: 12),
                RadioListTile<ThemeMode>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('System'),
                  subtitle: const Text('Match device appearance'),
                  value: ThemeMode.system,
                  groupValue: themeMode,
                  onChanged: (mode) {
                    if (mode != null) {
                      ref.read(themeModeProvider.notifier).setThemeMode(mode);
                    }
                  },
                ),
                RadioListTile<ThemeMode>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Light'),
                  subtitle: const Text('Bright background for daytime use'),
                  value: ThemeMode.light,
                  groupValue: themeMode,
                  onChanged: (mode) {
                    if (mode != null) {
                      ref.read(themeModeProvider.notifier).setThemeMode(mode);
                    }
                  },
                ),
                RadioListTile<ThemeMode>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Dark'),
                  subtitle: const Text('Low-glare trading focus'),
                  value: ThemeMode.dark,
                  groupValue: themeMode,
                  onChanged: (mode) {
                    if (mode != null) {
                      ref.read(themeModeProvider.notifier).setThemeMode(mode);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSectionTitle(title: 'Notifications'),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Notify me about new signals',
                  ),
                  subtitle: const Text('Get alerted when new signals go live'),
                  value: _notifySignals,
                  onChanged: _toggleLoading || user == null
                      ? null
                      : _toggleNotifications,
                ),
                if (isAdmin == true) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed:
                          _testLoading ? null : _sendTestSignalNotification,
                      icon: _testLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.notifications_active_outlined),
                      label: const Text('Send test signal notification'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSectionTitle(title: 'Account'),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _signOutLoading
                      ? null
                      : () async {
                          setState(() => _signOutLoading = true);
                          try {
                            await ref.read(authRepositoryProvider).signOut();
                            if (context.mounted) {
                              AppToast.success(
                                  context, 'Signed out successfully.');
                              rootNavigatorKey.currentState
                                  ?.popUntil((route) => route.isFirst);
                            }
                          } catch (error) {
                            if (context.mounted) {
                              AppToast.error(
                                  context, 'Unable to sign out. Try again.');
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _signOutLoading = false);
                            }
                          }
                        },
                  child: _signOutLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Sign out'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Community-generated content. Not financial advice. No guaranteed profits.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
