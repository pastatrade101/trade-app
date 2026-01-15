import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../../core/models/payment_intent.dart';
import '../../../core/models/product.dart';
import '../../../core/models/user_membership.dart';

class PaymentStatusScreen extends ConsumerStatefulWidget {
  const PaymentStatusScreen({
    super.key,
    required this.intentId,
    this.product,
    this.providerLabel,
    this.accountNumber,
  });

  final String intentId;
  final Product? product;
  final String? providerLabel;
  final String? accountNumber;

  @override
  ConsumerState<PaymentStatusScreen> createState() =>
      _PaymentStatusScreenState();
}

class _PaymentStatusScreenState extends ConsumerState<PaymentStatusScreen> {
  Timer? _timer;
  Timer? _redirectTimer;
  DateTime? _expiresAt;
  DateTime? _createdAt;
  Duration? _remaining;
  String? _lastStatus;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_expiresAt == null) {
        return;
      }
      final remaining = _expiresAt!.difference(DateTime.now());
      if (!mounted) {
        return;
      }
      setState(() {
        _remaining = remaining.isNegative ? Duration.zero : remaining;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _redirectTimer?.cancel();
    super.dispose();
  }

  void _syncTiming(PaymentIntent? intent) {
    final expiresAt = intent?.expiresAt;
    final createdAt = intent?.createdAt;
    if (_expiresAt == expiresAt && _createdAt == createdAt) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _expiresAt = expiresAt;
        _createdAt = createdAt;
        _remaining = _expiresAt == null
            ? null
            : _expiresAt!.difference(DateTime.now()).isNegative
                ? Duration.zero
                : _expiresAt!.difference(DateTime.now());
      });
    });
  }

  void _handleStatusChange(BuildContext context, String status) {
    if (_lastStatus == status) {
      return;
    }
    _lastStatus = status;
    _redirectTimer?.cancel();
    if (status == 'failed' || status == 'expired') {
      _redirectTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) {
          return;
        }
        Navigator.of(context).pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final membership = ref.watch(userMembershipProvider).value;
    final intentStream =
        ref.read(paymentRepositoryProvider).watchPaymentIntent(widget.intentId);
    return Scaffold(
      appBar: AppBar(title: const Text('Payment status')),
      body: StreamBuilder<PaymentIntent?>(
        stream: intentStream,
        builder: (context, snapshot) {
          final intent = snapshot.data;
          final status = intent?.status ?? 'pending';
          final membershipPaid = _isMembershipPaid(intent, membership);
          final isPaid = (intent?.isPaid ?? false) || membershipPaid;
          final isFailed = intent?.isFailed ?? false;
          final isPending = !isPaid && !isFailed;
          final effectiveStatus = isPaid ? 'paid' : status;

          _syncTiming(intent);
          _handleStatusChange(context, effectiveStatus);

          final productStream = intent != null
              ? ref.read(productRepositoryProvider).watchProduct(intent.productId)
              : Stream<Product?>.value(widget.product);

          return StreamBuilder<Product?>(
            stream: productStream,
            builder: (context, productSnapshot) {
              final product = productSnapshot.data ?? widget.product;
              final progress = _calculateProgress();
              final brandColor =
                  _providerBrandColor(intent?.provider ?? widget.providerLabel, tokens);

              return SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isPending)
                              _AwaitingCard(
                                remaining: _remaining,
                                progress: progress,
                                brandColor: brandColor,
                              )
                            else
                              _StatusHeader(
                                isPaid: isPaid,
                                isFailed: isFailed,
                              ),
                            const SizedBox(height: 16),
                            _OrderSummaryCard(
                              intent: intent,
                              product: product,
                              providerLabel: widget.providerLabel,
                              accountNumber: widget.accountNumber,
                            ),
                            const SizedBox(height: 16),
                            if (isPending)
                              _NextStepsCard(tokens: tokens)
                            else
                              _StatusInfo(isPaid: isPaid, tokens: tokens),
                            const SizedBox(height: 16),
                            _SecureRow(tokens: tokens),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        children: [
                          if (isPaid)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context)
                                      .popUntil((route) => route.isFirst);
                                },
                                child: const Text('Continue'),
                              ),
                            )
                          else if (isFailed)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Back to plans'),
                              ),
                            )
                          else
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('We will confirm once payment is received.'),
                                    ),
                                  );
                                },
                                child: const Text("I've Completed Payment"),
                              ),
                            ),
                          if (isFailed)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Returning to plans...',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: tokens.mutedText),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  double? _calculateProgress() {
    if (_remaining == null || _expiresAt == null || _createdAt == null) {
      return null;
    }
    final total = _expiresAt!.difference(_createdAt!);
    if (total.inSeconds <= 0) {
      return null;
    }
    final remainingSeconds = _remaining!.inSeconds.clamp(0, total.inSeconds);
    final value = 1 - (remainingSeconds / total.inSeconds);
    if (value.isNaN) {
      return null;
    }
    return value.clamp(0.0, 1.0);
  }

  bool _isMembershipPaid(
    PaymentIntent? intent,
    UserMembership? membership,
  ) {
    if (intent == null || membership == null) {
      return false;
    }
    if (!membership.isPremiumActive()) {
      return false;
    }
    final anchor = membership.updatedAt ?? membership.startedAt;
    final createdAt = intent.createdAt;
    if (anchor == null || createdAt == null) {
      return false;
    }
    return !anchor.isBefore(createdAt.subtract(const Duration(seconds: 5)));
  }
}

