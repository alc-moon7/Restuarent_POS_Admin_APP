import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app_controller.dart';
import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/status_badge.dart';
import '../../services/local_server_service.dart';

class ServerSetupScreen extends StatefulWidget {
  const ServerSetupScreen({super.key});

  @override
  State<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _ServerSetupScreenState extends State<ServerSetupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _restaurantController = TextEditingController();
  final TextEditingController _outletController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  bool _hydrated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hydrated) return;
    final app = AppScope.of(context);
    _restaurantController.text = app.restaurantName;
    _outletController.text = app.outletName;
    _portController.text = app.serverPort.toString();
    _hydrated = true;
  }

  @override
  void dispose() {
    _restaurantController.dispose();
    _outletController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final state = app.serverState;

    return AppScaffold(
      title: 'Local Server',
      subtitle: 'Host REST and WebSocket APIs on this device over WiFi.',
      actions: [StatusBadge.server(isRunning: state.isRunning)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SetupCard(
            formKey: _formKey,
            restaurantController: _restaurantController,
            outletController: _outletController,
            portController: _portController,
            busy: app.busy,
            onStart: _startServer,
          ),
          const SizedBox(height: 12),
          if (state.localIp == null)
            const _WarningCard(
              message:
                  'No WiFi/local IP was found. The server can run, but customer devices need the correct LAN IP after connecting to the same WiFi.',
            ),
          if (state.localIp == null) const SizedBox(height: 12),
          if (app.lastError != null)
            _WarningCard(message: app.lastError!, isError: true),
          if (app.lastError != null) const SizedBox(height: 12),
          _ServerStatusCard(
            state: state,
            connectedClients: app.connectedClients,
            onStart: _startServer,
            onStop: app.busy ? null : () => _runAction(app.stopServer),
            onRestart: app.busy ? null : () => _runAction(app.restartServer),
            onRefreshIp: app.busy ? null : _runRefreshIp,
            onCopyUrl: state.apiUrl == null
                ? null
                : () async {
                    await Clipboard.setData(
                      ClipboardData(text: '${state.apiUrl}/customer'),
                    );
                    if (!context.mounted) return;
                    _showSnack(context, 'Customer menu URL copied');
                  },
          ),
          const SizedBox(height: 12),
          _CustomerPortalQrCard(state: state),
          const SizedBox(height: 12),
          _HybridStatusCard(app: app),
          const SizedBox(height: 12),
          _EndpointCard(baseUrl: state.apiUrl, wsUrl: state.wsUrl),
          const SizedBox(height: 12),
          _ActivityLogCard(logs: app.apiLogs),
        ],
      ),
    );
  }

  Future<void> _startServer() async {
    if (!_formKey.currentState!.validate()) return;
    final app = AppScope.of(context);
    final ok = await app.startServer(
      restaurantName: _restaurantController.text,
      outletName: _outletController.text,
      port: int.parse(_portController.text),
    );
    if (!mounted) return;
    _showSnack(
      context,
      ok ? 'Server started' : app.lastError ?? 'Server failed',
    );
  }

  Future<void> _runAction(Future<bool> Function() action) async {
    final app = AppScope.of(context);
    final ok = await action();
    if (!mounted) return;
    _showSnack(
      context,
      ok ? 'Server updated' : app.lastError ?? 'Action failed',
    );
  }

  Future<void> _runRefreshIp() async {
    final app = AppScope.of(context);
    await app.refreshIp();
    if (!mounted) return;
    _showSnack(context, 'Local IP refreshed');
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({
    required this.formKey,
    required this.restaurantController,
    required this.outletController,
    required this.portController,
    required this.busy,
    required this.onStart,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController restaurantController;
  final TextEditingController outletController;
  final TextEditingController portController;
  final bool busy;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: PosColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.router_outlined,
                      color: PosColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create Local Restaurant Server',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Connect all devices to the same WiFi. Internet is not required.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 640;
                  final restaurant = TextFormField(
                    controller: restaurantController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Restaurant name',
                      prefixIcon: Icon(Icons.storefront_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Restaurant name is required';
                      }
                      return null;
                    },
                  );
                  final outlet = TextFormField(
                    controller: outletController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Outlet name',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Outlet name is required';
                      }
                      return null;
                    },
                  );
                  final port = TextFormField(
                    controller: portController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      prefixIcon: Icon(Icons.settings_ethernet),
                    ),
                    validator: (value) {
                      final port = int.tryParse(value ?? '');
                      if (port == null || port < 1 || port > 65535) {
                        return 'Use a valid port';
                      }
                      return null;
                    },
                  );
                  if (compact) {
                    return Column(
                      children: [
                        restaurant,
                        const SizedBox(height: 10),
                        outlet,
                        const SizedBox(height: 10),
                        port,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(flex: 2, child: restaurant),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: outlet),
                      const SizedBox(width: 12),
                      Expanded(child: port),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Create & Start Server',
                icon: Icons.play_arrow,
                busy: busy,
                onPressed: onStart,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServerStatusCard extends StatelessWidget {
  const _ServerStatusCard({
    required this.state,
    required this.connectedClients,
    required this.onStart,
    required this.onStop,
    required this.onRestart,
    required this.onRefreshIp,
    required this.onCopyUrl,
  });

  final ServerRuntimeState state;
  final int connectedClients;
  final VoidCallback onStart;
  final VoidCallback? onStop;
  final VoidCallback? onRestart;
  final VoidCallback? onRefreshIp;
  final VoidCallback? onCopyUrl;

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
                Expanded(
                  child: Text(
                    'Server status',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                StatusBadge.server(isRunning: state.isRunning),
              ],
            ),
            const SizedBox(height: 12),
            _InfoGrid(
              values: [
                _InfoValue('Local IP', state.localIp ?? 'Not found'),
                _InfoValue('Port', state.port.toString()),
                _InfoValue('API URL', state.apiUrl ?? 'Unavailable'),
                _InfoValue(
                  'Customer URL',
                  state.apiUrl == null
                      ? 'Unavailable'
                      : '${state.apiUrl}/customer',
                ),
                _InfoValue('WebSocket URL', state.wsUrl ?? 'Unavailable'),
                _InfoValue('Clients', connectedClients.toString()),
                _InfoValue(
                  'Started',
                  state.startedAt == null
                      ? 'Not running'
                      : DateFormat('MMM d, h:mm a').format(state.startedAt!),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                PrimaryButton(
                  label: 'Start Server',
                  icon: Icons.play_arrow,
                  secondary: true,
                  onPressed: state.isRunning ? null : onStart,
                ),
                PrimaryButton(
                  label: 'Stop Server',
                  icon: Icons.stop,
                  secondary: true,
                  onPressed: state.isRunning ? onStop : null,
                ),
                PrimaryButton(
                  label: 'Restart Server',
                  icon: Icons.restart_alt,
                  secondary: true,
                  onPressed: onRestart,
                ),
                PrimaryButton(
                  label: 'Refresh IP',
                  icon: Icons.refresh,
                  secondary: true,
                  onPressed: onRefreshIp,
                ),
                PrimaryButton(
                  label: 'Copy Customer URL',
                  icon: Icons.copy,
                  secondary: true,
                  onPressed: onCopyUrl,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerPortalQrCard extends StatelessWidget {
  const _CustomerPortalQrCard({required this.state});

  final ServerRuntimeState state;

  @override
  Widget build(BuildContext context) {
    final customerUrl = state.apiUrl == null
        ? null
        : '${state.apiUrl}/customer';
    final canOpen = state.isRunning && customerUrl != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 680;
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: PosColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.qr_code_2,
                        color: PosColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Customer portal QR',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    StatusBadge(
                      label: canOpen ? 'Ready' : 'Waiting',
                      color: canOpen ? PosColors.success : PosColors.warning,
                      icon: canOpen
                          ? Icons.check_circle_outline
                          : Icons.pending_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  canOpen
                      ? 'Scanning this QR opens the local customer menu on the same WiFi.'
                      : 'Start the local server and refresh IP to generate the customer menu QR.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: PosColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: PosColors.line),
                  ),
                  child: SelectableText(
                    customerUrl ?? 'Customer URL unavailable',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: canOpen ? PosColors.slate : PosColors.muted,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Copy Customer URL',
                  icon: Icons.copy,
                  secondary: true,
                  onPressed: canOpen
                      ? () async {
                          await Clipboard.setData(
                            ClipboardData(text: customerUrl),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Customer menu URL copied'),
                            ),
                          );
                        }
                      : null,
                ),
              ],
            );
            final qr = _QrPreview(data: customerUrl, enabled: canOpen);

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  details,
                  const SizedBox(height: 14),
                  Align(child: qr),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: details),
                const SizedBox(width: 16),
                qr,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _QrPreview extends StatelessWidget {
  const _QrPreview({required this.data, required this.enabled});

  final String? data;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PosColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: enabled && data != null
          ? QrImageView(
              data: data!,
              version: QrVersions.auto,
              size: 196,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: PosColors.slate,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: PosColors.slate,
              ),
            )
          : SizedBox(
              width: 196,
              height: 196,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: PosColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.qr_code_2,
                  size: 72,
                  color: PosColors.muted,
                ),
              ),
            ),
    );
  }
}

