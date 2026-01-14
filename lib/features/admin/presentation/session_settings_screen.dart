import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/models/trading_session_config.dart';
import '../../../core/widgets/app_toast.dart';

class SessionSettingsScreen extends ConsumerStatefulWidget {
  const SessionSettingsScreen({super.key});

  @override
  ConsumerState<SessionSettingsScreen> createState() =>
      _SessionSettingsScreenState();
}

class _SessionSettingsScreenState extends ConsumerState<SessionSettingsScreen> {
  final Map<String, TextEditingController> _durationControllers = {};
  final Map<String, bool> _enabled = {};
  DateTime? _lastUpdatedAt;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in _durationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _syncWithConfig(TradingSessionConfig config) {
    if (_lastUpdatedAt == config.updatedAt && _durationControllers.isNotEmpty) {
      return;
    }
    for (final key in tradingSessionKeys) {
      final session = config.sessions[key] ??
          TradingSession(
            key: key,
            label: tradingSessionLabels[key] ?? key,
            enabled: true,
            durationMinutes: defaultSessionDurationMinutes,
          );
      _durationControllers[key] ??=
          TextEditingController(text: session.durationMinutes.toString());
      _enabled[key] = session.enabled;
    }
    _lastUpdatedAt = config.updatedAt;
  }

  Future<void> _save(TradingSessionConfig config) async {
    setState(() {
      _error = null;
      _saving = true;
    });
    final updatedSessions = <String, TradingSession>{};
    for (final key in tradingSessionKeys) {
      final controller = _durationControllers[key];
      final duration = int.tryParse(controller?.text.trim() ?? '');
      if (duration == null || duration < 30 || duration > 480) {
        setState(() {
          _saving = false;
          _error = 'Duration for ${config.labelFor(key)} must be 30-480 minutes.';
        });
        return;
      }
      final existing = config.sessions[key];
      updatedSessions[key] = TradingSession(
        key: key,
        label: existing?.label ?? tradingSessionLabels[key] ?? key,
        enabled: _enabled[key] ?? true,
        durationMinutes: duration,
      );
    }

    final updatedConfig = TradingSessionConfig(
      timezone: config.timezone,
      sessions: updatedSessions,
      updatedAt: config.updatedAt,
    );

    try {
      await ref
          .read(tradingSessionRepositoryProvider)
          .updateConfig(updatedConfig);
      if (mounted) {
        AppToast.success(context, 'Session settings saved.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
        AppToast.error(context, 'Unable to save session settings.');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final configState = ref.watch(tradingSessionConfigProvider);
    final config = configState.asData?.value ?? TradingSessionConfig.fallback();
    _syncWithConfig(config);

    return Scaffold(
      appBar: AppBar(title: const Text('Session settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Timezone: ${config.timezone}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          ...tradingSessionKeys.map((key) {
            final session = config.sessions[key] ??
                TradingSession(
                  key: key,
                  label: tradingSessionLabels[key] ?? key,
                  enabled: true,
                  durationMinutes: defaultSessionDurationMinutes,
                );
            final controller = _durationControllers[key]!;
            final enabled = _enabled[key] ?? session.enabled;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            session.label,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Switch(
                          value: enabled,
                          onChanged: (value) =>
                              setState(() => _enabled[key] = value),
                        ),
                      ],
                    ),
                    TextFormField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Duration (minutes)',
                        helperText: '30 to 480 minutes',
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          if (_error != null)
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : () => _save(config),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save settings'),
            ),
          ),
        ],
      ),
    );
  }
}
