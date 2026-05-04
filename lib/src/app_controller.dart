import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'core/constants/cloud_defaults.dart';
import 'models/dashboard_metrics.dart';
import 'models/menu_item.dart';
import 'models/order_item.dart';
import 'models/order_model.dart';
import 'models/order_source.dart';
import 'models/order_status.dart';
import 'models/sales_report.dart';
import 'models/server_config.dart';
import 'models/sync_event.dart';
import 'services/cloud_api_service.dart';
import 'services/cloud_realtime_service.dart';
import 'services/connectivity_service.dart';
import 'services/local_database_service.dart';
import 'services/printer_service.dart';
import 'services/sync_service.dart';

class PosAppController extends ChangeNotifier {
  PosAppController({
    LocalDatabaseService? database,
    PrinterService? printerService,
    CloudApiService? cloudApiService,
    CloudRealtimeService? cloudRealtimeService,
    ConnectivityService? connectivityService,
    SyncService? syncService,
  }) : database = database ?? LocalDatabaseService(),
       printerService = printerService ?? PrinterService(),
       cloudApiService = cloudApiService ?? CloudApiService(),
       cloudRealtimeService = cloudRealtimeService ?? CloudRealtimeService(),
       connectivityService = connectivityService ?? ConnectivityService() {
    this.syncService =
        syncService ??
        SyncService(
          database: this.database,
          cloudApi: this.cloudApiService,
          cloudRealtime: this.cloudRealtimeService,
          connectivity: this.connectivityService,
        );
  }

  final LocalDatabaseService database;
  final PrinterService printerService;
  final CloudApiService cloudApiService;
  final CloudRealtimeService cloudRealtimeService;
  final ConnectivityService connectivityService;
  late final SyncService syncService;

  final Uuid _uuid = const Uuid();
  final List<StreamSubscription<Object?>> _subscriptions = [];

  bool initialized = false;
  bool busy = false;
  bool hasSeenIntro = false;
  String? lastError;
  List<MenuItem> menuItems = const [];
  List<OrderModel> orders = const [];
  List<SyncEvent> syncEvents = const [];
  SyncRuntimeState syncState = const SyncRuntimeState(
    isSyncing: false,
    cloudConnected: false,
    pendingCount: 0,
    failedCount: 0,
    logs: [],
  );

  ServerConfig serverConfig = const ServerConfig(
    serverId: '',
    restaurantId: '',
    outletId: '',
    restaurantName: '',
    outletName: '',
  );
  CloudConfig cloudConfig = CloudConfig(
    baseUrl: CloudDefaults.baseUrl,
    enabled: CloudDefaults.shouldEnableSyncByDefault,
    deviceToken: '',
    autoSyncIntervalSeconds: 30,
  );

  String get restaurantName => serverConfig.restaurantName;
  String get outletName => serverConfig.outletName;
  bool get isTenantReady {
    return serverConfig.restaurantId.trim().isNotEmpty &&
        serverConfig.outletId.trim().isNotEmpty &&
        serverConfig.restaurantName.trim().isNotEmpty &&
        serverConfig.outletName.trim().isNotEmpty &&
        cloudConfig.hasDeviceToken &&
        cloudConfig.hasValidBaseUrl;
  }

  Future<void> initialize() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      hasSeenIntro = preferences.getBool(_seenIntroKey) ?? false;
      serverConfig = ServerConfig(
        serverId: await _getOrCreatePreference(
          preferences,
          _serverIdKey,
          _uuid.v4(),
        ),
        restaurantId: preferences.getString(_restaurantIdKey) ?? '',
        outletId: preferences.getString(_outletIdKey) ?? '',
        restaurantName: preferences.getString(_restaurantNameKey) ?? '',
        outletName: preferences.getString(_outletNameKey) ?? '',
      );
      cloudConfig = CloudConfig(
        baseUrl: CloudDefaults.resolveBaseUrl(
          preferences.getString(_cloudApiUrlKey),
        ),
        enabled:
            preferences.getBool(_cloudSyncEnabledKey) ??
            CloudDefaults.shouldEnableSyncByDefault,
        deviceToken: preferences.getString(_deviceTokenKey) ?? '',
        autoSyncIntervalSeconds: preferences.getInt(_autoSyncIntervalKey) ?? 30,
      );

      _subscriptions.add(
        database.changes.listen((_) {
          unawaited(reloadData());
          unawaited(syncService.refreshSummary());
        }),
      );
      _subscriptions.add(
        syncService.stateStream.listen((state) {
          syncState = state;
          notifyListeners();
        }),
      );

