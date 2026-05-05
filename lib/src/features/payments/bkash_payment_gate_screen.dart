import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../app_scope.dart';
import '../../core/constants/payment_defaults.dart';
import '../../core/theme/app_theme.dart';
import '../../models/bkash_payment_session.dart';

class BkashPaymentGateScreen extends StatefulWidget {
  const BkashPaymentGateScreen({required this.onVerified, super.key});

  final VoidCallback onVerified;

  @override
  State<BkashPaymentGateScreen> createState() => _BkashPaymentGateScreenState();
}

class _BkashPaymentGateScreenState extends State<BkashPaymentGateScreen> {
  WebViewController? _webViewController;
  _Plan? _selectedPlan;
  BkashPaymentSession? _session;
  bool _creatingSession = false;
  bool _isCompletingPayment = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    final controller = _webViewController;
    if (controller != null) {
      return _BkashCheckoutPopup(controller: controller);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _BrandAssetLogo(
                        assetPath: 'assets/brand/terabyte_ai.png',
                        size: 112,
                      ),
                      SizedBox(width: 18),
                      _BrandAssetLogo(
                        assetPath: 'assets/brand/bkash.png',
                        size: 112,
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Text(
                    text.payWithBkash,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: PosColors.slate,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _PlanButton(
                    title: text.monthly,
                    amount: '৳800',
                    busy: _creatingSession && _selectedPlan == _Plan.monthly,
                    disabled: _creatingSession,
                    onTap: () => _openCheckout(_Plan.monthly),
                  ),
                  const SizedBox(height: 12),
                  _PlanButton(
                    title: text.annual,
                    amount: '৳9600',
                    busy: _creatingSession && _selectedPlan == _Plan.annual,
                    disabled: _creatingSession,
                    onTap: () => _openCheckout(_Plan.annual),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    _PaymentError(message: _error!),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openCheckout(_Plan plan) async {
    if (_creatingSession) return;
    if (PaymentDefaults.useDemoBkashGateway) {
      await _openDemoPayment(plan);
      return;
    }
    setState(() {
      _selectedPlan = plan;
      _creatingSession = true;
      _error = null;
    });
    try {
      final app = AppScope.of(context);
      final session = await app.createBkashSandboxPayment(amount: plan.amount);
      if (!mounted) return;
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: _handleNavigationRequest,
            onPageFinished: _completeIfSuccessful,
            onWebResourceError: (_) {
              if (!mounted) return;
              setState(() {
                _error = AppScope.of(context).strings.bkashCheckoutLoadFailed;
              });
            },
          ),
        )
        ..loadRequest(Uri.parse(session.checkoutUrl));
      setState(() {
        _session = session;
        _webViewController = controller;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = AppScope.of(context).strings.bkashSessionCreateFailed;
      });
    } finally {
      if (mounted) setState(() => _creatingSession = false);
    }
  }

  Future<void> _openDemoPayment(_Plan plan) async {
    setState(() {
      _selectedPlan = plan;
      _error = null;
    });
    final completed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DemoBkashPaymentDialog(plan: plan),
    );
    if (completed != true || !mounted) return;
    final app = AppScope.of(context);
    await app.markTemporaryBkashPaymentVerified(
      plan: plan.name,
      amount: plan.amount,
    );
    if (!mounted) return;
    widget.onVerified();
  }

  NavigationDecision _handleNavigationRequest(NavigationRequest request) {
    if (_isSuccessfulCallback(request.url)) {
      unawaited(_completePaymentAfterCallback());
    }
    return NavigationDecision.navigate;
  }

  Future<void> _completeIfSuccessful(String url) async {
    if (!_isSuccessfulCallback(url)) return;
    await _completePaymentAfterCallback();
  }

  bool _isSuccessfulCallback(String url) {
    final uri = Uri.tryParse(url);
    final status = uri?.queryParameters['status']?.toLowerCase();
    return status == 'success';
  }

  Future<void> _completePaymentAfterCallback() async {
    if (_isCompletingPayment) return;
    _isCompletingPayment = true;
    final plan = _selectedPlan ?? _Plan.monthly;
    final app = AppScope.of(context);
    final paymentId = _session?.paymentId;
    if (paymentId == null || paymentId.isEmpty) {
      await app.markTemporaryBkashPaymentVerified(
        plan: plan.name,
        amount: plan.amount,
      );
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      final verified = await app.verifyBkashSandboxPayment(paymentId);
      if (!verified) {
        if (!mounted) return;
        setState(() {
          _webViewController = null;
          _error = app.lastError ?? app.strings.bkashNotCompleted;
        });
        _isCompletingPayment = false;
        return;
      }
    }
    if (!mounted) return;
    widget.onVerified();
  }
}

class _BkashCheckoutPopup extends StatelessWidget {
  const _BkashCheckoutPopup({required this.controller});

  final WebViewController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalMargin = constraints.maxWidth < 420 ? 12.0 : 24.0;
            final verticalMargin = constraints.maxHeight < 720 ? 12.0 : 24.0;
            return Center(
              child: Container(
                width: constraints.maxWidth - (horizontalMargin * 2),
                height: constraints.maxHeight - (verticalMargin * 2),
                constraints: const BoxConstraints(
                  maxWidth: 520,
                  maxHeight: 760,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 30,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: WebViewWidget(controller: controller),
              ),
            );
          },
        ),
      ),
    );
  }
}

enum _Plan {
  monthly(PaymentDefaults.monthlyPlanAmount),
  annual(PaymentDefaults.annualPlanAmount);

  const _Plan(this.amount);
  final double amount;

  String get displayAmount => '৳${amount.toStringAsFixed(0)}';
}

class _DemoBkashPaymentDialog extends StatelessWidget {
  const _DemoBkashPaymentDialog({required this.plan});

  final _Plan plan;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    final planTitle = switch (plan) {
      _Plan.monthly => text.monthly,
      _Plan.annual => text.annual,
    };
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 32,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _BrandAssetLogo(
                  assetPath: 'assets/brand/bkash.png',
                  size: 74,
                ),
                const SizedBox(height: 16),
                Text(
                  text.bkashDemoPayment,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: PosColors.slate,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  text.planLine(planTitle, plan.displayAmount),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFE2136E),
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 14),
                _DemoValueRow(
                  label: text.wallet,
                  value: PaymentDefaults.bkashSandboxWallet,
                ),
                _DemoValueRow(
                  label: text.otp,
                  value: PaymentDefaults.bkashSandboxOtp,
                ),
                _DemoValueRow(
                  label: text.pin,
                  value: PaymentDefaults.bkashSandboxPin,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE2136E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(
                      text.completeDemoPayment,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(text.cancel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoValueRow extends StatelessWidget {
  const _DemoValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: PosColors.mutedSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PosColors.line),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                color: PosColors.muted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: PosColors.slate,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanButton extends StatelessWidget {
  const _PlanButton({
    required this.title,
    required this.amount,
    required this.onTap,
    this.busy = false,
    this.disabled = false,
  });

  final String title;
  final String amount;
  final VoidCallback onTap;
  final bool busy;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE2136E),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else
                Text(
                  amount,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentError extends StatelessWidget {
  const _PaymentError({required this.message});

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
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: PosColors.danger,
          fontWeight: FontWeight.w800,
          fontSize: 12.5,
        ),
      ),
    );
  }
}

class _BrandAssetLogo extends StatelessWidget {
  const _BrandAssetLogo({required this.assetPath, required this.size});

  final String assetPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}
