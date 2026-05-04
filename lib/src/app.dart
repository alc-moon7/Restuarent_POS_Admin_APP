import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'app_scope.dart';
import 'core/theme/app_theme.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/menu/menu_management_screen.dart';
import 'features/orders/orders_screen.dart';
import 'features/reports/reports_screen.dart';
import 'features/setup/tenant_setup_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/splash/mode_intro_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/sync/sync_status_screen.dart';

class LocalPosApp extends StatefulWidget {
  const LocalPosApp({super.key});

  @override
  State<LocalPosApp> createState() => _LocalPosAppState();
}

class _LocalPosAppState extends State<LocalPosApp> {
  late final PosAppController _controller;
  late final Future<void> _bootFuture;
  bool _showSplash = true;
  bool _showIntro = false;
  int _initialShellIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = PosAppController();
    _bootFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: _controller,
      child: MaterialApp(
        title: 'REs Admin',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(
              textScaler: mediaQuery.textScaler.clamp(maxScaleFactor: 1.12),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          child: _home(),
        ),
      ),
    );
  }

  Widget _home() {
    if (_showSplash) {
      return SplashScreen(
        bootFuture: _bootFuture,
        onFinished: () {
          setState(() {
            _showSplash = false;
            _showIntro = !_controller.hasSeenIntro;
            _initialShellIndex = _showIntro ? 5 : 0;
          });
        },
      );
    }
    if (_showIntro) {
      return ModeIntroScreen(
        onContinue: () async {
          await _controller.completeIntro();
          if (!mounted) return;
          setState(() {
            _showIntro = false;
            _initialShellIndex = 5;
          });
        },
      );
    }
    if (!_controller.isTenantReady) {
      return TenantSetupScreen(
        onProvisioned: () {
          setState(() {
            _initialShellIndex = 0;
          });
        },
      );
    }
    return MainShell(initialIndex: _initialShellIndex);
  }
}

class MainShell extends StatefulWidget {
  const MainShell({required this.initialIndex, super.key});

  final int initialIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _selectedIndex;

  static const List<_Destination> _destinations = [
    _Destination('Dashboard', Icons.dashboard_outlined, Icons.dashboard),
    _Destination('Menu', Icons.restaurant_menu_outlined, Icons.restaurant_menu),
    _Destination('Orders', Icons.receipt_long_outlined, Icons.receipt_long),
    _Destination('Reports', Icons.assessment_outlined, Icons.assessment),
    _Destination('Sync', Icons.cloud_sync_outlined, Icons.cloud_done),
    _Destination('Settings', Icons.tune_outlined, Icons.tune),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(onNavigate: _setIndex),
      const MenuManagementScreen(),
      const OrdersScreen(),
      const ReportsScreen(),
      const SyncStatusScreen(),
      const SettingsScreen(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 760;
        if (!useRail) {
          return Scaffold(
            body: IndexedStack(index: _selectedIndex, children: pages),
            bottomNavigationBar: DecoratedBox(
              decoration: const BoxDecoration(
                color: PosColors.surface,
                border: Border(top: BorderSide(color: PosColors.line)),
              ),
              child: NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: _setIndex,
                labelBehavior:
                    NavigationDestinationLabelBehavior.onlyShowSelected,
                destinations: _destinations
                    .map((destination) {
                      return NavigationDestination(
                        icon: Icon(destination.icon),
                        selectedIcon: Icon(destination.selectedIcon),
                        label: destination.label,
                      );
                    })
                    .toList(growable: false),
              ),
            ),
          );
        }

        final extended = constraints.maxWidth >= 1050;
        return Scaffold(
          body: Row(
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: PosColors.surface,
                  border: Border(right: BorderSide(color: PosColors.line)),
                ),
                child: NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _setIndex,
                  extended: extended,
                  minExtendedWidth: 224,
                  groupAlignment: -0.86,
                  leading: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 18, 14, 24),
                    child: _RailLogo(extended: extended),
                  ),
                  trailing: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 18, 12, 18),
                    child: _RailFooter(extended: extended),
                  ),
                  destinations: _destinations
                      .map((destination) {
                        return NavigationRailDestination(
                          icon: Icon(destination.icon),
                          selectedIcon: Icon(destination.selectedIcon),
                          label: Text(destination.label),
                        );
                      })
                      .toList(growable: false),
                ),
              ),
              Expanded(
                child: IndexedStack(index: _selectedIndex, children: pages),
              ),
            ],
          ),
        );
      },
    );
  }

  void _setIndex(int index) {
    setState(() => _selectedIndex = index);
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _RailLogo extends StatelessWidget {
  const _RailLogo({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: PosColors.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: PosColors.primary.withValues(alpha: 0.24),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(Icons.point_of_sale, color: Colors.white),
    );
    if (!extended) return mark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 10),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'REs Admin',
              style: TextStyle(
                color: PosColors.slate,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Cloud POS',
              style: TextStyle(
                color: PosColors.muted,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RailFooter extends StatelessWidget {
  const _RailFooter({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    if (!extended) {
      return const Icon(Icons.verified_user_outlined, color: PosColors.primary);
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PosColors.primarySoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PosColors.line),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified_user_outlined, color: PosColors.primary),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Secure cloud tenant',
              maxLines: 2,
              style: TextStyle(
                color: PosColors.primaryDark,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
