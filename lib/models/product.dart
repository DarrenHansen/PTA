import 'dart:typed_data';

/// Product catalog item and current stock balance.
class Product {
  int? id;
  String name;
  String description;
  double price;
  String photoPath;
  String photoBase64;
  String createdAt;
  int stock;
  int openingStock;
  int minimumStock;
  Uint8List? photoBytes;

  Product({
    this.id,
    required this.name,
    this.description = '',
    required this.price,
    this.photoPath = '',
    this.photoBase64 = '',
    this.createdAt = '',
    this.stock = 0,
    this.openingStock = 0,
    this.minimumStock = 0,
    this.photoBytes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'price': price,
        'photo_path': photoPath,
        'photo_base64': photoBase64,
        'created_at': createdAt,
        'stock': stock,
        'opening_stock': openingStock,
        'minimum_stock': minimumStock,
        'photo_bytes': photoBytes,
      };

  factory Product.fromMap(Map<String, dynamic> map) => Product(
        id: (map['id'] as num?)?.toInt(),
        name: map['name']?.toString() ?? '',
        description: map['description']?.toString() ?? '',
        price: (map['price'] as num?)?.toDouble() ?? 0,
        photoPath: map['photo_path']?.toString() ?? '',
        photoBase64: map['photo_base64']?.toString() ?? '',
        createdAt: map['created_at']?.toString() ?? '',
        stock: (map['stock'] as num?)?.toInt() ?? 0,
        openingStock: (map['opening_stock'] as num?)?.toInt() ?? 0,
        minimumStock: (map['minimum_stock'] as num?)?.toInt() ?? 0,
        photoBytes: map['photo_bytes'] as Uint8List?,
      );

  Product copyWith({
    int? id,
    String? name,
    String? description,
    double? price,
    String? photoPath,
    String? photoBase64,
    String? createdAt,
    int? stock,
    int? openingStock,
    int? minimumStock,
    Uint8List? photoBytes,
  }) =>
      Product(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        price: price ?? this.price,
        photoPath: photoPath ?? this.photoPath,
        photoBase64: photoBase64 ?? this.photoBase64,
        createdAt: createdAt ?? this.createdAt,
        stock: stock ?? this.stock,
        openingStock: openingStock ?? this.openingStock,
        minimumStock: minimumStock ?? this.minimumStock,
        photoBytes: photoBytes ?? this.photoBytes,
      );
}
