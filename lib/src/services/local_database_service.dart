import 'dart:async';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/menu_item.dart';
import '../models/order_item.dart';
import '../models/order_model.dart';
import '../models/order_status.dart';

class DatabaseValidationException implements Exception {
  const DatabaseValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocalDatabaseService {
  final Uuid _uuid = const Uuid();
  final StreamController<void> _changeController =
      StreamController<void>.broadcast();

  Database? _database;

  Stream<void> get changes => _changeController.stream;

  Future<void> initialize() async {
    if (_database != null) return;
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final databasePath = path.join(documentsDirectory.path, 'local_pos.db');
    _database = await openDatabase(
      databasePath,
      version: 1,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _createSchema,
    );
    await seedDemoItemsIfEmpty();
  }

  Future<void> seedDemoItemsIfEmpty() async {
    final db = await _db;
    final count =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM menu_items'),
        ) ??
        0;
    if (count > 0) return;

    final now = DateTime.now();
    final items = <MenuItem>[
      MenuItem(
        id: _uuid.v4(),
        name: 'Smoked Chicken Burger',
        description: 'Charred chicken, cheddar, lettuce, house aioli.',
        category: 'Burgers',
        price: 12.50,
        imageUrl:
            'https://images.unsplash.com/photo-1568901346375-23c9450c58cd',
        isAvailable: true,
        preparationTimeMinutes: 14,
        tags: const ['popular'],
        createdAt: now,
        updatedAt: now,
      ),
      MenuItem(
        id: _uuid.v4(),
        name: 'Saffron Chicken Biryani',
        description: 'Aromatic basmati rice, tender chicken, raita.',
        category: 'Rice',
        price: 14.00,
        imageUrl:
            'https://images.unsplash.com/photo-1631515243349-e0cb75fb8d3a',
        isAvailable: true,
        preparationTimeMinutes: 20,
        tags: const ['spicy'],
        createdAt: now,
        updatedAt: now,
      ),
      MenuItem(
        id: _uuid.v4(),
        name: 'Grilled Paneer Bowl',
        description: 'Paneer, quinoa, greens, roasted pepper dressing.',
        category: 'Bowls',
        price: 11.75,
        imageUrl: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c',
        isAvailable: true,
        preparationTimeMinutes: 12,
        tags: const ['veg'],
        createdAt: now,
        updatedAt: now,
      ),
      MenuItem(
        id: _uuid.v4(),
        name: 'Amber Lemon Iced Tea',
        description: 'Fresh brewed tea, citrus, mint, amber syrup.',
        category: 'Drinks',
        price: 4.25,
        imageUrl:
            'https://images.unsplash.com/photo-1497534446932-c925b458314e',
        isAvailable: true,
        preparationTimeMinutes: 5,
        tags: const ['cold'],
        createdAt: now,
        updatedAt: now,
      ),
    ];

    final batch = db.batch();
    for (final item in items) {
      batch.insert('menu_items', item.toMap());
    }
    await batch.commit(noResult: true);
    _emitChange();
  }

  Future<List<MenuItem>> getMenuItems({bool includeUnavailable = true}) async {
    final db = await _db;
    final rows = await db.query(
      'menu_items',
      where: includeUnavailable ? null : 'isAvailable = ?',
      whereArgs: includeUnavailable ? null : const [1],
      orderBy: 'category COLLATE NOCASE ASC, name COLLATE NOCASE ASC',
    );
    return rows.map(MenuItem.fromMap).toList(growable: false);
  }

