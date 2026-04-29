import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.floatingActionButton,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PosColors.background,
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                _horizontalPadding(context),
                20,
                _horizontalPadding(context),
                12,
              ),
              sliver: SliverToBoxAdapter(
                child: _Header(
                  title: title,
                  subtitle: subtitle,
                  actions: actions,
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                _horizontalPadding(context),
                0,
                _horizontalPadding(context),
                28,
              ),
              sliver: SliverToBoxAdapter(child: child),
            ),
          ],
        ),
      ),
    );
  }

  double _horizontalPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1200) return 32;
    if (width >= 700) return 24;
    return 16;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.actions, this.subtitle});

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final titleColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: textTheme.headlineMedium),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, style: textTheme.bodyMedium),
            ],
          ],
        );
        if (actions.isEmpty) return titleColumn;
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleColumn,
              const SizedBox(height: 14),
              Wrap(spacing: 10, runSpacing: 10, children: actions),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: titleColumn),
            const SizedBox(width: 16),
            Wrap(spacing: 10, runSpacing: 10, children: actions),
          ],
        );
      },
    );
  }
}
