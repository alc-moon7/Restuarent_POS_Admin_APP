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

  static const String temporaryBkashCheckoutUrl =
      'https://sandbox.payment.bkash.com/?paymentId=TR00007y9Y4Qe1777971977932&hash=2D-yborMXq6PJjh5MfyaNnREbNtYs._ss4_WsXgWORwCUjhtdeSTexoF29xUCfq5jqwCC0nWe4b-BaZUq-o(TdJGGdjh.VF0RaR11777971977932&mode=0000&apiVersion=v2/';
}