class _EndpointCard extends StatelessWidget {
  const _EndpointCard({required this.baseUrl, required this.wsUrl});

  final String? baseUrl;
  final String? wsUrl;

  @override
  Widget build(BuildContext context) {
    final endpoints = [
      _Endpoint('GET', '/health', 'Server status JSON'),
      _Endpoint('GET', '/customer', 'Customer web ordering app'),
      _Endpoint('GET', '/assets/*', 'Customer web static assets'),
      _Endpoint(
        'GET',
        '/.well-known/pos-server',
        'Discovery verification metadata',
      ),
      _Endpoint('GET', '/menu', 'Available menu items'),
      _Endpoint('POST', '/orders', 'Create a customer order'),
      _Endpoint('GET', '/orders', 'Admin order list'),
      _Endpoint('GET', '/orders/:id', 'Track one order by id'),
      _Endpoint('PATCH', '/orders/:id/status', 'Update order status'),
      _Endpoint('GET', '/sync/status', 'Pending and failed sync count'),
      _Endpoint('WS', '/ws', 'Live order updates'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('API monitor', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'CORS is enabled for browser and React clients. All responses are JSON.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            ...endpoints.map(
              (endpoint) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _EndpointRow(
                  endpoint: endpoint,
                  baseUrl: endpoint.method == 'WS' ? wsUrl : baseUrl,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HybridStatusCard extends StatelessWidget {
  const _HybridStatusCard({required this.app});

  final PosAppController app;

  @override
  Widget build(BuildContext context) {
    final discovery = app.discoveryState;
    final sync = app.syncState;
    final state = app.serverState;
    final lastPacket = discovery.lastPacket == null
        ? 'No packet broadcast yet'
        : const JsonEncoder.withIndent('  ').convert(discovery.lastPacket);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Hybrid access',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                StatusBadge(
                  label: discovery.isBroadcasting
                      ? 'Broadcasting'
                      : 'Discovery Off',
                  color: discovery.isBroadcasting
                      ? PosColors.success
                      : PosColors.muted,
                  icon: Icons.radar_outlined,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoGrid(
              values: [
                _InfoValue('Discovery port', discovery.port.toString()),
                _InfoValue(
                  'Discovery status',
                  discovery.isBroadcasting ? 'Broadcasting' : 'Stopped',
                ),
                _InfoValue(
                  'Cloud',
                  sync.cloudConnected
                      ? 'Connected'
                      : app.cloudConfig.enabled
                      ? 'Disconnected'
                      : 'Disabled',
                ),
                _InfoValue('Pending sync', sync.pendingCount.toString()),
                _InfoValue('Failed sync', sync.failedCount.toString()),
                _InfoValue('Cloud URL', app.cloudConfig.baseUrl),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                PrimaryButton(
                  label: 'Test Cloud',
                  icon: Icons.health_and_safety_outlined,
                  secondary: true,
                  onPressed: app.busy
                      ? null
                      : () async {
                          final ok = await app.testCloud();
                          if (!context.mounted) return;
                          _showSnack(
                            context,
                            ok ? 'Cloud API reachable' : 'Cloud API failed',
                          );
                        },
                ),
                PrimaryButton(
                  label: 'Sync Now',
                  icon: Icons.sync,
                  secondary: true,
                  onPressed: app.busy
                      ? null
                      : () async {
                          final ok = await app.syncNow();
                          if (!context.mounted) return;
                          _showSnack(
                            context,
                            ok ? 'Sync completed' : 'Sync failed',
                          );
                        },
                ),
                PrimaryButton(
                  label: 'Copy Customer URL',
                  icon: Icons.copy,
                  secondary: true,
                  onPressed: state.apiUrl == null
                      ? null
                      : () async {
                          await Clipboard.setData(
                            ClipboardData(text: '${state.apiUrl}/customer'),
                          );
                          if (!context.mounted) return;
                          _showSnack(context, 'Customer menu URL copied');
                        },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PosColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: PosColors.line),
              ),
              child: SelectableText(
                lastPacket,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ActivityLogCard extends StatelessWidget {
  const _ActivityLogCard({required this.logs});

  final List<ApiLogEntry> logs;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last API activity',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            if (logs.isEmpty)
              const _InlineEmpty(
                icon: Icons.monitor_heart_outlined,
                title: 'No activity yet',
                message: 'Requests and WebSocket connects will appear here.',
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final log = logs[index];
                  final ok = log.statusCode < 400;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 68,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: ok
                              ? PosColors.success.withValues(alpha: 0.1)
                              : PosColors.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${log.method} ${log.statusCode}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: ok ? PosColors.success : PosColors.danger,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              log.path,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (log.message != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                log.message!,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        DateFormat('h:mm:ss a').format(log.createdAt),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  );
                },
                separatorBuilder: (context, index) => const Divider(height: 16),
                itemCount: logs.length,
              ),
          ],
        ),
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PosColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PosColors.line),
      ),
      child: Column(
        children: [
          Icon(icon, color: PosColors.primary, size: 30),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? PosColors.danger : PosColors.warning;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.warning_amber_outlined,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: PosColors.slate),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.values});

  final List<_InfoValue> values;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        const spacing = 10.0;
        final tileWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: values
              .map((value) {
                return SizedBox(
                  width: tileWidth,
                  child: _InfoTile(value: value),
                );
              })
              .toList(growable: false),
        );
      },
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.value});

  final _InfoValue value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: PosColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PosColors.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value.label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(
            value.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _EndpointRow extends StatelessWidget {
  const _EndpointRow({required this.endpoint, required this.baseUrl});

  final _Endpoint endpoint;
  final String? baseUrl;

  @override
  Widget build(BuildContext context) {
    final url = endpoint.method == 'WS'
        ? (baseUrl ?? 'ws://ADMIN_LOCAL_IP:8080/ws')
        : '${baseUrl ?? 'http://ADMIN_LOCAL_IP:8080'}${endpoint.path}';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: PosColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PosColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: PosColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              endpoint.method,
              style: const TextStyle(
                color: PosColors.primary,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(url, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  endpoint.description,
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

class _Endpoint {
  const _Endpoint(this.method, this.path, this.description);

  final String method;
  final String path;
  final String description;
}

class _InfoValue {
  const _InfoValue(this.label, this.value);

  final String label;
  final String value;
}
