import 'dart:async';

import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/product.dart';

/// Product Provider - State Management untuk Product/Barang
class ProductProvider extends ChangeNotifier {
  final DBHelper _dbHelper = DBHelper.instance;

  List<Product> _products = [];
  bool _isLoading = false;
  bool lastPhotoUploadFailed = false;
  String? lastPhotoUploadError;
  bool lastPhotoStoredInFirestore = false;

  List<Product> get products => _products;
  bool get isLoading => _isLoading;

  Future<void> loadProducts() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data =
          await _dbHelper.getProducts().timeout(const Duration(seconds: 15));
      _products = data.map((map) => Product.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error loading products: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Product?> addProduct(Product product) async {
    lastPhotoUploadFailed = false;
    lastPhotoUploadError = null;
    lastPhotoStoredInFirestore = false;
    try {
      final id = await _dbHelper
          .insertProduct(product.toMap())
          .timeout(const Duration(seconds: 30));
      if (id > 0) {
        lastPhotoUploadFailed = _dbHelper.lastProductPhotoUploadFailed;
        lastPhotoUploadError = _dbHelper.lastProductPhotoUploadError;
        lastPhotoStoredInFirestore =
            _dbHelper.lastProductPhotoStoredInFirestore;
        final savedProduct = product.copyWith(id: id, photoBytes: null);
        _products = [..._products, savedProduct];
        notifyListeners();
        unawaited(loadProducts());
        return savedProduct;
      }
    } catch (e) {
      debugPrint('Error adding product: $e');
      rethrow;
    }
    return null;
  }

  Future<bool> updateProduct(Product product) async {
    lastPhotoUploadFailed = false;
    lastPhotoUploadError = null;
    lastPhotoStoredInFirestore = false;
    try {
      final result = await _dbHelper
          .updateProduct(product.id!, product.toMap())
          .timeout(const Duration(seconds: 30));
      if (result > 0) {
        lastPhotoUploadFailed = _dbHelper.lastProductPhotoUploadFailed;
        lastPhotoUploadError = _dbHelper.lastProductPhotoUploadError;
        lastPhotoStoredInFirestore =
            _dbHelper.lastProductPhotoStoredInFirestore;
        _products = _products
            .map((current) => current.id == product.id
                ? product.copyWith(photoBytes: null)
                : current)
            .toList();
        notifyListeners();
        unawaited(loadProducts());
        return true;
      }
    } catch (e) {
      debugPrint('Error updating product: $e');
    }
    return false;
  }

  Future<bool> addStock(int productId, int quantity, {String note = ''}) async {
    try {
      await _dbHelper.addStock(productId, quantity, note: note);
      await loadProducts();
      return true;
    } catch (e) {
      debugPrint('Error adding stock: $e');
      return false;
    }
  }

  Future<bool> adjustStock(
    int productId,
    int actualStock, {
    String note = '',
  }) async {
    try {
      await _dbHelper.adjustStock(productId, actualStock, note: note);
      await loadProducts();
      return true;
    } catch (e) {
      debugPrint('Error recording stock opname: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> loadStockMovements(
      {int? productId}) async {
    try {
      return await _dbHelper.getStockMovements(productId: productId);
    } catch (e) {
      debugPrint('Error loading stock movements: $e');
      return [];
    }
  }

  Future<bool> deleteProduct(int id) async {
    try {
      final result = await _dbHelper.deleteProduct(id);
      if (result > 0) {
        await loadProducts();
        return true;
      }
    } catch (e) {
      debugPrint('Error deleting product: $e');
    }
    return false;
  }

  Future<List<Product>> searchProducts(String keyword) async {
    final data = await _dbHelper.searchProducts(keyword);
    return data.map((map) => Product.fromMap(map)).toList();
  }
}
