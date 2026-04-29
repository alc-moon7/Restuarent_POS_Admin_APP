import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class DashboardCard extends StatelessWidget {
  const DashboardCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.caption,
    this.onTap,
    super.key,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 190;
        final iconSize = compact ? 26.0 : 32.0;
        final borderRadius = compact ? 9.0 : 11.0;
        final valueStyle = compact
            ? const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w900,
                color: PosColors.slate,
              )
            : Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              );
        final titleStyle = compact
            ? const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: PosColors.slate,
                height: 1.18,
              )
            : Theme.of(context).textTheme.titleMedium;

        return Card(
          child: Padding(
            padding: EdgeInsets.all(compact ? 10 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(borderRadius),
                      ),
                      child: Icon(icon, color: color, size: compact ? 16 : 20),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.trending_up,
                      color: PosColors.muted.withValues(alpha: 0.45),
                      size: compact ? 13 : 16,
                    ),
                  ],
                ),
                SizedBox(height: compact ? 6 : 8),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: valueStyle,
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
                ),
                if (caption != null && !compact) ...[
                  const SizedBox(height: 2),
                  Text(
                    caption!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: card,
    );
  }
}
