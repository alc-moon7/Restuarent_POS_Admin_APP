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
  final GlobalKey<FormState> _loginFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _createFormKey = GlobalKey<FormState>();
  bool _showCreate = false;

  final TextEditingController _loginIdController = TextEditingController();
  final TextEditingController _loginPasswordController =
      TextEditingController();

  final TextEditingController _restaurantController = TextEditingController();
  final TextEditingController _outletController = TextEditingController(
    text: 'Main Outlet',
  );
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _loginIdController.dispose();
    _loginPasswordController.dispose();
    _restaurantController.dispose();
    _outletController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
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
                          child: _showCreate
                              ? _CreateAccountForm(
                                  formKey: _createFormKey,
                                  restaurantController: _restaurantController,
                                  outletController: _outletController,
                                  emailController: _emailController,
                                  usernameController: _usernameController,
                                  passwordController: _passwordController,
                                  busy: app.busy,
                                  error: app.lastError,
                                  onSubmit: app.busy ? null : _createAccount,
                                  onBackToLogin: () {
                                    setState(() => _showCreate = false);
                                  },
                                  requiredValidator: _required,
                                )
                              : _LoginForm(
                                  formKey: _loginFormKey,
                                  loginIdController: _loginIdController,
                                  passwordController: _loginPasswordController,
                                  busy: app.busy,
                                  error: app.lastError,
                                  onLogin: app.busy ? null : _login,
                                  onCreateAccount: () {
                                    setState(() => _showCreate = true);
                                  },
                                  onForgotPassword: _forgotPassword,
                                  requiredValidator: _required,
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

  Future<void> _createAccount() async {
    if (!_createFormKey.currentState!.validate()) return;
    final app = AppScope.of(context);
    final ok = await app.createAccountAndProvisionTenant(
      restaurantName: _restaurantController.text,
      outletName: _outletController.text,
      email: _emailController.text,
      username: _usernameController.text,
      password: _passwordController.text,
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

  Future<void> _login() async {
    if (!_loginFormKey.currentState!.validate()) return;
    final app = AppScope.of(context);
    final ok = await app.loginWithAccount(
      usernameOrEmail: _loginIdController.text,
      password: _loginPasswordController.text,
    );
    if (!mounted) return;
    if (ok) {
      widget.onProvisioned();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(app.lastError ?? 'Login failed')),
    );
  }

  Future<void> _forgotPassword() async {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Forget password'),
          content: Text(
            'Please contact admin support to reset this device account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        );
      },
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

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.formKey,
    required this.loginIdController,
    required this.passwordController,
    required this.busy,
    required this.error,
    required this.onLogin,
    required this.onCreateAccount,
    required this.onForgotPassword,
    required this.requiredValidator,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController loginIdController;
  final TextEditingController passwordController;
  final bool busy;
  final String? error;
  final VoidCallback? onLogin;
  final VoidCallback onCreateAccount;
  final VoidCallback onForgotPassword;
  final String? Function(String?) requiredValidator;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Log in',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontSize: 30,
            ),
          ),
          SizedBox(height: 16),
          TextFormField(
            controller: loginIdController,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Enter your username/email',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: requiredValidator,
          ),
          SizedBox(height: 12),
          TextFormField(
            controller: passwordController,
            obscureText: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Enter your password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            validator: requiredValidator,
            onFieldSubmitted: (_) => onLogin?.call(),
          ),
          if (error != null) ...[
            SizedBox(height: 12),
            _InlineError(message: error!),
          ],
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: 'Log in',
              icon: Icons.login_rounded,
              busy: busy,
              onPressed: onLogin,
            ),
          ),
          SizedBox(height: 10),
          Row(
            children: [
              TextButton(
                onPressed: busy ? null : onCreateAccount,
                child: Text('Create account'),
              ),
              SizedBox(width: 6),
              TextButton(
                onPressed: busy ? null : onForgotPassword,
                child: Text('Forget pass'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreateAccountForm extends StatelessWidget {
  const _CreateAccountForm({
    required this.formKey,
    required this.restaurantController,
    required this.outletController,
    required this.emailController,
    required this.usernameController,
    required this.passwordController,
    required this.busy,
    required this.error,
    required this.onSubmit,
    required this.onBackToLogin,
    required this.requiredValidator,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController restaurantController;
  final TextEditingController outletController;
  final TextEditingController emailController;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final bool busy;
  final String? error;
  final VoidCallback? onSubmit;
  final VoidCallback onBackToLogin;
  final String? Function(String?) requiredValidator;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create account',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontSize: 30,
            ),
          ),
          SizedBox(height: 16),
          TextFormField(
            controller: restaurantController,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Restaurant name',
              prefixIcon: Icon(Icons.restaurant_outlined),
            ),
            validator: requiredValidator,
          ),
          SizedBox(height: 10),
          TextFormField(
            controller: outletController,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Outlet name',
              prefixIcon: Icon(Icons.storefront_outlined),
            ),
            validator: requiredValidator,
          ),
          SizedBox(height: 10),
          TextFormField(
            controller: emailController,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: requiredValidator,
          ),
          SizedBox(height: 10),
          TextFormField(
            controller: usernameController,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Username',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            validator: requiredValidator,
          ),
          SizedBox(height: 10),
          TextFormField(
            controller: passwordController,
            obscureText: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Pass',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            validator: requiredValidator,
            onFieldSubmitted: (_) => onSubmit?.call(),
          ),
          if (error != null) ...[
            SizedBox(height: 12),
            _InlineError(message: error!),
          ],
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: 'Create account',
              icon: Icons.person_add_alt_1_outlined,
              busy: busy,
              onPressed: onSubmit,
            ),
          ),
          SizedBox(height: 10),
          TextButton(
            onPressed: busy ? null : onBackToLogin,
            child: Text('Back to log in'),
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
