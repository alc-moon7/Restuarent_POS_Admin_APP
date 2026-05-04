import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/primary_button.dart';

class TenantSetupScreen extends StatefulWidget {
  const TenantSetupScreen({required this.onProvisioned, super.key});

  final VoidCallback onProvisioned;

  @override
  State<TenantSetupScreen> createState() => _TenantSetupScreenState();
}

class _TenantSetupScreenState extends State<TenantSetupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _restaurantController = TextEditingController();
  final TextEditingController _outletController = TextEditingController(
    text: 'Main Outlet',
  );

  @override
  void dispose() {
    _restaurantController.dispose();
    _outletController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: PosColors.background,
          body: SafeArea(
            child: Stack(
              children: [
                const _SetupWash(),
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: PosColors.primary,
                                        borderRadius: BorderRadius.circular(22),
                                        boxShadow: [
                                          BoxShadow(
                                            color: PosColors.primary.withValues(
                                              alpha: 0.22,
                                            ),
                                            blurRadius: 22,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.verified_outlined,
                                        color: Colors.white,
                                        size: 30,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Create Restaurant Cloud',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.displaySmall,
                                          ),
                                          const SizedBox(height: 4),
                                          const _SetupBadge(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Set up this restaurant once. The app will create a private restaurant/outlet identity in the cloud automatically.',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                const SizedBox(height: 20),
                                TextFormField(
                                  controller: _restaurantController,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Restaurant name',
                                    hintText: 'Example: Moon Bistro',
                                    prefixIcon: Icon(Icons.restaurant_outlined),
                                  ),
                                  validator: _required,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _outletController,
                                  textInputAction: TextInputAction.done,
                                  decoration: const InputDecoration(
                                    labelText: 'Outlet name',
                                    hintText: 'Example: Dhanmondi Branch',
                                    prefixIcon: Icon(Icons.storefront_outlined),
                                  ),
                                  validator: _required,
                                  onFieldSubmitted: (_) => _submit(),
                                ),
                                const SizedBox(height: 14),
                                _SecurityNotice(
                                  hasToken: app.cloudConfig.hasDeviceToken,
                                ),
                                if (app.lastError != null) ...[
                                  const SizedBox(height: 12),
                                  _InlineError(message: app.lastError!),
                                ],
                                const SizedBox(height: 18),
                                SizedBox(
                                  width: double.infinity,
                                  child: PrimaryButton(
                                    label: 'Create Cloud Restaurant',
                                    icon: Icons.cloud_done_outlined,
                                    busy: app.busy,
                                    onPressed: app.busy ? null : _submit,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final app = AppScope.of(context);
    final ok = await app.provisionTenant(
      restaurantName: _restaurantController.text,
      outletName: _outletController.text,
    );
    if (!mounted) return;
    if (ok) {
      widget.onProvisioned();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(app.lastError ?? 'Cloud setup failed')),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }
}

class _SetupWash extends StatelessWidget {
  const _SetupWash();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              PosColors.primarySoft,
              PosColors.accentSoft.withValues(alpha: 0.45),
              PosColors.background,
            ],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SetupBadge extends StatelessWidget {
  const _SetupBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: PosColors.primarySoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: PosColors.line),
      ),
      child: const Text(
        'One-time secure setup',
        style: TextStyle(
          color: PosColors.primaryDark,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _SecurityNotice extends StatelessWidget {
  const _SecurityNotice({required this.hasToken});

  final bool hasToken;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PosColors.success.withValues(alpha: 0.1),
        border: Border.all(color: PosColors.success.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, color: PosColors.success),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasToken
                  ? 'This device already has a private cloud token.'
                  : 'No API key setup is needed. A private device token will be issued and stored inside this app.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PosColors.danger.withValues(alpha: 0.08),
        border: Border.all(color: PosColors.danger.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
