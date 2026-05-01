import 'dart:io';

import 'package:network_info_plus/network_info_plus.dart';

class NetworkInfoService {
  NetworkInfoService({NetworkInfo? networkInfo})
    : _networkInfo = networkInfo ?? NetworkInfo();

  final NetworkInfo _networkInfo;

  Future<String?> getLocalIpAddress() async {
    final pluginIp = await _getPluginWifiIp();
    if (_isUsableIpv4(pluginIp)) return pluginIp;
    return _getFirstLocalInterfaceIp();
  }

  Stream<String?> watchLocalIp({
    Duration interval = const Duration(seconds: 8),
  }) async* {
    String? lastIp;
    while (true) {
      final currentIp = await getLocalIpAddress();
      if (currentIp != lastIp) {
        lastIp = currentIp;
        yield currentIp;
      }
      await Future<void>.delayed(interval);
    }
  }

  Future<String?> _getPluginWifiIp() async {
    try {
      return await _networkInfo.getWifiIP();
    } catch (_) {
      return null;
    }
  }

  Future<String?> _getFirstLocalInterfaceIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      );
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (_isUsableIpv4(address.address)) {
            return address.address;
          }
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  bool _isUsableIpv4(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    if (value == InternetAddress.loopbackIPv4.address) return false;
    if (value.startsWith('169.254.')) return false;
    return InternetAddress.tryParse(value)?.type == InternetAddressType.IPv4;
  }
}
