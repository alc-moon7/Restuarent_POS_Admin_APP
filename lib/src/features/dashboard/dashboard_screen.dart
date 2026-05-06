import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/mini_bar_chart.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/status_badge.dart';
import '../../models/sales_report.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({required this.onNavigate, super.key});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (!app.initialized && app.lastError == null) {
      return LoadingView(message: 'Preparing cloud workspace...');
    }
    if (app.lastError != null && !app.initialized) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: ErrorView(message: app.lastError!),
          ),
        ),
      );
    }

    final currency = NumberFormat.currency(symbol: r'$', decimalDigits: 2);
    final compactCurrency = NumberFormat.compactCurrency(symbol: r'$');
    final metrics = app.metrics;
    final sync = app.syncState;
    final report7 = app.salesReportForDays(7);

    return AppScaffold(
      title: _greeting(
        app.restaurantName.isEmpty ? 'Admin' : app.restaurantName,
      ),
      subtitle: 'Live overview of menu, orders, and cloud sync.',
      actions: [
        StatusBadge(
          label: sync.cloudConnected ? 'Cloud Live' : 'Cloud Queued',
          color: sync.cloudConnected ? PosColors.success : PosColors.warning,
          icon: sync.cloudConnected
              ? Icons.cloud_done_outlined
              : Icons.cloud_queue_outlined,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroPanel(
            todaySales: metrics.totalSales,
            todayOrders: metrics.todayOrders,
            sevenDayReport: report7,
            currency: currency,
            compactCurrency: compactCurrency,
          ),
          SizedBox(height: 18),
          _SectionLabel(icon: Icons.bolt_rounded, label: "Today's pulse"),
          SizedBox(height: 10),
          _PulseGrid(
            cards: [
              DashboardCard(
                title: 'Today orders',
                value: metrics.todayOrders.toString(),
                icon: Icons.today_outlined,
                color: PosColors.primary,
                onTap: () => onNavigate(0),
              ),
              DashboardCard(
                title: 'Pending now',
                value: metrics.pendingOrders.toString(),
                icon: Icons.pending_actions_outlined,
                color: PosColors.warning,
                onTap: () => onNavigate(0),
              ),
              DashboardCard(
                title: 'Completed',
                value: metrics.completedOrders.toString(),
                icon: Icons.done_all,
                color: PosColors.success,
                onTap: () => onNavigate(0),
              ),
              DashboardCard(
                title: 'Avg ticket',
                value: report7.averageOrderValue == 0
                    ? '—'
                    : currency.format(report7.averageOrderValue),
                icon: Icons.trending_up_outlined,
                color: PosColors.info,
                onTap: () => onNavigate(3),
              ),
            ],
          ),
          SizedBox(height: 18),
          _SectionLabel(
            icon: Icons.insights_rounded,
            label: 'Revenue & catalog',
          ),
          SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 920;
              final revenueCard = _RevenueBreakdownCard(
                weekSales: metrics.sevenDaySales,
                monthSales: metrics.thirtyDaySales,
                currency: currency,
                onOpenReports: () => onNavigate(3),
              );
              final catalogCard = _CatalogHealthCard(
                total: metrics.menuItemsCount,
                available: metrics.availableItemsCount,
                pendingSync: metrics.pendingSyncCount,
                onOpenMenu: () => onNavigate(1),
                onOpenSync: () => onNavigate(4),
              );
              if (!wide) {
                return Column(
                  children: [revenueCard, SizedBox(height: 10), catalogCard],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: revenueCard),
                  SizedBox(width: 10),
                  Expanded(child: catalogCard),
                ],
              );
            },
          ),
          SizedBox(height: 18),
          _SectionLabel(icon: Icons.flash_on_rounded, label: 'Quick actions'),
          SizedBox(height: 10),
          _QuickActions(onNavigate: onNavigate, onSyncNow: app.syncNow),
          SizedBox(height: 16),
          _CloudHintCard(
            connected: sync.cloudConnected,
            cloudUrl: app.cloudConfig.baseUrl,
          ),
        ],
      ),
    );
  }

  String _greeting(String name) {
    final hour = DateTime.now().hour;
    final part = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    return '$part, $name';
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                PosColors.primary.withValues(alpha: 0.20),
                PosColors.primary.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(PosRadii.sm),
            border: Border.all(
              color: PosColors.primary.withValues(alpha: 0.20),
            ),
          ),
          child: Icon(icon, color: PosColors.primary, size: 16),
        ),
        SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: PosColors.slate,
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.todaySales,
    required this.todayOrders,
    required this.sevenDayReport,
    required this.currency,
    required this.compactCurrency,
  });

  final double todaySales;
  final int todayOrders;
  final SalesReport sevenDayReport;
  final NumberFormat currency;
  final NumberFormat compactCurrency;

  @override
  Widget build(BuildContext context) {
    final daily = sevenDayReport.dailyBreakdown;
    final values = daily.map<double>((d) => d.sales).toList();
    final labels = daily
        .map<String>((d) => DateFormat('E').format(d.date).substring(0, 1))
        .toList();
    final yesterday = values.length >= 2 ? values[values.length - 2] : 0.0;
    final today = values.isEmpty ? 0.0 : values.last;
    final delta = today - yesterday;
    final pct = yesterday == 0 ? null : (delta / yesterday) * 100;

    return ClipRRect(
      borderRadius: BorderRadius.circular(PosRadii.lg),
      child: Container(
        decoration: BoxDecoration(
          gradient: PosGradients.brandDeep,
          borderRadius: BorderRadius.circular(PosRadii.lg),
          boxShadow: [
            BoxShadow(
              color: PosColors.primary.withValues(alpha: 0.32),
              blurRadius: 24,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -60,
              top: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.16),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: -40,
              bottom: -50,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      PosColors.primaryGlow.withValues(alpha: 0.30),
                      PosColors.primaryGlow.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 620;
                  final summary = _heroSummary(
                    context,
                    today,
                    delta,
                    pct,
                    values,
                  );
                  final chart = _heroChart(values, labels);
                  if (!wide) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [summary, SizedBox(height: 18), chart],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: summary),
                      SizedBox(width: 18),
                      Expanded(flex: 5, child: chart),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroSummary(
    BuildContext context,
    double today,
    double delta,
    double? pct,
    List<double> values,
  ) {
    final positive = delta >= 0;
    final arrow = positive
        ? Icons.trending_up_rounded
        : Icons.trending_down_rounded;
    final pctLabel = pct == null
        ? 'no data yesterday'
        : '${positive ? '+' : ''}${pct.toStringAsFixed(1)}% vs yesterday';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(PosRadii.pill),
            border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.today_rounded, size: 13, color: Colors.white),
              SizedBox(width: 6),
              Text(
                'TODAY · LIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 10.4,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        Text(
          currency.format(today),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 38,
            letterSpacing: 0,
            height: 1.0,
          ),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: positive
                    ? PosColors.primaryGlow.withValues(alpha: 0.28)
                    : PosColors.danger.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(PosRadii.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(arrow, color: Colors.white, size: 13),
                  SizedBox(width: 4),
                  Text(
                    pctLabel,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 14),
        Row(
          children: [
            _HeroChip(
              icon: Icons.receipt_long_rounded,
              label: '$todayOrders orders',
            ),
            SizedBox(width: 8),
            _HeroChip(
              icon: Icons.calendar_view_week_rounded,
              label:
                  '${compactCurrency.format(values.fold<double>(0, (s, v) => s + v))} this week',
            ),
          ],
        ),
      ],
    );
  }

  Widget _heroChart(List<double> values, List<String> labels) {
    return Container(
      padding: EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(PosRadii.md),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LAST 7 DAYS',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w900,
              fontSize: 10.4,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 10),
          MiniBarChart(
            values: values,
            labels: labels,
            color: Colors.white,
            height: 100,
            formatValue: (v) => compactCurrency.format(v),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(PosRadii.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseGrid extends StatelessWidget {
  const _PulseGrid({required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1080
            ? 4
            : width >= 700
            ? 4
            : width >= 380
            ? 2
            : 1;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: width >= 1080
              ? 2.05
              : width >= 700
              ? 1.6
              : 1.42,
          children: cards,
        );
      },
    );
  }
}

class _RevenueBreakdownCard extends StatelessWidget {
  const _RevenueBreakdownCard({
    required this.weekSales,
    required this.monthSales,
    required this.currency,
    required this.onOpenReports,
  });

  final double weekSales;
  final double monthSales;
  final NumberFormat currency;
  final VoidCallback onOpenReports;

  @override
  Widget build(BuildContext context) {
    final ratio = monthSales == 0
        ? 0.0
        : (weekSales / monthSales).clamp(0, 1).toDouble();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        PosColors.primary.withValues(alpha: 0.20),
                        PosColors.primary.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(PosRadii.sm),
                    border: Border.all(
                      color: PosColors.primary.withValues(alpha: 0.20),
                    ),
                  ),
                  child: Icon(
                    Icons.payments_rounded,
                    color: PosColors.primary,
                    size: 20,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Revenue',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: onOpenReports,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Reports'),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 18),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 14),
            _RevenueRow(
              label: 'This week',
              value: currency.format(weekSales),
              ratio: ratio,
              color: PosColors.primary,
            ),
            SizedBox(height: 14),
            _RevenueRow(
              label: 'This month',
              value: currency.format(monthSales),
              ratio: 1.0,
              color: PosColors.info,
            ),
          ],
        ),
      ),
    );
  }
}

