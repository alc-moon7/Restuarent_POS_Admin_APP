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
import '../../models/order_status.dart';
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

    final currency = NumberFormat.currency(symbol: '৳', decimalDigits: 2);
    final compactCurrency = NumberFormat.compactCurrency(symbol: '৳');
    final metrics = app.metrics;
    final sync = app.syncState;
    final report7 = app.salesReportForDays(7);
    final restaurantName = app.restaurantName.trim().isEmpty
        ? 'Restaurant'
        : app.restaurantName.trim();
    final pendingNow = app.orders
        .where((order) => order.status.adminStatus == OrderStatus.pending)
        .length;
    final acceptedNow = app.orders
        .where((order) => order.status.adminStatus == OrderStatus.accepted)
        .length;

    return AppScaffold(
      title: 'Home',
      showDatePill: false,
      centerHeader: true,
      actions: [
        _HomeHeaderDetails(
          restaurantName: restaurantName,
          greeting: _greeting(),
          cloudConnected: sync.cloudConnected,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroPanel(
            todaySales: metrics.totalSales,
            todayOrders: metrics.todayOrders,
            openOrders: metrics.pendingOrders,
            sevenDayReport: report7,
            currency: currency,
            compactCurrency: compactCurrency,
            onOpenOrders: () => onNavigate(0),
            onOpenReports: () => onNavigate(3),
          ),
          SizedBox(height: 14),
          _SectionLabel(icon: Icons.bolt_rounded, label: "Today's pulse"),
          SizedBox(height: 8),
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
                title: 'Pending',
                value: pendingNow.toString(),
                icon: Icons.pending_actions_outlined,
                color: PosColors.warning,
                onTap: () => onNavigate(0),
              ),
              DashboardCard(
                title: 'Accepted',
                value: acceptedNow.toString(),
                icon: Icons.check_circle_outline,
                color: PosColors.success,
                onTap: () => onNavigate(0),
              ),
              DashboardCard(
                title: 'Avg ticket',
                value: report7.averageOrderValue == 0
                    ? '-'
                    : currency.format(report7.averageOrderValue),
                icon: Icons.trending_up_outlined,
                color: PosColors.info,
                onTap: () => onNavigate(3),
              ),
            ],
          ),
          SizedBox(height: 14),
          _SectionLabel(
            icon: Icons.insights_rounded,
            label: 'Revenue & catalog',
          ),
          SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 860;
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
                  children: [revenueCard, SizedBox(height: 8), catalogCard],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: revenueCard),
                  SizedBox(width: 8),
                  Expanded(child: catalogCard),
                ],
              );
            },
          ),
          SizedBox(height: 14),
          _SectionLabel(icon: Icons.flash_on_rounded, label: 'Quick actions'),
          SizedBox(height: 8),
          _QuickActions(onNavigate: onNavigate, onSyncNow: app.syncNow),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    return hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
  }
}

class _HomeHeaderDetails extends StatelessWidget {
  const _HomeHeaderDetails({
    required this.restaurantName,
    required this.greeting,
    required this.cloudConnected,
  });

  final String restaurantName;
  final String greeting;
  final bool cloudConnected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          greeting,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: PosColors.slate,
            fontWeight: FontWeight.w900,
            fontSize: 13,
            height: 1.1,
          ),
        ),
        SizedBox(height: 7),
        Container(
          constraints: BoxConstraints(maxWidth: 280),
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: PosColors.surface,
            borderRadius: BorderRadius.circular(PosRadii.pill),
            border: Border.all(color: PosColors.lineStrong),
            boxShadow: [
              BoxShadow(
                color: PosColors.primary.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.restaurant_menu_rounded,
                color: PosColors.slate,
                size: 16,
              ),
              SizedBox(width: 7),
              Flexible(
                child: Text(
                  restaurantName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: PosColors.slate,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 7),
        _CloudHeaderStatus(connected: cloudConnected),
      ],
    );
  }
}

