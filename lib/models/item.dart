/// Model Item
class Item {
  int? id;
  int invoiceId;
  int? productId;
  String productName;
  String description;
  double price;
  int qty;

  Item({
    this.id,
    required this.invoiceId,
    this.productId,
    required this.productName,
    this.description = '',
    required this.price,
    required this.qty,
  });

  double get total => price * qty;

  Map<String, dynamic> toMap() => {
        'id': id,
        'invoice_id': invoiceId,
        'product_id': productId,
        'product_name': productName,
        'description': description,
        'price': price,
        'qty': qty,
      };

  factory Item.fromMap(Map<String, dynamic> map) => Item(
        id: (map['id'] as num?)?.toInt(),
        invoiceId: (map['invoice_id'] as num?)?.toInt() ?? 0,
        productId: (map['product_id'] as num?)?.toInt(),
        productName: map['product_name']?.toString() ?? '',
        description: map['description']?.toString() ?? '',
        price: (map['price'] as num?)?.toDouble() ?? 0,
        qty: (map['qty'] as num?)?.toInt() ?? 0,
      );

  Item copyWith({
    int? id,
    int? invoiceId,
    int? productId,
    String? productName,
    String? description,
    double? price,
    int? qty,
  }) =>
      Item(
        id: id ?? this.id,
        invoiceId: invoiceId ?? this.invoiceId,
        productId: productId ?? this.productId,
        productName: productName ?? this.productName,
        description: description ?? this.description,
        price: price ?? this.price,
        qty: qty ?? this.qty,
      );
}
