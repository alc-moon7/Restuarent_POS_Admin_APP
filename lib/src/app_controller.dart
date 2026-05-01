import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'models/dashboard_metrics.dart';
import 'models/menu_item.dart';
import 'models/order_model.dart';
import 'models/order_source.dart';
import 'models/order_status.dart';
import 'models/server_config.dart';
import 'models/sync_event.dart';
import 'services/cloud_api_service.dart';
import 'services/connectivity_service.dart';
import 'services/local_database_service.dart';
import 'services/local_server_service.dart';
import 'services/network_info_service.dart';
import 'services/printer_service.dart';
import 'services/server_discovery_service.dart';
import 'services/sync_service.dart';
import 'services/websocket_service.dart';

class PosAppController extends ChangeNotifier {
  PosAppController({
    LocalDatabaseService? database,
    LocalServerService? server,
    NetworkInfoService? networkInfo,
    WebSocketService? webSocketService,
    PrinterService? printerService,
    CloudApiService? cloudApiService,
    ConnectivityService? connectivityService,
    ServerDiscoveryService? discoveryService,
    SyncService? syncService,
  }) : database = database ?? LocalDatabaseService(),
       networkInfo = networkInfo ?? NetworkInfoService(),
       webSocketService = webSocketService ?? WebSocketService(),
       printerService = printerService ?? PrinterService(),
       cloudApiService = cloudApiService ?? CloudApiService(),
       connectivityService = connectivityService ?? ConnectivityService(),
       discoveryService = discoveryService ?? ServerDiscoveryService() {
    this.syncService =
        syncService ??
        SyncService(
          database: this.database,
          cloudApi: this.cloudApiService,
          connectivity: this.connectivityService,
        );
    localServer =
        server ??
        LocalServerService(
          database: this.database,
          networkInfo: this.networkInfo,
          webSocketService: this.webSocketService,
          discoveryService: this.discoveryService,
          onLocalMutation: () => this.syncService.syncNow(),
        );
  }

  final LocalDatabaseService database;
  final NetworkInfoService networkInfo;
  final WebSocketService webSocketService;
  final PrinterService printerService;
  final CloudApiService cloudApiService;
  final ConnectivityService connectivityService;
  final ServerDiscoveryService discoveryService;
  late final SyncService syncService;
  late final LocalServerService localServer;

  final Uuid _uuid = const Uuid();
  final List<StreamSubscription<Object?>> _subscriptions = [];

