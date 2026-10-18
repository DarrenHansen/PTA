import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/customer.dart';

/// Customer Provider - State Management untuk Customer/Klien
class CustomerProvider extends ChangeNotifier {
  final DBHelper _dbHelper = DBHelper.instance;

  List<Customer> _customers = [];
  bool _isLoading = false;

  List<Customer> get customers => _customers;
  bool get isLoading => _isLoading;

  Future<void> loadCustomers() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _dbHelper.getCustomers();
      _customers = data.map((map) => Customer.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error loading customers: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Customer?> addCustomer(Customer customer) async {
    try {
      final id = await _dbHelper.insertCustomer(customer.toMap());
      if (id > 0) {
        await loadCustomers();
        return customer.copyWith(id: id);
      }
    } catch (e) {
      debugPrint('Error adding customer: $e');
    }
    return null;
  }

  Future<bool> updateCustomer(Customer customer) async {
    try {
      final result =
          await _dbHelper.updateCustomer(customer.id!, customer.toMap());
      if (result > 0) {
        await loadCustomers();
        return true;
      }
    } catch (e) {
      debugPrint('Error updating customer: $e');
    }
    return false;
  }

  Future<bool> deleteCustomer(int id) async {
    try {
      final result = await _dbHelper.deleteCustomer(id);
      if (result > 0) {
        await loadCustomers();
        return true;
      }
    } catch (e) {
      debugPrint('Error deleting customer: $e');
    }
    return false;
  }

  Future<List<Customer>> searchCustomers(String keyword) async {
    final data = await _dbHelper.searchCustomers(keyword);
    return data.map((map) => Customer.fromMap(map)).toList();
  }
}
