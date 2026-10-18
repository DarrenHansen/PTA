import 'item.dart';

/// Enum status invoice
enum InvoiceStatus {
  paid,
  unpaid,
  overdue,
}

/// Extension untuk mapping status ke string & warna
extension InvoiceStatusExtension on InvoiceStatus {
  String get label {
    switch (this) {
      case InvoiceStatus.paid:
        return 'Paid';
      case InvoiceStatus.unpaid:
        return 'Unpaid';
      case InvoiceStatus.overdue:
        return 'Overdue';
    }
  }

  String get dbValue {
    switch (this) {
      case InvoiceStatus.paid:
        return 'paid';
      case InvoiceStatus.unpaid:
        return 'unpaid';
      case InvoiceStatus.overdue:
        return 'overdue';
    }
  }

  static InvoiceStatus fromDbValue(String value) {
    switch (value) {
      case 'paid':
        return InvoiceStatus.paid;
      case 'unpaid':
        return InvoiceStatus.unpaid;
      case 'overdue':
        return InvoiceStatus.overdue;
      default:
        return InvoiceStatus.unpaid;
    }
  }
}

/// Model Invoice
class Invoice {
  int? id;
  String invoiceNumber;
  String customerName;
  String customerAddress;
  String customerEmail;
  String customerPhone;
  String date;
  String dueDate;
  double total;
  double tax;
  double discount;
  String notes;
  InvoiceStatus status;
  List<Item> items;

  Invoice({
    this.id,
    required this.invoiceNumber,
    required this.customerName,
    this.customerAddress = '',
    this.customerEmail = '',
    this.customerPhone = '',
    required this.date,
    required this.dueDate,
    this.total = 0,
    this.tax = 0,
    this.discount = 0,
    this.notes = '',
    this.status = InvoiceStatus.unpaid,
    this.items = const [],
  });

  /// Subtotal sebelum pajak & diskon
  double get subtotal {
    double sum = 0;
    for (var item in items) {
      sum += item.total;
    }
    return sum;
  }

  /// Grand total = subtotal + pajak - diskon
  double get grandTotal {
    final taxAmount = subtotal * (tax / 100);
    return subtotal + taxAmount - discount;
  }

  /// Apakah invoice sudah overdue (berdasarkan dueDate)
  bool get isOverdue {
    final due = DateTime.tryParse(dueDate);
    if (due == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(due.year, due.month, due.day);
    return today.isAfter(dueDay) && status != InvoiceStatus.paid;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'customer_name': customerName,
      'customer_address': customerAddress,
      'customer_email': customerEmail,
      'customer_phone': customerPhone,
      'date': date,
      'due_date': dueDate,
      'total': grandTotal,
      'tax': tax,
      'discount': discount,
      'notes': notes,
      'status': status.dbValue,
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: map['id'],
      invoiceNumber: map['invoice_number'] ?? '',
      customerName: map['customer_name'] ?? '',
      customerAddress: map['customer_address'] ?? '',
      customerEmail: map['customer_email'] ?? '',
      customerPhone: map['customer_phone'] ?? '',
      date: map['date'] ?? '',
      dueDate: map['due_date'] ?? '',
      total: (map['total'] as num?)?.toDouble() ?? 0,
      tax: (map['tax'] as num?)?.toDouble() ?? 0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0,
      notes: map['notes'] ?? '',
      status: InvoiceStatusExtension.fromDbValue(map['status'] ?? 'unpaid'),
      items: map['items'] is List
          ? (map['items'] as List)
              .whereType<Map>()
              .map((item) => Item.fromMap(Map<String, dynamic>.from(item)))
              .toList()
          : const [],
    );
  }

  /// CopyWith untuk update parsial
  Invoice copyWith({
    int? id,
    String? invoiceNumber,
    String? customerName,
    String? customerAddress,
    String? customerEmail,
    String? customerPhone,
    String? date,
    String? dueDate,
    double? total,
    double? tax,
    double? discount,
    String? notes,
    InvoiceStatus? status,
    List<Item>? items,
  }) {
    return Invoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      customerName: customerName ?? this.customerName,
      customerAddress: customerAddress ?? this.customerAddress,
      customerEmail: customerEmail ?? this.customerEmail,
      customerPhone: customerPhone ?? this.customerPhone,
      date: date ?? this.date,
      dueDate: dueDate ?? this.dueDate,
      tax: tax ?? this.tax,
      discount: discount ?? this.discount,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      items: items ?? this.items,
      total: total ?? this.total,
    );
  }
}
