import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../utils/image_data.dart';

import '../services/firebase_config.dart';

/// Firebase-backed data service retained behind the existing DBHelper API.
/// Firestore data is scoped to users/{uid}; invoice stock changes are atomic.
class DBHelper {
  static final DBHelper instance = DBHelper._init();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool lastProductPhotoUploadFailed = false;
  String? lastProductPhotoUploadError;
  bool lastProductPhotoStoredInFirestore = false;
  bool lastBusinessLogoStoredInFirestore = false;
  String? _businessOwnerUid;

  DBHelper._init();

  /// Sets the shop account whose records this signed-in user can access.
  void setBusinessOwnerUid(String? uid) => _businessOwnerUid = uid;

  static String describeStorageError(Object error) {
    final details = error.toString();
    final lowerDetails = details.toLowerCase();
    if (lowerDetails.contains('spark') ||
        lowerDetails.contains('billing') ||
        lowerDetails.contains('402') ||
        lowerDetails.contains('no-cost')) {
      return 'Firebase Cloud Storage tidak tersedia pada paket Spark. Aktifkan Cloud Storage dengan paket Blaze agar gambar dapat diunggah.';
    }
    if (lowerDetails.contains('unauthorized') ||
        lowerDetails.contains('permission') ||
        lowerDetails.contains('403')) {
      return 'Firebase Storage menolak unggahan. Pastikan proyek memakai paket Blaze dan Storage Rules mengizinkan pengguna yang sudah login.';
    }
    if (lowerDetails.contains('timeout')) {
      return 'Unggah gambar melewati batas waktu. Periksa koneksi internet lalu coba lagi.';
    }
    return 'Firebase Storage gagal mengunggah gambar: $details';
  }

