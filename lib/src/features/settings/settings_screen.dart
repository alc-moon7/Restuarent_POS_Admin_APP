import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../app_controller.dart';
import '../../app_scope.dart';
import '../../core/constants/cloud_defaults.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/sync_event_tile.dart';
import '../../services/printer_service.dart';
import '../../services/sync_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _restaurantInfoFormKey = GlobalKey<FormState>();
  final TextEditingController _restaurantController = TextEditingController();
  final TextEditingController _outletController = TextEditingController();
  final TextEditingController _cloudUrlController = TextEditingController();
  final TextEditingController _restaurantIdController = TextEditingController();
  final TextEditingController _outletIdController = TextEditingController();
  final TextEditingController _syncIntervalController = TextEditingController();
  final TextEditingController _infoTitleController = TextEditingController();
  final TextEditingController _infoPhoneController = TextEditingController();
  final TextEditingController _infoEmailController = TextEditingController();
  final TextEditingController _infoAddressController = TextEditingController();
  final TextEditingController _infoWebsiteController = TextEditingController();
  final TextEditingController _infoDescriptionController =
      TextEditingController();
  Timer? _autoSaveDebounce;
  bool _cloudSyncEnabled = false;
  double _displayScale = 1.0;
  bool _hydrated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hydrated) return;
    final app = AppScope.of(context);
    _restaurantController.text = app.serverConfig.restaurantName;
    _outletController.text = app.serverConfig.outletName;
    _cloudUrlController.text = app.cloudConfig.baseUrl;
    _restaurantIdController.text = app.serverConfig.restaurantId;
    _outletIdController.text = app.serverConfig.outletId;
    _syncIntervalController.text = app.cloudConfig.autoSyncIntervalSeconds
        .toString();
    _cloudSyncEnabled = app.cloudConfig.enabled;
    _displayScale = app.uiScale;
    _restaurantController.addListener(_scheduleAutoSave);
    _outletController.addListener(_scheduleAutoSave);
    _cloudUrlController.addListener(_scheduleAutoSave);
    _syncIntervalController.addListener(_scheduleAutoSave);
    _hydrated = true;
  }

  @override
  void dispose() {
    _autoSaveDebounce?.cancel();
    _restaurantController.dispose();
    _outletController.dispose();
    _cloudUrlController.dispose();
    _restaurantIdController.dispose();
    _outletIdController.dispose();
    _syncIntervalController.dispose();
    _infoTitleController.dispose();
    _infoPhoneController.dispose();
    _infoEmailController.dispose();
    _infoAddressController.dispose();
    _infoWebsiteController.dispose();
    _infoDescriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    return AppScaffold(
      title: text.settings,
      showDatePill: false,
      pinHeader: true,
      child: Column(
        children: [
          _SettingsNavTile(
            title: text.restaurantSection,
            subtitle: text.restaurantSubtitle,
            icon: Icons.storefront_outlined,
            onTap: _openRestaurantInfo,
          ),
          SizedBox(height: 10),
          _SettingsNavTile(
            title: text.receiptPrinter,
            subtitle: text.receiptPrinterSubtitle,
            icon: Icons.print_outlined,
            onTap: _openReceiptPrinter,
          ),
          SizedBox(height: 10),
          _SettingsNavTile(
            title: text.cloudSync,
            subtitle: text.cloudSyncSubtitle,
            icon: Icons.cloud_sync_outlined,
            onTap: _openCloudSync,
          ),
          SizedBox(height: 10),
          _SettingsNavTile(
            title: text.themeMode,
            subtitle: text.themeModeSubtitle,
            icon: Icons.palette_outlined,
            onTap: _openThemeMode,
          ),
          SizedBox(height: 10),
          _SettingsNavTile(
            title: text.displaySize,
            subtitle: text.displaySizeSubtitle,
            icon: Icons.tune_rounded,
            onTap: _openDisplaySettings,
          ),
          SizedBox(height: 10),
          _SettingsNavTile(
            title: text.languageLabel,
            subtitle: text.languageSubtitle,
            icon: Icons.translate_rounded,
            onTap: _openLanguageSettings,
          ),
          SizedBox(height: 10),
          _SettingsNavTile(
            title: text.appCache,
            subtitle: text.clearCacheSubtitle,
            icon: Icons.cleaning_services_outlined,
            onTap: _openAppCache,
          ),
          SizedBox(height: 10),
          _SettingsNavTile(
            title: text.yourRestaurantInfo,
            subtitle: text.yourRestaurantInfoSubtitle,
            icon: Icons.business_outlined,
            onTap: _openYourRestaurantInfo,
          ),
          SizedBox(height: 10),
          _SettingsNavTile(
            title: text.aboutUs,
            subtitle: 'Product and company details',
            icon: Icons.info_outline_rounded,
            onTap: _openAboutUs,
          ),
          SizedBox(height: 10),
          _SettingsNavTile(
            title: text.privacyPolicy,
            subtitle: 'How we handle data and privacy',
            icon: Icons.privacy_tip_outlined,
            onTap: _openPrivacyPolicy,
          ),
        ],
      ),
    );
  }

  Future<void> _openDisplaySettings() async {
    final app = AppScope.of(context);
    final text = app.strings;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _SettingsSectionPage(
          title: text.displaySize,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DisplaySizeCard(
                value: _displayScale,
                label: app.uiScaleLabel,
                text: text,
                onChanged: (value) => setState(() => _displayScale = value),
                onChangeEnd: _updateDisplayScale,
                onPreset: (value) {
                  setState(() => _displayScale = value);
                  _updateDisplayScale(value);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openThemeMode() async {
    final app = AppScope.of(context);
    final text = app.strings;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _SettingsSectionPage(
          title: text.themeMode,
          child: Column(
            children: [
              _ThemeModeCard(
                selected: app.themePreference,
                text: text,
                onChanged: app.updateThemePreference,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openLanguageSettings() async {
    final app = AppScope.of(context);
    final text = app.strings;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _SettingsSectionPage(
          title: text.languageLabel,
          child: _LanguageCard(
            selected: app.language,
            text: text,
            onChanged: app.updateLanguage,
          ),
        ),
      ),
    );
  }

  Future<void> _openRestaurantInfo() async {
    final text = AppScope.of(context).strings;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _SettingsSectionPage(
          title: text.restaurantSection,
          child: Form(
            key: _formKey,
            child: _SectionCard(
              title: text.restaurantSection,
              subtitle: text.restaurantSubtitle,
              icon: Icons.storefront_outlined,
              children: [
                _ResponsiveFields(
                  children: [
                    TextFormField(
                      controller: _restaurantController,
                      decoration: InputDecoration(
                        labelText: text.restaurantName,
                        prefixIcon: Icon(Icons.restaurant_outlined),
                      ),
                      validator: _required,
                    ),
                    TextFormField(
                      controller: _outletController,
                      decoration: InputDecoration(
                        labelText: text.outletName,
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      validator: _required,
                    ),
                  ],
                ),
                SizedBox(height: 10),
                _ResponsiveFields(
                  children: [
                    TextFormField(
                      controller: _restaurantIdController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: text.restaurantId,
                        prefixIcon: Icon(Icons.badge_outlined),
                        helperText: text.restaurantIdHelper,
                      ),
                      validator: _required,
                    ),
                    TextFormField(
                      controller: _outletIdController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: text.outletId,
                        prefixIcon: Icon(Icons.pin_drop_outlined),
                        helperText: text.outletIdHelper,
                      ),
                      validator: _required,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openCloudSync() async {
    final app = AppScope.of(context);
    final text = app.strings;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _SettingsSectionPage(
          title: text.cloudSync,
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: SwitchListTile.adaptive(
                      value: _cloudSyncEnabled,
                      onChanged: (value) {
                        setState(() => _cloudSyncEnabled = value);
                        _scheduleAutoSave();
                      },
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      contentPadding: EdgeInsets.zero,
                      title: Text(text.enableCloudSync),
                    ),
                  ),
                ),
                SizedBox(height: 10),
                _SectionCard(
                  title: 'Sync Status',
                  subtitle: 'Queue, retry, logs, and cloud health in one place.',
                  icon: Icons.cloud_sync_outlined,
                  children: [
                    _InlineSyncStatus(app: app),
                    SizedBox(height: 10),
                    Text(
                      'Auto Sync Interval',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    SizedBox(height: 6),
                    TextFormField(
                      controller: _syncIntervalController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        hintText: text.seconds,
                        prefixIcon: Icon(Icons.timer_outlined),
                        floatingLabelBehavior: FloatingLabelBehavior.never,
                      ),
                      validator: (value) {
                        final seconds = int.tryParse(value ?? '');
                        if (seconds == null || seconds < 10) {
                          return text.minTenSeconds;
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Override Cloud API URL',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    SizedBox(height: 6),
                    TextFormField(
                      controller: _cloudUrlController,
                      decoration: InputDecoration(
                        hintText:
                            'https://project-ref.supabase.co/functions/v1/pos-api',
                        prefixIcon: Icon(Icons.link),
                        floatingLabelBehavior: FloatingLabelBehavior.never,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'No Manual API Key',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    SizedBox(height: 6),
                    _CloudSecretsNotice(
                      hasDeviceToken: app.cloudConfig.hasDeviceToken,
                    ),
                    if (!CloudDefaults.hasConfiguredBaseUrl) ...[
                      SizedBox(height: 10),
                      _CloudSecretsNotice(
                        warning: true,
                        title: text.supabaseUrlMissing,
                        message: text.supabaseUrlMissingMessage,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openReceiptPrinter() async {
    final app = AppScope.of(context);
    final text = app.strings;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _SettingsSectionPage(
          title: text.receiptPrinter,
          child: _PrinterSettingsCard(
            text: text,
            state: app.printerState,
            devices: app.pairedPrinters,
            onAutoPrintChanged: app.setAutoPrintOrders,
            onRefresh: _refreshPrinters,
            onConnect: _connectPrinter,
            onDisconnect: _disconnectPrinter,
            onTestPrint: _testPrinter,
          ),
        ),
      ),
    );
  }

  Future<void> _openAppCache() async {
    final text = AppScope.of(context).strings;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _SettingsSectionPage(
          title: text.appCache,
          child: _DangerCard(text: text, onClear: _confirmClearData),
        ),
      ),
    );
  }

  Future<void> _openYourRestaurantInfo() async {
    final app = AppScope.of(context);
    final text = app.strings;
    _infoTitleController.text = app.serverConfig.restaurantName;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _SettingsSectionPage(
          title: text.yourRestaurantInfo,
          child: Form(
            key: _restaurantInfoFormKey,
            child: _SectionCard(
              title: text.yourRestaurantInfo,
              subtitle: text.yourRestaurantInfoSubtitle,
              icon: Icons.business_outlined,
              children: [
                TextFormField(
                  controller: _infoTitleController,
                  decoration: InputDecoration(
                    labelText: text.restaurantName,
                    prefixIcon: Icon(Icons.store_mall_directory_outlined),
                  ),
                  validator: _required,
                ),
                SizedBox(height: 10),
                _ResponsiveFields(
                  children: [
                    TextFormField(
                      controller: _infoPhoneController,
                      decoration: InputDecoration(
                        labelText: text.contactPhone,
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    TextFormField(
                      controller: _infoEmailController,
                      decoration: InputDecoration(
                        labelText: text.contactEmail,
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                TextFormField(
                  controller: _infoAddressController,
                  decoration: InputDecoration(
                    labelText: text.contactAddress,
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                SizedBox(height: 10),
                TextFormField(
                  controller: _infoWebsiteController,
                  decoration: InputDecoration(
                    labelText: text.website,
                    prefixIcon: Icon(Icons.language_outlined),
                  ),
                ),
                SizedBox(height: 10),
                TextFormField(
                  controller: _infoDescriptionController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: text.description,
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _pushRestaurantInfo,
                    icon: Icon(Icons.cloud_upload_outlined),
                    label: Text(text.pushToCloud),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openAboutUs() async {
    final text = AppScope.of(context).strings;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _SettingsSectionPage(
          title: text.aboutUs,
          child: _SectionCard(
            title: text.aboutUs,
            subtitle: 'Terabyte AI Premium POS',
            icon: Icons.info_outline_rounded,
            children: [
              Text(
                'Hybrid POS Admin is built for modern restaurants that need both offline speed and cloud visibility. '
                'This app gives teams one reliable control center for menu, orders, reporting, and day-to-day operations.',
              ),
              SizedBox(height: 10),
              Text(
                'Product: Terabyte AI\nEmail: support@terabyteai.example\nWebsite: www.terabyteai.example',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPrivacyPolicy() async {
    final text = AppScope.of(context).strings;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _SettingsSectionPage(
          title: text.privacyPolicy,
          child: _SectionCard(
            title: text.privacyPolicy,
            subtitle: 'Data handling and protection',
            icon: Icons.privacy_tip_outlined,
            children: [
              Text(
                '1. Operational data is stored locally on the admin device so service remains available even without internet.',
              ),
              SizedBox(height: 8),
              Text(
                '2. When cloud sync is enabled, menu/order updates are sent to the configured backend using secure tokens.',
              ),
              SizedBox(height: 8),
              Text(
                '3. Sensitive secrets must stay in backend services. Do not store merchant keys directly in client apps.',
              ),
              SizedBox(height: 8),
              Text(
                '4. Restaurant owners are responsible for legal compliance on customer data retention and notices.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _scheduleAutoSave() {
    if (!_hydrated) return;
    _autoSaveDebounce?.cancel();
    _autoSaveDebounce = Timer(Duration(milliseconds: 450), _saveSilently);
  }

  Future<void> _saveSilently() async {
    if (!mounted) return;
    if (!_isValidAutoSavePayload()) return;
    final app = AppScope.of(context);
    await app.saveSettings(
      restaurantName: _restaurantController.text,
      outletName: _outletController.text,
      cloudApiUrl: _cloudUrlController.text,
      restaurantId: _restaurantIdController.text,
      outletId: _outletIdController.text,
      cloudSyncEnabled: _cloudSyncEnabled,
      autoSyncIntervalSeconds: int.parse(_syncIntervalController.text),
    );
  }

  Future<void> _pushRestaurantInfo() async {
    if (!_restaurantInfoFormKey.currentState!.validate()) return;
    final app = AppScope.of(context);
    final text = app.strings;
    final ok = await app.pushRestaurantInfo(
      title: _infoTitleController.text,
      phone: _infoPhoneController.text,
      email: _infoEmailController.text,
      address: _infoAddressController.text,
      website: _infoWebsiteController.text,
      description: _infoDescriptionController.text,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? text.detailsPushed : (app.lastError ?? text.saveFailed),
        ),
      ),
    );
  }

  bool _isValidAutoSavePayload() {
    if (_restaurantController.text.trim().isEmpty) return false;
    if (_outletController.text.trim().isEmpty) return false;
    final seconds = int.tryParse(_syncIntervalController.text.trim());
    if (seconds == null || seconds < 10) return false;
    return true;
  }

  Future<void> _updateDisplayScale(double value) async {
    final app = AppScope.of(context);
    await app.updateUiScale(value);
  }

  Future<void> _refreshPrinters() async {
    final app = AppScope.of(context);
    final text = app.strings;
    final printers = await app.refreshPairedPrinters();
    if (!mounted) return;
    final error = app.printerState.lastError;
    final message =
        error ??
        (printers.isEmpty
            ? text.noPairedPrintersFound
            : text.pairedPrinterFound(printers.length));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _connectPrinter(BluetoothPrinterDevice printer) async {
    final app = AppScope.of(context);
    final text = app.strings;
    final ok = await app.connectPrinter(printer);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? text.connectedTo(printer.label)
              : app.printerState.lastError ?? text.printerConnectionFailed,
        ),
      ),
    );
  }

  Future<void> _disconnectPrinter() async {
    final app = AppScope.of(context);
    final text = app.strings;
    final ok = await app.disconnectPrinter();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? text.printerDisconnected : text.disconnectFailed),
      ),
    );
  }

  Future<void> _testPrinter() async {
    final app = AppScope.of(context);
    final text = app.strings;
    final ok = await app.testPrinter();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? text.testTicketSent
              : app.printerState.lastError ?? text.testFailed,
        ),
      ),
    );
  }

  Future<void> _confirmClearData() async {
    final app = AppScope.of(context);
    final text = app.strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(text.clearCachedData),
        content: Text(text.clearCachedDataMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(text.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(text.clearData),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await app.clearLocalData();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text.cachedDataCleared)));
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppScope.of(context).strings.requiredField;
    }
    return null;
  }
}

class _InlineSyncStatus extends StatelessWidget {
  const _InlineSyncStatus({required this.app});

  final PosAppController app;

  @override
  Widget build(BuildContext context) {
    final sync = app.syncState;
    final lastSync = sync.lastSyncAt == null
        ? 'Never'
        : DateFormat('MMM d, h:mm a').format(sync.lastSyncAt!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InlineSyncSummary(
          pending: sync.pendingCount,
          failed: sync.failedCount,
          lastSync: lastSync,
          cloudEnabled: app.cloudConfig.enabled,
        ),
        SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: PrimaryButton(
                label: 'Sync Now',
                icon: Icons.sync,
                busy: sync.isSyncing,
                onPressed: app.busy
                    ? null
                    : () async {
                        final ok = await app.syncNow();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok ? 'Sync completed' : 'Sync failed',
                            ),
                          ),
                        );
                      },
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: PrimaryButton(
                label: 'Retry Failed',
                icon: Icons.restart_alt,
                secondary: true,
                onPressed: app.busy
                    ? null
                    : () async {
                        final ok = await app.retryFailedSync();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok ? 'Retry queued' : 'Retry failed',
                            ),
                          ),
                        );
                      },
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: PrimaryButton(
                label: 'Test Cloud',
                icon: Icons.health_and_safety_outlined,
                secondary: true,
                onPressed: app.busy
                    ? null
                    : () async {
                        final ok = await app.testCloud();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok ? 'Cloud API reachable' : 'Cloud API failed',
                            ),
                          ),
                        );
                      },
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        Text(
          'Sync Events',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        SizedBox(height: 6),
        if (sync.logs.isNotEmpty) ...[
          _InlineSyncLogs(logs: sync.logs),
          SizedBox(height: 8),
        ],
        if (app.syncEvents.isEmpty && sync.logs.isEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: PosColors.surface,
              borderRadius: BorderRadius.circular(PosRadii.md),
              border: Border.all(color: PosColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.cloud_sync_outlined,
                      size: 16,
                      color: PosColors.primary,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'No sync events',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Queued local changes will appear here before cloud push.',
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          Column(
            children: app.syncEvents
                .take(20)
                .map((event) => SyncEventTile(event: event))
                .toList(growable: false),
          ),
      ],
    );
  }
}

class _InlineSyncSummary extends StatelessWidget {
  const _InlineSyncSummary({
    required this.pending,
    required this.failed,
    required this.lastSync,
    required this.cloudEnabled,
  });

  final int pending;
  final int failed;
  final String lastSync;
  final bool cloudEnabled;

  @override
  Widget build(BuildContext context) {
    final topValues = [
      _InlineSyncValue('Pending', pending.toString(), Icons.sync),
      _InlineSyncValue('Failed', failed.toString(), Icons.error_outline),
      _InlineSyncValue('Cloud', '', Icons.cloud_outlined),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(flex: 3, child: _InlineSyncChip(value: topValues[0])),
            SizedBox(width: 6),
            Expanded(flex: 3, child: _InlineSyncChip(value: topValues[1])),
            SizedBox(width: 6),
            Expanded(flex: 5, child: _CloudSyncChip(enabled: cloudEnabled)),
          ],
        ),
        SizedBox(height: 6),
        _InlineSyncChip(
          value: _InlineSyncValue('Last sync', lastSync, Icons.history),
          fullWidth: true,
        ),
      ],
    );
  }
}

class _InlineSyncChip extends StatelessWidget {
  const _InlineSyncChip({required this.value, this.fullWidth = false});

  final _InlineSyncValue value;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final isLastSync = fullWidth && value.label.toLowerCase() == 'last sync';
    final parts = isLastSync ? value.value.split(',') : const <String>[];
    final hasDateTimeSplit = parts.length >= 2;
    final dateText = hasDateTimeSplit ? parts.first.trim() : value.value;
    final timeText = hasDateTimeSplit
        ? parts.sublist(1).join(',').trim()
        : value.value;

    final isPending = value.label.toLowerCase() == 'pending';
    final chip = Container(
      padding: EdgeInsets.fromLTRB(isPending ? 1 : 6, 9, 8, 9),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.sm),
        border: Border.all(color: PosColors.line),
      ),
      child: isLastSync
          ? Row(
              children: [
                Icon(value.icon, color: PosColors.primary, size: 13),
                SizedBox(width: 5),
                Text(
                  value.label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                        color: PosColors.slate.withValues(alpha: 0.28),
                        offset: Offset(0, 0),
                        blurRadius: 0.2,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 5),
                Expanded(
                  child: Text(
                    dateText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 12.2,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                          color: PosColors.slate.withValues(alpha: 0.28),
                          offset: Offset(0, 0),
                          blurRadius: 0.2,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  timeText,
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12.2,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                        color: PosColors.slate.withValues(alpha: 0.28),
                        offset: Offset(0, 0),
                        blurRadius: 0.2,
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Icon(value.icon, color: PosColors.primary, size: 13),
                SizedBox(width: 5),
                Text(
                  value.label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                        color: PosColors.slate.withValues(alpha: 0.28),
                        offset: Offset(0, 0),
                        blurRadius: 0.2,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 4),
                Flexible(
                  child: Text(
                    value.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 12.2,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                          color: PosColors.slate.withValues(alpha: 0.28),
                          offset: Offset(0, 0),
                          blurRadius: 0.2,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
    if (!fullWidth) return chip;
    return SizedBox(width: double.infinity, child: chip);
  }
}

class _CloudSyncChip extends StatelessWidget {
  const _CloudSyncChip({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.sm),
        border: Border.all(color: PosColors.line),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          Icon(Icons.cloud_outlined, color: PosColors.primary, size: 13),
          SizedBox(width: 5),
          Text(
            'Cloud',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                  color: PosColors.slate.withValues(alpha: 0.28),
                  offset: Offset(0, 0),
                  blurRadius: 0.2,
                ),
              ],
            ),
          ),
          SizedBox(width: 6),
          Text(
            enabled ? 'Enabled' : 'Disabled',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: enabled ? PosColors.success : PosColors.danger,
              shadows: [
                Shadow(
                  color: PosColors.slate.withValues(alpha: 0.22),
                  offset: Offset(0, 0),
                  blurRadius: 0.2,
                ),
              ],
            ),
          ),
          SizedBox(width: 4),
          Icon(
            enabled ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 12,
            color: enabled ? PosColors.success : PosColors.danger,
          ),
        ],
      ),
    );
  }
}

class _InlineSyncLogs extends StatelessWidget {
  const _InlineSyncLogs({required this.logs});

  final List<SyncLogEntry> logs;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return Text(
        'No sync logs yet.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    final recent = logs.take(6).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: recent
          .map(
            (entry) => Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                '${DateFormat('HH:mm').format(entry.createdAt)}  ${entry.message}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _InlineSyncValue {
  _InlineSyncValue(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}

class _SettingsNavTile extends StatelessWidget {
  const _SettingsNavTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(PosRadii.lg),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: PosGradients.cardTint(PosColors.primary),
                  borderRadius: BorderRadius.circular(PosRadii.sm),
                  border: Border.all(color: PosColors.line),
                ),
                child: Icon(icon, color: PosColors.primary, size: 18),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: PosColors.muted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSectionPage extends StatelessWidget {
  const _SettingsSectionPage({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: title,
      showDatePill: false,
      showBackButton: true,
      child: child,
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: PosGradients.cardTint(PosColors.primary),
                    borderRadius: BorderRadius.circular(PosRadii.md),
                    border: Border.all(
                      color: PosColors.primary.withValues(alpha: 0.20),
                    ),
                  ),
                  child: Icon(icon, color: PosColors.primary, size: 19),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (subtitle != null) ...[
                        SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DisplaySizeCard extends StatelessWidget {
  const _DisplaySizeCard({
    required this.value,
    required this.label,
    required this.text,
    required this.onChanged,
    required this.onChangeEnd,
    required this.onPreset,
  });

  final double value;
  final String label;
  final AppStrings text;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final ValueChanged<double> onPreset;

  @override
  Widget build(BuildContext context) {
    final percent = (value * 100).round();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: PosGradients.cardTint(PosColors.primary),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: PosGradients.brand,
                        borderRadius: BorderRadius.circular(PosRadii.md),
                        boxShadow: PosShadows.glow,
                      ),
                      child: Icon(
                        Icons.text_fields_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            text.displaySize,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          SizedBox(height: 3),
                          Text(
                            text.displaySizeSubtitle,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    _ScalePill(label: label, percent: percent),
                  ],
                ),
                SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PresetChip(
                      label: text.compact,
                      selected: value <= 0.88,
                      onTap: () => onPreset(0.84),
                    ),
                    _PresetChip(
                      label: text.comfortable,
                      selected: value > 0.88 && value < 0.98,
                      onTap: () => onPreset(0.92),
                    ),
                    _PresetChip(
                      label: text.large,
                      selected: value >= 0.98,
                      onTap: () => onPreset(1.02),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.remove_rounded,
                      color: PosColors.muted,
                      size: 18,
                    ),
                    Expanded(
                      child: Slider(
                        value: value,
                        min: PosAppController.minUiScale,
                        max: PosAppController.maxUiScale,
                        divisions: 15,
                        label: '$percent%',
                        onChanged: onChanged,
                        onChangeEnd: onChangeEnd,
                      ),
                    ),
                    Icon(Icons.add_rounded, color: PosColors.muted, size: 18),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.selected,
    required this.text,
    required this.onChanged,
  });

  final AppLanguage selected;
  final AppStrings text;
  final ValueChanged<AppLanguage> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: text.languageLabel,
      subtitle: text.languageSubtitle,
      icon: Icons.translate_rounded,
      children: [
        SegmentedButton<AppLanguage>(
          segments: [
            ButtonSegment<AppLanguage>(
              value: AppLanguage.bn,
              label: Text(text.bangla),
              icon: Text('অ'),
            ),
            ButtonSegment<AppLanguage>(
              value: AppLanguage.en,
              label: Text(text.english),
              icon: Text('A'),
            ),
          ],
          selected: {selected},
          showSelectedIcon: true,
          onSelectionChanged: (values) => onChanged(values.first),
        ),
      ],
    );
  }
}

class _ThemeModeCard extends StatelessWidget {
  const _ThemeModeCard({
    required this.selected,
    required this.text,
    required this.onChanged,
  });

  final AppThemePreference selected;
  final AppStrings text;
  final ValueChanged<AppThemePreference> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: text.themeMode,
      subtitle: text.themeModeSubtitle,
      icon: Icons.palette_outlined,
      children: [
        SegmentedButton<AppThemePreference>(
          segments: [
            ButtonSegment<AppThemePreference>(
              value: AppThemePreference.black,
              label: Text(text.blackMode),
              icon: Icon(Icons.dark_mode_outlined),
            ),
            ButtonSegment<AppThemePreference>(
              value: AppThemePreference.white,
              label: Text(text.whiteMode),
              icon: Icon(Icons.light_mode_outlined),
            ),
            ButtonSegment<AppThemePreference>(
              value: AppThemePreference.device,
              label: Text(text.deviceMode),
              icon: Icon(Icons.smartphone_outlined),
            ),
          ],
          selected: {selected},
          showSelectedIcon: true,
          onSelectionChanged: (values) => onChanged(values.first),
        ),
      ],
    );
  }
}

class _ScalePill extends StatelessWidget {
  const _ScalePill({required this.label, required this.percent});

  final String label;
  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.pill),
        border: Border.all(color: PosColors.line),
      ),
      child: Text(
        '$label - $percent%',
        style: TextStyle(
          color: PosColors.primary,
          fontWeight: FontWeight.w900,
          fontSize: 11.4,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: selected
          ? Icon(Icons.check_rounded, size: 16, color: PosColors.primary)
          : null,
      labelStyle: TextStyle(
        color: selected ? PosColors.primary : PosColors.slate,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _ResponsiveFields extends StatelessWidget {
  const _ResponsiveFields({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          return Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: 10),
                children[i],
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(width: 12),
              Expanded(child: children[i]),
            ],
          ],
        );
      },
    );
  }
}

class _CloudSecretsNotice extends StatelessWidget {
  const _CloudSecretsNotice({
    this.hasDeviceToken = false,
    this.warning = false,
    this.title,
    this.message,
  });

  final bool hasDeviceToken;
  final bool warning;
  final String? title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final color = warning ? PosColors.warning : PosColors.success;
    final text = AppScope.of(context).strings;
    final resolvedTitle = title ?? text.noManualApiKey;
    final resolvedMessage = message ?? text.noManualApiKeyMessage;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            warning ? Icons.info_outline : Icons.verified_user_outlined,
            color: color,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resolvedTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: 3),
                Text(
                  hasDeviceToken ? text.deviceAuthorized : resolvedMessage,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrinterSettingsCard extends StatelessWidget {
  const _PrinterSettingsCard({
    required this.text,
    required this.state,
    required this.devices,
    required this.onAutoPrintChanged,
    required this.onRefresh,
    required this.onConnect,
    required this.onDisconnect,
    required this.onTestPrint,
  });

  final AppStrings text;
  final PrinterRuntimeState state;
  final List<BluetoothPrinterDevice> devices;
  final ValueChanged<bool> onAutoPrintChanged;
  final Future<void> Function() onRefresh;
  final Future<void> Function(BluetoothPrinterDevice printer) onConnect;
  final Future<void> Function() onDisconnect;
  final Future<void> Function() onTestPrint;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: text.receiptPrinter,
      subtitle: text.receiptPrinterSubtitle,
      icon: Icons.print_outlined,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: state.connected
                ? PosColors.success.withValues(alpha: 0.09)
                : PosColors.mutedSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: state.connected
                  ? PosColors.success.withValues(alpha: 0.24)
                  : PosColors.line,
            ),
          ),
          child: Row(
            children: [
              Icon(
                state.connected
                    ? Icons.print_rounded
                    : Icons.print_disabled_outlined,
                color: state.connected ? PosColors.success : PosColors.muted,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.hasSelectedPrinter
                          ? state.selectedPrinterLabel
                          : text.noPrinterSelected,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: 2),
                    Text(
                      state.connected
                          ? text.printerConnectedAuto
                          : text.pairPrinterInstruction,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        SwitchListTile.adaptive(
          value: state.autoPrintEnabled,
          onChanged: state.busy ? null : onAutoPrintChanged,
          contentPadding: EdgeInsets.zero,
          title: Text(text.autoPrintNewOrders),
          subtitle: Text(text.autoPrintNewOrdersSubtitle),
        ),
        if (state.lastError != null) ...[
          SizedBox(height: 8),
          _PrinterErrorBanner(message: state.lastError!),
        ],
        SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: state.busy ? null : onRefresh,
              icon: Icon(Icons.bluetooth_searching_rounded),
              label: Text(text.refreshPairedPrinters),
            ),
            OutlinedButton.icon(
              onPressed: state.busy || !state.hasSelectedPrinter
                  ? null
                  : onTestPrint,
              icon: Icon(Icons.receipt_long_outlined),
              label: Text(text.testPrint),
            ),
            if (state.connected)
              OutlinedButton.icon(
                onPressed: state.busy ? null : onDisconnect,
                icon: Icon(Icons.link_off_rounded),
                label: Text(text.disconnect),
              ),
          ],
        ),
        if (devices.isNotEmpty) ...[
          SizedBox(height: 12),
          ...devices.map(
            (printer) => _PrinterDeviceTile(
              printer: printer,
              selected: printer.address == state.selectedPrinterAddress,
              busy: state.busy,
              text: text,
              onConnect: () => onConnect(printer),
            ),
          ),
        ],
      ],
    );
  }
}

class _PrinterDeviceTile extends StatelessWidget {
  const _PrinterDeviceTile({
    required this.printer,
    required this.selected,
    required this.busy,
    required this.text,
    required this.onConnect,
  });

  final BluetoothPrinterDevice printer;
  final bool selected;
  final bool busy;
  final AppStrings text;
  final Future<void> Function() onConnect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected
            ? PosColors.primary.withValues(alpha: 0.08)
            : PosColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? PosColors.primary.withValues(alpha: 0.24)
              : PosColors.line,
        ),
      ),
      child: Row(
        children: [
          Icon(
            selected ? Icons.check_circle_rounded : Icons.bluetooth_rounded,
            color: selected ? PosColors.primary : PosColors.muted,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  printer.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: 2),
                Text(
                  printer.address,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: busy ? null : onConnect,
            child: Text(selected ? text.reconnect : text.connect),
          ),
        ],
      ),
    );
  }
}

class _PrinterErrorBanner extends StatelessWidget {
  const _PrinterErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PosColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PosColors.danger.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: PosColors.danger),
          SizedBox(width: 10),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _DangerCard extends StatelessWidget {
  const _DangerCard({required this.text, required this.onClear});

  final AppStrings text;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.warning_amber_outlined, color: PosColors.danger),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text.appCache,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SizedBox(height: 4),
                  Text(
                    text.clearCacheSubtitle,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: Icon(Icons.delete_outline),
              label: Text(text.clearCache),
            ),
          ],
        ),
      ),
    );
  }
}
