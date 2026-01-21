import 'package:flutter/material.dart';

import 'affiliate_manager_screen.dart';
import 'report_review_screen.dart';
import 'signal_moderation_screen.dart';
import 'session_settings_screen.dart';
import 'plan_manager_screen.dart';
import 'global_offer_settings_screen.dart';
import 'package:stock_investment_flutter/app/app_icons.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin tools')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(AppIcons.link),
            title: const Text('Broker manager'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BrokerManagerScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(AppIcons.report),
            title: const Text('Review reports'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReportReviewScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(AppIcons.shield),
            title: const Text('Moderate signals'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SignalModerationScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(AppIcons.schedule),
            title: const Text('Session settings'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SessionSettingsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(AppIcons.payments_outlined),
            title: const Text('Publish plans'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PlanManagerScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(AppIcons.timer),
            title: const Text('Trials & offers'),
            subtitle: const Text('Toggle the global trial or discount'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const GlobalOfferSettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
