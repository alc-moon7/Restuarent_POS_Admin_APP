import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/primary_button.dart';

class ModeIntroScreen extends StatelessWidget {
  const ModeIntroScreen({required this.onContinue, super.key});

  final Future<void> Function() onContinue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 760;
                  final hero = _HeroPanel(onContinue: onContinue);
                  final cards = _CapabilityCards(wide: wide);
                  if (!wide) {
                    return ListView(
                      children: [hero, const SizedBox(height: 12), cards],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(flex: 5, child: hero),
                      const SizedBox(width: 14),
                      Expanded(flex: 4, child: cards),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.onContinue});

  final Future<void> Function() onContinue;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: PosColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.admin_panel_settings_outlined,
                color: PosColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Run your restaurant from the cloud',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Manage menu, orders, and status updates through the cloud API with realtime sync across customer websites.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: PosColors.muted),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Configure Cloud Admin',
              icon: Icons.arrow_forward,
              onPressed: () => onContinue(),
            ),
          ],
        ),
      ),
    );
  }
}

class _CapabilityCards extends StatelessWidget {
  const _CapabilityCards({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    final cards = [
      const _Capability(
        icon: Icons.cloud_done_outlined,
        title: 'Cloud APIs',
        message:
            'Supabase Edge Function endpoints for customer websites and admin sync.',
      ),
      const _Capability(
        icon: Icons.restaurant_menu,
        title: 'Live Menu',
        message: 'Availability changes sync to customer websites through cloud.',
      ),
      const _Capability(
        icon: Icons.receipt_long,
        title: 'Order Workflow',
        message:
            'Accept, prepare, ready, serve, or cancel orders from one dashboard.',
      ),
    ];

    return Column(
      mainAxisSize: wide ? MainAxisSize.min : MainAxisSize.max,
      children: cards
          .map(
            (card) =>
                Padding(padding: const EdgeInsets.only(bottom: 8), child: card),
          )
          .toList(growable: false),
    );
  }
}

class _Capability extends StatelessWidget {
  const _Capability({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: PosColors.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: PosColors.accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(message, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
