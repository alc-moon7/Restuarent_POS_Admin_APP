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
    if (trimmed == null || trimmed.isEmpty || trimmed == placeholderBaseUrl) {
      return baseUrl;
    }
    return trimmed;
  }
}