      await database.initialize();
      await syncService.initialize(
        cloudConfig: cloudConfig,
        serverConfig: serverConfig,
      );
      await reloadData();
      if (isTenantReady && cloudConfig.canSync) {
        unawaited(syncService.syncNow());
      }
      initialized = true;
      lastError = null;
    } catch (error) {
      lastError = 'App initialization failed: $error';
    } finally {
      notifyListeners();
    }
  }

  DashboardMetrics get metrics {
    final now = DateTime.now();
    final todaysOrders = orders
        .where((order) {
          return order.createdAt.year == now.year &&
              order.createdAt.month == now.month &&
              order.createdAt.day == now.day;
        })
        .toList(growable: false);
    final todayStart = DateTime(now.year, now.month, now.day);
    final sevenDayStart = todayStart.subtract(const Duration(days: 6));
    final thirtyDayStart = todayStart.subtract(const Duration(days: 29));

    return DashboardMetrics(
      todayOrders: todaysOrders.length,
      pendingOrders: orders.where((order) => order.status.isOpen).length,
      completedOrders: orders
          .where((order) => order.status == OrderStatus.served)
          .length,
      totalSales: todaysOrders
          .where((order) => order.status != OrderStatus.cancelled)
          .fold<double>(0, (total, order) => total + order.total),
      sevenDaySales: _salesSince(sevenDayStart),
      thirtyDaySales: _salesSince(thirtyDayStart),
      menuItemsCount: menuItems.length,
      availableItemsCount: menuItems.where((item) => item.isAvailable).length,
      pendingSyncCount: syncState.pendingCount,
    );
  }

  SalesReport salesReportForDays(int days) {
    return SalesReport.fromOrders(orders: orders, days: days);
  }

  List<String> get categories {
    final values = menuItems.map((item) => item.category).toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  double _salesSince(DateTime startAt) {
    return orders
        .where(
          (order) =>
              !order.createdAt.isBefore(startAt) &&
              order.status != OrderStatus.cancelled,
        )
        .fold<double>(0, (total, order) => total + order.total);
  }

  Future<void> completeIntro() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_seenIntroKey, true);
    hasSeenIntro = true;
    notifyListeners();
  }

  Future<void> reloadData() async {
    menuItems = await database.getMenuItems();
    orders = await database.getOrders();
    syncEvents = await database.getSyncEvents(statuses: null, limit: 100);
    notifyListeners();
  }

  Future<bool> saveSettings({
    required String restaurantName,
    required String outletName,
    required String cloudApiUrl,
    required String restaurantId,
    required String outletId,
    required bool cloudSyncEnabled,
    required int autoSyncIntervalSeconds,
  }) async {
    return _runBusy(() async {
      serverConfig = serverConfig.copyWith(
        restaurantName: restaurantName.trim(),
        outletName: outletName.trim(),
        restaurantId: restaurantId.trim().isEmpty
            ? serverConfig.restaurantId
            : restaurantId.trim(),
        outletId: outletId.trim().isEmpty
            ? serverConfig.outletId
            : outletId.trim(),
      );
      cloudConfig = cloudConfig.copyWith(
        baseUrl: CloudDefaults.resolveBaseUrl(cloudApiUrl),
        enabled: cloudSyncEnabled,
        autoSyncIntervalSeconds: autoSyncIntervalSeconds.clamp(10, 3600),
      );
      await _persistSettings();
      syncService.configure(
        cloudConfig: cloudConfig,
        serverConfig: serverConfig,
      );
      if (isTenantReady && cloudConfig.canSync) {
        unawaited(syncService.syncNow());
      }
    });
  }

  Future<bool> provisionTenant({
    required String restaurantName,
    required String outletName,
  }) async {
    return _runBusy(() async {
      final bootstrapCloudConfig = cloudConfig.copyWith(
        baseUrl: CloudDefaults.resolveBaseUrl(cloudConfig.baseUrl),
        enabled: true,
      );
      cloudApiService.configure(
        cloudConfig: bootstrapCloudConfig,
        serverConfig: serverConfig,
      );
      final tenant = await cloudApiService.bootstrapTenant(
        serverId: serverConfig.serverId,
        restaurantName: restaurantName.trim(),
        outletName: outletName.trim(),
        restaurantId: serverConfig.restaurantId,
        outletId: serverConfig.outletId,
      );
      serverConfig = serverConfig.copyWith(
        serverId: tenant.serverId,
        restaurantId: tenant.restaurantId,
        outletId: tenant.outletId,
        restaurantName: tenant.restaurantName,
        outletName: tenant.outletName,
      );
      cloudConfig = bootstrapCloudConfig.copyWith(
        deviceToken: tenant.deviceToken,
      );
      await _persistSettings();
      syncService.configure(
        cloudConfig: cloudConfig,
        serverConfig: serverConfig,
      );
      unawaited(syncService.syncNow());
    });
  }

  Future<void> saveMenuItem({
    String? id,
    required String name,
    required String description,
    required String category,
    required double price,
    required bool isAvailable,
    String? imageUrl,
    int? preparationTimeMinutes,
    List<String> tags = const [],
    DateTime? createdAt,
  }) async {
    final now = DateTime.now();
    final item = MenuItem(
      id: id ?? _uuid.v4(),
      name: name.trim(),
      description: description.trim(),
      category: category.trim().isEmpty ? 'General' : category.trim(),
      price: price,
      imageUrl: _cleanNullable(imageUrl),
      isAvailable: isAvailable,
      preparationTimeMinutes: preparationTimeMinutes,
      tags: tags,
      createdAt: createdAt ?? now,
      updatedAt: now,
    );
    await database.upsertMenuItem(item);
    unawaited(syncService.syncNow());
  }

  Future<String> uploadMenuImageDataUrl(String dataUrl) async {
    if (!cloudConfig.canSync) return dataUrl;
    return cloudApiService.uploadMenuImageDataUrl(dataUrl);
  }

  Future<void> deleteMenuItem(String id) async {
    await database.deleteMenuItem(id);
    unawaited(syncService.syncNow());
  }

  Future<void> toggleMenuAvailability(String id, bool isAvailable) async {
    await database.toggleMenuAvailability(id, isAvailable);
    unawaited(syncService.syncNow());
  }

  Future<void> createManualOrder({
    required List<OrderRequestItem> requestedItems,
    String? customerName,
    String? tableNo,
    String? note,
  }) async {
    await database.createOrder(
      requestedItems: requestedItems,
      customerName: customerName,
      tableNo: tableNo,
      note: note,
      source: OrderSource.manual,
    );
    unawaited(syncService.syncNow());
  }

  Future<void> updateOrderStatus(String id, OrderStatus status) async {
    await database.updateOrderStatus(id, status);
    unawaited(syncService.syncNow());
  }

  Future<bool> testCloud() async {
    var cloudOk = false;
    final actionOk = await _runBusy(() async {
      cloudOk = await syncService.testCloud();
    });
    return actionOk && cloudOk;
  }

  Future<bool> syncNow() async {
    return _runBusy(syncService.syncNow);
  }

  Future<bool> retryFailedSync() async {
    return _runBusy(syncService.retryFailed);
  }

  Future<void> clearLocalData() async {
    await database.clearLocalData();
    await reloadData();
  }

  Future<String> printTicketPreview(OrderModel order) {
    return printerService.previewTicket(order);
  }

  List<OrderModel> ordersFor({OrderStatus? status, OrderSource? source}) {
    return orders
        .where((order) {
          final matchesStatus = status == null || order.status == status;
          final matchesSource = source == null || order.source == source;
          return matchesStatus && matchesSource;
        })
        .toList(growable: false);
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(syncService.dispose());
    cloudApiService.close();
    unawaited(database.close());
    super.dispose();
  }

  Future<bool> _runBusy(Future<void> Function() action) async {
    busy = true;
    lastError = null;
    notifyListeners();
    try {
      await action();
      return true;
    } catch (error) {
      lastError = error.toString();
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _persistSettings() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _restaurantNameKey,
      serverConfig.restaurantName,
    );
    await preferences.setString(_outletNameKey, serverConfig.outletName);
    await preferences.setString(_restaurantIdKey, serverConfig.restaurantId);
    await preferences.setString(_outletIdKey, serverConfig.outletId);
    await preferences.setString(_serverIdKey, serverConfig.serverId);
    await preferences.setString(_cloudApiUrlKey, cloudConfig.baseUrl);
    await preferences.setBool(_cloudSyncEnabledKey, cloudConfig.enabled);
    await preferences.setString(_deviceTokenKey, cloudConfig.deviceToken);
    await preferences.setInt(
      _autoSyncIntervalKey,
      cloudConfig.autoSyncIntervalSeconds,
    );
  }

  Future<String> _getOrCreatePreference(
    SharedPreferences preferences,
    String key,
    String fallback,
  ) async {
    final existing = preferences.getString(key);
    if (existing != null && existing.trim().isNotEmpty) return existing;
    await preferences.setString(key, fallback);
    return fallback;
  }

  String? _cleanNullable(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  static const String _seenIntroKey = 'local_pos_seen_intro';
  static const String _restaurantNameKey = 'local_pos_restaurant_name';
  static const String _outletNameKey = 'local_pos_outlet_name';
  static const String _serverIdKey = 'local_pos_server_id';
  static const String _restaurantIdKey = 'local_pos_restaurant_id';
  static const String _outletIdKey = 'local_pos_outlet_id';
  static const String _cloudApiUrlKey = 'local_pos_cloud_api_url';
  static const String _deviceTokenKey = 'local_pos_device_token';
  static const String _cloudSyncEnabledKey = 'local_pos_cloud_sync_enabled';
  static const String _autoSyncIntervalKey = 'local_pos_auto_sync_interval';
}
