import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

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
  final TextEditingController _portController = TextEditingController();
  bool _hydrated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hydrated) return;
    final app = AppScope.of(context);
    _restaurantController.text = app.restaurantName;
    _portController.text = app.serverPort.toString();
    _hydrated = true;
  }

  @override
  void dispose() {
    _restaurantController.dispose();
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
            portController: _portController,
            busy: app.busy,
            onStart: _startServer,
          ),
          const SizedBox(height: 16),
          if (state.localIp == null)
            const _WarningCard(
              message:
                  'No WiFi/local IP was found. The server can run, but customer devices need the correct LAN IP after connecting to the same WiFi.',
            ),
          if (state.localIp == null) const SizedBox(height: 16),
          if (app.lastError != null)
            _WarningCard(message: app.lastError!, isError: true),
          if (app.lastError != null) const SizedBox(height: 16),
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
                    await Clipboard.setData(ClipboardData(text: state.apiUrl!));
                    if (!context.mounted) return;
                    _showSnack(context, 'API URL copied');
                  },
          ),
          const SizedBox(height: 16),
          _EndpointCard(baseUrl: state.apiUrl, wsUrl: state.wsUrl),
          const SizedBox(height: 16),
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
    required this.portController,
    required this.busy,
    required this.onStart,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController restaurantController;
  final TextEditingController portController;
  final bool busy;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: PosColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.router_outlined,
                      color: PosColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
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
              const SizedBox(height: 18),
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
                      children: [restaurant, const SizedBox(height: 12), port],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(flex: 3, child: restaurant),
                      const SizedBox(width: 12),
                      Expanded(child: port),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
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
        padding: const EdgeInsets.all(18),
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
            const SizedBox(height: 16),
            _InfoGrid(
              values: [
                _InfoValue('Local IP', state.localIp ?? 'Not found'),
                _InfoValue('Port', state.port.toString()),
                _InfoValue('API URL', state.apiUrl ?? 'Unavailable'),
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
            const SizedBox(height: 16),
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
                  label: 'Copy URL',
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

class _EndpointCard extends StatelessWidget {
  const _EndpointCard({required this.baseUrl, required this.wsUrl});

  final String? baseUrl;
  final String? wsUrl;

  @override
  Widget build(BuildContext context) {
    final endpoints = [
      _Endpoint('GET', '/health', 'Server status JSON'),
      _Endpoint('GET', '/menu', 'Available menu items'),
      _Endpoint('POST', '/orders', 'Create a customer order'),
      _Endpoint('GET', '/orders', 'Admin order list'),
      _Endpoint('PATCH', '/orders/:id/status', 'Update order status'),
      _Endpoint('WS', '/ws', 'Live order updates'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('API monitor', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'CORS is enabled for browser and React clients. All responses are JSON.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            ...endpoints.map(
              (endpoint) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
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

class _ActivityLogCard extends StatelessWidget {
  const _ActivityLogCard({required this.logs});

  final List<ApiLogEntry> logs;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last API activity',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
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
                        width: 74,
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
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
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
                separatorBuilder: (context, index) => const Divider(height: 20),
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
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: PosColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PosColors.line),
      ),
      child: Column(
        children: [
          Icon(icon, color: PosColors.primary, size: 30),
          const SizedBox(height: 10),
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
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.warning_amber_outlined,
              color: color,
            ),
            const SizedBox(width: 10),
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
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: values.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: columns == 1 ? 4.6 : 3.1,
          ),
          itemBuilder: (context, index) {
            final value = values[index];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PosColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: PosColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value.label,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
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
          },
        );
      },
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PosColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PosColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
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
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
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
