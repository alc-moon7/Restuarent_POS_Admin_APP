import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/discovery_packet.dart';

class DiscoveryRuntimeState {
  const DiscoveryRuntimeState({
    required this.isBroadcasting,
    required this.port,
    this.lastPacket,
    this.lastBroadcastAt,
    this.error,
  });

  final bool isBroadcasting;
  final int port;
  final Map<String, Object?>? lastPacket;
  final DateTime? lastBroadcastAt;
  final String? error;

  DiscoveryRuntimeState copyWith({
    bool? isBroadcasting,
    int? port,
    Map<String, Object?>? lastPacket,
    DateTime? lastBroadcastAt,
    String? error,
    bool clearError = false,
    bool clearPacket = false,
  }) {
    return DiscoveryRuntimeState(
      isBroadcasting: isBroadcasting ?? this.isBroadcasting,
      port: port ?? this.port,
      lastPacket: clearPacket ? null : lastPacket ?? this.lastPacket,
      lastBroadcastAt: lastBroadcastAt ?? this.lastBroadcastAt,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class ServerDiscoveryService {
  ServerDiscoveryService({this.discoveryPort = 45678});

  final int discoveryPort;
  final StreamController<DiscoveryRuntimeState> _stateController =
      StreamController<DiscoveryRuntimeState>.broadcast();

  RawDatagramSocket? _socket;
  Timer? _timer;
  DiscoveryPacket Function()? _packetBuilder;
  DiscoveryRuntimeState _state = const DiscoveryRuntimeState(
    isBroadcasting: false,
    port: 45678,
  );

  DiscoveryRuntimeState get state => _state;
  Stream<DiscoveryRuntimeState> get stateStream => _stateController.stream;

  Future<void> start(DiscoveryPacket Function() packetBuilder) async {
    _packetBuilder = packetBuilder;
    if (_socket == null) {
      try {
        _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
        _socket?.broadcastEnabled = true;
      } catch (error) {
        _state = _state.copyWith(
          isBroadcasting: false,
          error: 'Discovery could not start: $error',
        );
        _emitState();
        return;
      }
    }
    _timer?.cancel();
    _state = _state.copyWith(isBroadcasting: true, clearError: true);
    _emitState();
    _broadcastOnce();
    _timer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _broadcastOnce(),
    );
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _socket?.close();
    _socket = null;
    _state = _state.copyWith(isBroadcasting: false, clearError: true);
    _emitState();
  }

  void refreshNow() {
    if (_state.isBroadcasting) {
      _broadcastOnce();
    }
  }

  Future<void> dispose() async {
    await stop();
    await _stateController.close();
  }

  void _broadcastOnce() {
    final builder = _packetBuilder;
    final socket = _socket;
    if (builder == null || socket == null) return;
    try {
      final packet = builder().toJson();
      final payload = utf8.encode(jsonEncode(packet));
      socket.send(payload, InternetAddress('255.255.255.255'), discoveryPort);
      _state = _state.copyWith(
        isBroadcasting: true,
        lastPacket: packet,
        lastBroadcastAt: DateTime.now(),
        clearError: true,
      );
      _emitState();
    } catch (error) {
      _state = _state.copyWith(error: 'Discovery broadcast failed: $error');
      _emitState();
    }
  }

  void _emitState() {
    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }
  }
}
