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
    final text = app.strings;
    if (_outletController.text == 'Main Outlet') {
      _outletController.text = text.isBn ? 'প্রধান আউটলেট' : 'Main Outlet';
    }
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: PosColors.background,
          body: SafeArea(
            child: Stack(
              children: [
                _SetupWash(),
                Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 620),
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        gradient: PosGradients.brand,
                                        borderRadius: BorderRadius.circular(
                                          PosRadii.lg,
                                        ),
                                        boxShadow: PosShadows.glow,
                                      ),
                                      child: Icon(
                                        Icons.verified_rounded,
                                        color: Colors.white,
                                        size: 32,
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            text.createRestaurantCloud,
                                            style: Theme.of(context)
                                                .textTheme
                                                .displaySmall
                                                ?.copyWith(fontSize: 26),
                                          ),
                                          SizedBox(height: 6),
                                          _SetupBadge(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16),
                                Text(
                                  text.setupRestaurantDescription,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                SizedBox(height: 20),
                                TextFormField(
                                  controller: _restaurantController,
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    labelText: text.restaurantName,
                                    hintText: text.restaurantNameHint,
                                    prefixIcon: Icon(Icons.restaurant_outlined),
                                  ),
                                  validator: _required,
                                ),
                                SizedBox(height: 12),
                                TextFormField(
                                  controller: _outletController,
                                  textInputAction: TextInputAction.done,
                                  decoration: InputDecoration(
                                    labelText: text.outletName,
                                    hintText: text.outletNameHint,
                                    prefixIcon: Icon(Icons.storefront_outlined),
                                  ),
                                  validator: _required,
                                  onFieldSubmitted: (_) => _submit(),
                                ),
                                SizedBox(height: 14),
                                _SecurityNotice(
                                  hasToken: app.cloudConfig.hasDeviceToken,
                                ),
                                if (app.lastError != null) ...[
                                  SizedBox(height: 12),
                                  _InlineError(message: app.lastError!),
                                ],
                                SizedBox(height: 18),
                                SizedBox(
                                  width: double.infinity,
                                  child: PrimaryButton(
                                    label: text.createRestaurantCloud,
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
      SnackBar(content: Text(app.lastError ?? app.strings.cloudSetupFailed)),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppScope.of(context).strings.requiredField;
    }
    return null;
  }
}

class _SetupWash extends StatelessWidget {
  const _SetupWash();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
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
              child: SizedBox.expand(),
            ),
          ),
          Positioned(
            top: -100,
            left: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    PosColors.primaryGlow.withValues(alpha: 0.18),
                    PosColors.primaryGlow.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            right: -90,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    PosColors.accent.withValues(alpha: 0.12),
                    PosColors.accent.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupBadge extends StatelessWidget {
  const _SetupBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: PosColors.primarySoft,
        borderRadius: BorderRadius.circular(PosRadii.pill),
        border: Border.all(color: PosColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_clock_rounded, size: 12, color: PosColors.primary),
          SizedBox(width: 5),
          Text(
            'ONE-TIME SECURE SETUP',
            style: TextStyle(
              color: PosColors.primaryDark,
              fontWeight: FontWeight.w900,
              fontSize: 10.6,
              letterSpacing: 1.0,
            ),
          ),
        ],
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
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PosColors.success.withValues(alpha: 0.1),
        border: Border.all(color: PosColors.success.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, color: PosColors.success),
          SizedBox(width: 10),
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
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PosColors.danger.withValues(alpha: 0.08),
        border: Border.all(color: PosColors.danger.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
