import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/status_badge.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({required this.onNavigate, super.key});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (!app.initialized && app.lastError == null) {
      return const LoadingView(message: 'Preparing restaurant workspace...');
    }
    if (app.lastError != null && !app.initialized) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ErrorView(message: app.lastError!),
          ),
        ),
      );
    }

    final currency = NumberFormat.currency(symbol: r'$', decimalDigits: 2);
    final metrics = app.metrics;
    final server = app.serverState;

    return AppScaffold(
      title: 'Admin Dashboard',
      subtitle: 'Monitor server, orders, sales, and menu availability.',
      actions: [StatusBadge.server(isRunning: server.isRunning)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MetricGrid(
            cards: [
              DashboardCard(
                title: 'Server status',
                value: server.isRunning ? 'Online' : 'Offline',
                caption: server.apiUrl ?? 'Start local server',
                icon: Icons.wifi_tethering,
                color: server.isRunning ? PosColors.success : PosColors.muted,
                onTap: () => onNavigate(3),
              ),
              DashboardCard(
                title: 'Today orders',
                value: metrics.todayOrders.toString(),
                icon: Icons.today_outlined,
                color: PosColors.primary,
                onTap: () => onNavigate(2),
              ),
              DashboardCard(
                title: 'Pending orders',
                value: metrics.pendingOrders.toString(),
                icon: Icons.pending_actions_outlined,
                color: PosColors.warning,
                onTap: () => onNavigate(2),
              ),
              DashboardCard(
                title: 'Completed orders',
                value: metrics.completedOrders.toString(),
                icon: Icons.done_all,
                color: PosColors.success,
                onTap: () => onNavigate(2),
              ),
              DashboardCard(
                title: 'Total sales',
                value: currency.format(metrics.totalSales),
                icon: Icons.payments_outlined,
                color: const Color(0xFF2563EB),
              ),
              DashboardCard(
                title: 'Menu items',
                value: metrics.menuItemsCount.toString(),
                icon: Icons.restaurant_menu,
                color: PosColors.primaryDark,
                onTap: () => onNavigate(1),
              ),
              DashboardCard(
                title: 'Available items',
                value: metrics.availableItemsCount.toString(),
                icon: Icons.check_circle_outline,
                color: PosColors.success,
                onTap: () => onNavigate(1),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _QuickActions(onNavigate: onNavigate, apiUrl: server.apiUrl),
          const SizedBox(height: 22),
          _ServerHintCard(
            isRunning: server.isRunning,
            apiUrl: server.apiUrl,
            wsUrl: server.wsUrl,
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1080
            ? 4
            : width >= 620
            ? 2
            : 1;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: width >= 620 ? 1.55 : 1.75,
          children: cards,
        );
      },
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onNavigate, required this.apiUrl});

  final ValueChanged<int> onNavigate;
  final String? apiUrl;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick actions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                PrimaryButton(
                  label: 'Add Menu Item',
                  icon: Icons.add,
                  onPressed: () => onNavigate(1),
                ),
                PrimaryButton(
                  label: 'View Orders',
                  icon: Icons.receipt_long,
                  secondary: true,
                  onPressed: () => onNavigate(2),
                ),
                PrimaryButton(
                  label: 'Server Settings',
                  icon: Icons.settings_input_antenna,
                  secondary: true,
                  onPressed: () => onNavigate(3),
                ),
                PrimaryButton(
                  label: 'Copy Menu URL',
                  icon: Icons.copy,
                  secondary: true,
                  onPressed: apiUrl == null
                      ? null
                      : () async {
                          await Clipboard.setData(
                            ClipboardData(text: '$apiUrl/menu'),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Menu URL copied')),
                          );
                        },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerHintCard extends StatelessWidget {
  const _ServerHintCard({
    required this.isRunning,
    required this.apiUrl,
    required this.wsUrl,
  });

  final bool isRunning;
  final String? apiUrl;
  final String? wsUrl;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: PosColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.router_outlined, color: PosColors.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isRunning
                        ? 'Customer devices can connect now'
                        : 'Start the server before taking external orders',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isRunning
                        ? 'API: ${apiUrl ?? 'IP unavailable'}\nWebSocket: ${wsUrl ?? 'IP unavailable'}'
                        : 'Same WiFi is enough. Internet is not required.',
                    style: Theme.of(context).textTheme.bodyMedium,
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
