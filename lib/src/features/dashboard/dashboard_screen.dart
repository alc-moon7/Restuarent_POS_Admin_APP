import 'package:flutter/material.dart';
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
      return const LoadingView(message: 'Preparing cloud workspace...');
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
    final sync = app.syncState;

    return AppScaffold(
      title: 'Admin Dashboard',
      subtitle: 'Cloud menu, orders, sales, and realtime sync.',
      actions: [
        StatusBadge(
          label: sync.cloudConnected ? 'Cloud Connected' : 'Cloud Queued',
          color: sync.cloudConnected ? PosColors.success : PosColors.warning,
          icon: sync.cloudConnected
              ? Icons.cloud_done_outlined
              : Icons.cloud_queue_outlined,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MetricGrid(
            cards: [
              DashboardCard(
                title: 'Cloud sync',
                value: sync.cloudConnected ? 'Connected' : 'Queued',
                caption: app.cloudConfig.enabled
                    ? '${sync.pendingCount} pending'
                    : 'Disabled',
                icon: Icons.cloud_sync_outlined,
                color: sync.cloudConnected
                    ? PosColors.success
                    : PosColors.warning,
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
              DashboardCard(
                title: 'Pending sync',
                value: metrics.pendingSyncCount.toString(),
                icon: Icons.sync_problem_outlined,
                color: metrics.pendingSyncCount == 0
                    ? PosColors.success
                    : PosColors.warning,
                onTap: () => onNavigate(3),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _QuickActions(onNavigate: onNavigate, onSyncNow: app.syncNow),
          const SizedBox(height: 16),
          _CloudHintCard(
            connected: sync.cloudConnected,
            cloudUrl: app.cloudConfig.baseUrl,
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
            : width >= 760
            ? 3
            : width >= 320
            ? 2
            : 1;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: width >= 1080
              ? 2.15
              : width >= 760
              ? 1.9
              : width >= 620
              ? 1.75
              : 1.42,
          children: cards,
        );
      },
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onNavigate, required this.onSyncNow});

  final ValueChanged<int> onNavigate;
  final Future<bool> Function() onSyncNow;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick actions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
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
                  label: 'Sync Now',
                  icon: Icons.sync,
                  secondary: true,
                  onPressed: () async {
                    final ok = await onSyncNow();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok ? 'Sync completed' : 'Sync failed'),
                      ),
                    );
                  },
                ),
                PrimaryButton(
                  label: 'Cloud Settings',
                  icon: Icons.settings_outlined,
                  secondary: true,
                  onPressed: () => onNavigate(4),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CloudHintCard extends StatelessWidget {
  const _CloudHintCard({required this.connected, required this.cloudUrl});

  final bool connected;
  final String cloudUrl;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: PosColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                connected ? Icons.cloud_done_outlined : Icons.cloud_queue,
                color: PosColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    connected
                        ? 'Cloud ordering is connected'
                        : 'Cloud changes will sync when reachable',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Customer websites should use the cloud API configured for this app.\n$cloudUrl',
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
