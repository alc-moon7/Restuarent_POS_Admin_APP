import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/order_model.dart';
import '../../models/order_status.dart';
import '../theme/app_theme.dart';
import 'status_badge.dart';

class OrderCard extends StatelessWidget {
  const OrderCard({
    required this.order,
    required this.onStatusChanged,
    required this.onPrintTicket,
    super.key,
  });

  final OrderModel order;
  final ValueChanged<OrderStatus> onStatusChanged;
  final VoidCallback onPrintTicket;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: r'$', decimalDigits: 2);
    final createdTime = DateFormat('MMM d, h:mm a').format(order.createdAt);
    final accent = _accentForStatus(order.status);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [accent, accent.withValues(alpha: 0.5)],
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accent.withValues(alpha: 0.06),
                          PosColors.surfaceWarm,
                        ],
                      ),
                      border: const Border(
                        bottom: BorderSide(color: PosColors.line),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _OrderMark(status: order.status),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.orderNo,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _MetaPill(
                                    icon: Icons.person_outline,
                                    label: order.customerName ?? 'Walk-in',
                                  ),
                                  _MetaPill(
                                    icon: Icons.table_restaurant_outlined,
                                    label: 'Table ${order.tableNo ?? 'N/A'}',
                                  ),
                                  _MetaPill(
                                    icon: Icons.schedule,
                                    label: createdTime,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Wrap(
                            spacing: 5,
                            runSpacing: 5,
                            alignment: WrapAlignment.end,
                            children: [
                              StatusBadge.source(order.source),
                              StatusBadge.sync(order.syncStatus),
                              StatusBadge.order(order.status),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: PosColors.surfaceTinted,
                            borderRadius: BorderRadius.circular(PosRadii.md),
                            border: Border.all(color: PosColors.line),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Column(
                              children: order.items
                                  .map(
                                    (item) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 34,
                                            height: 34,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  PosColors.primary.withValues(
                                                    alpha: 0.18,
                                                  ),
                                                  PosColors.primary.withValues(
                                                    alpha: 0.08,
                                                  ),
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(11),
                                              border: Border.all(
                                                color: PosColors.primary
                                                    .withValues(alpha: 0.2),
                                              ),
                                            ),
                                            child: Text(
                                              '${item.qty}×',
                                              style: const TextStyle(
                                                color: PosColors.primary,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 12.5,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              item.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleMedium,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            currency.format(item.lineTotal),
                                            style: const TextStyle(
                                              color: PosColors.slate,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ),
                        ),
                        if (order.note != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: PosColors.accentSoft,
                              borderRadius: BorderRadius.circular(PosRadii.md),
                              border: Border.all(
                                color: PosColors.accent.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.sticky_note_2_outlined,
                                  size: 18,
                                  color: PosColors.warning,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    order.note!,
                                    style: const TextStyle(
                                      color: PosColors.slateSoft,
                                      fontWeight: FontWeight.w600,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 520;
                            final total = Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    PosColors.primary.withValues(alpha: 0.10),
                                    PosColors.primary.withValues(alpha: 0.02),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(
                                  PosRadii.md,
                                ),
                                border: Border.all(
                                  color: PosColors.primary.withValues(
                                    alpha: 0.18,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'TOTAL',
                                    style: TextStyle(
                                      color: PosColors.muted,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10.6,
                                      letterSpacing: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    currency.format(order.total),
                                    style: const TextStyle(
                                      color: PosColors.primaryDark,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ],
                              ),
                            );
                            final actions = Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: onPrintTicket,
                                  icon: const Icon(
                                    Icons.print_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Print Ticket'),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: PosColors.surface,
                                    borderRadius: BorderRadius.circular(
                                      PosRadii.sm + 2,
                                    ),
                                    border: Border.all(
                                      color: PosColors.lineStrong,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x0A0F2A1F),
                                        blurRadius: 6,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<OrderStatus>(
                                      value: order.status,
                                      borderRadius: BorderRadius.circular(
                                        PosRadii.md,
                                      ),
                                      icon: const Icon(
                                        Icons.expand_more_rounded,
                                        color: PosColors.slate,
                                      ),
                                      style: const TextStyle(
                                        color: PosColors.slate,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                      items: OrderStatus.values
                                          .map(
                                            (status) => DropdownMenuItem(
                                              value: status,
                                              child: Text(status.label),
                                            ),
                                          )
                                          .toList(growable: false),
                                      onChanged: (status) {
                                        if (status != null &&
                                            status != order.status) {
                                          onStatusChanged(status);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            );
                            if (compact) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  total,
                                  const SizedBox(height: 12),
                                  actions,
                                ],
                              );
                            }
                            return Row(
                              children: [total, const Spacer(), actions],
                            );
                          },
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
    );
  }

  Color _accentForStatus(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return PosColors.warning;
      case OrderStatus.accepted:
        return PosColors.primary;
      case OrderStatus.preparing:
        return PosColors.info;
      case OrderStatus.ready:
        return PosColors.purple;
      case OrderStatus.served:
        return PosColors.success;
      case OrderStatus.cancelled:
        return PosColors.danger;
    }
  }
}

class _OrderMark extends StatelessWidget {
  const _OrderMark({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      OrderStatus.pending => PosColors.warning,
      OrderStatus.accepted => PosColors.primary,
      OrderStatus.preparing => PosColors.info,
      OrderStatus.ready => PosColors.purple,
      OrderStatus.served => PosColors.success,
      OrderStatus.cancelled => PosColors.danger,
    };
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.20),
            color.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(PosRadii.md),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.14),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(Icons.receipt_long_outlined, color: color, size: 22),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(PosRadii.pill),
        border: Border.all(color: PosColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.5, color: PosColors.muted),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: PosColors.slateSoft,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
