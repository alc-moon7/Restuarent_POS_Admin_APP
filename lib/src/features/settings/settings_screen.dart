import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../core/constants/cloud_defaults.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/primary_button.dart';

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
            _SectionCard(
              title: 'Restaurant',
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
                      decoration: const InputDecoration(
                        labelText: 'Restaurant ID',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: _required,
                    ),
                    TextFormField(
                      controller: _outletIdController,
                      decoration: const InputDecoration(
                        labelText: 'Outlet ID',
                        prefixIcon: Icon(Icons.pin_drop_outlined),
                      ),
                      validator: _required,
                    ),
                  ],
                ),
              ],
            ),
            _SectionCard(
              title: 'Cloud Sync',
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
                const _CloudSecretsNotice(),
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

  Future<void> _confirmClearData() async {
    final app = AppScope.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear cached data?'),
        content: const Text(
          'Orders, menu items, and sync events will be cleared, then sample menu items will be seeded again.',
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
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: PosColors.primary),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
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
    this.warning = false,
    this.title = 'No manual API key required',
    this.message =
        'Supabase secrets stay inside the Edge Function. This app only stores the public function URL.',
  });

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
                Text(message, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
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