class _CloudHeaderStatus extends StatelessWidget {
  const _CloudHeaderStatus({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final color = connected ? PosColors.success : PosColors.warning;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: PosColors.background,
        borderRadius: BorderRadius.circular(PosRadii.pill),
        border: Border.all(color: PosColors.lineStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            connected ? Icons.check_circle_rounded : Icons.pending_rounded,
            color: color,
            size: 15,
          ),
          SizedBox(width: 6),
          Text(
            connected ? 'Cloud Connected' : 'Cloud Queue',
            style: TextStyle(
              color: PosColors.slate,
              fontWeight: FontWeight.w900,
              fontSize: 11.5,
              height: 1,
            ),
          ),
        ],
      ),
    );
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
          width: 27,
          height: 27,
          decoration: BoxDecoration(
            color: PosColors.surface,
            borderRadius: BorderRadius.circular(PosRadii.sm),
            border: Border.all(color: PosColors.lineStrong),
          ),
          child: Icon(icon, color: PosColors.slate, size: 15),
        ),
        SizedBox(width: 8),
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
    required this.openOrders,
    required this.sevenDayReport,
    required this.currency,
    required this.compactCurrency,
    required this.onOpenOrders,
    required this.onOpenReports,
  });

  final double todaySales;
  final int todayOrders;
  final int openOrders;
  final SalesReport sevenDayReport;
  final NumberFormat currency;
  final NumberFormat compactCurrency;
  final VoidCallback onOpenOrders;
  final VoidCallback onOpenReports;

  @override
  Widget build(BuildContext context) {
    final daily = sevenDayReport.dailyBreakdown;
    final values = daily.map<double>((day) => day.sales).toList();
    final labels = daily
        .map<String>((day) => DateFormat('E').format(day.date).substring(0, 1))
        .toList();
    final yesterday = values.length >= 2 ? values[values.length - 2] : 0.0;
    final delta = todaySales - yesterday;
    final pct = yesterday == 0 ? null : (delta / yesterday) * 100;

    return Card(
      color: PosColors.background,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PosRadii.lg),
        side: BorderSide(color: PosColors.lineStrong.withValues(alpha: 0.42)),
      ),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 620;
            final summary = _HeroSummary(
              todaySales: todaySales,
              todayOrders: todayOrders,
              openOrders: openOrders,
              delta: delta,
              pct: pct,
              weekSales: values.fold<double>(
                0,
                (total, value) => total + value,
              ),
              currency: currency,
              compactCurrency: compactCurrency,
              onOpenOrders: onOpenOrders,
              onOpenReports: onOpenReports,
            );
            final chart = _HeroChart(
              values: values,
              labels: labels,
              compactCurrency: compactCurrency,
            );
            if (!wide) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [summary, SizedBox(height: 14), chart],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: summary),
                SizedBox(width: 14),
                Expanded(flex: 5, child: chart),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeroSummary extends StatelessWidget {
  const _HeroSummary({
    required this.todaySales,
    required this.todayOrders,
    required this.openOrders,
    required this.delta,
    required this.pct,
    required this.weekSales,
    required this.currency,
    required this.compactCurrency,
    required this.onOpenOrders,
    required this.onOpenReports,
  });

  final double todaySales;
  final int todayOrders;
  final int openOrders;
  final double delta;
  final double? pct;
  final double weekSales;
  final NumberFormat currency;
  final NumberFormat compactCurrency;
  final VoidCallback onOpenOrders;
  final VoidCallback onOpenReports;

  @override
  Widget build(BuildContext context) {
    final positive = delta >= 0;
    final pctLabel = pct == null
        ? 'No previous day data'
        : '${positive ? '+' : ''}${pct!.toStringAsFixed(1)}% vs yesterday';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: PosColors.surface,
                borderRadius: BorderRadius.circular(PosRadii.pill),
                border: Border.all(color: PosColors.lineStrong),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.today_rounded, size: 13, color: PosColors.slate),
                  SizedBox(width: 5),
                  Text(
                    'TODAY LIVE',
                    style: TextStyle(
                      color: PosColors.slate,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 0.7,
                    ),
                  ),
                ],
              ),
            ),
            Spacer(),
            _SmallAction(label: 'Orders', onTap: onOpenOrders),
            SizedBox(width: 6),
            _SmallAction(label: 'Reports', onTap: onOpenReports),
          ],
        ),
        SizedBox(height: 12),
        Text(
          currency.format(todaySales),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: PosColors.slate,
            fontWeight: FontWeight.w900,
            fontSize: 30,
            letterSpacing: 0,
            height: 1,
          ),
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: positive
                ? PosColors.success.withValues(alpha: 0.10)
                : PosColors.danger.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(PosRadii.pill),
            border: Border.all(
              color: positive
                  ? PosColors.success.withValues(alpha: 0.28)
                  : PosColors.danger.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                positive
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                color: positive ? PosColors.success : PosColors.danger,
                size: 14,
              ),
              SizedBox(width: 5),
              Text(
                pctLabel,
                style: TextStyle(
                  color: PosColors.slate,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            _HeroChip(
              icon: Icons.receipt_long_rounded,
              label: '$todayOrders orders',
            ),
            _HeroChip(
              icon: Icons.pending_actions_rounded,
              label: '$openOrders open',
            ),
            _HeroChip(
              icon: Icons.calendar_view_week_rounded,
              label: '${compactCurrency.format(weekSales)} week',
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroChart extends StatelessWidget {
  const _HeroChart({
    required this.values,
    required this.labels,
    required this.compactCurrency,
  });

  final List<double> values;
  final List<String> labels;
  final NumberFormat compactCurrency;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.md),
        border: Border.all(color: PosColors.lineStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LAST 7 DAYS',
            style: TextStyle(
              color: PosColors.slate,
              fontWeight: FontWeight.w900,
              fontSize: 10.2,
              letterSpacing: 0.9,
            ),
          ),
          SizedBox(height: 8),
          MiniBarChart(
            values: values,
            labels: labels,
            color: PosColors.slate,
            height: 92,
            formatValue: (value) => compactCurrency.format(value),
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
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.pill),
        border: Border.all(color: PosColors.lineStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: PosColors.slate, size: 14),
          SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: PosColors.slate,
              fontWeight: FontWeight.w800,
              fontSize: 11,
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
        final columns = width >= 980
            ? 4
            : width >= 360
            ? 2
            : 1;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: width >= 980
              ? 2.35
              : width >= 520
              ? 2.05
              : width >= 360
              ? 1.75
              : 2.45,
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
      color: PosColors.background,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _IconBox(icon: Icons.payments_rounded),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Revenue',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onOpenReports,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Reports'),
                      Icon(Icons.chevron_right_rounded, size: 17),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            _RevenueRow(
              label: 'This week',
              value: currency.format(weekSales),
              ratio: ratio,
              color: PosColors.primary,
            ),
            SizedBox(height: 12),
            _RevenueRow(
              label: 'This month',
              value: currency.format(monthSales),
              ratio: 1,
              color: PosColors.warning,
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
                  fontSize: 11.5,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: PosColors.slate,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ],
        ),
        SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(PosRadii.pill),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ratio),
            duration: Duration(milliseconds: 600),
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
      color: PosColors.background,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _IconBox(icon: Icons.restaurant_menu_rounded),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Catalog & sync',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _RingStat(
                  ratio: ratio,
                  label: 'Available',
                  value: '$available/$total',
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      _MiniStat(
                        icon: Icons.check_circle_outline,
                        color: PosColors.success,
                        label: 'Available items',
                        value: available.toString(),
                      ),
                      SizedBox(height: 7),
                      _MiniStat(
                        icon: Icons.pause_circle_outline,
                        color: PosColors.warning,
                        label: 'Paused items',
                        value: paused.toString(),
                      ),
                      SizedBox(height: 7),
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
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpenMenu,
                    icon: Icon(Icons.menu_book_outlined, size: 16),
                    label: FittedBox(child: Text('Open menu')),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpenSync,
                    icon: Icon(Icons.sync_rounded, size: 16),
                    label: FittedBox(child: Text('Sync')),
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
  const _RingStat({
    required this.ratio,
    required this.label,
    required this.value,
  });

  final double ratio;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 86,
      height: 86,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ratio.clamp(0, 1).toDouble()),
            duration: Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return SizedBox(
                width: 86,
                height: 86,
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 8,
                  backgroundColor: PosColors.mutedSoft,
                  valueColor: AlwaysStoppedAnimation<Color>(PosColors.primary),
                ),
              );
            },
          ),
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: PosColors.background,
              shape: BoxShape.circle,
              border: Border.all(color: PosColors.lineStrong),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: PosColors.slate,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0,
                    height: 1,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: PosColors.muted,
                    fontWeight: FontWeight.w800,
                    fontSize: 8.5,
                    letterSpacing: 0,
                    height: 1,
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
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(PosRadii.xs),
            border: Border.all(color: color.withValues(alpha: 0.26)),
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: PosColors.muted,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: PosColors.slate,
            fontWeight: FontWeight.w900,
            fontSize: 13,
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
      color: PosColors.background,
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
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
              label: 'Settings',
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

class _SmallAction extends StatelessWidget {
  const _SmallAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PosRadii.pill),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: PosColors.surface,
          borderRadius: BorderRadius.circular(PosRadii.pill),
          border: Border.all(color: PosColors.lineStrong),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: PosColors.slate,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.sm),
        border: Border.all(color: PosColors.lineStrong),
      ),
      child: Icon(icon, color: PosColors.slate, size: 17),
    );
  }
}