class _AwaitingCard extends StatelessWidget {
  const _AwaitingCard({
    required this.remaining,
    required this.progress,
    required this.brandColor,
  });

  final Duration? remaining;
  final double? progress;
  final Color brandColor;

  @override
  Widget build(BuildContext context) {
    final darker = Color.lerp(brandColor, Colors.black, 0.2) ?? brandColor;
    final lighter = Color.lerp(brandColor, Colors.white, 0.15) ?? brandColor;
    final brightness = ThemeData.estimateBrightnessForColor(brandColor);
    final textColor = brightness == Brightness.dark ? Colors.white : Colors.black87;
    final timerText = remaining == null ? null : _formatDuration(remaining!);
    final isDelayed = remaining != null && remaining == Duration.zero;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [lighter, darker],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: darker.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: textColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.schedule, color: textColor),
              ),
              const SizedBox(width: 12),
              Text(
                'Awaiting Confirmation',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Please approve the mobile money prompt on your phone to complete the payment.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: textColor.withOpacity(0.9),
                ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: textColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Time remaining',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: textColor.withOpacity(0.85),
                        ),
                  ),
                ),
                if (timerText != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: textColor.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.timer, size: 14, color: textColor),
                        const SizedBox(width: 6),
                        Text(
                          timerText,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: textColor,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: progress,
              backgroundColor: textColor.withOpacity(0.18),
              valueColor: AlwaysStoppedAnimation<Color>(
                textColor.withOpacity(0.8),
              ),
            ),
          ),
          if (isDelayed) ...[
            const SizedBox(height: 10),
            Text(
              'This is taking longer than usual. Keep this screen open if you already approved.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: textColor.withOpacity(0.85),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({
    required this.isPaid,
    required this.isFailed,
  });

  final bool isPaid;
  final bool isFailed;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor =
        isPaid ? tokens.success : isFailed ? colorScheme.error : colorScheme.primary;
    final title = isPaid
        ? 'Payment confirmed'
        : isFailed
            ? 'Payment cancelled'
            : 'Waiting for confirmation';
    final subtitle = isPaid
        ? 'Congratulations! Your premium access is active.'
        : isFailed
            ? 'We did not receive confirmation from your wallet.'
            : 'Approve the mobile money prompt on your phone.';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            isPaid
                ? Icons.check_circle
                : isFailed
                    ? Icons.cancel
                    : Icons.hourglass_top,
            color: iconColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: tokens.mutedText,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({
    required this.intent,
    required this.product,
    required this.providerLabel,
    required this.accountNumber,
  });

  final PaymentIntent? intent;
  final Product? product;
  final String? providerLabel;
  final String? accountNumber;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final amount = intent != null
        ? '${intent!.amount.toStringAsFixed(0)} ${intent!.currency}'
        : product != null
            ? '${product!.price.toStringAsFixed(0)} ${product!.currency}'
            : '—';
    final planTitle = product?.title ?? _planLabel(intent?.productId);
    final phone = intent?.msisdn ?? accountNumber ?? '—';
    final provider = providerLabel ?? _providerLabel(intent?.provider);
    final reference = intent?.id ?? '—';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.border),
        boxShadow: [
          BoxShadow(
            color: tokens.shadow,
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Order Summary',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (planTitle.toLowerCase().contains('premium'))
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: tokens.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Premium',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: tokens.success,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: tokens.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tokens.border),
            ),
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              title: Text(
                'Total Amount',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.mutedText,
                    ),
              ),
              subtitle: Text(
                planTitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.mutedText,
                    ),
              ),
              trailing: Text(
                amount,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SummaryRow(label: 'Phone', value: phone),
          _SummaryRow(label: 'Provider', value: provider),
          _SummaryRow(label: 'Reference', value: reference),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: tokens.mutedText),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusInfo extends StatelessWidget {
  const _StatusInfo({
    required this.isPaid,
    required this.tokens,
  });

  final bool isPaid;
  final AppThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final message = isPaid
        ? 'You can now access all premium signals instantly.'
        : 'You can try again from the plan selection screen.';
    final color = isPaid ? tokens.success : Theme.of(context).colorScheme.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
            ),
      ),
    );
  }
}

