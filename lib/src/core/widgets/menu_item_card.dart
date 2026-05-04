import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/menu_item.dart';
import '../theme/app_theme.dart';
import 'menu_image_view.dart';
import 'status_badge.dart';

class MenuItemCard extends StatelessWidget {
  const MenuItemCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onAvailabilityChanged,
    super.key,
  });

  final MenuItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onAvailabilityChanged;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: r'$', decimalDigits: 2);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 1.82,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MenuImageView(imageUrl: item.imageUrl),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.02),
                              Colors.black.withValues(alpha: 0.26),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      bottom: 10,
                      child: StatusBadge(
                        label: item.isAvailable ? 'Available' : 'Paused',
                        color: item.isAvailable
                            ? PosColors.success
                            : PosColors.danger,
                        icon: item.isAvailable
                            ? Icons.check_circle_outline
                            : Icons.pause_circle_outline,
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Text(
                            currency.format(item.price),
                            style: const TextStyle(
                              color: PosColors.primaryDark,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              item.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 15.5,
                fontWeight: FontWeight.w900,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              item.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusBadge.sync(item.syncStatus),
                _SmallPill(icon: Icons.category_outlined, label: item.category),
                if (item.preparationTimeMinutes != null)
                  _SmallPill(
                    icon: Icons.timer_outlined,
                    label: '${item.preparationTimeMinutes} min',
                  ),
                ...item.tags.map(
                  (tag) => _SmallPill(icon: Icons.sell_outlined, label: tag),
                ),
              ],
            ),
            const Spacer(),
            const SizedBox(height: 8),
            const Divider(height: 1, color: PosColors.line),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SwitchListTile.adaptive(
                    value: item.isAvailable,
                    onChanged: onAvailabilityChanged,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Active'),
                  ),
                ),
                IconButton(
                  tooltip: 'Edit menu item',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Delete menu item',
                  onPressed: onDelete,
                  color: PosColors.danger,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  const _SmallPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: PosColors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: PosColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: PosColors.muted),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: PosColors.muted,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
