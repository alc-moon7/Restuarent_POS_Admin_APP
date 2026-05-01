import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

class CopyableTextCard extends StatelessWidget {
  const CopyableTextCard({
    required this.label,
    required this.value,
    this.icon = Icons.link,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final canCopy = value.trim().isNotEmpty && !value.contains('Unavailable');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PosColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PosColors.line),
      ),
      child: Row(
        children: [
          Icon(icon, color: PosColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 3),
                SelectableText(
                  value,
                  maxLines: 2,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy',
            onPressed: canCopy
                ? () async {
                    await Clipboard.setData(ClipboardData(text: value));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('$label copied')));
                  }
                : null,
            icon: const Icon(Icons.copy),
          ),
        ],
      ),
    );
  }
}