  Future<MenuItem?> getMenuItemById(String id) async {
    final db = await _db;
    final rows = await db.query(
      'menu_items',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MenuItem.fromMap(rows.first);
  }

  Future<void> upsertMenuItem(MenuItem item) async {
    final db = await _db;
    await db.insert(
      'menu_items',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _emitChange();
  }

  Future<void> deleteMenuItem(String id) async {
    final db = await _db;
    await db.delete('menu_items', where: 'id = ?', whereArgs: [id]);
    _emitChange();
  }

  Future<void> toggleMenuAvailability(String id, bool isAvailable) async {
    final db = await _db;
    await db.update(
      'menu_items',
      {
        'isAvailable': isAvailable ? 1 : 0,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _emitChange();
  }

  Future<List<OrderModel>> getOrders({OrderStatus? status}) async {
    final db = await _db;
    final orderRows = await db.query(
      'orders',
      where: status == null ? null : 'status = ?',
      whereArgs: status == null ? null : [status.value],
      orderBy: 'createdAt DESC',
    );

    final orders = <OrderModel>[];
    for (final row in orderRows) {
      final items = await _getOrderItems(row['id'] as String);
      orders.add(OrderModel.fromMap(row, items: items));
    }
    return orders;
  }

  Future<OrderModel?> getOrderById(String id) async {
    final db = await _db;
    final rows = await db.query(
      'orders',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final items = await _getOrderItems(id);
    return OrderModel.fromMap(rows.first, items: items);
  }

  Future<OrderModel> createOrder({
    required List<OrderRequestItem> requestedItems,
    String? customerName,
    String? tableNo,
    String? note,
  }) async {
    if (requestedItems.isEmpty) {
      throw const DatabaseValidationException(
        'Order must contain at least one item.',
      );
    }

    final db = await _db;
    final order = await db.transaction<OrderModel>((txn) async {
      final now = DateTime.now();
      final orderId = _uuid.v4();
      final orderItems = <OrderItem>[];
      var total = 0.0;

      for (final requestItem in requestedItems) {
        if (requestItem.qty <= 0) {
          throw const DatabaseValidationException(
            'Item quantity must be greater than zero.',
          );
        }

        final menuRows = await txn.query(
          'menu_items',
          where: 'id = ?',
          whereArgs: [requestItem.menuItemId],
          limit: 1,
        );
        if (menuRows.isEmpty) {
          throw DatabaseValidationException(
            'Menu item ${requestItem.menuItemId} was not found.',
          );
        }

        final menuItem = MenuItem.fromMap(menuRows.first);
        if (!menuItem.isAvailable) {
          throw DatabaseValidationException(
            '${menuItem.name} is currently unavailable.',
          );
        }

        final lineTotal = menuItem.price * requestItem.qty;
        total += lineTotal;
        orderItems.add(
          OrderItem(
            id: _uuid.v4(),
            orderId: orderId,
            menuItemId: menuItem.id,
            name: menuItem.name,
            qty: requestItem.qty,
            price: menuItem.price,
            lineTotal: lineTotal,
          ),
        );
      }

      final model = OrderModel(
        id: orderId,
        orderNo: _buildOrderNumber(now),
        customerName: _cleanNullable(customerName),
        tableNo: _cleanNullable(tableNo),
        note: _cleanNullable(note),
        status: OrderStatus.pending,
        total: total,
        items: orderItems,
        createdAt: now,
        updatedAt: now,
      );

      await txn.insert('orders', model.toMap());
      for (final item in orderItems) {
        await txn.insert('order_items', item.toMap());
      }
      return model;
    });

    _emitChange();
    return order;
  }

  Future<OrderModel> updateOrderStatus(String id, OrderStatus status) async {
    final db = await _db;
    final updatedRows = await db.update(
      'orders',
      {'status': status.value, 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (updatedRows == 0) {
      throw const DatabaseValidationException('Order was not found.');
    }
    final order = await getOrderById(id);
    if (order == null) {
      throw const DatabaseValidationException('Order was not found.');
    }
    _emitChange();
    return order;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
    await _changeController.close();
  }

  Future<Database> get _db async {
    if (_database == null) {
      await initialize();
    }
    return _database!;
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE menu_items (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        category TEXT NOT NULL,
        price REAL NOT NULL,
        imageUrl TEXT,
        isAvailable INTEGER NOT NULL,
        preparationTimeMinutes INTEGER,
        tags TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE orders (
        id TEXT PRIMARY KEY,
        orderNo TEXT NOT NULL UNIQUE,
        customerName TEXT,
        tableNo TEXT,
        note TEXT,
        status TEXT NOT NULL,
        total REAL NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE order_items (
        id TEXT PRIMARY KEY,
        orderId TEXT NOT NULL,
        menuItemId TEXT NOT NULL,
        name TEXT NOT NULL,
        qty INTEGER NOT NULL,
        price REAL NOT NULL,
        lineTotal REAL NOT NULL,
        FOREIGN KEY(orderId) REFERENCES orders(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX index_menu_items_category ON menu_items(category)',
    );
    await db.execute(
      'CREATE INDEX index_orders_status_created ON orders(status, createdAt)',
    );
    await db.execute(
      'CREATE INDEX index_order_items_order ON order_items(orderId)',
    );
  }

  Future<List<OrderItem>> _getOrderItems(String orderId) async {
    final db = await _db;
    final rows = await db.query(
      'order_items',
      where: 'orderId = ?',
      whereArgs: [orderId],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(OrderItem.fromMap).toList(growable: false);
  }

  String _buildOrderNumber(DateTime now) {
    final stamp = DateFormat('yyMMddHHmmss').format(now);
    final suffix = _uuid.v4().split('-').first.toUpperCase();
    return 'ORD-$stamp-$suffix';
  }

  String? _cleanNullable(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  void _emitChange() {
    if (!_changeController.isClosed) {
      _changeController.add(null);
    }
  }
}
