import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/status_badge.dart';
import '../../models/menu_item.dart';
import '../../models/order_item.dart';
import '../../models/order_model.dart';
import '../../models/order_source.dart';
import '../../models/order_status.dart';

const _adminOrderStatuses = <OrderStatus>[
  OrderStatus.pending,
  OrderStatus.accepted,
  OrderStatus.cancelled,
  OrderStatus.served,
];

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  OrderStatus? _filter = OrderStatus.pending;
  OrderSource? _sourceFilter;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

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
                    order.sequenceNo.toString().contains(query) ||
                    order.id.toLowerCase().contains(query) ||
                    (order.customerName ?? '').toLowerCase().contains(query) ||
                    (order.tableNo ?? '').toLowerCase().contains(query);
              })
              .toList(growable: false);
    return Scaffold(
      backgroundColor: PosColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OrdersHeader(
                canCreateOrder: app.menuItems.any((item) => item.isAvailable),
                onCreateOrder: () => _openManualOrderForm(context),
              ),
              SizedBox(height: 6),
              _StatusSummary(
                allOrders: allOrders,
                selected: _filter,
                onSelect: (status) => setState(() => _filter = status),
              ),
              SizedBox(height: 6),
              _ToolbarRow(
                controller: _searchController,
                onSearchChanged: (v) => setState(() => _searchQuery = v),
                sourceFilter: _sourceFilter,
                onSourceChanged: (s) => setState(() => _sourceFilter = s),
              ),
              SizedBox(height: 6),
              Expanded(
                child: _OrdersBoard(
                  orders: filtered,
                  selectedStatus: _filter,
                  onSelectedStatusChanged: (status) =>
                      setState(() => _filter = status),
                  onStatusChanged: (order, status) =>
                      _changeStatus(context, order, status),
                  onPrintTicket: (order) => _showTicketPreview(context, order),
                ),
              ),
            ],
          ),
        ),
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

class _OrdersHeader extends StatelessWidget {
  const _OrdersHeader({
    required this.canCreateOrder,
    required this.onCreateOrder,
  });

