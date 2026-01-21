import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../../core/widgets/app_toast.dart';
import '../../premium/models/global_offer.dart';
import 'package:stock_investment_flutter/app/app_icons.dart';

class GlobalOfferSettingsScreen extends ConsumerStatefulWidget {
  const GlobalOfferSettingsScreen({super.key});

  @override
  ConsumerState<GlobalOfferSettingsScreen> createState() =>
      _GlobalOfferSettingsScreenState();
}

class _GlobalOfferSettingsScreenState
    extends ConsumerState<GlobalOfferSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _trialController = TextEditingController();
  final _discountController = TextEditingController();
  bool _isActive = false;
  GlobalOfferType _type = GlobalOfferType.trial;
  DateTime? _startsAt;
  DateTime? _endsAt;
  int _lastSyncedKey = -1;
  bool _loading = false;

  @override
  void dispose() {
    _labelController.dispose();
    _trialController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  void _scheduleOfferSync(GlobalOffer? offer) {
    final nextKey = offer?.updatedAt?.millisecondsSinceEpoch ?? 0;
    if (_lastSyncedKey == nextKey) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _applyOffer(offer, nextKey);
    });
  }

  void _applyOffer(GlobalOffer? offer, int nextKey) {
    _lastSyncedKey = nextKey;
    _labelController.text = offer?.label ?? '';
    _isActive = offer?.isActive ?? false;
    _type = offer?.type ?? GlobalOfferType.trial;
    _trialController.text =
        offer != null && offer.trialDays > 0 ? '${offer.trialDays}' : '';
    _discountController.text = offer != null && offer.discountPercent > 0
        ? offer.discountPercent.toStringAsFixed(0)
        : '';
    _startsAt = offer?.startsAt;
    _endsAt = offer?.endsAt;
    setState(() {});
  }

  Future<DateTime?> _pickDateTime(DateTime? current) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (date == null) {
      return null;
    }
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current ?? now),
    );
    if (pickedTime == null) {
      return DateTime(
        date.year,
        date.month,
        date.day,
        current?.hour ?? DateTime.now().hour,
        current?.minute ?? DateTime.now().minute,
      );
    }
    return DateTime(
      date.year,
      date.month,
      date.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  Future<void> _saveOffer() async {
    if (_loading) {
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final label = _labelController.text.trim();
    if (label.isEmpty) {
      AppToast.error(context, 'Label is required.');
      return;
    }
    final startAt = _startsAt ?? DateTime.now();
    final trialDays = int.tryParse(_trialController.text) ?? 0;
    final discountPercent = double.tryParse(_discountController.text) ?? 0.0;
    if (_type == GlobalOfferType.trial && trialDays <= 0) {
      AppToast.error(context, 'Enter the trial duration in days.');
      return;
    }
    if (_type == GlobalOfferType.discount &&
        (discountPercent <= 0 || discountPercent > 100)) {
      AppToast.error(context, 'Enter a discount between 1 and 100.');
      return;
    }
    if (_endsAt != null && _endsAt!.isBefore(startAt)) {
      AppToast.error(context, 'End date must be after the start date.');
      return;
    }
    final payload = <String, dynamic>{
      'label': label,
      'isActive': _isActive,
      'type': _type == GlobalOfferType.discount ? 'discount' : 'trial',
      'trialDays': _type == GlobalOfferType.trial ? trialDays : 0,
      'discountPercent':
          _type == GlobalOfferType.discount ? discountPercent : 0,
      'startsAt': startAt,
      'endsAt': _endsAt,
    };

    setState(() => _loading = true);
    try {
      await ref.read(globalOfferRepositoryProvider).setOffer(payload);
      AppToast.success(context, 'Global offer saved.');
    } catch (error) {
      AppToast.error(context, 'Unable to save offer. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return 'Not set';
    }
    return DateFormat.yMMMd().add_jm().format(value);
  }

  Widget _buildDateTile({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    final tokens = AppThemeTokens.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        label == 'Ends at'
            ? AppIcons.stop_circle_outlined
            : AppIcons.calendar_today,
        color: Theme.of(context).colorScheme.primary,
      ),
      tileColor: tokens.surfaceAlt,
      title: Text(label),
      subtitle: Text(
        _formatDateTime(value),
        style: TextStyle(color: tokens.mutedText),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: onTap,
            child: const Text('Set'),
          ),
          if (onClear != null)
            IconButton(
              icon: const Icon(AppIcons.close),
              tooltip: 'Clear',
              onPressed: onClear,
            ),
        ],
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final config = ref.watch(globalOfferConfigProvider);
    if (config.hasValue) {
      _scheduleOfferSync(config.value);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trials & offers'),
        actions: [
          if (config.hasError)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                final _ = ref.refresh(globalOfferConfigProvider);
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (config.isLoading) const LinearProgressIndicator(),
            if (config.hasError)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Unable to load current offer.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SwitchListTile(
                        title: const Text('Offer is active'),
                        subtitle: const Text(
                          'Toggle availability without deleting the rule.',
                        ),
                        value: _isActive,
                        onChanged: (value) => setState(() => _isActive = value),
                      ),
                      const SizedBox(height: 12),
                      ToggleButtons(
                        isSelected: [
                          _type == GlobalOfferType.trial,
                          _type == GlobalOfferType.discount,
                        ],
                        onPressed: (index) {
                          setState(() {
                            _type = index == 0
                                ? GlobalOfferType.trial
                                : GlobalOfferType.discount;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        selectedColor: Theme.of(context).colorScheme.onPrimary,
                        fillColor: Theme.of(context).colorScheme.primary,
                        color: tokens.mutedText,
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            child: Text('Trial'),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            child: Text('Discount'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _type == GlobalOfferType.trial
                            ? 'Trial grants premium for a fixed number of days.'
                            : 'Discount applies to every premium plan.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: tokens.mutedText,
                            ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _labelController,
                        decoration: const InputDecoration(
                          labelText: 'Offer label',
                          hintText: 'e.g. 7-Day Free Trial',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Label is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      if (_type == GlobalOfferType.trial) ...[
                        TextFormField(
                          controller: _trialController,
                          decoration: const InputDecoration(
                            labelText: 'Trial days',
                            hintText: 'Enter number of days',
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (value) {
                            final parsed = int.tryParse(value ?? '');
                            if (parsed == null || parsed <= 0) {
                              return 'Enter at least 1 day';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ] else ...[
                        TextFormField(
                          controller: _discountController,
                          decoration: const InputDecoration(
                            labelText: 'Discount %',
                            hintText: 'Enter a percentage between 1 and 100',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^(\d+)?\.?\d{0,2}'),
                            ),
                          ],
                          validator: (value) {
                            final parsed = double.tryParse(value ?? '');
                            if (parsed == null || parsed <= 0 || parsed > 100) {
                              return 'Enter a valid discount';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        'Schedule',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      _buildDateTile(
                        label: 'Starts at',
                        value: _startsAt,
                        onTap: () async {
                          final picked = await _pickDateTime(_startsAt);
                          if (picked != null) {
                            setState(() => _startsAt = picked);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildDateTile(
                        label: 'Ends at',
                        value: _endsAt,
                        onTap: () async {
                          final picked = await _pickDateTime(_endsAt);
                          if (picked != null) {
                            setState(() => _endsAt = picked);
                          }
                        },
                        onClear: () {
                          setState(() => _endsAt = null);
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _saveOffer,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save offer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
