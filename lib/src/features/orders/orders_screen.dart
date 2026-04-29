import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/order_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/order_model.dart';
import '../../models/order_status.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  OrderStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final orders = app.orders
        .where((order) {
          return _filter == null || order.status == _filter;
        })
        .toList(growable: false);

    return AppScaffold(
      title: 'Orders',
      subtitle: 'Manage live order flow from pending to served.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusFilters(
            selected: _filter,
            onChanged: (status) => setState(() => _filter = status),
          ),
          const SizedBox(height: 12),
          if (app.orders.isEmpty)
            EmptyState(
              title: 'No orders yet',
              message:
                  'Orders created through POST /orders will appear here instantly.',
              icon: Icons.receipt_long_outlined,
              action: PrimaryButton(
                label: 'Open Server Setup',
                icon: Icons.settings_input_antenna,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Use the Server tab to start LAN ordering.',
                      ),
                    ),
                  );
                },
              ),
            )
          else if (orders.isEmpty)
            const EmptyState(
              title: 'No orders in this status',
              message: 'Select another status filter to view more orders.',
              icon: Icons.filter_alt_off_outlined,
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final order = orders[index];
                return OrderCard(
                  order: order,
                  onStatusChanged: (status) async {
                    await app.updateOrderStatus(order.id, status);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Order ${order.orderNo} marked ${status.label}',
                        ),
                      ),
                    );
                  },
                  onPrintTicket: () => _showTicketPreview(context, order),
                );
              },
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemCount: orders.length,
            ),
        ],
      ),
    );
  }

  Future<void> _showTicketPreview(
    BuildContext context,
    OrderModel order,
  ) async {
    final app = AppScope.of(context);
    final ticket = await app.printTicketPreview(order);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ticket Preview'),
        content: SingleChildScrollView(
          child: SelectableText(
            ticket,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _StatusFilters extends StatelessWidget {
  const _StatusFilters({required this.selected, required this.onChanged});

  final OrderStatus? selected;
  final ValueChanged<OrderStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: 'All',
                selected: selected == null,
                onTap: () => onChanged(null),
              ),
              for (final status in OrderStatus.values)
                _FilterChip(
                  label: status.label,
                  selected: selected == status,
                  onTap: () => onChanged(status),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: PosColors.primary.withValues(alpha: 0.14),
        labelStyle: TextStyle(
          color: selected ? PosColors.primary : PosColors.slate,
          fontWeight: FontWeight.w800,
        ),
        side: BorderSide(color: selected ? PosColors.primary : PosColors.line),
      ),
    );
  }
}
