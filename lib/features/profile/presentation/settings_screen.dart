import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../app/navigation.dart';
import '../../../app/providers.dart';
import '../../../core/models/app_user.dart';
import '../../../core/utils/session_cleanup.dart';
import '../../../core/widgets/app_section_card.dart';
import '../../../core/widgets/app_toast.dart';
import 'package:stock_investment_flutter/app/app_icons.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notifySignals = true;
  bool _notifyAnnouncements = true;
  bool _toggleLoading = false;
  bool _announcementLoading = false;
  bool _initialized = false;
  bool _testLoading = false;
  bool _testSessionLoading = false;
  bool _deleteLoading = false;

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
        {
          'notifyNewSignals': value,
          'notifSignals': value,
        },
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

  Future<void> _toggleAnnouncements(bool value) async {
    if (_announcementLoading) {
      return;
    }
    final user = ref.read(currentUserProvider).value;
    if (user == null) {
      return;
    }
    setState(() {
      _announcementLoading = true;
      _notifyAnnouncements = value;
    });
    try {
      if (value) {
        await ref.read(notificationServiceProvider).ensurePermission();
      }
      await ref.read(userRepositoryProvider).setUserFields(
        user.uid,
        {'notifAnnouncements': value},
      );
      if (mounted) {
        AppToast.success(
          context,
          value ? 'Announcement alerts enabled.' : 'Announcement alerts paused.',
        );
      }
    } catch (error) {
      if (mounted) {
        AppToast.error(context, 'Unable to update announcement settings.');
      }
    } finally {
      if (mounted) {
        setState(() => _announcementLoading = false);
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
    final traders = ref.read(supportTradersProvider).value ?? const <AppUser>[];
    final preferredTrader = traders.firstWhere(
      (trader) => trader.role == 'trader_admin',
      orElse: () => traders.isNotEmpty ? traders.first : user,
    );
    final traderUid = preferredTrader.uid;
    if (traderUid.isEmpty) {
      if (mounted) {
        AppToast.info(context, 'No trader found for test notification.');
      }
      return;
    }
    setState(() => _testLoading = true);
    try {
      await ref.read(notificationServiceProvider).sendTestNotification(
            traderUid: traderUid,
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

  Future<void> _confirmDeleteAccount(AppUser user) async {
    if (user.role == 'admin') {
      if (mounted) {
        AppToast.info(context, 'Admins cannot delete account data here.');
      }
      return;
    }
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return const _DeleteAccountSheet();
      },
    );
    if (confirmed != true) {
      return;
    }
    if (_deleteLoading) {
      return;
    }
    setState(() => _deleteLoading = true);
    try {
      await ref.read(userRepositoryProvider).deleteUserData(user);
      await prepareForSignOut(ref);
      await ref.read(authRepositoryProvider).signOut();
      if (context.mounted) {
        AppToast.success(context, 'Account data deleted.');
        rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
      }
    } catch (_) {
      if (context.mounted) {
        AppToast.error(context, 'Unable to delete account data.');
      }
    } finally {
      if (mounted) {
        setState(() => _deleteLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final user = ref.watch(currentUserProvider).value;
    final isAdmin = user?.role == 'admin';
    if (!_initialized && user != null) {
      _notifySignals = user.notifSignals ?? user.notifyNewSignals ?? true;
      _notifyAnnouncements = user.notifAnnouncements ?? true;
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
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Announcements & highlights',
                  ),
                  subtitle:
                      const Text('Get notified about announcements and updates'),
                  value: _notifyAnnouncements,
                  onChanged: _announcementLoading || user == null
                      ? null
                      : _toggleAnnouncements,
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
                          : const Icon(AppIcons.notifications_active_outlined),
                      label: const Text('Send test signal notification'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _testSessionLoading
                          ? null
                          : () async {
                              if (_testSessionLoading) {
                                return;
                              }
                              setState(() => _testSessionLoading = true);
                              try {
                                await ref
                                    .read(notificationServiceProvider)
                                    .sendTestSessionReminder(session: 'london');
                                if (mounted) {
                                  AppToast.success(
                                    context,
                                    'Test session reminder sent.',
                                  );
                                }
                              } catch (_) {
                                if (mounted) {
                                  AppToast.error(
                                    context,
                                    'Unable to send session reminder.',
                                  );
                                }
                              } finally {
                                if (mounted) {
                                  setState(() => _testSessionLoading = false);
                                }
                              }
                            },
                      icon: _testSessionLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(AppIcons.schedule),
                      label: const Text('Send test session reminder'),
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
                const SizedBox(height: 8),
                const Text('Sign out of your account on this device.'),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                      onPressed: user == null
                        ? null
                        : () async {
                            try {
                              await prepareForSignOut(ref);
                              await ref
                                  .read(authRepositoryProvider)
                                  .signOut();
                              if (context.mounted) {
                                AppToast.success(
                                  context,
                                  'Signed out successfully.',
                                );
                                rootNavigatorKey.currentState
                                    ?.popUntil((route) => route.isFirst);
                              }
                            } catch (_) {
                              if (context.mounted) {
                                AppToast.error(
                                  context,
                                  'Unable to sign out. Try again.',
                                );
                              }
                            }
                          },
                    icon: const Icon(AppIcons.logout),
                    label: const Text('Sign out'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (isAdmin != true) ...[
            AppSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppSectionTitle(title: 'Account data'),
                  const SizedBox(height: 8),
                  const Text(
                    'Delete your profile information stored in Firestore. '
                    'Your login account will remain active.',
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: user == null || _deleteLoading
                          ? null
                          : () => _confirmDeleteAccount(user),
                      icon: _deleteLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(AppIcons.delete_outline),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.redAccent),
                      ),
                      label: const Text('Delete account data'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            'Community-generated content. Not financial advice. No guaranteed profits.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _DeleteAccountSheet extends StatefulWidget {
  const _DeleteAccountSheet();

  @override
  State<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<_DeleteAccountSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _canDelete = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        viewInsets.bottom + 16,
      ),
      child: Material(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(20),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  AppIcons.delete_forever,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Delete account data',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'This removes your profile data from Firestore. '
                'Your authentication account will remain active.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                decoration: InputDecoration(
                  labelText: 'Type DELETE to confirm',
                  filled: true,
                  fillColor: tokens.surfaceAlt,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: tokens.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 1.4,
                    ),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _canDelete = value.trim().toUpperCase() == 'DELETE';
                  });
                },
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed:
                          _canDelete ? () => Navigator.of(context).pop(true) : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                      ),
                      child: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
