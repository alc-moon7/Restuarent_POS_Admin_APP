import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_controller.dart';
import '../../app_scope.dart';
import '../../core/constants/cloud_defaults.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/primary_button.dart';
import '../../services/printer_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _restaurantController = TextEditingController();
  final TextEditingController _outletController = TextEditingController();
  final TextEditingController _cloudUrlController = TextEditingController();
  final TextEditingController _restaurantIdController = TextEditingController();
  final TextEditingController _outletIdController = TextEditingController();
  final TextEditingController _syncIntervalController = TextEditingController();
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
    _hydrated = true;
  }

  @override
  void dispose() {
    _restaurantController.dispose();
    _outletController.dispose();
    _cloudUrlController.dispose();
    _restaurantIdController.dispose();
    _outletIdController.dispose();
    _syncIntervalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return AppScaffold(
      title: 'Settings',
      subtitle: 'Restaurant profile, cloud identity, and sync settings.',
      actions: [
        PrimaryButton(
          label: 'Save',
          icon: Icons.save_outlined,
          busy: app.busy,
          onPressed: _save,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DisplaySizeCard(
              value: _displayScale,
              label: app.uiScaleLabel,
              onChanged: (value) => setState(() => _displayScale = value),
              onChangeEnd: _updateDisplayScale,
              onPreset: (value) {
                setState(() => _displayScale = value);
                _updateDisplayScale(value);
              },
            ),
            _SectionCard(
              title: 'Restaurant',
              subtitle: 'Public identity for this outlet.',
              icon: Icons.storefront_outlined,
              children: [
                _ResponsiveFields(
                  children: [
                    TextFormField(
                      controller: _restaurantController,
                      decoration: const InputDecoration(
                        labelText: 'Restaurant name',
                        prefixIcon: Icon(Icons.restaurant_outlined),
                      ),
                      validator: _required,
                    ),
                    TextFormField(
                      controller: _outletController,
                      decoration: const InputDecoration(
                        labelText: 'Outlet name',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      validator: _required,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _ResponsiveFields(
                  children: [
                    TextFormField(
                      controller: _restaurantIdController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Restaurant ID',
                        prefixIcon: Icon(Icons.badge_outlined),
                        helperText: 'Created automatically by the cloud.',
                      ),
                      validator: _required,
                    ),
                    TextFormField(
                      controller: _outletIdController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Outlet ID',
                        prefixIcon: Icon(Icons.pin_drop_outlined),
                        helperText: 'Share this ID with the customer web app.',
                      ),
                      validator: _required,
                    ),
                  ],
                ),
              ],
            ),
            _SectionCard(
              title: 'Cloud Sync',
              subtitle: 'Cloud connection stays automatic for staff.',
              icon: Icons.cloud_sync_outlined,
              children: [
                TextFormField(
                  controller: _cloudUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Cloud API URL override',
                    hintText:
                        'https://project-ref.supabase.co/functions/v1/pos-api',
                    prefixIcon: Icon(Icons.link),
                    helperText:
                        'Leave as default after the Supabase URL is built into the APK.',
                  ),
                ),
                const SizedBox(height: 10),
                _CloudSecretsNotice(
                  hasDeviceToken: app.cloudConfig.hasDeviceToken,
                ),
                if (!CloudDefaults.hasConfiguredBaseUrl) ...[
                  const SizedBox(height: 10),
                  const _CloudSecretsNotice(
                    warning: true,
                    title: 'Supabase URL not built in yet',
                    message:
                        'Build the APK with POS_CLOUD_API_URL so admins do not need to edit this field.',
                  ),
                ],
                const SizedBox(height: 10),
                TextFormField(
                  controller: _syncIntervalController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Auto sync interval',
                    hintText: 'Seconds',
                    prefixIcon: Icon(Icons.timer_outlined),
                  ),
                  validator: (value) {
                    final seconds = int.tryParse(value ?? '');
                    if (seconds == null || seconds < 10) {
                      return 'Use at least 10 seconds';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  value: _cloudSyncEnabled,
                  onChanged: (value) =>
                      setState(() => _cloudSyncEnabled = value),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable cloud sync'),
                  subtitle: const Text(
                    'Changes queue safely when the cloud is temporarily unavailable.',
                  ),
                ),
              ],
            ),
            _PrinterSettingsCard(
              state: app.printerState,
              devices: app.pairedPrinters,
              onAutoPrintChanged: app.setAutoPrintOrders,
              onRefresh: _refreshPrinters,
              onConnect: _connectPrinter,
              onDisconnect: _disconnectPrinter,
              onTestPrint: _testPrinter,
            ),
            const SizedBox(height: 12),
            _DangerCard(onClear: _confirmClearData),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final app = AppScope.of(context);
    final ok = await app.saveSettings(
      restaurantName: _restaurantController.text,
      outletName: _outletController.text,
      cloudApiUrl: _cloudUrlController.text,
      restaurantId: _restaurantIdController.text,
      outletId: _outletIdController.text,
      cloudSyncEnabled: _cloudSyncEnabled,
      autoSyncIntervalSeconds: int.parse(_syncIntervalController.text),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Settings saved' : app.lastError ?? 'Save failed'),
      ),
    );
  }

  Future<void> _updateDisplayScale(double value) async {
    final app = AppScope.of(context);
    await app.updateUiScale(value);
  }

  Future<void> _refreshPrinters() async {
    final app = AppScope.of(context);
    final printers = await app.refreshPairedPrinters();
    if (!mounted) return;
    final error = app.printerState.lastError;
    final message =
        error ??
        (printers.isEmpty
            ? 'No paired Bluetooth printers found'
            : '${printers.length} paired printer found');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _connectPrinter(BluetoothPrinterDevice printer) async {
    final app = AppScope.of(context);
    final ok = await app.connectPrinter(printer);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Connected to ${printer.label}'
              : app.printerState.lastError ?? 'Printer connection failed',
        ),
      ),
    );
  }

  Future<void> _disconnectPrinter() async {
    final app = AppScope.of(context);
    final ok = await app.disconnectPrinter();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Printer disconnected' : 'Disconnect failed'),
      ),
    );
  }

  Future<void> _testPrinter() async {
    final app = AppScope.of(context);
    final ok = await app.testPrinter();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Test ticket sent' : app.printerState.lastError ?? 'Test failed',
        ),
      ),
    );
  }

  Future<void> _confirmClearData() async {
    final app = AppScope.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear cached data?'),
        content: const Text(
          'Orders, menu items, and sync events will be cleared from this device. No demo menu will be added again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear Data'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await app.clearLocalData();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Cached data cleared')));
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
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
            const SizedBox(height: 14),
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
    required this.onChanged,
    required this.onChangeEnd,
    required this.onPreset,
  });

  final double value;
  final String label;
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
            padding: const EdgeInsets.all(16),
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
                      child: const Icon(
                        Icons.text_fields_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Display Size',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Adjust the whole app for compact counters, tablets, or large text comfort.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    _ScalePill(label: label, percent: percent),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PresetChip(
                      label: 'Compact',
                      selected: value <= 0.94,
                      onTap: () => onPreset(0.90),
                    ),
                    _PresetChip(
                      label: 'Comfortable',
                      selected: value > 0.94 && value < 1.08,
                      onTap: () => onPreset(1.0),
                    ),
                    _PresetChip(
                      label: 'Large',
                      selected: value >= 1.08,
                      onTap: () => onPreset(1.12),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
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
                    const Icon(
                      Icons.add_rounded,
                      color: PosColors.muted,
                      size: 18,
                    ),
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

class _ScalePill extends StatelessWidget {
  const _ScalePill({required this.label, required this.percent});

  final String label;
  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.pill),
        border: Border.all(color: PosColors.line),
      ),
      child: Text(
        '$label - $percent%',
        style: const TextStyle(
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
          ? const Icon(Icons.check_rounded, size: 16, color: PosColors.primary)
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
                if (i > 0) const SizedBox(height: 10),
                children[i],
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
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
    this.title = 'No manual API key required',
    this.message =
        'Supabase secrets stay inside the Edge Function. This app stores only its private restaurant device token.',
  });

  final bool hasDeviceToken;
  final bool warning;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final color = warning ? PosColors.warning : PosColors.success;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
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
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(
                  hasDeviceToken
                      ? 'This device is authorized for the current restaurant/outlet. The token is hidden and managed automatically.'
                      : message,
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
    required this.state,
    required this.devices,
    required this.onAutoPrintChanged,
    required this.onRefresh,
    required this.onConnect,
    required this.onDisconnect,
    required this.onTestPrint,
  });

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
      title: 'Receipt Printer',
      subtitle: 'Deli ES421 Bluetooth ticket printing for new orders.',
      icon: Icons.print_outlined,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
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
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.selectedPrinterLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      state.connected
                          ? 'Connected. New orders will print automatically.'
                          : 'Pair the ES421 in Android Bluetooth settings, then connect here.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile.adaptive(
          value: state.autoPrintEnabled,
          onChanged: state.busy ? null : onAutoPrintChanged,
          contentPadding: EdgeInsets.zero,
          title: const Text('Auto print new orders'),
          subtitle: const Text(
            'When a cloud/manual order reaches this admin device, the kitchen ticket prints automatically.',
          ),
        ),
        if (state.lastError != null) ...[
          const SizedBox(height: 8),
          _PrinterErrorBanner(message: state.lastError!),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: state.busy ? null : onRefresh,
              icon: const Icon(Icons.bluetooth_searching_rounded),
              label: const Text('Refresh paired printers'),
            ),
            OutlinedButton.icon(
              onPressed: state.busy || !state.hasSelectedPrinter
                  ? null
                  : onTestPrint,
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Test print'),
            ),
            if (state.connected)
              OutlinedButton.icon(
                onPressed: state.busy ? null : onDisconnect,
                icon: const Icon(Icons.link_off_rounded),
                label: const Text('Disconnect'),
              ),
          ],
        ),
        if (devices.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...devices.map(
            (printer) => _PrinterDeviceTile(
              printer: printer,
              selected: printer.address == state.selectedPrinterAddress,
              busy: state.busy,
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
    required this.onConnect,
  });

  final BluetoothPrinterDevice printer;
  final bool selected;
  final bool busy;
  final Future<void> Function() onConnect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
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
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  printer.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  printer.address,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: busy ? null : onConnect,
            child: Text(selected ? 'Reconnect' : 'Connect'),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PosColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PosColors.danger.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: PosColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _DangerCard extends StatelessWidget {
  const _DangerCard({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_outlined, color: PosColors.danger),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App cache',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Clear cached menu, orders, and sync queue from this device.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Clear cache'),
            ),
          ],
        ),
      ),
    );
  }
}
