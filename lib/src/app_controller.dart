import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'models/dashboard_metrics.dart';
import 'models/menu_item.dart';
import 'models/order_model.dart';
import 'models/order_status.dart';
import 'services/api_client_service.dart';
import 'services/local_database_service.dart';
import 'services/local_server_service.dart';
import 'services/network_info_service.dart';
import 'services/printer_service.dart';
import 'services/websocket_service.dart';

class PosAppController extends ChangeNotifier {
  PosAppController({
    LocalDatabaseService? database,
    LocalServerService? server,
    NetworkInfoService? networkInfo,
    WebSocketService? webSocketService,
    PrinterService? printerService,
    ApiClientService? apiClientService,
  }) : database = database ?? LocalDatabaseService(),
       networkInfo = networkInfo ?? NetworkInfoService(),
       webSocketService = webSocketService ?? WebSocketService(),
       printerService = printerService ?? PrinterService(),
       apiClientService = apiClientService ?? ApiClientService() {
    localServer =
        server ??
        LocalServerService(
          database: this.database,
          networkInfo: this.networkInfo,
          webSocketService: this.webSocketService,
        );
  }

  final LocalDatabaseService database;
  final NetworkInfoService networkInfo;
  final WebSocketService webSocketService;
  final PrinterService printerService;
  final ApiClientService apiClientService;
  late final LocalServerService localServer;

  final Uuid _uuid = const Uuid();
  final List<StreamSubscription<Object?>> _subscriptions = [];

  bool initialized = false;
  bool busy = false;
  bool hasSeenIntro = false;
  String? lastError;
  String restaurantName = '';
  int serverPort = 8080;
  List<MenuItem> menuItems = const [];
  List<OrderModel> orders = const [];
  List<ApiLogEntry> apiLogs = const [];
  int connectedClients = 0;
  ServerRuntimeState serverState = const ServerRuntimeState(
    isRunning: false,
    port: 8080,
  );

  Future<void> initialize() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      hasSeenIntro = preferences.getBool(_seenIntroKey) ?? false;
      restaurantName = preferences.getString(_restaurantNameKey) ?? '';
      serverPort = preferences.getInt(_serverPortKey) ?? 8080;
      serverState = serverState.copyWith(
        restaurantName: restaurantName.isEmpty ? null : restaurantName,
        port: serverPort,
      );

      _subscriptions.add(
        database.changes.listen((_) => unawaited(reloadData())),
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
        webSocketService.clientCountStream.listen((count) {
          connectedClients = count;
          notifyListeners();
        }),
      );

      await database.initialize();
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
    notifyListeners();
  }

  Future<bool> startServer({
    required String restaurantName,
    required int port,
  }) async {
    return _runBusy(() async {
      await localServer.start(restaurantName: restaurantName, port: port);
      this.restaurantName = restaurantName.trim();
      serverPort = port;
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_restaurantNameKey, this.restaurantName);
      await preferences.setInt(_serverPortKey, serverPort);
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
  }

  Future<void> deleteMenuItem(String id) async {
    await database.deleteMenuItem(id);
  }

  Future<void> toggleMenuAvailability(String id, bool isAvailable) async {
    await database.toggleMenuAvailability(id, isAvailable);
  }

  Future<void> updateOrderStatus(String id, OrderStatus status) async {
    final order = await database.updateOrderStatus(id, status);
    webSocketService.broadcast({
      'type': 'order_status_updated',
      'data': order.toJson(),
    });
  }

  Future<String> printTicketPreview(OrderModel order) {
    return printerService.previewTicket(order);
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(localServer.dispose());
    webSocketService.dispose();
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

  String? _cleanNullable(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  static const String _seenIntroKey = 'local_pos_seen_intro';
  static const String _restaurantNameKey = 'local_pos_restaurant_name';
  static const String _serverPortKey = 'local_pos_server_port';
}
