import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../app_scope.dart';
import '../../core/constants/payment_defaults.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/bkash_payment_session.dart';

class BkashPaymentGateScreen extends StatefulWidget {
  const BkashPaymentGateScreen({required this.onVerified, super.key});

  final VoidCallback onVerified;

  @override
  State<BkashPaymentGateScreen> createState() => _BkashPaymentGateScreenState();
}

class _BkashPaymentGateScreenState extends State<BkashPaymentGateScreen> {
  final NumberFormat _currency = NumberFormat.currency(
    symbol: '৳',
    decimalDigits: 2,
  );

  BkashPaymentSession? _session;
  WebViewController? _webViewController;
  bool _creating = false;
  bool _verifying = false;
  bool _callbackSeen = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final amount = PaymentDefaults.sandboxAmount;
    return Scaffold(
      backgroundColor: PosColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            const _PaymentWash(),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 820;
                      final intro = _ActivationCard(
                        amount: _currency.format(amount),
                        creating: _creating,
                        verifying: _verifying || app.busy,
                        paymentId: _session?.paymentId,
                        error: _error,
                        onCreatePayment: _createPayment,
                        onVerify: _session == null
                            ? null
                            : () => _verifyPayment(_session!.paymentId),
                      );
                      final checkout = _CheckoutPanel(
                        controller: _webViewController,
                        callbackSeen: _callbackSeen,
                      );
                      if (!wide) {
                        return Column(
                          children: [
                            intro,
                            const SizedBox(height: 12),
                            Expanded(child: checkout),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(flex: 4, child: intro),
                          const SizedBox(width: 14),
                          Expanded(flex: 6, child: checkout),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createPayment() async {
    if (_creating || _verifying) return;
    final app = AppScope.of(context);
    setState(() {
      _creating = true;
      _error = null;
      _callbackSeen = false;
    });
    try {
      final session = await app.createBkashSandboxPayment();
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (request) {
              if (_isCallbackUrl(request.url)) {
                _callbackSeen = true;
              }
              return NavigationDecision.navigate;
            },
            onPageFinished: (url) {
              if (_isCallbackUrl(url)) {
                _callbackSeen = true;
                _verifyPayment(session.paymentId);
              }
            },
            onWebResourceError: (error) {
              if (!mounted) return;
              setState(() {
                _error =
                    'bKash checkout could not load. Check internet and try again.';
              });
            },
          ),
        )
        ..loadRequest(Uri.parse(session.checkoutUrl));
      if (!mounted) return;
      setState(() {
        _session = session;
        _webViewController = controller;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _verifyPayment(String paymentId) async {
    if (_verifying) return;
    final app = AppScope.of(context);
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final ok = await app.verifyBkashSandboxPayment(paymentId);
      if (!mounted) return;
      if (ok) {
        widget.onVerified();
        return;
      }
      setState(() {
        _error = app.lastError ?? 'Payment is not completed yet.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  bool _isCallbackUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && uri.path.contains('/payments/bkash/callback');
  }
}

class _ActivationCard extends StatelessWidget {
  const _ActivationCard({
    required this.amount,
    required this.creating,
    required this.verifying,
    required this.paymentId,
    required this.error,
    required this.onCreatePayment,
    required this.onVerify,
  });

  final String amount;
  final bool creating;
  final bool verifying;
  final String? paymentId;
  final String? error;
  final VoidCallback onCreatePayment;
  final VoidCallback? onVerify;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: PosGradients.cardTint(const Color(0xFFE2136E)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2136E),
                    borderRadius: BorderRadius.circular(PosRadii.lg),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE2136E).withValues(alpha: 0.30),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 31,
                  ),
                ),
                const SizedBox(height: 18),
                const _SandboxBadge(),
                const SizedBox(height: 14),
                Text(
                  'Activate your\nrestaurant admin.',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontSize: 31,
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Complete the bKash sandbox checkout first. After successful verification, restaurant setup will open automatically.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: PosColors.muted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                _AmountCard(amount: amount),
                const SizedBox(height: 10),
                const _SandboxTestCard(),
                if (paymentId != null) ...[
                  const SizedBox(height: 10),
                  _PaymentIdCard(paymentId: paymentId!),
                ],
                if (error != null) ...[
                  const SizedBox(height: 10),
                  _InlineError(message: error!),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    label: paymentId == null
                        ? 'Pay with bKash Sandbox'
                        : 'Create New Payment',
                    icon: Icons.payment_rounded,
                    busy: creating,
                    onPressed: creating || verifying ? null : onCreatePayment,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    label: 'Verify Payment',
                    icon: Icons.verified_rounded,
                    secondary: true,
                    busy: verifying,
                    onPressed: verifying ? null : onVerify,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutPanel extends StatelessWidget {
  const _CheckoutPanel({required this.controller, required this.callbackSeen});

  final WebViewController? controller;
  final bool callbackSeen;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: const BoxDecoration(
              color: PosColors.surface,
              border: Border(bottom: BorderSide(color: PosColors.line)),
            ),
            child: Row(
              children: [
                Icon(
                  callbackSeen ? Icons.verified_rounded : Icons.shield_outlined,
                  color: callbackSeen ? PosColors.success : PosColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    callbackSeen
                        ? 'bKash callback received'
                        : 'Secure sandbox checkout',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: controller == null
                ? const _CheckoutPlaceholder()
                : WebViewWidget(controller: controller!),
          ),
        ],
      ),
    );
  }
}

class _CheckoutPlaceholder extends StatelessWidget {
  const _CheckoutPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: PosColors.primarySoft,
                borderRadius: BorderRadius.circular(PosRadii.xl),
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: PosColors.primary,
                size: 34,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Checkout will appear here',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Tap Pay with bKash Sandbox to open the test checkout securely.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _SandboxBadge extends StatelessWidget {
  const _SandboxBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE2136E).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(PosRadii.pill),
        border: Border.all(
          color: const Color(0xFFE2136E).withValues(alpha: 0.22),
        ),
      ),
      child: const Text(
        'BKASH SANDBOX',
        style: TextStyle(
          color: Color(0xFFE2136E),
          fontSize: 10.6,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _AmountCard extends StatelessWidget {
  const _AmountCard({required this.amount});

  final String amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.md),
        border: Border.all(color: PosColors.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.payments_rounded, color: PosColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sandbox activation fee',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Text(
            amount,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: PosColors.primaryDark),
          ),
        ],
      ),
    );
  }
}

class _SandboxTestCard extends StatelessWidget {
  const _SandboxTestCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE2136E).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(PosRadii.md),
        border: Border.all(
          color: const Color(0xFFE2136E).withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sandbox test values',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFFE2136E),
            ),
          ),
          const SizedBox(height: 8),
          const _TestValueRow(
            label: 'Wallet',
            value: PaymentDefaults.bkashSandboxWallet,
          ),
          const _TestValueRow(
            label: 'OTP',
            value: PaymentDefaults.bkashSandboxOtp,
          ),
          const _TestValueRow(
            label: 'PIN',
            value: PaymentDefaults.bkashSandboxPin,
          ),
        ],
      ),
    );
  }
}

class _TestValueRow extends StatelessWidget {
  const _TestValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Text(
              label,
              style: const TextStyle(
                color: PosColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: PosColors.slate,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentIdCard extends StatelessWidget {
  const _PaymentIdCard({required this.paymentId});

  final String paymentId;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PosColors.mutedSoft,
        borderRadius: BorderRadius.circular(PosRadii.md),
      ),
      child: Text(
        'Payment ID: $paymentId',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: PosColors.slate,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
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
        color: PosColors.danger.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(PosRadii.md),
        border: Border.all(color: PosColors.danger.withValues(alpha: 0.22)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: PosColors.danger,
          fontSize: 12.4,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PaymentWash extends StatelessWidget {
  const _PaymentWash();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFE2136E).withValues(alpha: 0.08),
              PosColors.primarySoft,
              PosColors.background,
            ],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}