  bool initialized = false;
  bool busy = false;
  bool hasSeenIntro = false;
  String? lastError;
  List<MenuItem> menuItems = const [];
  List<OrderModel> orders = const [];
  List<SyncEvent> syncEvents = const [];
  List<ApiLogEntry> apiLogs = const [];
  int connectedClients = 0;
  ServerRuntimeState serverState = const ServerRuntimeState(
    isRunning: false,
    port: 8080,
  );
  DiscoveryRuntimeState discoveryState = const DiscoveryRuntimeState(
    isBroadcasting: false,
    port: 45678,
  );
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
    localPort: 8080,
    discoveryEnabled: true,
  );
  CloudConfig cloudConfig = const CloudConfig(
    baseUrl: 'https://api.example.com',
    enabled: false,
    deviceToken: '',
    autoSyncIntervalSeconds: 30,
  );

  String get restaurantName => serverConfig.restaurantName;
  String get outletName => serverConfig.outletName;
  int get serverPort => serverConfig.localPort;

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
        restaurantId: await _getOrCreatePreference(
          preferences,
          _restaurantIdKey,
          'restaurant-${_uuid.v4().split('-').first}',
        ),
        outletId: await _getOrCreatePreference(
          preferences,
          _outletIdKey,
          'outlet-${_uuid.v4().split('-').first}',
        ),
        restaurantName: preferences.getString(_restaurantNameKey) ?? '',
        outletName: preferences.getString(_outletNameKey) ?? '',
        localPort: preferences.getInt(_serverPortKey) ?? 8080,
        discoveryEnabled: preferences.getBool(_discoveryEnabledKey) ?? true,
      );
      cloudConfig = CloudConfig(
        baseUrl:
            preferences.getString(_cloudApiUrlKey) ?? 'https://api.example.com',
        enabled: preferences.getBool(_cloudSyncEnabledKey) ?? false,
        deviceToken: preferences.getString(_deviceTokenKey) ?? '',
        autoSyncIntervalSeconds: preferences.getInt(_autoSyncIntervalKey) ?? 30,
      );
      serverState = serverState.copyWith(
        serverId: serverConfig.serverId,
        restaurantId: serverConfig.restaurantId,
        outletId: serverConfig.outletId,
        restaurantName: serverConfig.restaurantName.isEmpty
            ? null
            : serverConfig.restaurantName,
        outletName: serverConfig.outletName.isEmpty
            ? null
            : serverConfig.outletName,
        port: serverConfig.localPort,
        cloudBaseUrl: cloudConfig.baseUrl,
        cloudSyncEnabled: cloudConfig.enabled,
        discoveryEnabled: serverConfig.discoveryEnabled,
      );

      _subscriptions.add(
        database.changes.listen((_) {
          unawaited(reloadData());
          unawaited(syncService.refreshSummary());
        }),
      );
      _subscriptions.add(
        localServer.stateStream.listen((state) {
          serverState = state;
          notifyListeners();
        }),
      );
      _subscriptions.add(
        localServer.logsStream.listen((logs) {
          apiLogs = logs;
          notifyListeners();
        }),
      );
      _subscriptions.add(
        discoveryService.stateStream.listen((state) {
          discoveryState = state;
          notifyListeners();
        }),
      );
      _subscriptions.add(
        syncService.stateStream.listen((state) {
          syncState = state;
          unawaited(
            localServer.updateMetadata(
              serverConfig: serverConfig,
              cloudConfig: cloudConfig,
              cloudConnected: state.cloudConnected,
            ),
          );
          notifyListeners();
        }),
      );
      _subscriptions.add(
        webSocketService.clientCountStream.listen((count) {
          connectedClients = count;
          notifyListeners();
        }),
      );

      await database.initialize();
      await syncService.initialize(
        cloudConfig: cloudConfig,
        serverConfig: serverConfig,
      );
      await localServer.updateMetadata(
        serverConfig: serverConfig,
        cloudConfig: cloudConfig,
        cloudConnected: syncState.cloudConnected,
      );
      await refreshIp();
      await reloadData();
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

    return DashboardMetrics(
      todayOrders: todaysOrders.length,
      pendingOrders: orders.where((order) => order.status.isOpen).length,
      completedOrders: orders
          .where((order) => order.status == OrderStatus.served)
          .length,
      totalSales: todaysOrders
          .where((order) => order.status != OrderStatus.cancelled)
          .fold<double>(0, (total, order) => total + order.total),
      menuItemsCount: menuItems.length,
      availableItemsCount: menuItems.where((item) => item.isAvailable).length,
      pendingSyncCount: syncState.pendingCount,
    );
  }

  List<String> get categories {
    final values = menuItems.map((item) => item.category).toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
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
    required int localPort,
    required String cloudApiUrl,
    required String restaurantId,
    required String outletId,
    required String deviceToken,
    required bool cloudSyncEnabled,
    required bool discoveryEnabled,
    required int autoSyncIntervalSeconds,
  }) async {
    return _runBusy(() async {
      if (localPort < 1 || localPort > 65535) {
        throw const LocalServerException('Port must be between 1 and 65535.');
      }
      final oldPort = serverConfig.localPort;
      serverConfig = serverConfig.copyWith(
        restaurantName: restaurantName.trim(),
        outletName: outletName.trim(),
        localPort: localPort,
        restaurantId: restaurantId.trim().isEmpty
            ? serverConfig.restaurantId
            : restaurantId.trim(),
        outletId: outletId.trim().isEmpty
            ? serverConfig.outletId
            : outletId.trim(),
        discoveryEnabled: discoveryEnabled,
      );
      cloudConfig = cloudConfig.copyWith(
        baseUrl: cloudApiUrl.trim().isEmpty
            ? 'https://api.example.com'
            : cloudApiUrl.trim(),
        enabled: cloudSyncEnabled,
        deviceToken: deviceToken.trim(),
        autoSyncIntervalSeconds: autoSyncIntervalSeconds.clamp(10, 3600),
      );
      await _persistSettings();
      syncService.configure(
        cloudConfig: cloudConfig,
        serverConfig: serverConfig,
      );
      await localServer.updateMetadata(
        serverConfig: serverConfig,
        cloudConfig: cloudConfig,
        cloudConnected: syncState.cloudConnected,
      );
      if (localServer.state.isRunning && oldPort != serverConfig.localPort) {
        await localServer.restart();
      }
    });
  }

  Future<bool> startServer({
    String? restaurantName,
    String? outletName,
    int? port,
  }) async {
    return _runBusy(() async {
      if (restaurantName != null || outletName != null || port != null) {
        serverConfig = serverConfig.copyWith(
          restaurantName: restaurantName?.trim(),
          outletName: outletName?.trim(),
          localPort: port,
        );
        await _persistSettings();
      }
      await localServer.start(
        serverConfig: serverConfig,
        cloudConfig: cloudConfig,
        cloudConnected: syncState.cloudConnected,
      );
      unawaited(syncService.syncNow());
    });
  }

  Future<bool> stopServer() async {
    return _runBusy(localServer.stop);
  }

  Future<bool> restartServer() async {
    return _runBusy(localServer.restart);
  }

  Future<void> refreshIp() async {
    await localServer.refreshIp();
    serverState = localServer.state;
    notifyListeners();
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
    final saved = await database.getMenuItemById(item.id, includeDeleted: true);
    webSocketService.broadcast({
      'type': 'menu_updated',
      'data': saved?.toJson() ?? item.toJson(),
    });
    unawaited(syncService.syncNow());
  }

  Future<void> deleteMenuItem(String id) async {
    await database.deleteMenuItem(id);
    webSocketService.broadcast({
      'type': 'menu_updated',
      'data': {'id': id, 'deleted': true},
    });
    unawaited(syncService.syncNow());
  }

  Future<void> toggleMenuAvailability(String id, bool isAvailable) async {
    final item = await database.toggleMenuAvailability(id, isAvailable);
    webSocketService.broadcast({'type': 'menu_updated', 'data': item.toJson()});
    unawaited(syncService.syncNow());
  }

  Future<void> updateOrderStatus(String id, OrderStatus status) async {
    final order = await database.updateOrderStatus(id, status);
    webSocketService.broadcast({
      'type': 'order_status_updated',
      'data': order.toJson(),
    });
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
    unawaited(localServer.dispose());
    unawaited(discoveryService.dispose());
    unawaited(syncService.dispose());
    webSocketService.dispose();
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
    await preferences.setInt(_serverPortKey, serverConfig.localPort);
    await preferences.setString(_restaurantIdKey, serverConfig.restaurantId);
    await preferences.setString(_outletIdKey, serverConfig.outletId);
    await preferences.setString(_serverIdKey, serverConfig.serverId);
    await preferences.setBool(
      _discoveryEnabledKey,
      serverConfig.discoveryEnabled,
    );
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
  static const String _serverPortKey = 'local_pos_server_port';
  static const String _serverIdKey = 'local_pos_server_id';
  static const String _restaurantIdKey = 'local_pos_restaurant_id';
  static const String _outletIdKey = 'local_pos_outlet_id';
  static const String _cloudApiUrlKey = 'local_pos_cloud_api_url';
  static const String _deviceTokenKey = 'local_pos_device_token';
  static const String _cloudSyncEnabledKey = 'local_pos_cloud_sync_enabled';
  static const String _discoveryEnabledKey = 'local_pos_discovery_enabled';
  static const String _autoSyncIntervalKey = 'local_pos_auto_sync_interval';
}
