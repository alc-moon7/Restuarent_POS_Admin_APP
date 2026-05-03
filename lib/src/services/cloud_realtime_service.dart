import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/server_config.dart';
import 'cloud_api_service.dart';

class CloudRealtimeService {
  SupabaseClient? _client;
  RealtimeChannel? _channel;
  String? _channelName;
  bool _subscribed = false;

  bool get isSubscribed => _subscribed;
  String? get channelName => _channelName;

  Future<void> connect({
    required CloudRealtimeConfig config,
    required ServerConfig serverConfig,
    required void Function(Map<String, Object?> event) onEvent,
    void Function(String message)? onLog,
  }) async {
    if (!config.canConnect) return;
    final nextChannel = config.channelName(serverConfig.outletId);
    if (_subscribed && _channelName == nextChannel) return;

    await disconnect();
    _client = SupabaseClient(config.supabaseUrl, config.publishableKey);
    _channelName = nextChannel;
    final channel = _client!.channel(nextChannel);

    for (final event in const [
      'device_registered',
      'device_heartbeat',
      'menu_updated',
      'order_created',
      'order_status_updated',
    ]) {
      channel.onBroadcast(
        event: event,
        callback: (payload) {
          onEvent(_normalizePayload(event, payload));
        },
      );
    }

    _channel = channel;
    channel.subscribe((status, [error]) {
      _subscribed = status == RealtimeSubscribeStatus.subscribed;
      if (_subscribed) {
        onLog?.call('Cloud realtime connected: $nextChannel');
      } else if (error != null) {
        onLog?.call('Cloud realtime status $status: $error');
      }
    });
  }

  Future<void> disconnect() async {
    final channel = _channel;
    _channel = null;
    _channelName = null;
    _subscribed = false;
    if (channel != null) {
      await channel.unsubscribe();
    }
  }

  Map<String, Object?> _normalizePayload(
    String event,
    Map<String, dynamic> payload,
  ) {
    final raw = payload['payload'];
    if (raw is Map) {
      final normalized = Map<String, Object?>.from(raw);
      normalized['type'] ??= event;
      return normalized;
    }
    return {
      'type': event,
      'data': raw,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}
