import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

enum _OrdersView { board, list }

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  OrderStatus? _filter;
  OrderSource? _sourceFilter;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  _OrdersView _view = _OrdersView.board;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final allOrders = app.ordersFor(source: _sourceFilter);
    final query = _searchQuery.trim().toLowerCase();
    final filtered = query.isEmpty
        ? allOrders
        : allOrders
              .where((order) {
                return order.orderNo.toLowerCase().contains(query) ||
                    (order.customerName ?? '').toLowerCase().contains(query) ||
                    (order.tableNo ?? '').toLowerCase().contains(query);
              })
              .toList(growable: false);
    final orders = _filter == null
        ? filtered
        : filtered.where((o) => o.status == _filter).toList(growable: false);

    return AppScaffold(
      title: 'Orders',
      subtitle: 'Live order workflow — pending to served.',
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
          _StatusSummary(
            allOrders: allOrders,
            selected: _filter,
            onSelect: (status) => setState(() => _filter = status),
          ),
          SizedBox(height: 12),
          _ToolbarRow(
            controller: _searchController,
            onSearchChanged: (v) => setState(() => _searchQuery = v),
            sourceFilter: _sourceFilter,
            onSourceChanged: (s) => setState(() => _sourceFilter = s),
            view: _view,
            onViewChanged: (v) => setState(() => _view = v),
          ),
          SizedBox(height: 12),
          if (app.orders.isEmpty)
            EmptyState(
              title: 'No orders yet',
              message: 'Cloud customer orders will appear here after sync.',
              icon: Icons.receipt_long_outlined,
            )
          else if (orders.isEmpty)
            EmptyState(
              title: 'No orders match the filters',
              message: 'Try clearing the search or status filter.',
              icon: Icons.filter_alt_off_outlined,
            )
          else if (_view == _OrdersView.board)
            _KanbanBoard(
              orders: orders,
              onStatusChanged: (order, status) =>
                  _changeStatus(context, order, status),
              onPrintTicket: (order) => _showTicketPreview(context, order),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final order = orders[index];
                return OrderCard(
                  order: order,
                  onStatusChanged: (status) =>
                      _changeStatus(context, order, status),
                  onPrintTicket: () => _showTicketPreview(context, order),
                );
              },
              separatorBuilder: (context, index) => SizedBox(height: 10),
              itemCount: orders.length,
            ),
        ],
      ),
    );
  }

  Future<void> _changeStatus(
    BuildContext context,
    OrderModel order,
    OrderStatus status,
  ) async {
    final app = AppScope.of(context);
    await app.updateOrderStatus(order.id, status);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Order ${order.orderNo} marked ${status.label}')),
    );
  }

  Future<void> _openManualOrderForm(BuildContext context) async {
    final app = AppScope.of(context);
    final menuItems = app.menuItems
        .where((item) => item.isAvailable)
        .toList(growable: false);
    if (menuItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No available menu items to order')),
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
    ).showSnackBar(SnackBar(content: Text('Manual order created')));
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
        title: Text('Ticket Preview'),
        content: SingleChildScrollView(
          child: SelectableText(
            ticket,
            style: TextStyle(fontFamily: 'monospace'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () async {
              final ok = await app.printOrderTicket(order);
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? 'Ticket sent to printer'
                        : app.printerState.lastError ?? 'Print failed',
                  ),
                ),
              );
            },
            icon: Icon(Icons.print_outlined),
            label: Text('Print'),
          ),
        ],
      ),
    );
  }
}

class _StatusSummary extends StatelessWidget {
  const _StatusSummary({
    required this.allOrders,
    required this.selected,
    required this.onSelect,
  });

  final List<OrderModel> allOrders;
  final OrderStatus? selected;
  final ValueChanged<OrderStatus?> onSelect;

