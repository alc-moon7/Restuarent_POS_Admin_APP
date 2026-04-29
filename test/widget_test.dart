import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/core/theme/app_theme.dart';

void main() {
  test('app theme exposes the Local POS color system', () {
    final theme = AppTheme.light();

    expect(theme.colorScheme.primary.toARGB32(), 0xFF006C5B);
    expect(theme.colorScheme.secondary.toARGB32(), 0xFFF59E0B);
    expect(theme.useMaterial3, isTrue);
  });
}
