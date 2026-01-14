import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/highlight.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_section_card.dart';
import '../../../core/widgets/app_toast.dart';

class HighlightManagerScreen extends ConsumerStatefulWidget {
  const HighlightManagerScreen({super.key});

  @override
  ConsumerState<HighlightManagerScreen> createState() =>
      _HighlightManagerScreenState();
}

class _HighlightManagerScreenState extends ConsumerState<HighlightManagerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _targetIdController = TextEditingController();

  String _dateKey = tanzaniaDateKey();
  String _type = 'signal';
  bool _isActive = true;
  bool _loading = false;
  bool _loadingHighlight = false;
  bool _loadingTargets = false;
  DailyHighlight? _currentHighlight;
  String? _selectedTargetId;
  List<HighlightTargetOption> _targets = const [];

  @override
  void initState() {
    super.initState();
    _loadHighlight();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _targetIdController.dispose();
    super.dispose();
  }

  Future<void> _loadHighlight() async {
    setState(() => _loadingHighlight = true);
    try {
      final highlight = await ref
          .read(highlightRepositoryProvider)
          .fetchHighlightByDate(_dateKey);
      if (!mounted) return;
      setState(() {
        _currentHighlight = highlight;
        _type = highlight?.type ?? _type;
        _isActive = highlight?.isActive ?? true;
        _titleController.text = highlight?.title ?? '';
        _subtitleController.text = highlight?.subtitle ?? '';
        _targetIdController.text = highlight?.targetId ?? '';
        _selectedTargetId = highlight?.targetId;
      });
      await _loadTargets(preferredId: highlight?.targetId);
    } catch (_) {
      if (mounted) {
        AppToast.error(context, 'Unable to load highlight');
      }
    } finally {
      if (mounted) {
        setState(() => _loadingHighlight = false);
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;
    final newKey = tanzaniaDateKey(picked);
    if (newKey == _dateKey) return;
    setState(() => _dateKey = newKey);
    await _loadHighlight();
  }

  Future<void> _loadTargets({String? preferredId}) async {
    if (!mounted) return;
    setState(() => _loadingTargets = true);
    try {
      List<HighlightTargetOption> options = [];
      switch (_type) {
        case 'tip':
          final tips = await ref
              .read(tipRepositoryProvider)
              .fetchLatestTips(status: 'published', limit: 50);
          options = tips
              .map((tip) => HighlightTargetOption(
                    id: tip.id,
                    title: tip.title,
                    subtitle:
                        '${tip.type} • ${formatTanzaniaDateTime(tip.createdAt)}',
                  ))
              .toList();
          break;
        case 'trader':
          final traders = await ref.read(userRepositoryProvider).fetchTraders(
                orderField: 'createdAt',
                descending: true,
                limit: 50,
              );
          options = traders
              .map((trader) => HighlightTargetOption(
                    id: trader.uid,
                    title: _displayName(trader),
                    subtitle:
                        trader.username.isNotEmpty ? '@${trader.username}' : '',
                  ))
              .toList();
          break;
        case 'signal':
        default:
          final signals = await ref
              .read(signalRepositoryProvider)
              .fetchLatestSignals(
                statuses: const [
                  'open',
                  'resolved',
                  'expired_unverified',
                ],
                limit: 50,
              );
          options = signals
              .map((signal) => HighlightTargetOption(
                    id: signal.id,
                    title: '${signal.pair} ${signal.direction}',
                    subtitle:
                        '${signal.session} • ${formatTanzaniaDateTime(signal.createdAt)}',
                  ))
              .toList();
      }

      if (preferredId != null &&
          preferredId.isNotEmpty &&
          !options.any((option) => option.id == preferredId)) {
        options = [
          HighlightTargetOption(
            id: preferredId,
            title: 'Current selection',
            subtitle: preferredId,
          ),
          ...options,
        ];
      }

      if (!mounted) return;
      setState(() {
        _targets = options;
        if (preferredId != null && preferredId.isNotEmpty) {
          _selectedTargetId = preferredId;
          _targetIdController.text = preferredId;
        } else if (options.isNotEmpty) {
          _selectedTargetId = options.first.id;
          _targetIdController.text = options.first.id;
        } else {
          _selectedTargetId = null;
        }
      });
    } catch (_) {
      if (mounted) {
        AppToast.error(context, 'Unable to load targets');
      }
    } finally {
      if (mounted) {
        setState(() => _loadingTargets = false);
      }
    }
  }

  Future<void> _onTypeChanged(String? value) async {
    if (value == null || value == _type) return;
    setState(() {
      _type = value;
      _targets = const [];
      _selectedTargetId = null;
      _targetIdController.text = '';
    });
    await _loadTargets();
  }

  Widget _buildTargetField() {
    if (_loadingTargets) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          LinearProgressIndicator(),
          SizedBox(height: 8),
          Text('Loading targets...'),
        ],
      );
    }

    if (_targets.isNotEmpty) {
      return DropdownButtonFormField<String>(
        value: _selectedTargetId,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Target',
          helperText: 'Select the item to highlight',
        ),
        items: _targets
            .map(
              (option) => DropdownMenuItem<String>(
                value: option.id,
                child: _buildTargetDropdownItem(option),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value == null) return;
          setState(() => _selectedTargetId = value);
          _targetIdController.text = value;
        },
        validator: (value) =>
            value == null || value.trim().isEmpty ? 'Target is required' : null,
      );
    }

    return TextFormField(
      controller: _targetIdController,
      decoration: const InputDecoration(
        labelText: 'Target ID',
        helperText: 'Signal ID, Tip ID, or Trader UID',
      ),
      validator: (value) => value == null || value.trim().isEmpty
          ? 'Target ID is required'
          : null,
    );
  }

  Widget _buildTargetDropdownItem(HighlightTargetOption option) {
    final label = option.subtitle.isNotEmpty
        ? '${option.title} • ${option.subtitle}'
        : option.title;
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }

  String _displayName(AppUser user) {
    if (user.displayName.isNotEmpty) {
      return user.displayName;
    }
    if (user.username.isNotEmpty) {
      return user.username;
    }
    return user.uid;
  }

  Future<void> _save() async {
    if (_loading) return;
    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid) return;
    setState(() => _loading = true);
    try {
      final highlight = DailyHighlight(
        id: _dateKey,
        type: _type,
        targetId: _targetIdController.text.trim(),
        title: _titleController.text.trim(),
        subtitle: _subtitleController.text.trim(),
        dateKey: _dateKey,
        isActive: _isActive,
        createdAt: _currentHighlight?.createdAt,
        updatedAt: DateTime.now(),
      );
      await ref.read(highlightRepositoryProvider).saveHighlight(highlight);
      if (mounted) {
        AppToast.success(context, 'Highlight saved');
      }
    } catch (error) {
      if (mounted) {
        AppToast.error(context, 'Unable to save highlight');
      }
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
        user?.role == 'trader' && user?.traderStatus == 'active';
    if (user == null || !isActiveTrader) {
      return const Scaffold(
        body: Center(child: Text('Trader access required.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Daily highlight')),
      body: _loadingHighlight
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AppSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppSectionTitle(title: 'Date'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _dateKey,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _pickDate,
                              icon: const Icon(Icons.calendar_today),
                              label: const Text('Change'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'One highlight per day. Saving updates this date.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppSectionTitle(title: 'Highlight'),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _type,
                          decoration: const InputDecoration(labelText: 'Type'),
                          items: const [
                            DropdownMenuItem(
                              value: 'signal',
                              child: Text('Signal'),
                            ),
                            DropdownMenuItem(
                              value: 'tip',
                              child: Text('Tip'),
                            ),
                            DropdownMenuItem(
                              value: 'trader',
                              child: Text('Trader'),
                            ),
                          ],
                          onChanged: _onTypeChanged,
                        ),
                        const SizedBox(height: 12),
                        _buildTargetField(),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _titleController,
                          maxLength: 80,
                          decoration:
                              const InputDecoration(labelText: 'Title'),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Title is required'
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _subtitleController,
                          maxLength: 140,
                          decoration:
                              const InputDecoration(labelText: 'Subtitle'),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Subtitle is required'
                                  : null,
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _isActive,
                          title: const Text('Active'),
                          onChanged: (value) => setState(() {
                            _isActive = value;
                          }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _save,
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save highlight'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class HighlightTargetOption {
  const HighlightTargetOption({
    required this.id,
    required this.title,
    required this.subtitle,
  });

  final String id;
  final String title;
  final String subtitle;
}