  @override
  Widget build(BuildContext context) {
    final tiles = <_SummaryTile>[
      _SummaryTile(
        status: null,
        label: 'All',
        count: allOrders.length,
        color: PosColors.slate,
        icon: Icons.list_alt_rounded,
      ),
      ...OrderStatus.values.map(
        (s) => _SummaryTile(
          status: s,
          label: s.label,
          count: allOrders.where((o) => o.status == s).length,
          color: _colorForStatus(s),
          icon: _iconForStatus(s),
        ),
      ),
    ];

    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tiles.length,
        separatorBuilder: (_, _) => SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tile = tiles[index];
          final isSelected = selected == tile.status;
          return _StatusChip(
            tile: tile,
            selected: isSelected,
            onTap: () => onSelect(tile.status),
          );
        },
      ),
    );
  }
}

class _SummaryTile {
  _SummaryTile({
    required this.status,
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });
  final OrderStatus? status;
  final String label;
  final int count;
  final Color color;
  final IconData icon;
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.tile,
    required this.selected,
    required this.onTap,
  });

  final _SummaryTile tile;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PosRadii.md),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 180),
          padding: EdgeInsets.fromLTRB(14, 10, 16, 10),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      tile.color.withValues(alpha: 0.18),
                      tile.color.withValues(alpha: 0.08),
                    ],
                  )
                : null,
            color: selected ? null : PosColors.surface,
            borderRadius: BorderRadius.circular(PosRadii.md),
            border: Border.all(
              color: selected
                  ? tile.color.withValues(alpha: 0.45)
                  : PosColors.line,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: tile.color.withValues(alpha: 0.18),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Color(0x0A0F2A1F),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: tile.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(PosRadii.sm),
                ),
                child: Icon(tile.icon, color: tile.color, size: 17),
              ),
              SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    tile.count.toString(),
                    style: TextStyle(
                      color: selected ? tile.color : PosColors.slate,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      letterSpacing: 0,
                      height: 1.0,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    tile.label.toUpperCase(),
                    style: TextStyle(
                      color: selected ? tile.color : PosColors.muted,
                      fontWeight: FontWeight.w800,
                      fontSize: 9.6,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _colorForStatus(OrderStatus s) {
  return switch (s) {
    OrderStatus.pending => PosColors.warning,
    OrderStatus.accepted => PosColors.primary,
    OrderStatus.preparing => PosColors.info,
    OrderStatus.ready => PosColors.purple,
    OrderStatus.served => PosColors.success,
    OrderStatus.cancelled => PosColors.danger,
  };
}

IconData _iconForStatus(OrderStatus s) {
  return switch (s) {
    OrderStatus.pending => Icons.schedule_rounded,
    OrderStatus.accepted => Icons.check_circle_outline,
    OrderStatus.preparing => Icons.local_fire_department_outlined,
    OrderStatus.ready => Icons.room_service_outlined,
    OrderStatus.served => Icons.done_all_rounded,
    OrderStatus.cancelled => Icons.cancel_outlined,
  };
}

class _ToolbarRow extends StatelessWidget {
  const _ToolbarRow({
    required this.controller,
    required this.onSearchChanged,
    required this.sourceFilter,
    required this.onSourceChanged,
    required this.view,
    required this.onViewChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSearchChanged;
  final OrderSource? sourceFilter;
  final ValueChanged<OrderSource?> onSourceChanged;
  final _OrdersView view;
  final ValueChanged<_OrdersView> onViewChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 720;
            final search = TextField(
              controller: controller,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Order #, customer, table…',
              ),
            );
            final sourceMenu = _SourceDropdown(
              value: sourceFilter,
              onChanged: onSourceChanged,
            );
            final viewToggle = _ViewToggle(
              value: view,
              onChanged: onViewChanged,
            );
            if (compact) {
              return Column(
                children: [
                  search,
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: sourceMenu),
                      SizedBox(width: 8),
                      viewToggle,
                    ],
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(flex: 5, child: search),
                SizedBox(width: 10),
                Expanded(flex: 3, child: sourceMenu),
                SizedBox(width: 10),
                viewToggle,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SourceDropdown extends StatelessWidget {
  const _SourceDropdown({required this.value, required this.onChanged});

  final OrderSource? value;
  final ValueChanged<OrderSource?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<OrderSource?>(
      initialValue: value,
      decoration: InputDecoration(
        prefixIcon: Icon(Icons.merge_type_rounded),
        labelText: 'Source',
      ),
      items: [
        DropdownMenuItem<OrderSource?>(
          value: null,
          child: Text('All sources'),
        ),
        for (final s in OrderSource.values)
          DropdownMenuItem<OrderSource?>(value: s, child: Text(s.label)),
      ],
      onChanged: onChanged,
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.value, required this.onChanged});

  final _OrdersView value;
  final ValueChanged<_OrdersView> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_OrdersView>(
      style: ButtonStyle(visualDensity: VisualDensity.compact),
      segments: [
        ButtonSegment(
          value: _OrdersView.board,
          icon: Icon(Icons.view_kanban_rounded),
          tooltip: 'Board',
        ),
        ButtonSegment(
          value: _OrdersView.list,
          icon: Icon(Icons.view_list_rounded),
          tooltip: 'List',
        ),
      ],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (set) => onChanged(set.first),
    );
  }
}

class _KanbanBoard extends StatelessWidget {
  const _KanbanBoard({
    required this.orders,
    required this.onStatusChanged,
    required this.onPrintTicket,
  });

  final List<OrderModel> orders;
  final void Function(OrderModel order, OrderStatus status) onStatusChanged;
  final void Function(OrderModel order) onPrintTicket;

  static final _columns = <OrderStatus>[
    OrderStatus.pending,
    OrderStatus.accepted,
    OrderStatus.preparing,
    OrderStatus.ready,
    OrderStatus.served,
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: 560,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: BouncingScrollPhysics(),
            itemCount: _columns.length,
            separatorBuilder: (_, _) => SizedBox(width: 12),
            itemBuilder: (context, index) {
              final status = _columns[index];
              final lane = orders.where((o) => o.status == status).toList();
              return SizedBox(
                width: 320,
                child: _Lane(
                  status: status,
                  orders: lane,
                  onStatusChanged: onStatusChanged,
                  onPrintTicket: onPrintTicket,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _Lane extends StatelessWidget {
  const _Lane({
    required this.status,
    required this.orders,
    required this.onStatusChanged,
    required this.onPrintTicket,
  });

  final OrderStatus status;
  final List<OrderModel> orders;
  final void Function(OrderModel order, OrderStatus status) onStatusChanged;
  final void Function(OrderModel order) onPrintTicket;

  @override
  Widget build(BuildContext context) {
    final color = _colorForStatus(status);
    return Container(
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.lg),
        border: Border.all(color: PosColors.line),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A0F2A1F),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.16),
                  color.withValues(alpha: 0.04),
                ],
              ),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(PosRadii.lg),
              ),
              border: Border(bottom: BorderSide(color: PosColors.line)),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(PosRadii.sm),
                  ),
                  child: Icon(_iconForStatus(status), color: color, size: 16),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    status.label.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(PosRadii.pill),
                    border: Border.all(color: color.withValues(alpha: 0.32)),
                  ),
                  child: Text(
                    orders.length.toString(),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: orders.isEmpty
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _iconForStatus(status),
                            color: color.withValues(alpha: 0.45),
                            size: 28,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'No ${status.label.toLowerCase()} orders',
                            style: TextStyle(
                              color: PosColors.muted,
                              fontWeight: FontWeight.w700,
                              fontSize: 11.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.all(10),
                    itemCount: orders.length,
                    separatorBuilder: (_, _) => SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final order = orders[i];
                      return _LaneCard(
                        order: order,
                        accent: color,
                        onAdvance: () {
                          final next = _nextStatus(order.status);
                          if (next != null) onStatusChanged(order, next);
                        },
                        onCancel: () =>
                            onStatusChanged(order, OrderStatus.cancelled),
                        onPrint: () => onPrintTicket(order),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  OrderStatus? _nextStatus(OrderStatus current) {
    switch (current) {
      case OrderStatus.pending:
        return OrderStatus.accepted;
      case OrderStatus.accepted:
        return OrderStatus.preparing;
      case OrderStatus.preparing:
        return OrderStatus.ready;
      case OrderStatus.ready:
        return OrderStatus.served;
      case OrderStatus.served:
      case OrderStatus.cancelled:
        return null;
    }
  }
}

class _LaneCard extends StatelessWidget {
  const _LaneCard({
    required this.order,
    required this.accent,
    required this.onAdvance,
    required this.onCancel,
    required this.onPrint,
  });

  final OrderModel order;
  final Color accent;
  final VoidCallback onAdvance;
  final VoidCallback onCancel;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: r'$', decimalDigits: 2);
    final time = DateFormat('h:mm a').format(order.createdAt);
    final canAdvance =
        order.status != OrderStatus.served &&
        order.status != OrderStatus.cancelled;
    final canCancel =
        order.status != OrderStatus.served &&
        order.status != OrderStatus.cancelled;

    return Container(
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.md),
        border: Border.all(color: PosColors.line),
        boxShadow: [
          BoxShadow(
            color: Color(0x080F2A1F),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent, accent.withValues(alpha: 0.4)],
              ),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(PosRadii.md),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.orderNo,
                        style: TextStyle(
                          color: PosColors.slate,
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    Text(
                      time,
                      style: TextStyle(
                        color: PosColors.muted,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _MiniMeta(
                      icon: Icons.person_outline,
                      label: order.customerName ?? 'Walk-in',
                    ),
                    _MiniMeta(
                      icon: Icons.table_restaurant_outlined,
                      label: 'T${order.tableNo ?? '·'}',
                    ),
                    _MiniMeta(
                      icon: Icons.shopping_bag_outlined,
                      label:
                          '${order.items.length} item${order.items.length == 1 ? '' : 's'}',
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: PosColors.surfaceTinted,
                    borderRadius: BorderRadius.circular(PosRadii.sm),
                    border: Border.all(color: PosColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final item in order.items.take(3))
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 1.5),
                          child: Row(
                            children: [
                              Text(
                                '${item.qty}×',
                                style: TextStyle(
                                  color: PosColors.primary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11.5,
                                ),
                              ),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  item.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: PosColors.slateSoft,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (order.items.length > 3)
                        Padding(
                          padding: EdgeInsets.only(top: 3),
                          child: Text(
                            '+ ${order.items.length - 3} more',
                            style: TextStyle(
                              color: PosColors.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      currency.format(order.total),
                      style: TextStyle(
                        color: PosColors.primaryDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 0,
                      ),
                    ),
                    Spacer(),
                    _CardIconBtn(
                      icon: Icons.print_outlined,
                      tooltip: 'Print ticket',
                      onTap: onPrint,
                    ),
                    SizedBox(width: 6),
                    if (canCancel)
                      _CardIconBtn(
                        icon: Icons.close_rounded,
                        tooltip: 'Cancel order',
                        onTap: onCancel,
                        color: PosColors.danger,
                      ),
                  ],
                ),
                if (canAdvance) ...[
                  SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onAdvance,
                      icon: Icon(Icons.arrow_forward_rounded, size: 17),
                      label: Text(
                        _nextLabel(order.status),
                        style: TextStyle(fontSize: 12.5),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        padding: EdgeInsets.symmetric(vertical: 9),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _nextLabel(OrderStatus status) {
    return switch (status) {
      OrderStatus.pending => 'Accept',
      OrderStatus.accepted => 'Start preparing',
      OrderStatus.preparing => 'Mark ready',
      OrderStatus.ready => 'Mark served',
      _ => 'Advance',
    };
  }
}

class _CardIconBtn extends StatelessWidget {
  const _CardIconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? PosColors.slate;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(PosRadii.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(PosRadii.sm),
          child: Padding(
            padding: EdgeInsets.all(7),
            child: Icon(icon, color: c, size: 16),
          ),
        ),
      ),
    );
  }
}

class _MiniMeta extends StatelessWidget {
  const _MiniMeta({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: PosColors.surfaceTinted,
        borderRadius: BorderRadius.circular(PosRadii.pill),
        border: Border.all(color: PosColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11.5, color: PosColors.muted),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: PosColors.slateSoft,
              fontWeight: FontWeight.w700,
              fontSize: 10.6,
            ),
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
    final currency = NumberFormat.currency(symbol: r'$', decimalDigits: 2);
    final total = _lines.fold<double>(0, (sum, line) {
      if (line.menuItemId == null) return sum;
      final item = widget.menuItems.firstWhere(
        (m) => m.id == line.menuItemId,
        orElse: () => widget.menuItems.first,
      );
      return sum + item.price * line.qty;
    });
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, 14, 18, 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: PosGradients.brand,
                        borderRadius: BorderRadius.circular(PosRadii.sm + 2),
                        boxShadow: PosShadows.glow,
                      ),
                      child: Icon(
                        Icons.add_shopping_cart_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create Manual Order',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            'Add walk-in or phone orders manually',
                            style: TextStyle(
                              color: PosColors.muted,
                              fontWeight: FontWeight.w600,
                              fontSize: 11.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 560;
                    final customer = TextField(
                      controller: _customerController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Customer name',
                        hintText: 'Optional',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    );
                    final table = TextField(
                      controller: _tableController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Table number',
                        hintText: 'Optional',
                        prefixIcon: Icon(Icons.table_restaurant_outlined),
                      ),
                    );
                    if (compact) {
                      return Column(
                        children: [customer, SizedBox(height: 10), table],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: customer),
                        SizedBox(width: 12),
                        Expanded(child: table),
                      ],
                    );
                  },
                ),
                SizedBox(height: 10),
                TextField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Order note',
                    hintText: 'Optional',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.shopping_basket_outlined,
                      size: 18,
                      color: PosColors.primary,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Items',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Spacer(),
                    Text(
                      '${_lines.length} line${_lines.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: PosColors.muted,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.6,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                ..._lines.asMap().entries.map((entry) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: 10),
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
                  icon: Icon(Icons.add),
                  label: Text('Add another item'),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        PosColors.primary.withValues(alpha: 0.10),
                        PosColors.primary.withValues(alpha: 0.02),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(PosRadii.md),
                    border: Border.all(
                      color: PosColors.primary.withValues(alpha: 0.20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'TOTAL',
                        style: TextStyle(
                          color: PosColors.muted,
                          fontWeight: FontWeight.w900,
                          fontSize: 11.5,
                          letterSpacing: 1.4,
                        ),
                      ),
                      Spacer(),
                      Text(
                        currency.format(total),
                        style: TextStyle(
                          color: PosColors.primaryDark,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: Icon(Icons.receipt_long_outlined),
                    label: Text('Create Order'),
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
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: PosColors.surfaceWarm,
        border: Border.all(color: PosColors.line),
        borderRadius: BorderRadius.circular(PosRadii.md),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final selector = DropdownButtonFormField<String>(
            initialValue: line.menuItemId,
            decoration: InputDecoration(
              labelText: 'Menu item',
              prefixIcon: Icon(Icons.restaurant_menu_rounded),
            ),
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
              SizedBox(width: 4),
              IconButton(
                tooltip: 'Remove item',
                onPressed: canRemove ? onRemove : null,
                icon: Icon(Icons.delete_outline),
                color: PosColors.danger,
              ),
            ],
          );

          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                selector,
                SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: controls),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: selector),
              SizedBox(width: 8),
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
    return Container(
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.pill),
        border: Border.all(color: PosColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Decrease',
            onPressed: qty <= 1 ? null : () => onChanged(qty - 1),
            icon: Icon(Icons.remove_rounded, size: 18),
          ),
          SizedBox(
            width: 22,
            child: Text(
              qty.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: PosColors.slate,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Increase',
            onPressed: () => onChanged(qty + 1),
            icon: Icon(Icons.add_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _DraftOrderLine {
  _DraftOrderLine({required this.menuItemId});

  String? menuItemId;
  int qty = 1;
}

class _ManualOrderResult {
  _ManualOrderResult({
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
