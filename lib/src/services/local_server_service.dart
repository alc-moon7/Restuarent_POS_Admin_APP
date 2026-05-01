import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/discovery_packet.dart';
import '../models/order_item.dart';
import '../models/order_source.dart';
import '../models/order_status.dart';
import '../models/server_config.dart';
import 'local_database_service.dart';
import 'network_info_service.dart';
import 'server_discovery_service.dart';
import 'websocket_service.dart';

class LocalServerException implements Exception {
  const LocalServerException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ServerRuntimeState {
  const ServerRuntimeState({
    required this.isRunning,
    required this.port,
    this.serverId = '',
    this.restaurantId = '',
    this.outletId = '',
    this.restaurantName,
    this.outletName,
    this.localIp,
    this.cloudBaseUrl = 'https://api.example.com',
    this.cloudSyncEnabled = false,
    this.cloudConnected = false,
    this.discoveryEnabled = true,
    this.startedAt,
    this.error,
  });

  final bool isRunning;
  final String serverId;
  final String restaurantId;
  final String outletId;
  final String? restaurantName;
  final String? outletName;
  final String? localIp;
  final int port;
  final String cloudBaseUrl;
  final bool cloudSyncEnabled;
  final bool cloudConnected;
  final bool discoveryEnabled;
  final DateTime? startedAt;
  final String? error;

  String? get apiUrl =>
      localIp == null || localIp!.isEmpty ? null : 'http://$localIp:$port';

  String? get wsUrl =>
      localIp == null || localIp!.isEmpty ? null : 'ws://$localIp:$port/ws';

  ServerRuntimeState copyWith({
    bool? isRunning,
    String? serverId,
    String? restaurantId,
    String? outletId,
    String? restaurantName,
    String? outletName,
    String? localIp,
    int? port,
    String? cloudBaseUrl,
    bool? cloudSyncEnabled,
    bool? cloudConnected,
    bool? discoveryEnabled,
    DateTime? startedAt,
    String? error,
    bool clearError = false,
    bool clearStartedAt = false,
    bool clearLocalIp = false,
  }) {
    return ServerRuntimeState(
      isRunning: isRunning ?? this.isRunning,
      serverId: serverId ?? this.serverId,
      restaurantId: restaurantId ?? this.restaurantId,
      outletId: outletId ?? this.outletId,
      restaurantName: restaurantName ?? this.restaurantName,
      outletName: outletName ?? this.outletName,
      localIp: clearLocalIp ? null : localIp ?? this.localIp,
      port: port ?? this.port,
      cloudBaseUrl: cloudBaseUrl ?? this.cloudBaseUrl,
      cloudSyncEnabled: cloudSyncEnabled ?? this.cloudSyncEnabled,
      cloudConnected: cloudConnected ?? this.cloudConnected,
      discoveryEnabled: discoveryEnabled ?? this.discoveryEnabled,
      startedAt: clearStartedAt ? null : startedAt ?? this.startedAt,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class ApiLogEntry {
  const ApiLogEntry({
    required this.method,
    required this.path,
    required this.statusCode,
    required this.createdAt,
    this.message,
  });

  final String method;
  final String path;
  final int statusCode;
  final DateTime createdAt;
  final String? message;
}

class LocalServerService {
  LocalServerService({
    required LocalDatabaseService database,
    required NetworkInfoService networkInfo,
    required WebSocketService webSocketService,
    required ServerDiscoveryService discoveryService,
    Future<void> Function()? onLocalMutation,
  }) : _database = database,
       _networkInfo = networkInfo,
       _webSocketService = webSocketService,
       _discoveryService = discoveryService,
       _onLocalMutation = onLocalMutation;

  final LocalDatabaseService _database;
  final NetworkInfoService _networkInfo;
  final WebSocketService _webSocketService;
  final ServerDiscoveryService _discoveryService;
  final Future<void> Function()? _onLocalMutation;
  final StreamController<ServerRuntimeState> _stateController =
      StreamController<ServerRuntimeState>.broadcast();
  final StreamController<List<ApiLogEntry>> _logsController =
      StreamController<List<ApiLogEntry>>.broadcast();

  HttpServer? _server;
  StreamSubscription<String?>? _ipSubscription;
  ServerConfig? _serverConfig;
  CloudConfig? _cloudConfig;
  ServerRuntimeState _state = const ServerRuntimeState(
    isRunning: false,
    port: 8080,
  );
  final List<ApiLogEntry> _logs = [];

  ServerRuntimeState get state => _state;
  List<ApiLogEntry> get logs => List.unmodifiable(_logs);
  Stream<ServerRuntimeState> get stateStream => _stateController.stream;
  Stream<List<ApiLogEntry>> get logsStream => _logsController.stream;

  Future<void> start({
    required ServerConfig serverConfig,
    required CloudConfig cloudConfig,
    required bool cloudConnected,
  }) async {
    if (serverConfig.localPort < 1 || serverConfig.localPort > 65535) {
      throw const LocalServerException('Port must be between 1 and 65535.');
    }
    if (serverConfig.restaurantName.trim().isEmpty) {
      throw const LocalServerException('Restaurant name is required.');
    }
    if (_server != null) {
      await stop();
    }

    _serverConfig = serverConfig;
    _cloudConfig = cloudConfig;
    final localIp = await _networkInfo.getLocalIpAddress();
    final handler = const Pipeline()
        .addMiddleware(_corsMiddleware)
        .addMiddleware(_activityLogger)
        .addHandler(_router);

    try {
      _server = await shelf_io.serve(
        handler,
        InternetAddress.anyIPv4,
        serverConfig.localPort,
        shared: false,
      );
      _server?.autoCompress = true;
      _state = ServerRuntimeState(
        isRunning: true,
        serverId: serverConfig.serverId,
        restaurantId: serverConfig.restaurantId,
        outletId: serverConfig.outletId,
        restaurantName: serverConfig.restaurantName.trim(),
        outletName: serverConfig.outletName.trim(),
        localIp: localIp,
        port: serverConfig.localPort,
        cloudBaseUrl: cloudConfig.baseUrl,
        cloudSyncEnabled: cloudConfig.enabled,
        cloudConnected: cloudConnected,
        discoveryEnabled: serverConfig.discoveryEnabled,
        startedAt: DateTime.now(),
      );
      _addLog(
        'SERVER',
        '/',
        200,
        'Server started on port ${serverConfig.localPort}',
      );
      _emitState();
      _startIpPolling();
      if (serverConfig.discoveryEnabled) {
        await _discoveryService.start(_buildDiscoveryPacket);
      }
    } on SocketException catch (error) {
      final message =
          error.osError?.errorCode == 48 || error.osError?.errorCode == 98
          ? 'Port ${serverConfig.localPort} is already in use. Try another port.'
          : 'Could not start server: ${error.message}';
      _state = _state.copyWith(
        isRunning: false,
        serverId: serverConfig.serverId,
        restaurantId: serverConfig.restaurantId,
        outletId: serverConfig.outletId,
        restaurantName: serverConfig.restaurantName.trim(),
        outletName: serverConfig.outletName.trim(),
        localIp: localIp,
        port: serverConfig.localPort,
        cloudBaseUrl: cloudConfig.baseUrl,
        cloudSyncEnabled: cloudConfig.enabled,
        cloudConnected: cloudConnected,
        discoveryEnabled: serverConfig.discoveryEnabled,
        error: message,
        clearStartedAt: true,
      );
      _emitState();
      throw LocalServerException(message);
    } catch (error) {
      final message = 'Could not start server: $error';
      _state = _state.copyWith(
        isRunning: false,
        localIp: localIp,
        port: serverConfig.localPort,
        error: message,
        clearStartedAt: true,
      );
      _emitState();
      throw LocalServerException(message);
    }
  }

  Future<void> stop() async {
    await _ipSubscription?.cancel();
    _ipSubscription = null;
    await _discoveryService.stop();
    await _server?.close(force: true);
    _server = null;
    await _webSocketService.closeAll();
    _state = _state.copyWith(
      isRunning: false,
      clearStartedAt: true,
      clearError: true,
    );
    _addLog('SERVER', '/', 200, 'Server stopped');
    _emitState();
  }

  Future<void> restart() async {
    final serverConfig = _serverConfig;
    final cloudConfig = _cloudConfig;
    if (serverConfig == null || cloudConfig == null) {
      throw const LocalServerException('Server settings are required.');
    }
    final cloudConnected = _state.cloudConnected;
    await stop();
    await start(
      serverConfig: serverConfig,
      cloudConfig: cloudConfig,
      cloudConnected: cloudConnected,
    );
  }

  Future<void> refreshIp() async {
    final localIp = await _networkInfo.getLocalIpAddress();
    _state = _state.copyWith(
      localIp: localIp,
      clearLocalIp: localIp == null,
      clearError: true,
    );
    _discoveryService.refreshNow();
    _emitState();
  }

  Future<void> updateMetadata({
    required ServerConfig serverConfig,
    required CloudConfig cloudConfig,
    required bool cloudConnected,
  }) async {
    _serverConfig = serverConfig;
    _cloudConfig = cloudConfig;
    _state = _state.copyWith(
      serverId: serverConfig.serverId,
      restaurantId: serverConfig.restaurantId,
      outletId: serverConfig.outletId,
      restaurantName: serverConfig.restaurantName,
      outletName: serverConfig.outletName,
      port: serverConfig.localPort,
      cloudBaseUrl: cloudConfig.baseUrl,
      cloudSyncEnabled: cloudConfig.enabled,
      cloudConnected: cloudConnected,
      discoveryEnabled: serverConfig.discoveryEnabled,
    );
    _emitState();
    if (!_state.isRunning) return;
    if (serverConfig.discoveryEnabled &&
        !_discoveryService.state.isBroadcasting) {
      await _discoveryService.start(_buildDiscoveryPacket);
    } else if (!serverConfig.discoveryEnabled &&
        _discoveryService.state.isBroadcasting) {
      await _discoveryService.stop();
    } else {
      _discoveryService.refreshNow();
    }
  }

  Future<void> dispose() async {
    await stop();
    await _stateController.close();
    await _logsController.close();
  }

  Handler get _router {
    final router =
        Router(
            notFoundHandler: (request) {
              return _json({
                'ok': false,
                'error': 'Route not found.',
                'path': request.requestedUri.path,
              }, statusCode: HttpStatus.notFound);
            },
          )
          ..get('/health', _health)
          ..get('/.well-known/pos-server', _wellKnownServer)
          ..get('/customer', _customerIndex)
          ..get('/customer/<path|.*>', _customerIndex)
          ..get('/cart', _customerIndex)
          ..get('/settings', _customerIndex)
          ..get('/order/<path|.*>', _customerIndex)
          ..get('/r/<restaurantId>/o/<outletId>', _customerIndex)
          ..get('/assets/<path|.*>', _customerAsset)
          ..get('/menu', _menu)
          ..post('/orders', _createOrder)
          ..get('/orders', _orders)
          ..patch('/orders/<id>/status', _updateOrderStatus)
          ..get('/sync/status', _syncStatus)
          ..get(
            '/ws',
            webSocketHandler((WebSocketChannel channel, String? protocol) {
              _webSocketService.attach(channel);
              _addLog('WS', '/ws', 101, 'Client connected');
            }, pingInterval: const Duration(seconds: 20)),
          );

    return router.call;
  }

  Future<Response> _health(Request request) async {
    return _json(_serverMetadataJson());
  }

  Future<Response> _wellKnownServer(Request request) async {
    return _json(_serverMetadataJson());
  }

  Future<Response> _customerIndex(Request request) {
    return _serveCustomerAsset('index.html');
  }

  Future<Response> _customerAsset(Request request) {
    final path = request.params['path'];
    if (path == null || path.contains('..')) {
      return Future.value(
        _json({
          'ok': false,
          'error': 'Asset not found.',
        }, statusCode: HttpStatus.notFound),
      );
    }
    return _serveCustomerAsset('assets/$path');
  }

  Future<Response> _menu(Request request) async {
    final includeUnavailable =
        request.url.queryParameters['includeUnavailable'] == 'true';
    final items = await _database.getMenuItems(
      includeUnavailable: includeUnavailable,
    );
    return _json({
      'ok': true,
      'count': items.length,
      'data': items.map((item) => item.toJson()).toList(growable: false),
    });
  }

  Future<Response> _orders(Request request) async {
    final orders = await _database.getOrders();
    return _json({
      'ok': true,
      'count': orders.length,
      'data': orders.map((order) => order.toJson()).toList(growable: false),
    });
  }

  Future<Response> _syncStatus(Request request) async {
    final summary = await _database.getSyncSummary();
    return _json({'ok': true, ...summary.toJson()});
  }

  Future<Response> _createOrder(Request request) async {
    try {
      final body = await _readJsonObject(request);
      final rawItems = body['items'];
      if (rawItems is! List) {
        return _badRequest('Request body must include an items array.');
      }
      final requestedItems = rawItems
          .map((item) {
            if (item is! Map) {
              throw const FormatException('Each order item must be an object.');
            }
            return OrderRequestItem.fromJson(Map<String, Object?>.from(item));
          })
          .toList(growable: false);

      final order = await _database.createOrder(
        id: (body['id'] ?? body['orderId'])?.toString(),
        customerName: body['customerName']?.toString(),
        tableNo: body['tableNo']?.toString(),
        note: body['note']?.toString(),
        source: OrderSource.localLan,
        requestedItems: requestedItems,
      );
      _webSocketService.broadcast({
        'type': 'order_created',
        'data': order.toJson(),
      });
      unawaited(_onLocalMutation?.call());
      return _json({
        'ok': true,
        'data': order.toJson(),
      }, statusCode: HttpStatus.created);
    } on FormatException catch (error) {
      return _badRequest(error.message);
    } on DatabaseValidationException catch (error) {
      return _badRequest(error.message);
    } catch (error) {
      return _serverError('Could not create order: $error');
    }
  }

  Future<Response> _updateOrderStatus(Request request) async {
    try {
      final id = request.params['id'];
      if (id == null || id.isEmpty) {
        return _badRequest('Order id is required.');
      }
      final body = await _readJsonObject(request);
      final status = OrderStatus.tryParse(body['status']?.toString());
      if (status == null) {
        return _badRequest(
          'Invalid status. Use pending, accepted, preparing, ready, served, or cancelled.',
        );
      }
      final order = await _database.updateOrderStatus(id, status);
      _webSocketService.broadcast({
        'type': 'order_status_updated',
        'data': order.toJson(),
      });
      unawaited(_onLocalMutation?.call());
      return _json({'ok': true, 'data': order.toJson()});
    } on FormatException catch (error) {
      return _badRequest(error.message);
    } on DatabaseValidationException catch (error) {
      return _badRequest(error.message);
    } catch (error) {
      return _serverError('Could not update order status: $error');
    }
  }

  Future<Map<String, Object?>> _readJsonObject(Request request) async {
    final rawBody = await request.readAsString();
    if (rawBody.trim().isEmpty) {
      throw const FormatException('Request body is required.');
    }
    final decoded = jsonDecode(rawBody);
    if (decoded is! Map) {
      throw const FormatException('Request body must be a JSON object.');
    }
    return Map<String, Object?>.from(decoded);
  }

  Response _badRequest(String message) {
    return _json({
      'ok': false,
      'error': message,
    }, statusCode: HttpStatus.badRequest);
  }

  Response _serverError(String message) {
    return _json({
      'ok': false,
      'error': message,
    }, statusCode: HttpStatus.internalServerError);
  }

  Future<Response> _serveCustomerAsset(String relativePath) async {
    final assetPath = 'assets/customer_web/$relativePath';
    try {
      final data = await rootBundle.load(assetPath);
      return Response.ok(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        headers: {HttpHeaders.contentTypeHeader: _contentType(relativePath)},
      );
    } on FlutterError {
      return _json({
        'ok': false,
        'error': 'Customer web asset not found.',
      }, statusCode: HttpStatus.notFound);
    }
  }

  Map<String, Object?> _serverMetadataJson() {
    return {
      'ok': true,
      'server': 'hybrid-pos-local',
      'mode': 'local',
      'serverId': _state.serverId,
      'restaurantId': _state.restaurantId,
      'outletId': _state.outletId,
      'restaurantName': _state.restaurantName ?? '',
      'outletName': _state.outletName ?? '',
      'ip': _state.localIp,
      'port': _state.port,
      'baseUrl': _state.apiUrl,
      'wsUrl': _state.wsUrl,
      'cloudSyncEnabled': _state.cloudSyncEnabled,
      'cloudConnected': _state.cloudConnected,
      'discoveryEnabled': _state.discoveryEnabled,
      'connectedClients': _webSocketService.connectedClients,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  DiscoveryPacket _buildDiscoveryPacket() {
    return DiscoveryPacket(
      serverId: _state.serverId,
      restaurantId: _state.restaurantId,
      outletId: _state.outletId,
      restaurantName: _state.restaurantName ?? 'Hybrid POS',
      localIp: _state.localIp,
      port: _state.port,
      cloudBaseUrl: _state.cloudBaseUrl,
      timestamp: DateTime.now(),
    );
  }

  String _contentType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.html')) return 'text/html; charset=utf-8';
    if (lower.endsWith('.js')) return 'application/javascript; charset=utf-8';
    if (lower.endsWith('.css')) return 'text/css; charset=utf-8';
    if (lower.endsWith('.json')) return 'application/json; charset=utf-8';
    if (lower.endsWith('.svg')) return 'image/svg+xml';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.ico')) return 'image/x-icon';
    return 'application/octet-stream';
  }

  void _startIpPolling() {
    unawaited(_ipSubscription?.cancel());
    _ipSubscription = _networkInfo.watchLocalIp().listen((ip) {
      if (ip == _state.localIp) return;
      _state = _state.copyWith(localIp: ip, clearLocalIp: ip == null);
      _addLog(
        'NETWORK',
        '/ip',
        200,
        'Local IP changed to ${ip ?? 'not found'}',
      );
      _discoveryService.refreshNow();
      _emitState();
    });
  }

  static Handler _corsMiddleware(Handler inner) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok(
          jsonEncode({'ok': true}),
          headers: {
            HttpHeaders.contentTypeHeader: ContentType.json.mimeType,
            ..._corsHeaders,
          },
        );
      }
      final response = await inner(request);
      return response.change(headers: {...response.headers, ..._corsHeaders});
    };
  }

  Handler _activityLogger(Handler inner) {
    return (Request request) async {
      try {
        final response = await inner(request);
        _addLog(request.method, request.requestedUri.path, response.statusCode);
        return response;
      } catch (error) {
        _addLog(
          request.method,
          request.requestedUri.path,
          HttpStatus.internalServerError,
          error.toString(),
        );
        rethrow;
      }
    };
  }

  static Response _json(
    Map<String, Object?> body, {
    int statusCode = HttpStatus.ok,
  }) {
    return Response(
      statusCode,
      headers: {HttpHeaders.contentTypeHeader: ContentType.json.mimeType},
      body: jsonEncode(body),
    );
  }

  void _addLog(String method, String path, int statusCode, [String? message]) {
    _logs.insert(
      0,
      ApiLogEntry(
        method: method,
        path: path,
        statusCode: statusCode,
        createdAt: DateTime.now(),
        message: message,
      ),
    );
    if (_logs.length > 80) {
      _logs.removeRange(80, _logs.length);
    }
    if (!_logsController.isClosed) {
      _logsController.add(List.unmodifiable(_logs));
    }
  }

  void _emitState() {
    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }
  }

  static const Map<String, String> _corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PATCH, DELETE, OPTIONS',
    'Access-Control-Allow-Headers':
        'Origin, Content-Type, Accept, Authorization, Idempotency-Key',
  };
}
