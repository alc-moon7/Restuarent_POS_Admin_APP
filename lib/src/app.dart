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
            bottomNavigationBar: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _setIndex,
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
          );
        }

        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: _selectedIndex,
                onDestinationSelected: _setIndex,
                extended: constraints.maxWidth >= 1050,
                minExtendedWidth: 210,
                leading: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: _RailLogo(),
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
              const VerticalDivider(width: 1),
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
  const _RailLogo();

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 19,
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Colors.white,
      child: const Icon(Icons.point_of_sale),
    );
  }
}
