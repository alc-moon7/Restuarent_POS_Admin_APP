import 'package:flutter/material.dart';

import '../../models/order_source.dart';
import '../../models/order_status.dart';
import '../../models/sync_status.dart';
import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    required this.label,
    required this.color,
    this.icon,
    super.key,
  });

  factory StatusBadge.order(OrderStatus status) {
    return StatusBadge(
      label: status.label,
      color: _colorForOrderStatus(status),
      icon: _iconForOrderStatus(status),
    );
  }

  factory StatusBadge.sync(SyncStatus status) {
    return StatusBadge(
      label: status.label,
      color: _colorForSyncStatus(status),
      icon: _iconForSyncStatus(status),
    );
  }

  factory StatusBadge.source(OrderSource source) {
    return StatusBadge(
      label: source.label,
      color: source == OrderSource.cloud
          ? const Color(0xFF2563EB)
          : source == OrderSource.manual
          ? PosColors.accent
          : PosColors.primary,
      icon: source == OrderSource.cloud
          ? Icons.cloud_outlined
          : source == OrderSource.manual
          ? Icons.edit_note
          : Icons.router_outlined,
    );
  }

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  static Color _colorForOrderStatus(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return PosColors.warning;
      case OrderStatus.accepted:
        return PosColors.primary;
      case OrderStatus.preparing:
        return const Color(0xFF2563EB);
      case OrderStatus.ready:
        return const Color(0xFF7C3AED);
      case OrderStatus.served:
        return PosColors.success;
      case OrderStatus.cancelled:
        return PosColors.danger;
    }
  }

  static IconData _iconForOrderStatus(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.schedule;
      case OrderStatus.accepted:
        return Icons.check_circle_outline;
      case OrderStatus.preparing:
        return Icons.local_fire_department_outlined;
      case OrderStatus.ready:
        return Icons.room_service_outlined;
      case OrderStatus.served:
        return Icons.done_all;
      case OrderStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }

  static Color _colorForSyncStatus(SyncStatus status) {
    switch (status) {
      case SyncStatus.synced:
        return PosColors.success;
      case SyncStatus.pending:
        return PosColors.warning;
      case SyncStatus.failed:
        return PosColors.danger;
    }
  }

  static IconData _iconForSyncStatus(SyncStatus status) {
    switch (status) {
      case SyncStatus.synced:
        return Icons.cloud_done_outlined;
      case SyncStatus.pending:
        return Icons.sync_outlined;
      case SyncStatus.failed:
        return Icons.cloud_off_outlined;
    }
  }
}
