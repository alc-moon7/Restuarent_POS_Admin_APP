class CloudDefaults {
  CloudDefaults._();

  static String productionBaseUrl =
      'https://vnhxfvtpkgykatvbrczn.supabase.co/functions/v1/pos-api';

  static String placeholderBaseUrl = 'https://api.example.com';

  static String baseUrl = String.fromEnvironment(
    'POS_CLOUD_API_URL',
    defaultValue: productionBaseUrl,
  );

  static bool forceCloudSyncEnabled = bool.fromEnvironment(
    'POS_CLOUD_SYNC_ENABLED',
  );

  static bool get hasConfiguredBaseUrl {
    final trimmed = baseUrl.trim();
    return trimmed.isNotEmpty && trimmed != placeholderBaseUrl;
  }

  static bool get shouldEnableSyncByDefault {
    return forceCloudSyncEnabled || hasConfiguredBaseUrl;
  }

  static String resolveBaseUrl(String? override) {
    final trimmed = override?.trim();
    if (trimmed == null ||
        trimmed.isEmpty ||
        trimmed == placeholderBaseUrl ||
        _isLocalOrPrivateUrl(trimmed)) {
      return baseUrl;
    }
    return trimmed;
  }

  static bool _isLocalOrPrivateUrl(String value) {
    final uri = Uri.tryParse(value);
    final host = uri?.host.toLowerCase() ?? '';
    if (host.isEmpty) return false;
    if (host == 'localhost' || host == '127.0.0.1' || host == '0.0.0.0') {
      return true;
    }
    if (host.startsWith('192.168.') || host.startsWith('10.')) {
      return true;
    }
    final parts = host.split('.');
    if (parts.length == 4 && parts.first == '172') {
      final second = int.tryParse(parts[1]);
      return second != null && second >= 16 && second <= 31;
    }
    return false;
  }
}