  String get _uid {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('Masuk terlebih dahulu untuk mengakses data.');
    }
    return _businessOwnerUid ?? uid;
  }

  CollectionReference<Map<String, dynamic>> _collection(String name) =>
      _firestore.collection('users').doc(_uid).collection(name);

  Map<String, dynamic> _clean(Map<String, dynamic> values) {
    final result = Map<String, dynamic>.from(values)
      ..remove('id')
      ..remove('created_at')
      ..remove('updated_at')
      ..remove('user_id')
      ..remove('photo_bytes')
      ..remove('logo_bytes');
    return result;
  }

  Map<String, dynamic> _mapDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) =>
      _mapSnapshot(doc);

  Map<String, dynamic> _mapSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) =>
      <String, dynamic>{...?(doc.data()), 'id': int.tryParse(doc.id) ?? 0};

  Future<int> _nextId(String counterName) async {
    final counter = _collection('metadata').doc('counters');
    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(counter);
      final current = (snapshot.data()?[counterName] as num?)?.toInt() ?? 0;
      final next = current + 1;
      transaction.set(counter, {counterName: next}, SetOptions(merge: true));
      return next;
    });
  }

  Future<String> _uploadImage(
    String folder,
    String fileName,
    Uint8List bytes,
  ) async {
    if (!FirebaseConfig.hasStorage) {
      throw StateError(
        'Penyimpanan foto belum dikonfigurasi. Data lain tetap dapat disimpan tanpa foto.',
      );
    }
    final ref =
        FirebaseStorage.instance.ref('users/$_uid/$folder/$fileName.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  List<Map<String, dynamic>> _normaliseItems(
    int invoiceId,
    List<Map<String, dynamic>> items,
  ) =>
      items.asMap().entries.map((entry) {
        final item = _clean(entry.value);
        item['id'] = entry.key + 1;
        item['invoice_id'] = invoiceId;
        item['qty'] = (item['qty'] as num?)?.toInt() ?? 1;
        final productId = item['product_id'];
        if (productId is num) item['product_id'] = productId.toInt();
        return item;
      }).toList();

  Map<int, int> _productQuantities(List<Map<String, dynamic>> items) {
    final quantities = <int, int>{};
    for (final item in items) {
      final rawId = item['product_id'];
      final productId = rawId is num ? rawId.toInt() : int.tryParse('$rawId');
      final quantity = (item['qty'] as num?)?.toInt() ?? 0;
      if (productId != null && productId > 0 && quantity > 0) {
        quantities.update(productId, (value) => value + quantity,
            ifAbsent: () => quantity);
      }
    }
    return quantities;
  }

  double _invoiceTotal(
    Map<String, dynamic> invoice,
    List<Map<String, dynamic>> items,
  ) {
    final subtotal = items.fold<double>(
      0,
      (total, item) =>
          total +
          ((item['price'] as num?)?.toDouble() ?? 0) *
              ((item['qty'] as num?)?.toInt() ?? 0),
    );
    final tax = (invoice['tax'] as num?)?.toDouble() ?? 0;
    final discount = (invoice['discount'] as num?)?.toDouble() ?? 0;
    return (subtotal + subtotal * tax / 100 - discount)
        .clamp(0, double.infinity);
  }

  Map<String, dynamic> _movement({
    required int productId,
    required String productName,
    required String type,
    required int quantity,
    required int previousStock,
    required int newStock,
    int? invoiceId,
    String note = '',
  }) =>
      {
        'product_id': productId,
        'product_name': productName,
        'type': type,
        'quantity': quantity,
        'previous_stock': previousStock,
        'new_stock': newStock,
        'invoice_id': invoiceId,
        'note': note,
        'created_at': DateTime.now().toIso8601String(),
      };

  Future<List<Map<String, dynamic>>> getInvoices() async {
    final snapshot = await _collection('invoices').get();
    final rows = snapshot.docs.map(_mapDocument).toList();
    rows.sort((a, b) => '${b['date']}'.compareTo('${a['date']}'));
    return rows;
  }

  Future<List<Map<String, dynamic>>> getInvoicesInDateRange(
    String startDate,
    String endDate,
  ) async {
    final snapshot = await _collection('invoices')
        .where('date', isGreaterThanOrEqualTo: startDate)
        .where('date', isLessThanOrEqualTo: endDate)
        .orderBy('date', descending: true)
        .get();
    return snapshot.docs.map(_mapDocument).toList();
  }

  Future<List<Map<String, dynamic>>> getOverdueInvoices() async {
    final snapshot = await _collection('invoices')
        .where('due_date', isLessThan: _dateKey(DateTime.now()))
        .get();
    final invoices = snapshot.docs
        .map(_mapDocument)
        .where((invoice) => invoice['status'] != 'paid')
        .toList();
    invoices.sort(
        (a, b) => '${a['due_date'] ?? ''}'.compareTo('${b['due_date'] ?? ''}'));
    return invoices;
  }

  Future<Map<String, dynamic>?> getInvoiceById(int id) async {
    final doc = await _collection('invoices').doc('$id').get();
    return doc.exists ? _mapSnapshot(doc) : null;
  }

  Future<List<Map<String, dynamic>>> searchInvoices(String keyword) async {
    final query = keyword.trim().toLowerCase();
    final invoices = await getInvoices();
    return invoices.where((invoice) {
      return ['customer_name', 'invoice_number', 'customer_phone']
          .any((key) => '${invoice[key] ?? ''}'.toLowerCase().contains(query));
    }).toList();
  }

  Future<List<Map<String, dynamic>>> filterInvoicesByStatus(
      String status) async {
    final invoices = await getInvoices();
    return invoices.where((invoice) => invoice['status'] == status).toList();
  }

  Future<int> updateInvoiceStatus(int id, String status) async {
    await _collection('invoices').doc('$id').update({
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    });
    return 1;
  }

  Future<List<Map<String, dynamic>>> getOverdueCandidates() async {
    final today = _dateKey(DateTime.now());
    final invoices = await getInvoices();
    return invoices
        .where((invoice) =>
            invoice['status'] != 'paid' &&
            '${invoice['due_date']}'.compareTo(today) < 0)
        .map((invoice) => {'id': invoice['id'], 'status': invoice['status']})
        .toList();
  }

  Future<List<Map<String, dynamic>>> getInvoicesApproachingDue(
    int daysBefore,
  ) async {
    final due = _dateKey(DateTime.now().add(Duration(days: daysBefore)));
    final invoices = await getInvoices();
    return invoices
        .where((invoice) =>
            invoice['status'] != 'paid' && invoice['due_date'] == due)
        .toList();
  }

  Future<Map<String, dynamic>> getInvoiceStats() async {
    final invoices = await getInvoices();
    final paid = invoices.where((invoice) => invoice['status'] == 'paid');
    return {
      'total': invoices.length,
      'paid': paid.length,
      'unpaid':
          invoices.where((invoice) => invoice['status'] == 'unpaid').length,
      'overdue':
          invoices.where((invoice) => invoice['status'] == 'overdue').length,
      'revenue': paid.fold<double>(
        0,
        (total, invoice) =>
            total + ((invoice['total'] as num?)?.toDouble() ?? 0),
      ),
    };
  }

  Future<Map<String, dynamic>> createInvoice(
    Map<String, dynamic> invoice,
    List<Map<String, dynamic>> items,
  ) async {
    final id = await _nextId('invoices');
    final collection = _collection('invoices');
    final invoiceRef = collection.doc('$id');
    final date = '${invoice['date'] ?? _dateKey(DateTime.now())}';
    final itemRows = _normaliseItems(id, items);
    final quantities = _productQuantities(itemRows);
    final productRefs = quantities.keys
        .map((productId) => _collection('products').doc('$productId'))
        .toList();

    return _firestore.runTransaction((transaction) async {
      final productSnapshots = await Future.wait(
        productRefs.map((ref) => transaction.get(ref)),
      );
      final updatedProducts = <int, Map<String, dynamic>>{};
      for (var index = 0; index < productRefs.length; index++) {
        final productId = quantities.keys.elementAt(index);
        final snapshot = productSnapshots[index];
        if (!snapshot.exists) {
          throw StateError('Produk pada invoice sudah tidak tersedia.');
        }
        final product = snapshot.data()!;
        final previous = (product['stock'] as num?)?.toInt() ?? 0;
        final sold = quantities[productId]!;
        if (sold > previous) {
          throw StateError(
              'Stok ${product['name']} tidak cukup. Tersedia $previous, diminta $sold.');
        }
        updatedProducts[productId] = {
          ...product,
          'previous_stock': previous,
          'stock': previous - sold,
        };
      }

      final invoiceNumber =
          'INV-${date.replaceAll('-', '')}-${id.toString().padLeft(5, '0')}';
      final data = _clean(invoice)
        ..['id'] = id
        ..['invoice_number'] = invoiceNumber
        ..['date'] = date
        ..['total'] = _invoiceTotal(invoice, itemRows)
        ..['items'] = itemRows
        ..['created_at'] = DateTime.now().toIso8601String()
        ..['updated_at'] = DateTime.now().toIso8601String();
      data['status'] ??= 'unpaid';
      transaction.set(invoiceRef, data);

      for (final entry in updatedProducts.entries) {
        final productId = entry.key;
        final product = entry.value;
        final previous = product['previous_stock'] as int;
        final updated = product['stock'] as int;
        transaction.update(
            productRefs[quantities.keys.toList().indexOf(productId)],
            {'stock': updated, 'updated_at': DateTime.now().toIso8601String()});
        transaction.set(
          _collection('inventory_movements').doc(),
          _movement(
            productId: productId,
            productName: '${product['name']}',
            type: 'sale',
            quantity: quantities[productId]!,
            previousStock: previous,
            newStock: updated,
            invoiceId: id,
            note: invoiceNumber,
          ),
        );
      }
      return data;
    });
  }

  Future<Map<String, dynamic>> replaceInvoice(
    int id,
    Map<String, dynamic> invoice,
    List<Map<String, dynamic>> items,
  ) async {
    final invoiceRef = _collection('invoices').doc('$id');
    final newItems = _normaliseItems(id, items);
    final changes = <int, int>{};
    return _firestore.runTransaction((transaction) async {
      final oldSnapshot = await transaction.get(invoiceRef);
      if (!oldSnapshot.exists) throw StateError('Invoice tidak ditemukan.');
      final oldRows = ((oldSnapshot.data()?['items'] as List?) ?? [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final oldQuantities = _productQuantities(oldRows);
      final newQuantities = _productQuantities(newItems);
      for (final key in {...oldQuantities.keys, ...newQuantities.keys}) {
        final delta = (oldQuantities[key] ?? 0) - (newQuantities[key] ?? 0);
        if (delta != 0) changes[key] = delta;
      }

      final productIds = changes.keys.toList();
      final refs =
          productIds.map((key) => _collection('products').doc('$key')).toList();
      final snapshots =
          await Future.wait(refs.map((ref) => transaction.get(ref)));
      final updates = <int, Map<String, dynamic>>{};
      for (var index = 0; index < productIds.length; index++) {
        final productId = productIds[index];
        final snapshot = snapshots[index];
        if (!snapshot.exists) {
          if (changes[productId]! < 0) {
            throw StateError('Produk pada invoice sudah tidak tersedia.');
          }
          continue;
        }
        final product = snapshot.data()!;
        final previous = (product['stock'] as num?)?.toInt() ?? 0;
        final updated = previous + changes[productId]!;
        if (updated < 0) {
          throw StateError(
              'Stok ${product['name']} tidak cukup untuk perubahan invoice.');
        }
        updates[productId] = {
          ...product,
          'previous_stock': previous,
          'stock': updated,
        };
      }

      for (var index = 0; index < productIds.length; index++) {
        final productId = productIds[index];
        final product = updates[productId];
        if (product == null) continue;
        final updated = product['stock'] as int;
        final previous = product['previous_stock'] as int;
        transaction.update(refs[index], {
          'stock': updated,
          'updated_at': DateTime.now().toIso8601String(),
        });
        transaction.set(
          _collection('inventory_movements').doc(),
          _movement(
            productId: productId,
            productName: '${product['name']}',
            type: changes[productId]! > 0
                ? 'invoice_edit_return'
                : 'invoice_edit_sale',
            quantity: changes[productId]!.abs(),
            previousStock: previous,
            newStock: updated,
            invoiceId: id,
            note: '${oldSnapshot.data()?['invoice_number'] ?? ''}',
          ),
        );
      }

      final updatedInvoice = _clean(invoice)
        ..['id'] = id
        ..['invoice_number'] =
            oldSnapshot.data()?['invoice_number'] ?? invoice['invoice_number']
        ..['items'] = newItems
        ..['total'] = _invoiceTotal(invoice, newItems)
        ..['updated_at'] = DateTime.now().toIso8601String();
      transaction.set(invoiceRef, updatedInvoice, SetOptions(merge: true));
      return updatedInvoice;
    });
  }

  Future<int> deleteInvoice(int id) async {
    final invoiceRef = _collection('invoices').doc('$id');
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(invoiceRef);
      if (!snapshot.exists) return;
      final invoice = snapshot.data()!;
      final items = ((invoice['items'] as List?) ?? [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final quantities = _productQuantities(items);
      final productIds = quantities.keys.toList();
      final refs =
          productIds.map((key) => _collection('products').doc('$key')).toList();
      final snapshots =
          await Future.wait(refs.map((ref) => transaction.get(ref)));
      for (var index = 0; index < productIds.length; index++) {
        final productId = productIds[index];
        final productSnapshot = snapshots[index];
        if (!productSnapshot.exists) continue;
        final product = productSnapshot.data()!;
        final previous = (product['stock'] as num?)?.toInt() ?? 0;
        final restored = previous + quantities[productId]!;
        transaction.update(refs[index], {'stock': restored});
        transaction.set(
          _collection('inventory_movements').doc(),
          _movement(
            productId: productId,
            productName: '${product['name']}',
            type: 'invoice_cancel',
            quantity: quantities[productId]!,
            previousStock: previous,
            newStock: restored,
            invoiceId: id,
            note: '${invoice['invoice_number'] ?? ''}',
          ),
        );
      }
      transaction.delete(invoiceRef);
    });
    return 1;
  }

  Future<List<Map<String, dynamic>>> getItems(int invoiceId) async {
    final invoice = await getInvoiceById(invoiceId);
    final rows = invoice?['items'];
    if (rows is! List) return [];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<int> insertCustomer(Map<String, dynamic> data) async {
    final id = await _nextId('customers');
    final row = _clean(data)
      ..['id'] = id
      ..['created_at'] = DateTime.now().toIso8601String();
    await _collection('customers').doc('$id').set(row);
    return id;
  }

  Future<int> updateCustomer(int id, Map<String, dynamic> data) async {
    await _collection('customers').doc('$id').update({
      ..._clean(data),
      'updated_at': DateTime.now().toIso8601String(),
    });
    return 1;
  }

  Future<int> deleteCustomer(int id) async {
    await _collection('customers').doc('$id').delete();
    return 1;
  }

  Future<List<Map<String, dynamic>>> getCustomers() async {
    final snapshot = await _collection('customers').orderBy('name').get();
    return snapshot.docs.map(_mapDocument).toList();
  }

  Future<List<Map<String, dynamic>>> searchCustomers(String keyword) async {
    final query = keyword.trim().toLowerCase();
    final rows = await getCustomers();
    return rows
        .where((row) =>
            '${row['name'] ?? ''}'.toLowerCase().contains(query) ||
            '${row['phone'] ?? ''}'.toLowerCase().contains(query) ||
            '${row['email'] ?? ''}'.toLowerCase().contains(query))
        .toList();
  }

  Future<int> insertProduct(Map<String, dynamic> data) async {
    lastProductPhotoUploadFailed = false;
    lastProductPhotoUploadError = null;
    lastProductPhotoStoredInFirestore = false;
    final id = await _nextId('products').timeout(const Duration(seconds: 12));
    final row = _clean(data);
    final photoBytes = data['photo_bytes'];
    if (photoBytes is Uint8List && photoBytes.isNotEmpty) {
      try {
        final compactBytes = ImageData.compressForFirestore(photoBytes);
        try {
          row['photo_path'] = await _uploadImage(
            'products',
            '$id',
            compactBytes,
          ).timeout(const Duration(seconds: 12));
          row.remove('photo_base64');
        } catch (_) {
          row['photo_base64'] = base64Encode(compactBytes);
          lastProductPhotoStoredInFirestore = true;
        }
      } catch (error) {
        lastProductPhotoUploadFailed = true;
        lastProductPhotoUploadError = error.toString();
      }
    }
    final stock = (row['stock'] as num?)?.toInt() ?? 0;
    row['id'] = id;
    row['stock'] = stock;
    row['opening_stock'] = (row['opening_stock'] as num?)?.toInt() ?? stock;
    row['minimum_stock'] = (row['minimum_stock'] as num?)?.toInt() ?? 0;
    row['created_at'] = DateTime.now().toIso8601String();
    await _firestore.runTransaction((transaction) async {
      transaction.set(_collection('products').doc('$id'), row);
      if (stock > 0) {
        transaction.set(
          _collection('inventory_movements').doc(),
          _movement(
            productId: id,
            productName: '${row['name']}',
            type: 'opening',
            quantity: stock,
            previousStock: 0,
            newStock: stock,
            note: 'Stok awal produk',
          ),
        );
      }
    }).timeout(const Duration(seconds: 15));
    return id;
  }

  Future<int> updateProduct(int id, Map<String, dynamic> data) async {
    lastProductPhotoUploadFailed = false;
    lastProductPhotoUploadError = null;
    lastProductPhotoStoredInFirestore = false;
    final row = _clean(data)
      ..remove('stock')
      ..remove('opening_stock');
    final photoBytes = data['photo_bytes'];
    if (photoBytes is Uint8List && photoBytes.isNotEmpty) {
      try {
        final compactBytes = ImageData.compressForFirestore(photoBytes);
        try {
          row['photo_path'] = await _uploadImage(
            'products',
            '$id',
            compactBytes,
          ).timeout(const Duration(seconds: 12));
          row.remove('photo_base64');
        } catch (_) {
          row['photo_base64'] = base64Encode(compactBytes);
          lastProductPhotoStoredInFirestore = true;
        }
      } catch (error) {
        lastProductPhotoUploadFailed = true;
        lastProductPhotoUploadError = error.toString();
      }
    }
    await _collection('products').doc('$id').update({
      ...row,
      'updated_at': DateTime.now().toIso8601String(),
    }).timeout(const Duration(seconds: 15));
    return 1;
  }

  Future<int> addStock(int productId, int quantity, {String note = ''}) async {
    if (quantity <= 0) {
      throw ArgumentError('Jumlah stok masuk harus lebih dari 0.');
    }
    final productRef = _collection('products').doc('$productId');
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(productRef);
      if (!snapshot.exists) throw StateError('Produk tidak ditemukan.');
      final product = snapshot.data()!;
      final previous = (product['stock'] as num?)?.toInt() ?? 0;
      final updated = previous + quantity;
      transaction.update(productRef, {
        'stock': updated,
        'updated_at': DateTime.now().toIso8601String(),
      });
      transaction.set(
        _collection('inventory_movements').doc(),
        _movement(
          productId: productId,
          productName: '${product['name']}',
          type: 'stock_in',
          quantity: quantity,
          previousStock: previous,
          newStock: updated,
          note: note,
        ),
      );
    });
    return 1;
  }

  /// Reconcile the recorded balance with a physical stock count atomically.
  Future<int> adjustStock(
    int productId,
    int actualStock, {
    String note = '',
  }) async {
    if (actualStock < 0) {
      throw ArgumentError('Stok fisik tidak boleh kurang dari 0.');
    }
    final productRef = _collection('products').doc('$productId');
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(productRef);
      if (!snapshot.exists) throw StateError('Produk tidak ditemukan.');
      final product = snapshot.data()!;
      final previous = (product['stock'] as num?)?.toInt() ?? 0;
      if (previous == actualStock) {
        throw StateError('Stok fisik sama dengan stok yang tercatat.');
      }
      transaction.update(productRef, {
        'stock': actualStock,
        'updated_at': DateTime.now().toIso8601String(),
      });
      transaction.set(
        _collection('inventory_movements').doc(),
        _movement(
          productId: productId,
          productName: '${product['name']}',
          type: 'stock_opname',
          quantity: (actualStock - previous).abs(),
          previousStock: previous,
          newStock: actualStock,
          note: note,
        ),
      );
    });
    return 1;
  }

  Future<List<Map<String, dynamic>>> getStockMovements({int? productId}) async {
    // Keep the history screen responsive even when the store has many invoices.
    final snapshot = await _collection('inventory_movements')
        .orderBy('created_at', descending: true)
        .limit(300)
        .get();
    final rows = snapshot.docs
        .map(_mapDocument)
        .where((row) => productId == null || row['product_id'] == productId)
        .toList();
    rows.sort((a, b) =>
        '${b['created_at'] ?? ''}'.compareTo('${a['created_at'] ?? ''}'));
    return rows;
  }

  Future<int> deleteProduct(int id) async {
    final ref = _collection('products').doc('$id');
    final snapshot = await ref.get();
    final photo = snapshot.data()?['photo_path']?.toString() ?? '';
    await ref.delete();
    if (photo.isNotEmpty && FirebaseConfig.hasStorage) {
      try {
        await FirebaseStorage.instance.refFromURL(photo).delete();
      } catch (_) {}
    }
    return 1;
  }

  Future<List<Map<String, dynamic>>> getProducts() async {
    final snapshot = await _collection('products').orderBy('name').get();
    return snapshot.docs.map(_mapDocument).toList();
  }

  Future<List<Map<String, dynamic>>> searchProducts(String keyword) async {
    final query = keyword.trim().toLowerCase();
    final products = await getProducts();
    return products
        .where((row) => '${row['name'] ?? ''}'.toLowerCase().contains(query))
        .toList();
  }

  Future<Map<String, dynamic>?> getBusinessProfile() async {
    final doc = await _collection('business_profile').doc('main').get();
    if (!doc.exists) return null;
    return {...?doc.data(), 'id': 1};
  }

  Future<Map<String, dynamic>?> saveBusinessProfile(
    Map<String, dynamic> data,
  ) async {
    lastBusinessLogoStoredInFirestore = false;
    final row = _clean(data);
    final logoBytes = data['logo_bytes'];
    var logoUploadFailed = false;
    String? logoUploadError;
    if (logoBytes is Uint8List && logoBytes.isNotEmpty) {
      try {
        final compactBytes = ImageData.compressForFirestore(logoBytes);
        try {
          row['logo_path'] = await _uploadImage(
            'business_profile',
            'main',
            compactBytes,
          ).timeout(const Duration(seconds: 12));
          row.remove('logo_base64');
        } catch (_) {
          row['logo_base64'] = base64Encode(compactBytes);
          lastBusinessLogoStoredInFirestore = true;
        }
      } catch (error) {
        // Save the business details even when Firebase Storage is unavailable.
        // Keep the existing logo URL if one was already saved.
        logoUploadFailed = true;
        logoUploadError = error.toString();
      }
    }
    row['updated_at'] = DateTime.now().toIso8601String();
    row['created_at'] ??= DateTime.now().toIso8601String();
    await _collection('business_profile')
        .doc('main')
        .set(row, SetOptions(merge: true))
        .timeout(const Duration(seconds: 12));
    final saved = <String, dynamic>{...row, 'id': 1};
    if (logoUploadFailed) {
      // Returned to the provider only; this marker is never written to Firestore.
      saved['_logo_upload_failed'] = true;
      saved['_logo_upload_error'] = logoUploadError;
    }
    if (lastBusinessLogoStoredInFirestore) {
      saved['_logo_stored_in_firestore'] = true;
    }
    return saved;
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
