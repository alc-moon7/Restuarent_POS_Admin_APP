import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/menu_item.dart';
import '../theme/app_theme.dart';
import 'menu_image_view.dart';
import 'status_badge.dart';

class MenuItemCard extends StatefulWidget {
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
  State<MenuItemCard> createState() => _MenuItemCardState();
}

class _MenuItemCardState extends State<MenuItemCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: r'$', decimalDigits: 2);
    final available = widget.item.isAvailable;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(PosRadii.lg),
          boxShadow: _hovering ? PosShadows.raised : PosShadows.card,
        ),
        child: Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PosRadii.lg),
            side: BorderSide(
              color: _hovering
                  ? PosColors.primary.withValues(alpha: 0.3)
                  : PosColors.line,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(PosRadii.md),
                  child: AspectRatio(
                    aspectRatio: 1.78,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AnimatedScale(
                          scale: _hovering ? 1.04 : 1.0,
                          duration: Duration(milliseconds: 320),
                          curve: Curves.easeOut,
                          child: ColorFiltered(
                            colorFilter: ColorFilter.mode(
                              available
                                  ? Colors.transparent
                                  : Colors.black.withValues(alpha: 0.18),
                              BlendMode.darken,
                            ),
                            child: MenuImageView(
                              imageUrl: widget.item.imageUrl,
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.36),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 10,
                          bottom: 10,
                          child: StatusBadge(
                            label: available ? 'Available' : 'Paused',
                            color: available
                                ? PosColors.success
                                : PosColors.danger,
                            icon: available
                                ? Icons.check_circle_outline
                                : Icons.pause_circle_outline,
                          ),
                        ),
                        Positioned(
                          right: 10,
                          top: 10,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.96),
                              borderRadius: BorderRadius.circular(
                                PosRadii.pill,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x1A0F2A1F),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              child: Text(
                                currency.format(widget.item.price),
                                style: TextStyle(
                                  color: PosColors.primaryDark,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12.5,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  widget.item.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  widget.item.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusBadge.sync(widget.item.syncStatus),
                    _SmallPill(
                      icon: Icons.category_outlined,
                      label: widget.item.category,
                    ),
                    if (widget.item.preparationTimeMinutes != null)
                      _SmallPill(
                        icon: Icons.timer_outlined,
                        label: '${widget.item.preparationTimeMinutes} min',
                      ),
                    ...widget.item.tags.map(
                      (tag) =>
                          _SmallPill(icon: Icons.sell_outlined, label: tag),
                    ),
                  ],
                ),
                Spacer(),
                SizedBox(height: 10),
                Divider(height: 1),
                SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: SwitchListTile.adaptive(
                        value: widget.item.isAvailable,
                        onChanged: widget.onAvailabilityChanged,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          widget.item.isAvailable ? 'Active' : 'Paused',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: widget.item.isAvailable
                                ? PosColors.success
                                : PosColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    _IconAction(
                      icon: Icons.edit_outlined,
                      tooltip: 'Edit menu item',
                      onPressed: widget.onEdit,
                      color: PosColors.primary,
                    ),
                    SizedBox(width: 6),
                    _IconAction(
                      icon: Icons.delete_outline,
                      tooltip: 'Delete menu item',
                      onPressed: widget.onDelete,
                      color: PosColors.danger,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(PosRadii.sm),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(PosRadii.sm),
          child: Padding(
            padding: EdgeInsets.all(8),
            child: Icon(icon, color: color, size: 19),
          ),
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
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: PosColors.surfaceTinted,
        borderRadius: BorderRadius.circular(PosRadii.pill),
        border: Border.all(color: PosColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: PosColors.muted),
          SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: PosColors.slateSoft,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