  final bool canCreateOrder;
  final VoidCallback onCreateOrder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: PosColors.primary,
              borderRadius: BorderRadius.circular(PosRadii.md),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              color: PosColors.slate,
              size: 20,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Orders',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Accept, serve, print',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: PosColors.muted,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 6),
          FilledButton.icon(
            onPressed: canCreateOrder ? onCreateOrder : null,
            icon: Icon(Icons.add_rounded, size: 16),
            label: Text('New', style: TextStyle(fontSize: 12)),
            style: FilledButton.styleFrom(
              minimumSize: Size(0, 34),
              padding: EdgeInsets.symmetric(horizontal: 10),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
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
        status: OrderStatus.pending,
        label: 'Pending',
        subtitle: 'Orders',
        count: allOrders
            .where((o) => o.status.adminStatus == OrderStatus.pending)
            .length,
        color: PosColors.warning,
        icon: Icons.pending_actions_outlined,
      ),
      _SummaryTile(
        status: OrderStatus.accepted,
        label: 'Accepted',
        subtitle: 'Orders',
        count: allOrders
            .where((o) => o.status.adminStatus == OrderStatus.accepted)
            .length,
        color: PosColors.primaryDark,
        icon: Icons.check_circle_outline,
      ),
      _SummaryTile(
        status: OrderStatus.cancelled,
        label: 'Cancelled',
        subtitle: 'Orders',
        count: allOrders
            .where((o) => o.status.adminStatus == OrderStatus.cancelled)
            .length,
        color: PosColors.danger,
        icon: Icons.cancel_outlined,
      ),
      _SummaryTile(
        status: OrderStatus.served,
        label: 'History',
        subtitle: 'Served',
        count: allOrders
            .where((o) => o.status.adminStatus == OrderStatus.served)
            .length,
        color: PosColors.slate,
        icon: Icons.history_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 560) {
          return SizedBox(
            height: 62,
            child: Row(
              children: [
                for (var index = 0; index < tiles.length; index++) ...[
                  if (index > 0) SizedBox(width: 8),
                  Expanded(
                    child: _StatusCardButton(
                      tile: tiles[index],
                      selected: selected == tiles[index].status,
                      onTap: () => onSelect(tiles[index].status),
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        return SizedBox(
          height: 112,
          child: GridView.builder(
            padding: EdgeInsets.zero,
            physics: NeverScrollableScrollPhysics(),
            itemCount: tiles.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 52,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final tile = tiles[index];
              return _StatusCardButton(
                tile: tile,
                selected: selected == tile.status,
                onTap: () => onSelect(tile.status),
              );
            },
          ),
        );
      },
    );
  }
}

class _SummaryTile {
  _SummaryTile({
    required this.status,
    required this.label,
    required this.subtitle,
    required this.count,
    required this.color,
    required this.icon,
  });
  final OrderStatus? status;
  final String label;
  final String subtitle;
  final int count;
  final Color color;
  final IconData icon;
}

class _StatusCardButton extends StatelessWidget {
  const _StatusCardButton({
    required this.tile,
    required this.selected,
    required this.onTap,
  });

  final _SummaryTile tile;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = selected ? PosColors.primary : PosColors.background;
    final foreground = selected ? PosColors.slate : tile.color;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PosRadii.md),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(PosRadii.md),
            border: Border.all(
              color: selected
                  ? PosColors.primaryDark.withValues(alpha: 0.32)
                  : PosColors.lineStrong.withValues(alpha: 0.42),
              width: selected ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: selected ? 0.12 : 0.06),
                blurRadius: selected ? 12 : 8,
                offset: Offset(0, selected ? 5 : 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: selected
                      ? PosColors.background.withValues(alpha: 0.48)
                      : tile.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(PosRadii.sm),
                ),
                child: Icon(tile.icon, color: foreground, size: 17),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tile.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: PosColors.slate,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      tile.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? PosColors.slateSoft : PosColors.muted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 6),
              Text(
                tile.count.toString(),
                style: TextStyle(
                  color: PosColors.slate,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _colorForStatus(OrderStatus s) {
  return switch (s.adminStatus) {
    OrderStatus.pending => PosColors.warning,
    OrderStatus.accepted => PosColors.primaryDark,
    OrderStatus.preparing => PosColors.primaryDark,
    OrderStatus.ready => PosColors.primaryDark,
    OrderStatus.served => PosColors.success,
    OrderStatus.cancelled => PosColors.danger,
  };
}

IconData _iconForStatus(OrderStatus s) {
  return switch (s.adminStatus) {
    OrderStatus.pending => Icons.pending_actions_outlined,
    OrderStatus.accepted => Icons.check_circle_outline,
    OrderStatus.preparing => Icons.check_circle_outline,
    OrderStatus.ready => Icons.check_circle_outline,
    OrderStatus.served => Icons.done_all_rounded,
    OrderStatus.cancelled => Icons.cancel_outlined,
  };
}

String _laneTitle(OrderStatus status) {
  return status.adminStatus == OrderStatus.served ? 'History' : status.label;
}

class _ToolbarRow extends StatelessWidget {
  const _ToolbarRow({
    required this.controller,
    required this.onSearchChanged,
    required this.sourceFilter,
    required this.onSourceChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSearchChanged;
  final OrderSource? sourceFilter;
  final ValueChanged<OrderSource?> onSourceChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Card(
        margin: EdgeInsets.zero,
        color: PosColors.background,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PosRadii.lg),
          side: BorderSide(color: PosColors.lineStrong.withValues(alpha: 0.36)),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final search = SizedBox(
                height: 34,
                child: TextField(
                  controller: controller,
                  onChanged: onSearchChanged,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: PosColors.slate,
                  ),
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search_rounded, size: 17),
                    prefixIconConstraints: BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    hintText: 'Search order',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: PosColors.muted,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 0,
                    ),
                  ),
                ),
              );
              final sourceMenu = _SourceDropdown(
                value: sourceFilter,
                onChanged: onSourceChanged,
              );
              if (compact) {
                return Row(
                  children: [
                    Expanded(child: search),
                    SizedBox(width: 6),
                    SizedBox(width: 108, child: sourceMenu),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 5, child: search),
                  SizedBox(width: 10),
                  Expanded(flex: 3, child: sourceMenu),
                ],
              );
            },
          ),
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
    final label = value == null ? 'All' : _shortSourceLabel(value!);
    return PopupMenuButton<OrderSource?>(
      initialValue: value,
      tooltip: 'Filter source',
      onSelected: onChanged,
      itemBuilder: (context) => [
        PopupMenuItem<OrderSource?>(value: null, child: Text('All sources')),
        for (final s in OrderSource.values)
          PopupMenuItem<OrderSource?>(value: s, child: Text(s.label)),
      ],
      child: Container(
        height: 34,
        padding: EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: PosColors.background,
          borderRadius: BorderRadius.circular(PosRadii.md),
          border: Border.all(
            color: PosColors.lineStrong.withValues(alpha: 0.42),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.merge_type_rounded, size: 16, color: PosColors.muted),
            SizedBox(width: 5),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: PosColors.slate,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
            SizedBox(width: 3),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 17,
              color: PosColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

String _shortSourceLabel(OrderSource source) {
  return switch (source) {
    OrderSource.localLan => 'LAN',
    OrderSource.cloud => 'Cloud',
    OrderSource.manual => 'Manual',
  };
}

class _OrdersBoard extends StatefulWidget {
  const _OrdersBoard({
    required this.orders,
    required this.selectedStatus,
    required this.onSelectedStatusChanged,
    required this.onStatusChanged,
    required this.onPrintTicket,
  });

  final List<OrderModel> orders;
  final OrderStatus? selectedStatus;
  final ValueChanged<OrderStatus> onSelectedStatusChanged;
  final void Function(OrderModel order, OrderStatus status) onStatusChanged;
  final void Function(OrderModel order) onPrintTicket;

  @override
  State<_OrdersBoard> createState() => _OrdersBoardState();
}

class _OrdersBoardState extends State<_OrdersBoard> {
  PageController? _ordersPageController;

  PageController get _pageController => _ordersPageController ??=
      PageController(initialPage: _pageForStatus(widget.selectedStatus));

  @override
  void initState() {
    super.initState();
    _pageController;
  }

  @override
  void didUpdateWidget(covariant _OrdersBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedStatus != widget.selectedStatus) {
      _scheduleFocus();
    }
  }

  @override
  void dispose() {
    _ordersPageController?.dispose();
    super.dispose();
  }

  int _pageForStatus(OrderStatus? status) {
    final index = status == null
        ? 0
        : _adminOrderStatuses.indexOf(status.adminStatus);
    return index < 0 ? 0 : index;
  }

  void _scheduleFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = _ordersPageController;
      if (!mounted || controller == null || !controller.hasClients) return;
      final target = _pageForStatus(widget.selectedStatus);
      final current = (controller.page ?? controller.initialPage).round();
      if (current == target) return;
      controller.animateToPage(
        target,
        duration: Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final statuses = _adminOrderStatuses;
    return PageView.builder(
      controller: _pageController,
      physics: PageScrollPhysics(parent: BouncingScrollPhysics()),
      itemCount: statuses.length,
      onPageChanged: (index) {
        widget.onSelectedStatusChanged(statuses[index]);
      },
      itemBuilder: (context, index) {
        final status = statuses[index];
        final laneOrders = widget.orders
            .where((order) => order.status.adminStatus == status)
            .toList(growable: false);
        return _OrderLane(
          status: status,
          orders: laneOrders,
          isSelected: widget.selectedStatus?.adminStatus == status,
          onStatusChanged: widget.onStatusChanged,
          onPrintTicket: widget.onPrintTicket,
        );
      },
    );
  }
}

class _OrderLane extends StatelessWidget {
  const _OrderLane({
    required this.status,
    required this.orders,
    required this.isSelected,
    required this.onStatusChanged,
    required this.onPrintTicket,
  });

  final OrderStatus status;
  final List<OrderModel> orders;
  final bool isSelected;
  final void Function(OrderModel order, OrderStatus status) onStatusChanged;
  final void Function(OrderModel order) onPrintTicket;

  @override
  Widget build(BuildContext context) {
    final color = _colorForStatus(status);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PosColors.background,
        borderRadius: BorderRadius.circular(PosRadii.lg),
        border: Border.all(
          color: isSelected
              ? PosColors.primaryDark.withValues(alpha: 0.42)
              : PosColors.lineStrong.withValues(alpha: 0.36),
          width: isSelected ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? PosColors.primary.withValues(alpha: 0.28)
                : Colors.black.withValues(alpha: 0.07),
            blurRadius: isSelected ? 16 : 12,
            offset: Offset(0, isSelected ? 7 : 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 44,
            padding: EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: PosColors.background,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(PosRadii.lg),
              ),
              border: Border(
                bottom: BorderSide(
                  color: PosColors.lineStrong.withValues(alpha: 0.36),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(PosRadii.sm),
                  ),
                  child: Icon(_iconForStatus(status), color: color, size: 14),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _laneTitle(status),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                _CountPill(count: orders.length, color: color),
              ],
            ),
          ),
          Expanded(
            child: orders.isEmpty
                ? _LaneEmpty(status: status, color: color)
                : ListView.separated(
                    padding: EdgeInsets.all(8),
                    itemCount: orders.length,
                    separatorBuilder: (_, _) => SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return _CompactOrderCard(
                        order: order,
                        accent: color,
                        onPrint: () => onPrintTicket(order),
                        onStatusChanged: (status) =>
                            onStatusChanged(order, status),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(PosRadii.pill),
      ),
      child: Text(
        count.toString(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _LaneEmpty extends StatelessWidget {
  const _LaneEmpty({required this.status, required this.color});

  final OrderStatus status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconForStatus(status), color: color.withValues(alpha: 0.45)),
            SizedBox(height: 6),
            Text(
              'No ${_laneTitle(status).toLowerCase()} orders',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: PosColors.muted,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactOrderCard extends StatelessWidget {
  const _CompactOrderCard({
    required this.order,
    required this.accent,
    required this.onPrint,
    required this.onStatusChanged,
  });

  final OrderModel order;
  final Color accent;
  final VoidCallback onPrint;
  final ValueChanged<OrderStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: r'$', decimalDigits: 2);
    final time = _displayOrderTime(order);
    final nextStatus = _nextStatus(order.status);
    final canCancel =
        order.status != OrderStatus.served &&
        order.status != OrderStatus.cancelled;

    return Container(
      decoration: BoxDecoration(
        color: PosColors.background,
        borderRadius: BorderRadius.circular(PosRadii.md),
        border: Border.all(color: PosColors.lineStrong.withValues(alpha: 0.36)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 9,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _OrderNoPill(order.displaySequence),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    order.orderNo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: PosColors.slate,
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                Text(
                  time,
                  style: TextStyle(
                    color: PosColors.muted,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                _MiniInfo(
                  Icons.person_outline,
                  order.customerName ?? 'Walk-in',
                ),
                _MiniInfo(
                  Icons.table_restaurant_outlined,
                  'T${order.tableNo ?? '-'}',
                ),
                StatusBadge.order(order.status),
              ],
            ),
            SizedBox(height: 7),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: PosColors.background,
                borderRadius: BorderRadius.circular(PosRadii.sm),
                border: Border.all(
                  color: PosColors.lineStrong.withValues(alpha: 0.28),
                ),
              ),
              child: Column(
                children: [
                  for (final item in order.items.take(2))
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 1.5),
                      child: Row(
                        children: [
                          Text(
                            '${item.qty}x',
                            style: TextStyle(
                              color: PosColors.primaryDark,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                          SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: PosColors.slateSoft,
                                fontWeight: FontWeight.w700,
                                fontSize: 11.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (order.items.length > 2)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '+ ${order.items.length - 2} more',
                        style: TextStyle(
                          color: PosColors.muted,
                          fontWeight: FontWeight.w700,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Text(
                  currency.format(order.total),
                  style: TextStyle(
                    color: PosColors.primaryDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                  ),
                ),
                Spacer(),
                _MiniAction(
                  icon: Icons.print_outlined,
                  tooltip: 'Print',
                  onTap: onPrint,
                ),
                if (canCancel) ...[
                  SizedBox(width: 5),
                  _MiniAction(
                    icon: Icons.close_rounded,
                    tooltip: 'Cancel',
                    color: PosColors.danger,
                    onTap: () => onStatusChanged(OrderStatus.cancelled),
                  ),
                ],
              ],
            ),
            if (nextStatus != null) ...[
              SizedBox(height: 7),
              SizedBox(
                width: double.infinity,
                height: 32,
                child: FilledButton.icon(
                  onPressed: () => onStatusChanged(nextStatus),
                  icon: Icon(Icons.arrow_forward_rounded, size: 15),
                  label: Text(
                    _nextLabel(order.status),
                    style: TextStyle(fontSize: 11.5),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  OrderStatus? _nextStatus(OrderStatus status) {
    return switch (status.adminStatus) {
      OrderStatus.pending => OrderStatus.accepted,
      OrderStatus.accepted => OrderStatus.served,
      _ => null,
    };
  }

  String _nextLabel(OrderStatus status) {
    return switch (status.adminStatus) {
      OrderStatus.pending => 'Accept',
      OrderStatus.accepted => 'Mark served',
      _ => 'Advance',
    };
  }
}

String _displayOrderTime(OrderModel order) {
  final timestamp =
      order.status.adminStatus == OrderStatus.served ||
          order.status.adminStatus == OrderStatus.cancelled
      ? order.updatedAt
      : order.createdAt;
  final local = timestamp.toLocal();
  final now = DateTime.now();
  final isToday =
      local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
  return DateFormat(isToday ? 'h:mm a' : 'MMM d, h:mm a').format(local);
}

class _OrderNoPill extends StatelessWidget {
  const _OrderNoPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: PosColors.primary,
        borderRadius: BorderRadius.circular(PosRadii.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: PosColors.slate,
          fontWeight: FontWeight.w900,
          fontSize: 10.8,
        ),
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: PosColors.slate),
          SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: PosColors.slate,
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
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
          child: SizedBox(
            width: 28,
            height: 28,
            child: Icon(icon, size: 15, color: c),
          ),
        ),
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
                        color: PosColors.slate,
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
        color: PosColors.background,
        border: Border.all(color: PosColors.lineStrong.withValues(alpha: 0.36)),
        borderRadius: BorderRadius.circular(PosRadii.md),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
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
        color: PosColors.background,
        borderRadius: BorderRadius.circular(PosRadii.pill),
        border: Border.all(color: PosColors.lineStrong.withValues(alpha: 0.36)),
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
