import 'dart:async';
import 'dart:math';

import '../models/menu_item.dart';
import '../models/order_item.dart';
import '../models/order_model.dart';
import '../models/order_status.dart';
import '../models/server_config.dart';
import '../models/sync_event.dart';
import '../models/sync_status.dart';
import 'cloud_api_service.dart';
import 'connectivity_service.dart';
import 'local_database_service.dart';

class SyncLogEntry {
  const SyncLogEntry({
    required this.message,
    required this.createdAt,
    this.isError = false,
  });

  final String message;
  final DateTime createdAt;
  final bool isError;
}

class SyncRuntimeState {
  const SyncRuntimeState({
    required this.isSyncing,
    required this.cloudConnected,
    required this.pendingCount,
    required this.failedCount,
    required this.logs,
    this.lastSyncAt,
    this.lastError,
  });

  final bool isSyncing;
  final bool cloudConnected;
  final int pendingCount;
  final int failedCount;
  final DateTime? lastSyncAt;
  final String? lastError;
  final List<SyncLogEntry> logs;

  SyncRuntimeState copyWith({
    bool? isSyncing,
    bool? cloudConnected,
    int? pendingCount,
    int? failedCount,
    DateTime? lastSyncAt,
    String? lastError,
    List<SyncLogEntry>? logs,
    bool clearError = false,
  }) {
    return SyncRuntimeState(
      isSyncing: isSyncing ?? this.isSyncing,
      cloudConnected: cloudConnected ?? this.cloudConnected,
      pendingCount: pendingCount ?? this.pendingCount,
      failedCount: failedCount ?? this.failedCount,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastError: clearError ? null : lastError ?? this.lastError,
      logs: logs ?? this.logs,
    );
  }
}

class SyncService {
  SyncService({
    required LocalDatabaseService database,
    required CloudApiService cloudApi,
    required ConnectivityService connectivity,
  }) : _database = database,
       _cloudApi = cloudApi,
       _connectivity = connectivity;

  final LocalDatabaseService _database;
  final CloudApiService _cloudApi;
  final ConnectivityService _connectivity;
  final StreamController<SyncRuntimeState> _stateController =
      StreamController<SyncRuntimeState>.broadcast();

  StreamSubscription<bool>? _connectivitySubscription;
  Timer? _autoSyncTimer;
  CloudConfig _cloudConfig = const CloudConfig(
    baseUrl: 'https://api.example.com',
    enabled: false,
    deviceToken: '',
    autoSyncIntervalSeconds: 30,
  );
  bool _online = false;
  SyncRuntimeState _state = const SyncRuntimeState(
    isSyncing: false,
    cloudConnected: false,
    pendingCount: 0,
    failedCount: 0,
    logs: [],
  );

  SyncRuntimeState get state => _state;
  Stream<SyncRuntimeState> get stateStream => _stateController.stream;

  Future<void> initialize({
    required CloudConfig cloudConfig,
    required ServerConfig serverConfig,
  }) async {
    configure(cloudConfig: cloudConfig, serverConfig: serverConfig);
    await refreshSummary();
    _online = await _connectivity.hasInternetAccess();
    _connectivitySubscription ??= _connectivity.onlineStream.listen((online) {
      _online = online;
      if (online) {
        _addLog('Internet restored. Sync queue will run.');
        unawaited(syncNow());
      } else {
        _state = _state.copyWith(
          cloudConnected: false,
          lastError: 'Internet unavailable.',
        );
        _emitState();
      }
    });
  }

  void configure({
    required CloudConfig cloudConfig,
    required ServerConfig serverConfig,
  }) {
    _cloudConfig = cloudConfig;
    _cloudApi.configure(cloudConfig: cloudConfig, serverConfig: serverConfig);
    _autoSyncTimer?.cancel();
    if (cloudConfig.canSync) {
      final seconds = max(10, cloudConfig.autoSyncIntervalSeconds);
      _autoSyncTimer = Timer.periodic(
        Duration(seconds: seconds),
        (_) => unawaited(syncNow()),
      );
    }
  }

  Future<bool> testCloud() async {
    if (!_cloudConfig.canSync) {
      _state = _state.copyWith(
        cloudConnected: false,
        lastError: 'Cloud API URL is empty or invalid.',
      );
      _addLog('Cloud health skipped: URL is empty or invalid.', isError: true);
      _emitState();
      return false;
    }
    try {
      await _cloudApi.testHealth();
      _state = _state.copyWith(cloudConnected: true, clearError: true);
      _addLog('Cloud health check passed.');
      _emitState();
      return true;
    } catch (error) {
      _state = _state.copyWith(
        cloudConnected: false,
        lastError: error.toString(),
      );
      _addLog('Cloud health failed: $error', isError: true);
      _emitState();
      return false;
    }
  }

