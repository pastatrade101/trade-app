import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../../core/models/product.dart';
import '../../../core/repositories/payment_repository.dart';
import '../../../core/widgets/app_toast.dart';
import 'payment_status_screen.dart';

class PaymentMethodScreen extends ConsumerStatefulWidget {
  const PaymentMethodScreen({super.key, required this.product});

  final Product product;

  @override
  ConsumerState<PaymentMethodScreen> createState() =>
      _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends ConsumerState<PaymentMethodScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _provider = 'mixx';
  bool _loading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
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
    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) {
        throw Exception('Sign in required.');
      }
      final phone = _phoneController.text.trim();
      if (phone != user.phoneNumber && phone.isNotEmpty) {
        await ref
            .read(userRepositoryProvider)
            .updatePhoneNumber(uid: user.uid, phoneNumber: phone);
      }
      final result =
          await ref.read(paymentRepositoryProvider).createPaymentIntent(
                productId: widget.product.id,
                provider: _provider,
                accountNumber: phone,
              );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PaymentStatusScreen(
            intentId: result.intentId,
            product: widget.product,
            providerLabel: selectedMethod.label,
            accountNumber: phone,
          ),
        ),
      );
    } on PaymentRequestException catch (error) {
      if (mounted) {
        AppToast.error(context, 'Payment failed: ${error.message}');
      }
    } catch (error) {
      if (mounted) {
        AppToast.error(context, 'Payment failed: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
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
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    secondary: _BrandBadge(color: method.color, icon: method.icon),
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
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number (M-Pesa/Airtel/Tigo)',
                ),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) {
                    return 'Phone number required';
                  }
                  if (trimmed.length < 9) {
                    return 'Enter a valid phone number';
                  }
                  return null;
                },
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Text('Pay Now'),
                ),
              ),
            ],
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
    provider: 'mixx',
    label: 'Mixx by Yas',
    subtitle: 'USSD/push prompt on your Mixx wallet',
    color: Color(0xFFFFD100),
    icon: Icons.phone_android,
  ),
  _PaymentMethodOption(
    provider: 'vodacom',
    label: 'M-Pesa (Vodacom)',
    subtitle: 'Approve the M-Pesa prompt on your phone',
    color: Color(0xFFE60000),
    icon: Icons.phone_android,
  ),
  _PaymentMethodOption(
    provider: 'airtel',
    label: 'Airtel Money',
    subtitle: 'Approve the Airtel Money request',
    color: Color(0xFF2563EB),
    icon: Icons.phone_android,
  ),
  _PaymentMethodOption(
    provider: 'tigo',
    label: 'Tigo Pesa',
    subtitle: 'Authorize on your TigoPesa wallet',
    color: Color(0xFF0033A0),
    icon: Icons.phone_android,
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
