import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/order_item.dart';
import '../models/order_status.dart';
import 'local_database_service.dart';
import 'network_info_service.dart';
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
    this.restaurantName,
    this.localIp,
    this.startedAt,
    this.error,
  });

  final bool isRunning;
  final String? restaurantName;
  final String? localIp;
  final int port;
  final DateTime? startedAt;
  final String? error;

  String? get apiUrl =>
      localIp == null || localIp!.isEmpty ? null : 'http://$localIp:$port';

  String? get wsUrl =>
      localIp == null || localIp!.isEmpty ? null : 'ws://$localIp:$port/ws';

  ServerRuntimeState copyWith({
    bool? isRunning,
    String? restaurantName,
    String? localIp,
    int? port,
    DateTime? startedAt,
    String? error,
    bool clearError = false,
    bool clearStartedAt = false,
    bool clearLocalIp = false,
  }) {
    return ServerRuntimeState(
      isRunning: isRunning ?? this.isRunning,
      restaurantName: restaurantName ?? this.restaurantName,
      localIp: clearLocalIp ? null : localIp ?? this.localIp,
      port: port ?? this.port,
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
  }) : _database = database,
       _networkInfo = networkInfo,
       _webSocketService = webSocketService;

  final LocalDatabaseService _database;
  final NetworkInfoService _networkInfo;
  final WebSocketService _webSocketService;
  final StreamController<ServerRuntimeState> _stateController =
      StreamController<ServerRuntimeState>.broadcast();
  final StreamController<List<ApiLogEntry>> _logsController =
      StreamController<List<ApiLogEntry>>.broadcast();

  HttpServer? _server;
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
    required String restaurantName,
    required int port,
  }) async {
    if (port < 1 || port > 65535) {
      throw const LocalServerException('Port must be between 1 and 65535.');
    }
    if (restaurantName.trim().isEmpty) {
      throw const LocalServerException('Restaurant name is required.');
    }
    if (_server != null) {
      await stop();
    }

    final localIp = await _networkInfo.getLocalIpAddress();
    final handler = const Pipeline()
        .addMiddleware(_corsMiddleware)
        .addMiddleware(_activityLogger)
        .addHandler(_router);

    try {
      _server = await shelf_io.serve(
        handler,
        InternetAddress.anyIPv4,
        port,
        shared: false,
      );
      _server?.autoCompress = true;
      _state = ServerRuntimeState(
        isRunning: true,
        restaurantName: restaurantName.trim(),
        localIp: localIp,
        port: port,
        startedAt: DateTime.now(),
      );
      _addLog('SERVER', '/', 200, 'Server started on port $port');
      _emitState();
    } on SocketException catch (error) {
      final message =
          error.osError?.errorCode == 48 || error.osError?.errorCode == 98
          ? 'Port $port is already in use. Try another port.'
          : 'Could not start server: ${error.message}';
      _state = _state.copyWith(
        isRunning: false,
        restaurantName: restaurantName.trim(),
        localIp: localIp,
        port: port,
        error: message,
        clearStartedAt: true,
      );
      _emitState();
      throw LocalServerException(message);
    } catch (error) {
      final message = 'Could not start server: $error';
      _state = _state.copyWith(
        isRunning: false,
        restaurantName: restaurantName.trim(),
        localIp: localIp,
        port: port,
        error: message,
        clearStartedAt: true,
      );
      _emitState();
      throw LocalServerException(message);
    }
  }

  Future<void> stop() async {
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
    final restaurantName = _state.restaurantName;
    final port = _state.port;
    if (restaurantName == null || restaurantName.trim().isEmpty) {
      throw const LocalServerException('Restaurant name is required.');
    }
    await stop();
    await start(restaurantName: restaurantName, port: port);
  }

  Future<void> refreshIp() async {
    final localIp = await _networkInfo.getLocalIpAddress();
    _state = _state.copyWith(
      localIp: localIp,
      clearLocalIp: localIp == null,
      clearError: true,
    );
    _emitState();
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
          ..get('/menu', _menu)
          ..post('/orders', _createOrder)
          ..get('/orders', _orders)
          ..patch('/orders/<id>/status', _updateOrderStatus)
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
    return _json({
      'ok': true,
      'status': _state.isRunning ? 'running' : 'stopped',
      'restaurantName': _state.restaurantName,
      'localIp': _state.localIp,
      'port': _state.port,
      'apiUrl': _state.apiUrl,
      'webSocketUrl': _state.wsUrl,
      'connectedClients': _webSocketService.connectedClients,
      'startedAt': _state.startedAt?.toIso8601String(),
    });
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
        customerName: body['customerName']?.toString(),
        tableNo: body['tableNo']?.toString(),
        note: body['note']?.toString(),
        requestedItems: requestedItems,
      );
      _webSocketService.broadcast({
        'type': 'order_created',
        'data': order.toJson(),
      });
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
    'Access-Control-Allow-Methods': 'GET, POST, PATCH, OPTIONS',
    'Access-Control-Allow-Headers':
        'Origin, Content-Type, Accept, Authorization',
  };
}
