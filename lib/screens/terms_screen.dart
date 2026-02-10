import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/widgets/app_toast.dart';
import '../services/terms_service.dart';

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool _agreed = false;
  bool _saving = false;

  Future<void> _submit() async {
    if (_saving || !_agreed) {
      return;
    }
    setState(() {
      _saving = true;
    });
    try {
      await TermsService().acceptTerms();
    } catch (error) {
      if (mounted) {
        AppToast.error(context, 'Unable to save acceptance. Try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildTermsContent(textTheme, tokens),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(color: tokens.border),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CheckboxListTile(
                    value: _agreed,
                    onChanged: _saving
                        ? null
                        : (value) {
                            setState(() {
                              _agreed = value ?? false;
                            });
                          },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('I Agree'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _agreed && !_saving ? _submit : null,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Continue'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<Widget> _buildTermsContent(
  TextTheme textTheme,
  AppThemeTokens tokens,
) {
  final lines = _termsText.split('\n');
  final widgets = <Widget>[];

  for (final line in lines) {
    if (line.trim().isEmpty) {
      widgets.add(const SizedBox(height: 12));
      continue;
    }

    if (line == 'Terms & Conditions') {
      widgets.add(
        Text(
          line,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      );
      continue;
    }

    if (line.startsWith('Last updated:')) {
      widgets.add(
        Text(
          line,
          style: textTheme.labelMedium?.copyWith(color: tokens.mutedText),
        ),
      );
      continue;
    }

    if (RegExp(r'^\d+\.').hasMatch(line) || line == 'Acceptance') {
      widgets.add(
        Text(
          line,
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      );
      continue;
    }

    if (line.startsWith('- ')) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Text(
            line,
            style: textTheme.bodyMedium?.copyWith(
              height: 1.45,
              color: tokens.mutedText,
            ),
          ),
        ),
      );
      continue;
    }

    widgets.add(
      Text(
        line,
        style: textTheme.bodyMedium?.copyWith(
          height: 1.45,
          color: tokens.mutedText,
        ),
      ),
    );
  }

  return widgets;
}

const String _termsText = '''Terms & Conditions
Last updated: 16 January 2026

Welcome to Mchambuzi Kai Official Trading App (“the App”), powered by Soko Gliant.
By creating an account, accessing, or using this App, you agree to be bound by these
Terms & Conditions. If you do not agree, please do not use the App.

1. Nature of the Service (Important)
Mchambuzi Kai Official Trading App provides:
- Educational trading signals
- Market insights and commentary
- Trading ideas shared by Mchambuzi Kai
- Optional AI-generated explanations based strictly on provided signal parameters

This App does NOT provide financial, investment, or trading advice.
All content is for educational and informational purposes only.

You acknowledge that:
- Trading involves high risk
- You are solely responsible for your trades
- You may lose part or all of your trading capital

2. No Financial Advice Disclaimer
Nothing within this App constitutes financial advice, investment advice,
trading advice, or a recommendation to buy or sell any asset.
You should consult a licensed financial professional before trading.

3. Trading Signals & Accuracy
- Signals are based on the personal analysis of Mchambuzi Kai
- No guarantee of profitability or accuracy
- Market conditions can change rapidly
- Past performance does not guarantee future results

4. AI-Generated Content Disclaimer
Some content may be generated or assisted by Artificial Intelligence (AI).
AI explanations:
- Use signal parameters only
- Do not analyze live charts or real-time prices
- Are educational and may be inaccurate
- Are NOT financial advice

5. User Responsibility
You agree that:
- You manage your own risk and capital
- You understand leverage and volatility
- You trade at your own discretion

Neither the App, Mchambuzi Kai, nor Soko Gliant is responsible for losses.

6. Premium Subscriptions & Payments
- Some features require Premium membership
- Payments are non-refundable unless required by law
- Premium duration depends on selected plan
- Features and pricing may change

7. Payments & Third-Party Services
Payments may use mobile money or third-party providers.
We are not responsible for provider delays, failures, or outages.

8. Testimonials
Testimonials reflect personal experiences only.
Results vary and are not guaranteed.

9. Account Usage
You must not share accounts, resell content, or abuse the platform.
We may suspend accounts that violate these terms.

10. Limitation of Liability
We are not liable for:
- Trading losses
- Missed opportunities
- Technical failures or downtime
Use of this App is entirely at your own risk.

11. Changes to Terms
We may update these Terms at any time.
Continued use means acceptance of updates.

12. Governing Law
These Terms are governed by the laws of the United Republic of Tanzania.

13. Contact
Support email: support@mchambuzikai.app

Acceptance
By tapping “I Agree”, you confirm you understand and accept all terms and risks.
''';
