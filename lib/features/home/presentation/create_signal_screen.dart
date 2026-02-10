import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/providers.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/models/signal.dart';
import '../../../core/models/trading_session_config.dart';
import '../../../core/models/vote_aggregate.dart';
import '../../../core/utils/role_helpers.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/utils/validators.dart';
import '../../../services/analytics_service.dart';
import 'package:stock_investment_flutter/app/app_icons.dart';

class CreateSignalScreen extends ConsumerStatefulWidget {
  const CreateSignalScreen({super.key});

  @override
  ConsumerState<CreateSignalScreen> createState() => _CreateSignalScreenState();
}

class _CreateSignalScreenState extends ConsumerState<CreateSignalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _entryPriceController = TextEditingController();
  final _entryMinController = TextEditingController();
  final _entryMaxController = TextEditingController();
  final _stopLossController = TextEditingController();
  final _tp1Controller = TextEditingController();
  final _tp2Controller = TextEditingController();
  final _reasoningController = TextEditingController();
  final _tagsController = TextEditingController();

  String? _pair;
  String? _direction;
  String? _entryType;
  String? _riskLevel;
  String? _session;
  TimeOfDay? _validUntilTime;
  File? _imageFile;
  bool _useEntryRange = false;
  bool _premiumOnly = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _entryPriceController.dispose();
    _entryMinController.dispose();
    _entryMaxController.dispose();
    _stopLossController.dispose();
    _tp1Controller.dispose();
    _tp2Controller.dispose();
    _reasoningController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  bool _validateEntry(double? entryPrice, double? entryMin, double? entryMax) {
    if (_useEntryRange) {
      if (entryMin == null || entryMax == null) {
        _error = 'Entry range is required.';
        return false;
      }
      if (entryMin > entryMax) {
        _error = 'Entry range min must be <= max.';
        return false;
      }
      return true;
    }
    if (entryPrice == null) {
      _error = 'Entry price is required.';
      return false;
    }
    return true;
  }

  bool _validateRiskLogic({
    required double entryPoint,
    required double stopLoss,
    required double tp1,
    required String direction,
  }) {
    if (direction == 'Buy') {
      if (tp1 <= entryPoint || stopLoss >= entryPoint) {
        _error = 'For buys, TP must be above entry and SL below entry.';
        return false;
      }
    } else if (direction == 'Sell') {
      if (tp1 >= entryPoint || stopLoss <= entryPoint) {
        _error = 'For sells, TP must be below entry and SL above entry.';
        return false;
      }
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_pair == null ||
        _direction == null ||
        _entryType == null ||
        _riskLevel == null ||
        _session == null) {
      setState(() => _error = 'Please complete all required selections.');
      return;
    }
    if (_validUntilTime == null) {
      setState(() => _error = 'Please select a valid until time.');
      return;
    }

    final entryPrice = double.tryParse(_entryPriceController.text.trim());
    final entryMin = double.tryParse(_entryMinController.text.trim());
    final entryMax = double.tryParse(_entryMaxController.text.trim());
    final stopLoss = double.tryParse(_stopLossController.text.trim());
    final tp1 = double.tryParse(_tp1Controller.text.trim());
    final tp2 = double.tryParse(_tp2Controller.text.trim());

    if (stopLoss == null || tp1 == null) {
      setState(() => _error = 'Stop loss and TP1 are required.');
      return;
    }

    if (!_validateEntry(entryPrice, entryMin, entryMax)) {
      setState(() {});
      return;
    }

    final entryPoint =
        _useEntryRange ? ((entryMin! + entryMax!) / 2) : entryPrice!;

    if (!_validateRiskLogic(
      entryPoint: entryPoint,
      stopLoss: stopLoss,
      tp1: tp1,
      direction: _direction!,
    )) {
      setState(() {});
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final user = ref.read(currentUserProvider).value;
    if (user == null) {
      setState(() {
        _loading = false;
        _error = 'You must be signed in.';
      });
      return;
    }

    String? imageUrl;
    if (_imageFile != null) {
      imageUrl = await ref.read(storageServiceProvider).uploadSignalImage(
            uid: user.uid,
            file: _imageFile!,
          );
    }

    final tags = _tagsController.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();

    final validUntil = _resolveValidUntil(_validUntilTime!);

    final signal = Signal(
      id: '',
      uid: user.uid,
      posterNameSnapshot: user.displayName,
      posterVerifiedSnapshot: user.isVerified,
      pair: _pair!,
      direction: _direction!,
      entryType: _entryType!,
      entryPrice: _useEntryRange ? null : entryPrice,
      entryRange:
          _useEntryRange ? EntryRange(min: entryMin!, max: entryMax!) : null,
      stopLoss: stopLoss,
      tp1: tp1,
      tp2: tp2,
      premiumOnly: _premiumOnly,
      riskLevel: _riskLevel!,
      session: _session!,
      validUntil: validUntil,
      reasoning: _reasoningController.text.trim(),
      tags: tags,
      imageUrl: imageUrl,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: 'open',
      voteAgg: VoteAggregate.empty(),
      resolvedBy: null,
      resolvedAt: null,
      finalOutcome: null,
      likesCount: 0,
      dislikesCount: 0,
    );

    try {
      await ref.read(signalRepositoryProvider).createSignal(signal);
      AnalyticsService.instance.logEvent(
        'signal_create',
        params: {
          'pair': signal.pair,
          'direction': signal.direction,
        },
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final isActiveTrader =
        user != null && isTrader(user.role) && user.traderStatus == 'active';

    if (!isActiveTrader) {
      return const Scaffold(
        body: Center(child: Text('Only active traders can create signals.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Create signal')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSessionConfigBanner(),
              DropdownButtonFormField<String>(
                value: _pair,
                decoration: const InputDecoration(labelText: 'Pair'),
                items: AppConstants.instruments
                    .map((pair) =>
                        DropdownMenuItem(value: pair, child: Text(pair)))
                    .toList(),
                onChanged: (value) => setState(() => _pair = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _direction,
                decoration: const InputDecoration(labelText: 'Direction'),
                items: AppConstants.directionOptions
                    .map((direction) => DropdownMenuItem(
                        value: direction, child: Text(direction)))
                    .toList(),
                onChanged: (value) => setState(() => _direction = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _entryType,
                decoration: const InputDecoration(labelText: 'Entry type'),
                items: AppConstants.entryTypes
                    .map((entry) =>
                        DropdownMenuItem(value: entry, child: Text(entry)))
                    .toList(),
                onChanged: (value) => setState(() => _entryType = value),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Mark as premium signal'),
                subtitle: const Text('Premium signals hide entry, SL, TP, and reason.'),
                value: _premiumOnly,
                onChanged: (value) => setState(() => _premiumOnly = value),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Use entry range'),
                value: _useEntryRange,
                onChanged: (value) => setState(() => _useEntryRange = value),
              ),
              const SizedBox(height: 12),
              if (_useEntryRange)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _entryMinController,
                        decoration:
                            const InputDecoration(labelText: 'Entry min'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _entryMaxController,
                        decoration:
                            const InputDecoration(labelText: 'Entry max'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                )
              else
                TextFormField(
                  controller: _entryPriceController,
                  decoration: const InputDecoration(labelText: 'Entry price'),
                  keyboardType: TextInputType.number,
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _stopLossController,
                decoration: const InputDecoration(labelText: 'Stop loss'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tp1Controller,
                decoration: const InputDecoration(labelText: 'Take profit 1'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tp2Controller,
                decoration: const InputDecoration(labelText: 'Take profit 2'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _riskLevel,
                decoration: const InputDecoration(labelText: 'Risk level'),
                items: AppConstants.riskLevels
                    .map((risk) =>
                        DropdownMenuItem(value: risk, child: Text(risk)))
                    .toList(),
                onChanged: (value) => setState(() => _riskLevel = value),
              ),
              const SizedBox(height: 12),
              _buildSessionPicker(),
              const SizedBox(height: 12),
              _buildValidityPicker(),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reasoningController,
                decoration: const InputDecoration(labelText: 'Reasoning'),
                maxLength: 300,
                validator: (value) => validateRequired(value, 'Reasoning'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags (comma separated)',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(AppIcons.image),
                label: Text(_imageFile == null
                    ? 'Upload chart image'
                    : 'Replace image'),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child:
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Text('Publish signal'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionConfigBanner() {
    final sessionConfigState = ref.watch(tradingSessionConfigProvider);
    final config = sessionConfigState.asData?.value;
    final missingConfig = config == null || config.updatedAt == null;
    if (sessionConfigState.hasError) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          'Session settings unavailable. Using default sessions.',
          style: const TextStyle(color: Colors.orange),
        ),
      );
    }
    if (missingConfig) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          'Session settings not saved yet. Using default sessions.',
          style: const TextStyle(color: Colors.orange),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildSessionPicker() {
    final sessionConfigState = ref.watch(tradingSessionConfigProvider);
    final config = sessionConfigState.asData?.value ??
        TradingSessionConfig.fallback();
    final enabledSessions = config.enabledSessionsOrdered();
    final sessions = enabledSessions.isNotEmpty
        ? enabledSessions
        : TradingSessionConfig.fallback().enabledSessionsOrdered();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _session,
          decoration: const InputDecoration(labelText: 'Session'),
          items: sessions
              .map(
                (session) => DropdownMenuItem(
                  value: session.key,
                  child: Text(session.label),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _session = value),
        ),
      ],
    );
  }

  Widget _buildValidityPicker() {
    final now = DateTime.now();
    final selected = _validUntilTime;
    final resolved =
        selected != null ? _resolveValidUntil(selected, now: now) : null;
    final durationLabel = resolved != null
        ? _formatDuration(resolved.difference(now))
        : null;
    final previewExpiration = resolved != null
        ? formatTanzaniaDateTime(resolved)
        : null;
    final displayTime = selected != null
        ? MaterialLocalizations.of(context).formatTimeOfDay(selected)
        : 'Select time';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _pickValidityTime,
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Valid until time'),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(displayTime),
                const Icon(Icons.access_time, size: 18),
              ],
            ),
          ),
        ),
        if (durationLabel != null) ...[
          const SizedBox(height: 6),
          Text(
            'Valid for $durationLabel.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (previewExpiration != null)
            Text(
              'Expires at: $previewExpiration (Tanzania time)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ],
    );
  }

  Future<void> _pickValidityTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _validUntilTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _validUntilTime = picked;
      });
    }
  }

  DateTime _resolveValidUntil(TimeOfDay time, {DateTime? now}) {
    final base = now ?? DateTime.now();
    var candidate = DateTime(
      base.year,
      base.month,
      base.day,
      time.hour,
      time.minute,
    );
    if (!candidate.isAfter(base)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    }
    if (hours > 0) {
      return '${hours}h';
    }
    return '${minutes}m';
  }
}
