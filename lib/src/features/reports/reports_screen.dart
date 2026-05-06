import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/sales_report.dart';
import '../../services/report_pdf_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ReportPdfService _pdfService = ReportPdfService();
  final NumberFormat _currency = NumberFormat.currency(
    symbol: r'$',
    decimalDigits: 2,
  );
  final DateFormat _date = DateFormat('MMM d');
  int _days = 1;
  bool _exporting = false;
  bool _printing = false;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final report = app.salesReportForDays(_days);
    return AppScaffold(
      title: 'Sales Reports',
      subtitle: 'Daily, 7-day, and 30-day order history with PDF export.',
      actions: [
        PrimaryButton(
          label: 'Export PDF',
          icon: Icons.picture_as_pdf_outlined,
          busy: _exporting,
          onPressed: report.totalOrders == 0 ? null : () => _sharePdf(report),
        ),
        PrimaryButton(
          label: 'Print',
          icon: Icons.print_outlined,
          secondary: true,
          busy: _printing,
          onPressed: report.totalOrders == 0 ? null : () => _printPdf(report),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PeriodSelector(value: _days, onChanged: _setDays),
          SizedBox(height: 12),
          _ReportSummary(report: report, currency: _currency),
          SizedBox(height: 12),
          if (report.totalOrders == 0)
            EmptyState(
              title: 'No orders in this period',
              message:
                  'Orders will appear here after customers or staff create them.',
              icon: Icons.assessment_outlined,
            )
          else ...[
            _DailyBreakdown(report: report, currency: _currency, date: _date),
            SizedBox(height: 12),
            _TopItems(report: report, currency: _currency),
          ],
        ],
      ),
    );
  }

  void _setDays(int days) {
    if (_days == days) return;
    setState(() => _days = days);
  }

  Future<void> _sharePdf(SalesReport report) async {
    final app = AppScope.of(context);
    setState(() => _exporting = true);
    try {
      await _pdfService.shareSalesReport(
        report: report,
        serverConfig: app.serverConfig,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF export failed: $error')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _printPdf(SalesReport report) async {
    final app = AppScope.of(context);
    setState(() => _printing = true);
    try {
      await _pdfService.printSalesReport(
        report: report,
        serverConfig: app.serverConfig,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Print failed: $error')));
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: SegmentedButton<int>(
          segments: [
            ButtonSegment(
              value: 1,
              label: Text('1 Day'),
              icon: Icon(Icons.today_outlined),
            ),
            ButtonSegment(
              value: 7,
              label: Text('7 Days'),
              icon: Icon(Icons.date_range_outlined),
            ),
            ButtonSegment(
              value: 30,
              label: Text('30 Days'),
              icon: Icon(Icons.calendar_month_outlined),
            ),
          ],
          selected: {value},
          onSelectionChanged: (values) => onChanged(values.first),
        ),
      ),
    );
  }
}

class _ReportSummary extends StatelessWidget {
  const _ReportSummary({required this.report, required this.currency});

  final SalesReport report;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 960
            ? 4
            : constraints.maxWidth >= 620
            ? 3
            : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: constraints.maxWidth >= 620 ? 2.0 : 1.35,
          children: [
            _ReportTile(
              label: 'Total sales',
              value: currency.format(report.totalSales),
              icon: Icons.payments_outlined,
              color: PosColors.primary,
            ),
            _ReportTile(
              label: 'Orders',
              value: report.totalOrders.toString(),
              icon: Icons.receipt_long_outlined,
              color: Color(0xFF2563EB),
            ),
            _ReportTile(
              label: 'Avg order',
              value: currency.format(report.averageOrderValue),
              icon: Icons.trending_up_outlined,
              color: PosColors.success,
            ),
            _ReportTile(
              label: 'Items sold',
              value: report.totalItemsSold.toString(),
              icon: Icons.local_dining_outlined,
              color: PosColors.warning,
            ),
            _ReportTile(
              label: 'Open',
              value: report.openOrders.toString(),
              icon: Icons.pending_actions_outlined,
              color: PosColors.warning,
            ),
            _ReportTile(
              label: 'Completed',
              value: report.completedOrders.toString(),
              icon: Icons.done_all,
              color: PosColors.success,
            ),
          ],
        );
      },
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: PosGradients.cardTint(color)),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
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
                    border: Border.all(color: color.withValues(alpha: 0.22)),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label.toUpperCase(),
                        style: TextStyle(
                          color: PosColors.muted,
                          fontWeight: FontWeight.w800,
                          fontSize: 10.4,
                          letterSpacing: 1.1,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
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

class _DailyBreakdown extends StatelessWidget {
  const _DailyBreakdown({
    required this.report,
    required this.currency,
    required this.date,
  });

  final SalesReport report;
  final NumberFormat currency;
  final DateFormat date;

  @override
  Widget build(BuildContext context) {
    return _ReportCard(
      title: 'Daily breakdown',
      icon: Icons.bar_chart_outlined,
      child: Column(
        children: [
          for (final day in report.dailyBreakdown.reversed)
            _LineRow(
              title: date.format(day.date),
              subtitle: '${day.orders} orders',
              trailing: currency.format(day.sales),
            ),
        ],
      ),
    );
  }
}

class _TopItems extends StatelessWidget {
  const _TopItems({required this.report, required this.currency});

  final SalesReport report;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    return _ReportCard(
      title: 'Top selling items',
      icon: Icons.emoji_events_outlined,
      child: report.topItems.isEmpty
          ? Text(
              'No item sales yet.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          : Column(
              children: [
                for (final item in report.topItems)
                  _LineRow(
                    title: item.name,
                    subtitle: '${item.qty} sold',
                    trailing: currency.format(item.sales),
                  ),
              ],
            ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.title, required this.icon, required this.child});

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: PosColors.primary),
                SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Text(trailing, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
