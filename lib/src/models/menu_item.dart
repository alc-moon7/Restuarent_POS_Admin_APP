import 'dart:convert';

class MenuItem {
  const MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.isAvailable,
    required this.createdAt,
    required this.updatedAt,
    this.imageUrl,
    this.preparationTimeMinutes,
    this.tags = const [],
  });

  final String id;
  final String name;
  final String description;
  final String category;
  final double price;
  final String? imageUrl;
  final bool isAvailable;
  final int? preparationTimeMinutes;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  MenuItem copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    double? price,
    String? imageUrl,
    bool? isAvailable,
    int? preparationTimeMinutes,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
      preparationTimeMinutes:
          preparationTimeMinutes ?? this.preparationTimeMinutes,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'price': price,
      'imageUrl': imageUrl,
      'isAvailable': isAvailable ? 1 : 0,
      'preparationTimeMinutes': preparationTimeMinutes,
      'tags': jsonEncode(tags),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'price': price,
      'imageUrl': imageUrl,
      'isAvailable': isAvailable,
      'preparationTimeMinutes': preparationTimeMinutes,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory MenuItem.fromMap(Map<String, Object?> map) {
    return MenuItem(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      category: map['category'] as String? ?? 'General',
      price: (map['price'] as num).toDouble(),
      imageUrl: map['imageUrl'] as String?,
      isAvailable: (map['isAvailable'] as int? ?? 1) == 1,
      preparationTimeMinutes: map['preparationTimeMinutes'] as int?,
      tags: _decodeTags(map['tags'] as String?),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  static List<String> _decodeTags(String? rawTags) {
    if (rawTags == null || rawTags.trim().isEmpty) return const [];
    final decoded = jsonDecode(rawTags);
    if (decoded is List) {
      return decoded.map((tag) => tag.toString()).toList(growable: false);
    }
    return const [];
  }
}
