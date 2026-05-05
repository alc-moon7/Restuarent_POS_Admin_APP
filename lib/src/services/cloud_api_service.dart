import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants/cloud_defaults.dart';
import '../models/bkash_payment_session.dart';
import '../models/menu_item.dart';
import '../models/order_model.dart';
import '../models/order_status.dart';
import '../models/server_config.dart';

class CloudApiException implements Exception {
  const CloudApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CloudRealtimeConfig {
  const CloudRealtimeConfig({
    required this.enabled,
    required this.supabaseUrl,
    required this.publishableKey,
    required this.channelPrefix,
  });

  final bool enabled;
  final String supabaseUrl;
  final String publishableKey;
  final String channelPrefix;

  bool get canConnect {
    return enabled &&
        supabaseUrl.trim().isNotEmpty &&
        publishableKey.trim().isNotEmpty &&
        channelPrefix.trim().isNotEmpty;
  }

  String channelName(String outletId) => '${channelPrefix.trim()}$outletId';

  static CloudRealtimeConfig? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, Object?>.from(value);
    final supabaseUrl = json['supabaseUrl']?.toString().trim() ?? '';
    final publishableKey = json['publishableKey']?.toString().trim() ?? '';
    final channelPrefix =
        json['channelPrefix']?.toString().trim() ?? 'pos:outlet:';
    return CloudRealtimeConfig(
      enabled: json['enabled'] == true,
      supabaseUrl: supabaseUrl,
      publishableKey: publishableKey,
      channelPrefix: channelPrefix,
    );
  }
}

class TenantBootstrapResult {
  const TenantBootstrapResult({
    required this.serverId,
    required this.restaurantId,
    required this.outletId,
    required this.restaurantName,
    required this.outletName,
    required this.deviceToken,
  });

  final String serverId;
  final String restaurantId;
  final String outletId;
  final String restaurantName;
  final String outletName;
  final String deviceToken;

  static TenantBootstrapResult fromJson(Map<String, Object?> json) {
    final data = json['data'] is Map
        ? Map<String, Object?>.from(json['data'] as Map)
        : json;
    return TenantBootstrapResult(
      serverId: _required(data, 'serverId'),
      restaurantId: _required(data, 'restaurantId'),
      outletId: _required(data, 'outletId'),
      restaurantName: _required(data, 'restaurantName'),
      outletName: _required(data, 'outletName'),
      deviceToken: _required(data, 'deviceToken'),
    );
  }

  static String _required(Map<String, Object?> json, String key) {
    final value = json[key]?.toString().trim() ?? '';
    if (value.isEmpty) {
      throw CloudApiException('Cloud tenant response is missing $key.');
    }
    return value;
  }
}

class CloudApiService {
  CloudApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  CloudConfig _cloudConfig = CloudConfig(
    baseUrl: CloudDefaults.baseUrl,
    enabled: CloudDefaults.shouldEnableSyncByDefault,
    deviceToken: '',
    autoSyncIntervalSeconds: 30,
  );
  ServerConfig? _serverConfig;
  CloudRealtimeConfig? _realtimeConfig;

  CloudRealtimeConfig? get realtimeConfig => _realtimeConfig;

  void configure({
    required CloudConfig cloudConfig,
    required ServerConfig serverConfig,
  }) {
    _cloudConfig = cloudConfig;
    _serverConfig = serverConfig;
  }

  Future<Map<String, Object?>> testHealth() async {
    final uri = _uri('/health');
    if (uri == null) {
      throw const CloudApiException('Cloud API URL is empty or invalid.');
    }
    final response = await _sendJson('GET', uri);
    _captureRealtimeConfig(response);
    return response;
  }

  Future<CloudRealtimeConfig?> loadRealtimeConfig() async {
    if (_realtimeConfig?.canConnect == true) return _realtimeConfig;
    if (!_cloudConfig.canConnect) return null;
    await testHealth();
    return _realtimeConfig;
  }

  Future<TenantBootstrapResult> bootstrapTenant({
    required String serverId,
    required String restaurantName,
    required String outletName,
    String? restaurantId,
    String? outletId,
  }) async {
    final uri = _uri('/tenants/bootstrap');
    if (uri == null) {
      throw const CloudApiException('Cloud API URL is empty or invalid.');
    }
    final response = await _sendJson(
      'POST',
      uri,
      body: {
        'serverId': serverId,
        'restaurantName': restaurantName,
        'outletName': outletName,
        if (restaurantId?.trim().isNotEmpty == true)
          'restaurantId': restaurantId!.trim(),
        if (outletId?.trim().isNotEmpty == true) 'outletId': outletId!.trim(),
      },
      idempotencyKey: 'tenant-bootstrap-$serverId',
    );
    return TenantBootstrapResult.fromJson(response);
  }

