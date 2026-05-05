import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'app_scope.dart';
import 'core/theme/app_theme.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/menu/menu_management_screen.dart';
import 'features/orders/orders_screen.dart';
import 'features/payments/bkash_payment_gate_screen.dart';
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
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final uiScale = _controller.uiScale;
          return MaterialApp(
            title: 'REs Admin',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light().copyWith(
              visualDensity: _visualDensityFor(uiScale),
            ),
            builder: (context, child) {
              final mediaQuery = MediaQuery.of(context);
              final systemScale = mediaQuery.textScaler.scale(1);
              final effectiveScale = (systemScale * uiScale)
                  .clamp(0.82, 1.24)
                  .toDouble();
              return MediaQuery(
                data: mediaQuery.copyWith(
                  textScaler: TextScaler.linear(effectiveScale),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              child: _home(),
            ),
          );
        },
      ),
    );
  }

  VisualDensity _visualDensityFor(double uiScale) {
    final density = ((uiScale - 1) * 5).clamp(-0.9, 0.8).toDouble();
    return VisualDensity(horizontal: density, vertical: density);
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
    if (_controller.requiresBkashPayment) {
      return BkashPaymentGateScreen(
        onVerified: () {
          setState(() {
            _showIntro = false;
            _initialShellIndex = 0;
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
            bottomNavigationBar: _FloatingBottomNav(
              destinations: _destinations,
              selectedIndex: _selectedIndex,
              onChanged: _setIndex,
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
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x0A0F2A1F),
                      blurRadius: 22,
                      offset: Offset(2, 0),
                    ),
                  ],
                ),
                child: NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _setIndex,
                  extended: extended,
                  minExtendedWidth: 232,
                  groupAlignment: -0.86,
                  leading: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 22, 14, 28),
                    child: _RailLogo(extended: extended),
                  ),
                  trailing: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 18, 12, 22),
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
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: PosGradients.brand,
        borderRadius: BorderRadius.circular(PosRadii.md),
        boxShadow: [
          BoxShadow(
            color: PosColors.primary.withValues(alpha: 0.36),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Icon(
        Icons.point_of_sale_rounded,
        color: Colors.white,
        size: 24,
      ),
    );
    if (!extended) return mark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'REs Admin',
              style: TextStyle(
                color: PosColors.slate,
                fontWeight: FontWeight.w900,
                fontSize: 16.5,
                letterSpacing: 0,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Cloud POS Suite',
              style: TextStyle(
                color: PosColors.muted,
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FloatingBottomNav extends StatelessWidget {
  const _FloatingBottomNav({
    required this.destinations,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<_Destination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final showLabel = width >= 390;
    final barHeight = showLabel ? 66.0 : 60.0;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: PosColors.surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: PosColors.line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x180F2A1F),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: SizedBox(
          height: barHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              children: [
                for (var i = 0; i < destinations.length; i++)
                  Expanded(
                    flex: showLabel && i == selectedIndex ? 2 : 1,
                    child: _BottomNavItem(
                      destination: destinations[i],
                      selected: i == selectedIndex,
                      showLabel: showLabel,
                      onTap: () => onChanged(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.destination,
    required this.selected,
    required this.showLabel,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : PosColors.muted;
    final icon = selected ? destination.selectedIcon : destination.icon;

    return Tooltip(
      message: destination.label,
      child: Semantics(
        button: true,
        selected: selected,
        label: destination.label,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                height: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: selected && showLabel ? 10 : 0,
                ),
                decoration: BoxDecoration(
                  gradient: selected ? PosGradients.brand : null,
                  color: selected ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: selected ? PosShadows.glow : const [],
                ),
                child: Center(
                  child: showLabel && selected
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, color: foreground, size: 20),
                            const SizedBox(width: 6),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  destination.label,
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: foreground,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11.5,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Icon(icon, color: foreground, size: selected ? 23 : 22),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RailFooter extends StatelessWidget {
  const _RailFooter({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    if (!extended) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: PosColors.primarySoft,
          borderRadius: BorderRadius.circular(PosRadii.sm),
          border: Border.all(color: PosColors.line),
        ),
        child: const Icon(
          Icons.verified_user_outlined,
          color: PosColors.primary,
          size: 20,
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PosColors.primarySoft,
            PosColors.primarySoft.withValues(alpha: 0.55),
          ],
        ),
        borderRadius: BorderRadius.circular(PosRadii.md),
        border: Border.all(color: PosColors.line),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.verified_user_outlined,
            color: PosColors.primary,
            size: 20,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Secure tenant',
                  style: TextStyle(
                    color: PosColors.primaryDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Token verified',
                  style: TextStyle(
                    color: PosColors.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 10.5,
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
