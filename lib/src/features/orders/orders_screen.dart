import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/order_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/menu_item.dart';
import '../../models/order_item.dart';
import '../../models/order_model.dart';
import '../../models/order_source.dart';
import '../../models/order_status.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  OrderStatus? _filter;
  OrderSource? _sourceFilter;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final orders = app.ordersFor(status: _filter, source: _sourceFilter);

    return AppScaffold(
      title: 'Orders',
      subtitle: 'Manage live order flow from pending to served.',
      actions: [
        PrimaryButton(
          label: 'New Order',
          icon: Icons.add_shopping_cart,
          onPressed: app.menuItems.any((item) => item.isAvailable)
              ? () => _openManualOrderForm(context)
              : null,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusFilters(
            selected: _filter,
            onChanged: (status) => setState(() => _filter = status),
          ),
          const SizedBox(height: 10),
          _SourceFilters(
            selected: _sourceFilter,
            onChanged: (source) => setState(() => _sourceFilter = source),
          ),
          const SizedBox(height: 12),
          if (app.orders.isEmpty)
            EmptyState(
              title: 'No orders yet',
              message: 'Cloud customer orders will appear here after sync.',
              icon: Icons.receipt_long_outlined,
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

  Future<void> _openManualOrderForm(BuildContext context) async {
    final app = AppScope.of(context);
    final menuItems = app.menuItems
        .where((item) => item.isAvailable)
        .toList(growable: false);
    if (menuItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No available menu items to order')),
      );
      return;
    }

    final result = await showModalBottomSheet<_ManualOrderResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _ManualOrderForm(menuItems: menuItems),
    );
    if (result == null) return;

    await app.createManualOrder(
      requestedItems: result.items,
      customerName: result.customerName,
      tableNo: result.tableNo,
      note: result.note,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Manual order created')));
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

class _ManualOrderForm extends StatefulWidget {
  const _ManualOrderForm({required this.menuItems});

  final List<MenuItem> menuItems;

  @override
  State<_ManualOrderForm> createState() => _ManualOrderFormState();
}

class _ManualOrderFormState extends State<_ManualOrderForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _tableController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  late final List<_DraftOrderLine> _lines;

  @override
  void initState() {
    super.initState();
    _lines = [_DraftOrderLine(menuItemId: widget.menuItems.first.id)];
  }

  @override
  void dispose() {
    _customerController.dispose();
    _tableController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Create Manual Order',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 560;
                    final customer = TextField(
                      controller: _customerController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Customer name',
                        hintText: 'Optional',
                      ),
                    );
                    final table = TextField(
                      controller: _tableController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Table number',
                        hintText: 'Optional',
                      ),
                    );
                    if (compact) {
                      return Column(
                        children: [customer, const SizedBox(height: 10), table],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: customer),
                        const SizedBox(width: 12),
                        Expanded(child: table),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Order note',
                    hintText: 'Optional',
                  ),
                ),
                const SizedBox(height: 12),
                Text('Items', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ..._lines.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _OrderLineEditor(
                      line: entry.value,
                      menuItems: widget.menuItems,
                      canRemove: _lines.length > 1,
                      onChanged: () => setState(() {}),
                      onRemove: () {
                        setState(() => _lines.removeAt(entry.key));
                      },
                    ),
                  );
                }),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(
                      () => _lines.add(
                        _DraftOrderLine(menuItemId: widget.menuItems.first.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add item'),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Create Order'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final items = _lines
        .where((line) => line.menuItemId != null && line.qty > 0)
        .map(
          (line) =>
              OrderRequestItem(menuItemId: line.menuItemId!, qty: line.qty),
        )
        .toList(growable: false);
    if (items.isEmpty) return;
    Navigator.pop(
      context,
      _ManualOrderResult(
        customerName: _emptyToNull(_customerController.text),
        tableNo: _emptyToNull(_tableController.text),
        note: _emptyToNull(_noteController.text),
        items: items,
      ),
    );
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _OrderLineEditor extends StatelessWidget {
  const _OrderLineEditor({
    required this.line,
    required this.menuItems,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  final _DraftOrderLine line;
  final List<MenuItem> menuItems;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: PosColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final selector = DropdownButtonFormField<String>(
            initialValue: line.menuItemId,
            decoration: const InputDecoration(labelText: 'Menu item'),
            items: menuItems
                .map((item) {
                  return DropdownMenuItem(
                    value: item.id,
                    child: Text(item.name, overflow: TextOverflow.ellipsis),
                  );
                })
                .toList(growable: false),
            onChanged: (value) {
              line.menuItemId = value;
              onChanged();
            },
            validator: (value) {
              if (value == null || value.isEmpty) return 'Select item';
              return null;
            },
          );
          final controls = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _QtyStepper(
                qty: line.qty,
                onChanged: (qty) {
                  line.qty = qty;
                  onChanged();
                },
              ),
              IconButton(
                tooltip: 'Remove item',
                onPressed: canRemove ? onRemove : null,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          );

          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                selector,
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: controls),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: selector),
              const SizedBox(width: 8),
              controls,
            ],
          );
        },
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({required this.qty, required this.onChanged});

  final int qty;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Decrease',
          onPressed: qty <= 1 ? null : () => onChanged(qty - 1),
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 28,
          child: Text(
            qty.toString(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: 'Increase',
          onPressed: () => onChanged(qty + 1),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}

class _DraftOrderLine {
  _DraftOrderLine({required this.menuItemId});

  String? menuItemId;
  int qty = 1;
}

class _ManualOrderResult {
  const _ManualOrderResult({
    required this.items,
    this.customerName,
    this.tableNo,
    this.note,
  });

  final String? customerName;
  final String? tableNo;
  final String? note;
  final List<OrderRequestItem> items;
}

class _SourceFilters extends StatelessWidget {
  const _SourceFilters({required this.selected, required this.onChanged});

  final OrderSource? selected;
  final ValueChanged<OrderSource?> onChanged;

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
                label: 'All Sources',
                selected: selected == null,
                onTap: () => onChanged(null),
              ),
              for (final source in OrderSource.values)
                _FilterChip(
                  label: source.label,
                  selected: selected == source,
                  onTap: () => onChanged(source),
                ),
            ],
          ),
        ),
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