  Future<BkashPaymentSession> createBkashSandboxPayment({
    required String serverId,
    required double amount,
  }) async {
    final uri = _uri('/payments/bkash/create');
    if (uri == null) {
      throw const CloudApiException('Cloud API URL is empty or invalid.');
    }
    final response = await _sendJson(
      'POST',
      uri,
      body: {
        'serverId': serverId,
        'amount': amount,
        'currency': 'BDT',
        'purpose': 'admin_activation',
      },
      idempotencyKey:
          'bkash-activation-$serverId-${DateTime.now().millisecondsSinceEpoch}',
    );
    return BkashPaymentSession.fromJson(response);
  }

  Future<BkashPaymentSession> verifyBkashPayment(String paymentId) async {
    final uri = _uri('/payments/bkash/$paymentId/verify');
    if (uri == null) {
      throw const CloudApiException('Cloud API URL is empty or invalid.');
    }
    final response = await _sendJson('POST', uri);
    return BkashPaymentSession.fromJson(response);
  }

  Future<BkashPaymentSession> getBkashPaymentStatus(String paymentId) async {
    final uri = _uri('/payments/bkash/$paymentId/status');
    if (uri == null) {
      throw const CloudApiException('Cloud API URL is empty or invalid.');
    }
    final response = await _sendJson('GET', uri);
    return BkashPaymentSession.fromJson(response);
  }

  Future<Map<String, Object?>> registerDevice() async {
    final config = _requireServerConfig();
    final uri = _uri('/devices/register');
    if (uri == null) {
      throw const CloudApiException('Cloud API URL is empty or invalid.');
    }
    return _sendJson(
      'POST',
      uri,
      body: {
        'serverId': config.serverId,
        'restaurantId': config.restaurantId,
        'outletId': config.outletId,
        'restaurantName': config.restaurantName,
        'outletName': config.outletName,
      },
      idempotencyKey: 'device-${config.serverId}',
    );
  }

  Future<Map<String, Object?>> pushMenuItem(MenuItem item) async {
    final config = _requireServerConfig();
    final uri = _uri('/outlets/${config.outletId}/menu');
    if (uri == null) {
      throw const CloudApiException('Cloud API URL is empty or invalid.');
    }
    return _sendJson(
      'POST',
      uri,
      body: item.toJson(),
      idempotencyKey: 'menu-${item.id}-${item.version}',
    );
  }

  Future<Map<String, Object?>> updateMenuItem(MenuItem item) async {
    final config = _requireServerConfig();
    final uri = _uri('/outlets/${config.outletId}/menu/${item.id}');
    if (uri == null) {
      throw const CloudApiException('Cloud API URL is empty or invalid.');
    }
    return _sendJson(
      'PATCH',
      uri,
      body: item.toJson(),
      idempotencyKey: 'menu-${item.id}-${item.version}',
    );
  }

  Future<String> uploadMenuImageDataUrl(String dataUrl) async {
    final config = _requireServerConfig();
    final uri = _uri('/outlets/${config.outletId}/menu/images');
    if (uri == null) {
      throw const CloudApiException('Cloud API URL is empty or invalid.');
    }
    final response = await _sendJson(
      'POST',
      uri,
      body: {
        'dataUrl': dataUrl,
        'fileName': 'menu-${DateTime.now().millisecondsSinceEpoch}.jpg',
      },
      idempotencyKey:
          'menu-image-${config.serverId}-${DateTime.now().microsecondsSinceEpoch}',
    );
    final data = response['data'] is Map
        ? Map<String, Object?>.from(response['data'] as Map)
        : response;
    final publicUrl = data['publicUrl']?.toString().trim() ?? '';
    if (publicUrl.isEmpty) {
      throw const CloudApiException('Cloud image upload did not return a URL.');
    }
    return publicUrl;
  }

  Future<Map<String, Object?>> deleteMenuItem(String id) async {
    final config = _requireServerConfig();
    final uri = _uri('/outlets/${config.outletId}/menu/$id');
    if (uri == null) {
      throw const CloudApiException('Cloud API URL is empty or invalid.');
    }
    return _sendJson('DELETE', uri, idempotencyKey: 'menu-delete-$id');
  }