class _NextStepsCard extends StatelessWidget {
  const _NextStepsCard({required this.tokens});

  final AppThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              Icon(Icons.receipt_long, size: 18),
              SizedBox(width: 8),
              Text(
                'Next Steps',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          SizedBox(height: 12),
          _StepRow(
            number: '1',
            text: 'Check your phone for the mobile money prompt.',
          ),
          SizedBox(height: 10),
          _StepRow(
            number: '2',
            text: 'Enter your wallet PIN to approve the payment.',
          ),
          SizedBox(height: 10),
          _StepRow(
            number: '3',
            text: 'We will confirm automatically once payment is received.',
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 24,
          width: 24,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _SecureRow extends StatelessWidget {
  const _SecureRow({required this.tokens});

  final AppThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.verified_user, size: 18, color: tokens.success),
        const SizedBox(width: 8),
        Text(
          'Secure Payment Processing',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tokens.mutedText,
              ),
        ),
      ],
    );
  }
}

String _planLabel(String? productId) {
  switch (productId) {
    case 'premium_daily':
      return 'Premium Daily';
    case 'premium_weekly':
      return 'Premium Weekly';
    case 'premium_monthly':
      return 'Premium Monthly';
    default:
      return productId ?? 'Premium';
  }
}

String _providerLabel(String? provider) {
  switch ((provider ?? '').toLowerCase()) {
    case 'mixx':
      return 'Mixx by Yas';
    case 'vodacom':
      return 'M-Pesa (Vodacom)';
    case 'airtel':
      return 'Airtel Money';
    case 'tigo':
      return 'Tigo Pesa';
    default:
      return provider ?? 'Mobile money';
  }
}

Color _providerBrandColor(String? provider, AppThemeTokens tokens) {
  final value = (provider ?? '').toLowerCase();
  if (value.contains('vodacom') || value.contains('m-pesa')) {
    return const Color(0xFFE60000);
  }
  if (value.contains('tigo')) {
    return const Color(0xFF0033A0);
  }
  if (value.contains('mixx') || value.contains('yas')) {
    return const Color(0xFFFFD100);
  }
  if (value.contains('halopesa') || value.contains('halo')) {
    return const Color(0xFF00A651);
  }
  return tokens.heroStart;
}

String _formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}
