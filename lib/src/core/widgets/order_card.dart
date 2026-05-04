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

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              decoration: const BoxDecoration(
                color: PosColors.surfaceWarm,
                border: Border(bottom: BorderSide(color: PosColors.line)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _OrderMark(status: order.status),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.orderNo,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 7,
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
                            _MetaPill(icon: Icons.schedule, label: createdTime),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
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
                      color: PosColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: PosColors.line),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        children: order.items
                            .map((item) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 5,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: PosColors.primary.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${item.qty}x',
                                        style: const TextStyle(
                                          color: PosColors.primary,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 9),
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
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            })
                            .toList(growable: false),
                      ),
                    ),
                  ),
                  if (order.note != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: PosColors.accentSoft,
                        borderRadius: BorderRadius.circular(14),
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
                          Expanded(child: Text(order.note!)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 520;
                      final total = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            currency.format(order.total),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: PosColors.primary,
                                  fontSize: 22,
                                ),
                          ),
                        ],
                      );
                      final actions = Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: onPrintTicket,
                            icon: const Icon(Icons.print_outlined),
                            label: const Text('Print Ticket'),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: PosColors.surfaceWarm,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: PosColors.line),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<OrderStatus>(
                                value: order.status,
                                borderRadius: BorderRadius.circular(14),
                                items: OrderStatus.values
                                    .map((status) {
                                      return DropdownMenuItem(
                                        value: status,
                                        child: Text(status.label),
                                      );
                                    })
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
                        children: [
                          Expanded(child: total),
                          actions,
                        ],
                      );
                    },
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
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Icon(Icons.receipt_long_outlined, color: color),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: PosColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: PosColors.muted),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: PosColors.muted,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
