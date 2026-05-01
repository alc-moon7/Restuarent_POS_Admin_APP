enum OrderStatus {
  pending,
  accepted,
  preparing,
  ready,
  served,
  cancelled;

  String get value => name;

  String get label {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.accepted:
        return 'Accepted';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.ready:
        return 'Ready';
      case OrderStatus.served:
        return 'Served';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  bool get isOpen =>
      this == OrderStatus.pending ||
      this == OrderStatus.accepted ||
      this == OrderStatus.preparing ||
      this == OrderStatus.ready;

  int get priority {
    switch (this) {
      case OrderStatus.pending:
        return 0;
      case OrderStatus.accepted:
        return 1;
      case OrderStatus.preparing:
        return 2;
      case OrderStatus.ready:
        return 3;
      case OrderStatus.served:
        return 4;
      case OrderStatus.cancelled:
        return 99;
    }
  }

  bool canTransitionTo(OrderStatus next) {
    if (this == next) return true;
    if (this == OrderStatus.served) return next == OrderStatus.served;
    if (next == OrderStatus.cancelled) return this != OrderStatus.served;
    if (this == OrderStatus.cancelled) return next == OrderStatus.cancelled;
    return next.priority >= priority;
  }

  static OrderStatus? tryParse(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase();
    for (final status in OrderStatus.values) {
      if (status.value == normalized) return status;
    }
    return null;
  }
}
