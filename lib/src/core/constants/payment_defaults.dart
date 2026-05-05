class PaymentDefaults {
  const PaymentDefaults._();

  static const bool requireBkashGate = bool.fromEnvironment(
    'POS_REQUIRE_BKASH_GATE',
    defaultValue: true,
  );

  static const String sandboxAmountText = String.fromEnvironment(
    'POS_BKASH_SANDBOX_AMOUNT',
    defaultValue: '10',
  );

  static double get sandboxAmount {
    final parsed = double.tryParse(sandboxAmountText);
    if (parsed == null || parsed <= 0) return 10;
    return parsed;
  }

  static const String bkashSandboxWallet = '01770618575';
  static const String bkashSandboxOtp = '123456';
  static const String bkashSandboxPin = '12121';

  static const double monthlyPlanAmount = 800;
  static const double annualPlanAmount = 9600;

  static const bool useDemoBkashGateway = bool.fromEnvironment(
    'POS_BKASH_DEMO_MODE',
    defaultValue: true,
  );
}