class _RevenueRow extends StatelessWidget {
  const _RevenueRow({
    required this.label,
    required this.value,
    required this.ratio,
    required this.color,
  });

  final String label;
  final String value;
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: PosColors.muted,
                  fontWeight: FontWeight.w800,
                  fontSize: 11.6,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: PosColors.slate,
                fontWeight: FontWeight.w900,
                fontSize: 16.5,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(PosRadii.pill),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ratio),
            duration: Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: PosColors.mutedSoft,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CatalogHealthCard extends StatelessWidget {
  const _CatalogHealthCard({
    required this.total,
    required this.available,
    required this.pendingSync,
    required this.onOpenMenu,
    required this.onOpenSync,
  });

  final int total;
  final int available;
  final int pendingSync;
  final VoidCallback onOpenMenu;
  final VoidCallback onOpenSync;

  @override
  Widget build(BuildContext context) {
    final paused = (total - available).clamp(0, total);
    final ratio = total == 0 ? 0.0 : available / total;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        PosColors.accent.withValues(alpha: 0.22),
                        PosColors.accent.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(PosRadii.sm),
                    border: Border.all(
                      color: PosColors.accent.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Icon(
                    Icons.restaurant_menu_rounded,
                    color: PosColors.accent,
                    size: 20,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Catalog & sync',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _RingStat(
                  ratio: ratio,
                  label: 'Available',
                  value: '$available/$total',
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MiniStat(
                        icon: Icons.check_circle_outline,
                        color: PosColors.success,
                        label: 'Available items',
                        value: available.toString(),
                      ),
                      SizedBox(height: 8),
                      _MiniStat(
                        icon: Icons.pause_circle_outline,
                        color: PosColors.warning,
                        label: 'Paused items',
                        value: paused.toString(),
                      ),
                      SizedBox(height: 8),
                      _MiniStat(
                        icon: Icons.sync_problem_outlined,
                        color: pendingSync == 0
                            ? PosColors.success
                            : PosColors.warning,
                        label: 'Pending sync',
                        value: pendingSync.toString(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpenMenu,
                    icon: Icon(Icons.menu_book_outlined, size: 17),
                    label: Text('Open menu'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpenSync,
                    icon: Icon(Icons.sync_rounded, size: 17),
                    label: Text('Sync log'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RingStat extends StatelessWidget {
  const _RingStat({required this.ratio, required this.label, required this.value});

  final double ratio;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ratio),
            duration: Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return SizedBox(
                width: 96,
                height: 96,
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 8,
                  backgroundColor: PosColors.mutedSoft,
                  valueColor: AlwaysStoppedAnimation<Color>(PosColors.success),
                ),
              );
            },
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: PosColors.slate,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 0,
                ),
              ),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: PosColors.muted,
                  fontWeight: FontWeight.w800,
                  fontSize: 9,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(PosRadii.xs),
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: PosColors.muted,
              fontWeight: FontWeight.w700,
              fontSize: 12.2,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: PosColors.slate,
            fontWeight: FontWeight.w900,
            fontSize: 13.5,
          ),
        ),
      ],
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
        padding: EdgeInsets.all(14),
        child: Wrap(
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
              onPressed: () => onNavigate(0),
            ),
            PrimaryButton(
              label: 'Reports',
              icon: Icons.assessment_outlined,
              secondary: true,
              onPressed: () => onNavigate(3),
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
    final color = connected ? PosColors.success : PosColors.warning;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    color.withValues(alpha: 0.12),
                    color.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withValues(alpha: 0.22),
                        color.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(PosRadii.md),
                    border: Border.all(color: color.withValues(alpha: 0.28)),
                  ),
                  child: Icon(
                    connected
                        ? Icons.cloud_done_rounded
                        : Icons.cloud_queue_rounded,
                    color: color,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              connected
                                  ? 'Cloud ordering is connected'
                                  : 'Cloud changes will sync when reachable',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(
                                PosRadii.pill,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(color: color, blurRadius: 6),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  connected ? 'LIVE' : 'QUEUED',
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Customer websites should use the cloud API configured for this app.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: PosColors.surfaceTinted,
                          borderRadius: BorderRadius.circular(PosRadii.sm),
                          border: Border.all(color: PosColors.line),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.link_rounded,
                              size: 14,
                              color: PosColors.muted,
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: SelectableText(
                                cloudUrl,
                                maxLines: 1,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11.5,
                                  color: PosColors.slateSoft,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
