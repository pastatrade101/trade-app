import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../../core/models/product.dart';
import '../../../core/repositories/payment_repository.dart';
import '../../../core/widgets/app_toast.dart';
import 'payment_status_screen.dart';
import '../../../services/analytics_service.dart';
import 'package:stock_investment_flutter/app/app_icons.dart';

class PaymentMethodScreen extends ConsumerStatefulWidget {
  const PaymentMethodScreen({
    super.key,
    required this.product,
    this.initialProvider,
  });

  final Product product;
  final String? initialProvider;

  @override
  ConsumerState<PaymentMethodScreen> createState() =>
      _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends ConsumerState<PaymentMethodScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _phoneFieldKey = GlobalKey();
  final _phoneFocusNode = FocusNode();
  final _scrollController = ScrollController();
  late String _provider;
  bool _loading = false;
  static const double _bottomBarHeight = 84;
  static const double _keyboardExtraPadding = 120;

  @override
  void initState() {
    super.initState();
    _provider = widget.initialProvider ?? 'mixx';
    _phoneFocusNode.addListener(() {
      if (_phoneFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 140), () {
          if (!mounted) return;
          _scrollIntoView();
          _scrollToBottom();
        });
      }
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollIntoView() {
    final context = _phoneFieldKey.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      alignment: 0.2,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    final target = position.maxScrollExtent + _keyboardExtraPadding;
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _submit() async {
    if (_loading) {
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _loading = true);
    final selectedMethod = _methods.firstWhere(
      (method) => method.provider == _provider,
      orElse: () => _methods.first,
    );
    final phone = _phoneController.text.trim();
    await AnalyticsService.instance.logEvent(
      'premium_start_checkout',
      params: {
        'provider': _provider,
        'planId': widget.product.id,
        'amount': widget.product.price,
      },
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PaymentStatusScreen(
          intentId: null,
          product: widget.product,
          provider: _provider,
          providerLabel: selectedMethod.label,
          accountNumber: phone,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final user = ref.watch(currentUserProvider).value;
    if (user != null && _phoneController.text.isEmpty) {
      _phoneController.text = user.phoneNumber ?? '';
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Payment method')),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 +
                  MediaQuery.of(context).viewInsets.bottom +
                  (MediaQuery.of(context).viewInsets.bottom > 0
                      ? _keyboardExtraPadding
                      : _bottomBarHeight),
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              Text(
                'Select mobile money',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              ..._methods.map(
                (method) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: RadioListTile<String>(
                    value: method.provider,
                    groupValue: _provider,
                    onChanged: (value) =>
                        setState(() => _provider = value ?? _provider),
                    secondary: _BrandBadge(
                      color: method.color,
                      icon: method.icon,
                    ),
                    title: Text(method.label),
                    subtitle: Text(
                      method.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: tokens.mutedText,
                          ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: _phoneFieldKey,
                controller: _phoneController,
                focusNode: _phoneFocusNode,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                onTap: _scrollIntoView,
                decoration: const InputDecoration(
                  labelText: 'Phone number (e.g. 0XXXXXXXXX)',
                  counterText: '',
                ),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) {
                    return 'Phone number required';
                  }
                  if (!RegExp(r'^0\d{9}$').hasMatch(trimmed)) {
                    return 'Enter 10 digits starting with 0';
                  }
                  return null;
                },
              ),
              if (MediaQuery.of(context).viewInsets.bottom > 0) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: Text(_loading ? 'Submitting...' : 'Pay Now'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: MediaQuery.of(context).viewInsets.bottom > 0
          ? null
          : AnimatedPadding(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: _bottomBarHeight - 24,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: Text(_loading ? 'Submitting...' : 'Pay Now'),
                  ),
                ),
              ),
            ),
    );
  }
}

class _PaymentMethodOption {
  const _PaymentMethodOption({
    required this.provider,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  final String provider;
  final String label;
  final String subtitle;
  final Color color;
  final IconData icon;
}

const _methods = [
  _PaymentMethodOption(
    provider: 'vodacom',
    label: 'M-Pesa (Vodacom)',
    subtitle: 'Approve the M-Pesa prompt on your phone',
    color: Color(0xFFE60000),
    icon: AppIcons.phone_android,
  ),
  _PaymentMethodOption(
    provider: 'airtel',
    label: 'Airtel Money',
    subtitle: 'Approve the Airtel Money request',
    color: Color(0xFF2563EB),
    icon: AppIcons.phone_android,
  ),
  _PaymentMethodOption(
    provider: 'tigo',
    label: 'Tigo Pesa',
    subtitle: 'Authorize on your TigoPesa wallet',
    color: Color(0xFF0033A0),
    icon: AppIcons.phone_android,
  ),
  _PaymentMethodOption(
    provider: 'halopesa',
    label: 'HaloPesa',
    subtitle: 'Approve the HaloPesa request',
    color: Color(0xFF00A651),
    icon: AppIcons.phone_android,
  ),
];

class _BrandBadge extends StatelessWidget {
  const _BrandBadge({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final brightness = ThemeData.estimateBrightnessForColor(color);
    final iconColor = brightness == Brightness.dark ? Colors.white : Colors.black;
    return CircleAvatar(
      radius: 20,
      backgroundColor: color,
      child: Icon(icon, color: iconColor, size: 20),
    );
  }
}
