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
              padding: const EdgeInsets.all(24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 760;
                  final hero = _HeroPanel(onContinue: onContinue);
                  final cards = _CapabilityCards(wide: wide);
                  if (!wide) {
                    return ListView(
                      children: [hero, const SizedBox(height: 18), cards],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(flex: 5, child: hero),
                      const SizedBox(width: 20),
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
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: PosColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.admin_panel_settings_outlined,
                color: PosColors.primary,
                size: 32,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Run your restaurant from one admin device',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 12),
            Text(
              'Start in Admin/Server mode, manage menu and orders locally, then let customer apps connect over the same WiFi without internet.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: PosColors.muted),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Set up Admin Server',
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
        icon: Icons.wifi_tethering,
        title: 'Local LAN APIs',
        message:
            'HTTP and WebSocket endpoints for future Flutter or React clients.',
      ),
      const _Capability(
        icon: Icons.restaurant_menu,
        title: 'Live Menu',
        message:
            'Availability changes update the served /menu response instantly.',
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
            (card) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: card,
            ),
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
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: PosColors.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: PosColors.accent),
            ),
            const SizedBox(width: 14),
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
