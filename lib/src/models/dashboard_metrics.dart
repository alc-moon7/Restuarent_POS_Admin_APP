class DashboardMetrics {
  const DashboardMetrics({
    required this.todayOrders,
    required this.pendingOrders,
    required this.completedOrders,
    required this.totalSales,
    required this.menuItemsCount,
    required this.availableItemsCount,
    required this.pendingSyncCount,
  });

  final int todayOrders;
  final int pendingOrders;
  final int completedOrders;
  final double totalSales;
  final int menuItemsCount;
  final int availableItemsCount;
  final int pendingSyncCount;
}