  Future<Map<String, Object?>> pushOrder(OrderModel order) async {
    final config = _requireServerConfig();
    final uri = _uri('/outlets/${config.outletId}/orders');
    if (uri == null) {
      throw const CloudApiException('Cloud API URL is empty or invalid.');
    }
    return _sendJson(
      'POST',
      uri,
      body: order.toJson(),
      idempotencyKey: 'order-${order.id}',
    );
  }

  Future<Map<String, Object?>> pushOrderStatus(
    String orderId,
    OrderStatus status,
  ) async {
    final config = _requireServerConfig();
    final uri = _uri('/outlets/${config.outletId}/orders/$orderId/status');
    if (uri == null) {
      throw const CloudApiException('Cloud API URL is empty or invalid.');
    }
    return _sendJson(
      'PATCH',
      uri,
      body: {
        'status': status.value,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      idempotencyKey: 'order-status-$orderId-${status.value}',
    );
  }

  Future<List<Map<String, Object?>>> pullMenu({DateTime? since}) async {
    final config = _requireServerConfig();
    final uri = _uri(
      '/outlets/${config.outletId}/menu',
      queryParameters: since == null
          ? null
          : {'since': since.toIso8601String()},
    );
    if (uri == null) return const [];
    final json = await _sendJson('GET', uri);
    return _extractList(json);
  }

  Future<List<Map<String, Object?>>> pullOrders({DateTime? since}) async {
    final config = _requireServerConfig();
    final uri = _uri(
      '/outlets/${config.outletId}/orders',
      queryParameters: since == null
          ? null
          : {'since': since.toIso8601String()},
    );
    if (uri == null) return const [];
    final json = await _sendJson('GET', uri);
    return _extractList(json);
  }

  Future<Map<String, Object?>> _sendJson(
    String method,
    Uri uri, {
    Map<String, Object?>? body,
    String? idempotencyKey,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (_cloudConfig.deviceToken.trim().isNotEmpty)
        'Authorization': 'Bearer ${_cloudConfig.deviceToken.trim()}',
    };
    if (idempotencyKey != null) {
      headers['Idempotency-Key'] = idempotencyKey;
    }
    final encodedBody = body == null ? null : jsonEncode(body);
    final response = await _request(
      method,
      uri,
      headers,
      encodedBody,
    ).timeout(const Duration(seconds: 12));
    final decoded = response.body.trim().isEmpty
        ? <String, Object?>{}
        : jsonDecode(response.body);
    final payload = decoded is Map
        ? Map<String, Object?>.from(decoded)
        : <String, Object?>{'data': decoded};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudApiException(
        payload['error']?.toString() ??
            'Cloud request failed: HTTP ${response.statusCode}',
      );
    }
    return payload;
  }

  Future<http.Response> _request(
    String method,
    Uri uri,
    Map<String, String> headers,
    String? body,
  ) {
    switch (method) {
      case 'GET':
        return _client.get(uri, headers: headers);
      case 'POST':
        return _client.post(uri, headers: headers, body: body);
      case 'PATCH':
        return _client.patch(uri, headers: headers, body: body);
      case 'DELETE':
        return _client.delete(uri, headers: headers);
      default:
        throw CloudApiException('Unsupported cloud method $method.');
    }
  }

  List<Map<String, Object?>> _extractList(Map<String, Object?> json) {
    final raw = json['data'] ?? json['items'] ?? json['orders'] ?? json['menu'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .toList(growable: false);
  }

  Uri? _uri(String path, {Map<String, String>? queryParameters}) {
    final base = _baseUri();
    if (base == null) return null;
    return base.replace(
      path: _joinPaths(base.path, path),
      queryParameters: queryParameters,
    );
  }

  Uri? _baseUri() {
    if (!_cloudConfig.canConnect) return null;
    return Uri.tryParse(_cloudConfig.baseUrl.trim());
  }

  String _joinPaths(String basePath, String endpointPath) {
    final cleanBase = basePath.endsWith('/')
        ? basePath.substring(0, basePath.length - 1)
        : basePath;
    final cleanEndpoint = endpointPath.startsWith('/')
        ? endpointPath.substring(1)
        : endpointPath;
    if (cleanBase.isEmpty) return '/$cleanEndpoint';
    return '$cleanBase/$cleanEndpoint';
  }

  ServerConfig _requireServerConfig() {
    final config = _serverConfig;
    if (config == null) {
      throw const CloudApiException('Server config is not ready.');
    }
    return config;
  }

  void _captureRealtimeConfig(Map<String, Object?> json) {
    final config = CloudRealtimeConfig.fromJson(json['realtime']);
    if (config != null) _realtimeConfig = config;
  }

  void close() {
    _client.close();
  }
}
