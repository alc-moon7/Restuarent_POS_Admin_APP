import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class MiniBarChart extends StatelessWidget {
  const MiniBarChart({
    required this.values,
    required this.labels,
    this.color,
    this.height = 86,
    this.formatValue,
    this.highlightLast = true,
    super.key,
  });

  final List<double> values;
  final List<String> labels;
  final Color? color;
  final double height;
  final String Function(double)? formatValue;
  final bool highlightLast;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? PosColors.primary;
    if (values.isEmpty) return SizedBox.shrink();
    final maxValue = values.fold<double>(0, (m, v) => v > m ? v : m);
    final safeMax = maxValue == 0 ? 1 : maxValue;
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barWidth =
              (constraints.maxWidth - (values.length - 1) * 6) / values.length;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < values.length; i++) ...[
                if (i > 0) SizedBox(width: 6),
                _Bar(
                  width: barWidth.clamp(8, 40).toDouble(),
                  height: height - 22,
                  ratio: values[i] / safeMax,
                  label: labels[i],
                  highlight: highlightLast && i == values.length - 1,
                  color: color,
                  topLabel: values[i] > 0 && i == values.length - 1
                      ? formatValue?.call(values[i])
                      : null,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.width,
    required this.height,
    required this.ratio,
    required this.label,
    required this.highlight,
    required this.color,
    this.topLabel,
  });

  final double width;
  final double height;
  final double ratio;
  final String label;
  final bool highlight;
  final Color color;
  final String? topLabel;

  @override
  Widget build(BuildContext context) {
    final barColor = highlight ? color : color.withValues(alpha: 0.4);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (topLabel != null)
          Padding(
            padding: EdgeInsets.only(bottom: 3),
            child: Text(
              topLabel!,
              style: TextStyle(
                color: barColor,
                fontWeight: FontWeight.w900,
                fontSize: 9.6,
              ),
            ),
          ),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: ratio.clamp(0, 1).toDouble()),
          duration: Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) {
            return Container(
              width: width,
              height: (height * value).clamp(2, height).toDouble(),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [barColor, barColor.withValues(alpha: 0.55)],
                ),
                borderRadius: BorderRadius.circular(6),
                boxShadow: highlight
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.32),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
            );
          },
        ),
        SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: highlight ? PosColors.slate : PosColors.muted,
            fontWeight: highlight ? FontWeight.w900 : FontWeight.w700,
            fontSize: 9.5,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}