  Future<void> syncNow() async {
    await refreshSummary();
    if (_state.isSyncing) return;
    if (!_cloudConfig.canSync) {
      _state = _state.copyWith(
        cloudConnected: false,
        lastError: 'Cloud sync disabled or URL invalid.',
      );
      _emitState();
      return;
    }
    if (!_online && !await _connectivity.hasInternetAccess()) {
      _state = _state.copyWith(
        cloudConnected: false,
        lastError: 'Internet unavailable. Sync queue is pending.',
      );
      _emitState();
      return;
    }

    _state = _state.copyWith(isSyncing: true, clearError: true);
    _emitState();
    try {
      await _cloudApi.registerDevice();
      _state = _state.copyWith(cloudConnected: true, clearError: true);
      final events = await _database.getSyncEvents(
        statuses: {SyncStatus.pending, SyncStatus.failed},
        limit: 120,
      );
      var synced = 0;
      for (final event in events) {
        if (event.status == SyncStatus.failed && !_backoffReady(event)) {
          continue;
        }
        try {
          await _pushEvent(event);
          await _database.markSyncEventSynced(event);
          synced++;
        } catch (error) {
          await _database.markSyncEventFailed(event, error);
          _addLog(
            'Sync failed for ${event.entityType}:${event.entityId}: $error',
            isError: true,
          );
        }
      }
      if (synced > 0) {
        _addLog('Synced $synced pending event${synced == 1 ? '' : 's'}.');
      }
      await refreshSummary();
      _state = _state.copyWith(
        isSyncing: false,
        cloudConnected: true,
        lastSyncAt: DateTime.now(),
        clearError: true,
      );
    } catch (error) {
      _state = _state.copyWith(
        isSyncing: false,
        cloudConnected: false,
        lastError: error.toString(),
      );
      _addLog('Sync stopped: $error', isError: true);
    } finally {
      await refreshSummary();
      _emitState();
    }
  }

  Future<void> retryFailed() async {
    await _database.retryFailedSyncEvents();
    _addLog('Failed events moved back to pending.');
    await syncNow();
  }

  Future<void> refreshSummary() async {
    final summary = await _database.getSyncSummary();
    _state = _state.copyWith(
      pendingCount: summary.pendingCount,
      failedCount: summary.failedCount,
      lastSyncAt: summary.lastSyncAt ?? _state.lastSyncAt,
    );
    _emitState();
  }

  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    _autoSyncTimer?.cancel();
    await _stateController.close();
  }

  Future<void> _pushEvent(SyncEvent event) async {
    final payload = event.payload;
    switch (event.entityType) {
      case 'menu_item':
        if (event.action == 'delete') {
          await _cloudApi.deleteMenuItem(event.entityId);
        } else if (event.action == 'update') {
          await _cloudApi.updateMenuItem(MenuItem.fromMap(payload));
        } else {
          await _cloudApi.pushMenuItem(MenuItem.fromMap(payload));
        }
        return;
      case 'order':
        await _cloudApi.pushOrder(_orderFromPayload(payload));
        return;
      case 'order_status':
        final status = OrderStatus.tryParse(payload['status']?.toString());
        if (status == null) {
          throw const CloudApiException('Order status payload is invalid.');
        }
        await _cloudApi.pushOrderStatus(event.entityId, status);
        return;
      case 'server_config':
        await _cloudApi.registerDevice();
        return;
      default:
        throw CloudApiException('Unknown sync entity ${event.entityType}.');
    }
  }

  OrderModel _orderFromPayload(Map<String, Object?> payload) {
    final rawItems = payload['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((item) => OrderItem.fromMap(Map<String, Object?>.from(item)))
              .toList(growable: false)
        : const <OrderItem>[];
    return OrderModel.fromMap(payload, items: items);
  }

  bool _backoffReady(SyncEvent event) {
    final retry = event.retryCount.clamp(0, 8);
    final delaySeconds = min(300, pow(2, retry).toInt() * 5);
    return DateTime.now().difference(event.updatedAt).inSeconds >= delaySeconds;
  }

  void _addLog(String message, {bool isError = false}) {
    final logs = [
      SyncLogEntry(
        message: message,
        createdAt: DateTime.now(),
        isError: isError,
      ),
      ..._state.logs,
    ];
    if (logs.length > 80) {
      logs.removeRange(80, logs.length);
    }
    _state = _state.copyWith(logs: List.unmodifiable(logs));
    _emitState();
  }

  void _emitState() {
    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }
  }
}
