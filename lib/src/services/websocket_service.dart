import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  final Set<WebSocketChannel> _clients = {};
  final StreamController<int> _clientCountController =
      StreamController<int>.broadcast();

  int get connectedClients => _clients.length;

  Stream<int> get clientCountStream => _clientCountController.stream;

  void attach(WebSocketChannel channel) {
    _clients.add(channel);
    _emitClientCount();
    channel.stream.listen(
      (_) {},
      onDone: () => _remove(channel),
      onError: (_) => _remove(channel),
      cancelOnError: true,
    );
  }

  void broadcast(Map<String, Object?> event) {
    final payload = jsonEncode({
      ...event,
      'sentAt': DateTime.now().toIso8601String(),
    });
    for (final client in List<WebSocketChannel>.from(_clients)) {
      try {
        client.sink.add(payload);
      } catch (_) {
        _remove(client);
      }
    }
  }

  Future<void> closeAll() async {
    for (final client in List<WebSocketChannel>.from(_clients)) {
      await client.sink.close();
    }
    _clients.clear();
    _emitClientCount();
  }

  void dispose() {
    _clientCountController.close();
  }

  void _remove(WebSocketChannel channel) {
    if (_clients.remove(channel)) {
      _emitClientCount();
    }
  }

  void _emitClientCount() {
    if (!_clientCountController.isClosed) {
      _clientCountController.add(_clients.length);
    }
  }
}
