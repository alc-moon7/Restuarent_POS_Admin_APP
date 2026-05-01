class DiscoveryPacket {
  const DiscoveryPacket({
    required this.serverId,
    required this.restaurantId,
    required this.outletId,
    required this.restaurantName,
    required this.localIp,
    required this.port,
    required this.cloudBaseUrl,
    required this.timestamp,
  });

  final String serverId;
  final String restaurantId;
  final String outletId;
  final String restaurantName;
  final String? localIp;
  final int port;
  final String cloudBaseUrl;
  final DateTime timestamp;

  String? get baseUrl =>
      localIp == null || localIp!.isEmpty ? null : 'http://$localIp:$port';

  String? get wsUrl =>
      localIp == null || localIp!.isEmpty ? null : 'ws://$localIp:$port/ws';

  String? get healthUrl => localIp == null || localIp!.isEmpty
      ? null
      : 'http://$localIp:$port/health';

  Map<String, Object?> toJson() {
    return {
      'type': 'POS_SERVER_ADVERTISEMENT',
      'version': '1.0.0',
      'serverId': serverId,
      'restaurantId': restaurantId,
      'outletId': outletId,
      'restaurantName': restaurantName,
      'localIp': localIp,
      'port': port,
      'baseUrl': baseUrl,
      'wsUrl': wsUrl,
      'healthUrl': healthUrl,
      'cloudBaseUrl': cloudBaseUrl,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
