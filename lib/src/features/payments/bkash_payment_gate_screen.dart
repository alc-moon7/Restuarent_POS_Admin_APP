import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../app_scope.dart';
import '../../core/constants/payment_defaults.dart';
import '../../core/theme/app_theme.dart';

class BkashPaymentGateScreen extends StatefulWidget {
  const BkashPaymentGateScreen({required this.onVerified, super.key});

  final VoidCallback onVerified;

  @override
  State<BkashPaymentGateScreen> createState() => _BkashPaymentGateScreenState();
}

class _BkashPaymentGateScreenState extends State<BkashPaymentGateScreen> {
  WebViewController? _webViewController;
  _Plan? _selectedPlan;
  bool _isCompletingPayment = false;

  @override
  Widget build(BuildContext context) {
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
                    'To use this App Pay with Bkash',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: PosColors.slate,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _PlanButton(
                    title: 'Monthly',
                    amount: '৳800',
                    onTap: () => _openCheckout(_Plan.monthly),
                  ),
                  const SizedBox(height: 12),
                  _PlanButton(
                    title: 'Annual',
                    amount: '৳9600',
                    onTap: () => _openCheckout(_Plan.annual),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openCheckout(_Plan plan) {
    _selectedPlan = plan;
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _handleNavigationRequest,
          onPageFinished: _completeIfSuccessful,
        ),
      )
      ..loadRequest(Uri.parse(PaymentDefaults.temporaryBkashCheckoutUrl));
    setState(() => _webViewController = controller);
  }

  NavigationDecision _handleNavigationRequest(NavigationRequest request) {
    if (_isSuccessfulCallback(request.url)) {
      unawaited(_completePayment());
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  Future<void> _completeIfSuccessful(String url) async {
    if (!_isSuccessfulCallback(url)) return;
    await _completePayment();
  }

  bool _isSuccessfulCallback(String url) {
    final uri = Uri.tryParse(url);
    final status = uri?.queryParameters['status']?.toLowerCase();
    return status == 'success';
  }

  Future<void> _completePayment() async {
    if (_isCompletingPayment) return;
    _isCompletingPayment = true;
    final plan = _selectedPlan ?? _Plan.monthly;
    final app = AppScope.of(context);
    await app.markTemporaryBkashPaymentVerified(
      plan: plan.name,
      amount: plan.amount,
    );
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
}

class _PlanButton extends StatelessWidget {
  const _PlanButton({
    required this.title,
    required this.amount,
    required this.onTap,
  });

  final String title;
  final String amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE2136E),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
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
