import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class DashboardCard extends StatefulWidget {
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
  State<DashboardCard> createState() => _DashboardCardState();
}

class _DashboardCardState extends State<DashboardCard> {
  bool _hovering = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 190;
        return MouseRegion(
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: AnimatedScale(
            scale: _pressed ? 0.985 : 1.0,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(PosRadii.lg),
                boxShadow: _hovering
                    ? [
                        BoxShadow(
                          color: widget.color.withValues(alpha: 0.18),
                          blurRadius: 26,
                          offset: const Offset(0, 14),
                        ),
                      ]
                    : PosShadows.card,
              ),
              child: Material(
                color: Colors.transparent,
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(PosRadii.lg),
                    side: BorderSide(
                      color: _hovering
                          ? widget.color.withValues(alpha: 0.32)
                          : PosColors.line,
                    ),
                  ),
                  child: InkWell(
                    onTap: widget.onTap,
                    onHighlightChanged: (v) => setState(() => _pressed = v),
                    splashColor: widget.color.withValues(alpha: 0.08),
                    highlightColor: widget.color.withValues(alpha: 0.04),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: PosGradients.cardTint(widget.color),
                            ),
                          ),
                        ),
                        Positioned(
                          top: -28,
                          right: -28,
                          child: Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  widget.color.withValues(alpha: 0.18),
                                  widget.color.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  widget.color,
                                  widget.color.withValues(alpha: 0.55),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(compact ? 11 : 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  _IconBox(
                                    icon: widget.icon,
                                    color: widget.color,
                                    compact: compact,
                                  ),
                                  const Spacer(),
                                  if (widget.onTap != null)
                                    AnimatedSlide(
                                      duration: const Duration(
                                        milliseconds: 220,
                                      ),
                                      offset: _hovering
                                          ? const Offset(0.18, 0)
                                          : Offset.zero,
                                      child: Icon(
                                        Icons.arrow_forward_rounded,
                                        color: _hovering
                                            ? widget.color
                                            : PosColors.muted.withValues(
                                                alpha: 0.5,
                                              ),
                                        size: compact ? 16 : 18,
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: compact ? 8 : 12),
                              Text(
                                widget.value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    (compact
                                            ? const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w900,
                                                color: PosColors.slate,
                                                letterSpacing: 0,
                                              )
                                            : Theme.of(
                                                context,
                                              ).textTheme.headlineMedium)
                                        ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0,
                                        ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.title,
                                maxLines: compact ? 1 : 2,
                                overflow: TextOverflow.ellipsis,
                                style: compact
                                    ? const TextStyle(
                                        fontSize: 11.6,
                                        fontWeight: FontWeight.w800,
                                        color: PosColors.slate,
                                        height: 1.2,
                                      )
                                    : Theme.of(context).textTheme.titleMedium,
                              ),
                              if (widget.caption != null && !compact) ...[
                                const SizedBox(height: 4),
                                Text(
                                  widget.caption!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({
    required this.icon,
    required this.color,
    required this.compact,
  });

  final IconData icon;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 32 : 40,
      height: compact ? 32 : 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.20),
            color.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(compact ? 11 : 13),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: compact ? 17 : 21),
    );
  }
}
