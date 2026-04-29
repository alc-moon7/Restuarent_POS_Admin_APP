import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../models/order_model.dart';

class PrinterService {
  Future<String> previewTicket(OrderModel order) async {
    final currency = NumberFormat.currency(symbol: r'$', decimalDigits: 2);
    final buffer = StringBuffer()
      ..writeln('LOCAL POS')
      ..writeln('Kitchen Ticket')
      ..writeln('Order: ${order.orderNo}')
      ..writeln('Table: ${order.tableNo ?? 'Takeaway'}')
      ..writeln('Time: ${DateFormat('MMM d, h:mm a').format(order.createdAt)}')
      ..writeln('------------------------------');

    for (final item in order.items) {
      buffer.writeln(
        '${item.qty}x ${item.name}  ${currency.format(item.lineTotal)}',
      );
    }

    buffer
      ..writeln('------------------------------')
      ..writeln('Total: ${currency.format(order.total)}')
      ..writeln('Status: ${order.status.label}');

    final ticket = buffer.toString();
    debugPrint(ticket);
    return ticket;
  }
}
