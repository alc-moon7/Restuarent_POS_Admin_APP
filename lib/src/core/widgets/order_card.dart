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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.orderNo,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${order.customerName ?? 'Walk-in'} • Table ${order.tableNo ?? 'N/A'}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                StatusBadge.order(order.status),
              ],
            ),
            const SizedBox(height: 14),
            DecoratedBox(
              decoration: BoxDecoration(
                color: PosColors.background,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: order.items
                      .map((item) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
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
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              Text(currency.format(item.lineTotal)),
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
              Row(
                children: [
                  const Icon(Icons.sticky_note_2_outlined, size: 17),
                  const SizedBox(width: 8),
                  Expanded(child: Text(order.note!)),
                ],
              ),
            ],
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 520;
                final total = Text(
                  currency.format(order.total),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: PosColors.primary),
                );
                final meta = Text(
                  createdTime,
                  style: Theme.of(context).textTheme.bodyMedium,
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
                    DropdownButtonHideUnderline(
                      child: DropdownButton<OrderStatus>(
                        value: order.status,
                        borderRadius: BorderRadius.circular(16),
                        items: OrderStatus.values
                            .map((status) {
                              return DropdownMenuItem(
                                value: status,
                                child: Text(status.label),
                              );
                            })
                            .toList(growable: false),
                        onChanged: (status) {
                          if (status != null && status != order.status) {
                            onStatusChanged(status);
                          }
                        },
                      ),
                    ),
                  ],
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      total,
                      const SizedBox(height: 4),
                      meta,
                      const SizedBox(height: 12),
                      actions,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [total, const SizedBox(height: 4), meta],
                      ),
                    ),
                    actions,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
