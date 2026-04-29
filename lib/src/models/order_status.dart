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

  static OrderStatus? tryParse(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase();
    for (final status in OrderStatus.values) {
      if (status.value == normalized) return status;
    }
    return null;
  }
}
