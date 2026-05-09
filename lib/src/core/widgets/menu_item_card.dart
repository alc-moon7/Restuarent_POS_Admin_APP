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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _hovering ? 0.12 : 0.07),
              blurRadius: _hovering ? 16 : 12,
              offset: Offset(0, _hovering ? 7 : 5),
            ),
          ],
        ),
        child: Card(
          color: PosColors.background,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PosRadii.lg),
            side: BorderSide(
              color: _hovering
                  ? PosColors.primaryDark.withValues(alpha: 0.42)
                  : PosColors.lineStrong.withValues(alpha: 0.36),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(PosRadii.md),
                  child: AspectRatio(
                    aspectRatio: 1.82,
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
                SizedBox(height: 7),
                Text(
                  widget.item.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2),
                Text(
                  widget.item.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: _SmallPill(
                        icon: Icons.category_outlined,
                        label: widget.item.category,
                      ),
                    ),
                    SizedBox(width: 6),
                    StatusBadge.sync(widget.item.syncStatus),
                  ],
                ),
                SizedBox(height: 5),
                Divider(height: 1),
                SizedBox(height: 1),
                Row(
                  children: [
                    Expanded(
                      child: SwitchListTile.adaptive(
                        value: widget.item.isAvailable,
                        onChanged: widget.onAvailabilityChanged,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        visualDensity: VisualDensity.compact,
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
                      color: PosColors.slate,
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
        color: PosColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PosRadii.sm),
          side: BorderSide(color: PosColors.lineStrong.withValues(alpha: 0.36)),
        ),
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
        color: PosColors.background,
        borderRadius: BorderRadius.circular(PosRadii.pill),
        border: Border.all(color: PosColors.lineStrong.withValues(alpha: 0.36)),
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
