import 'package:flutter/foundation.dart';

import '../database/db_helper.dart';
import '../models/invoice.dart';
import '../models/item.dart';

/// State management for invoices fetched from the Laravel API.
class InvoiceProvider extends ChangeNotifier {
  final DBHelper _dbHelper = DBHelper.instance;

  List<Invoice> _invoices = [];
  List<Invoice> _filteredInvoices = [];
  InvoiceStatus? _filterStatus;
  String _searchQuery = '';
  bool _isLoading = false;
  String? _lastError;

  List<Invoice> get invoices =>
      _filteredInvoices.isEmpty && _filterStatus == null && _searchQuery.isEmpty
          ? _invoices
          : _filteredInvoices;

  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  InvoiceStatus? get filterStatus => _filterStatus;
  String get searchQuery => _searchQuery;

  Future<void> loadInvoices() async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await _dbHelper.getInvoices();
      _invoices = data.map(Invoice.fromMap).toList();
      await applyFilters();
    } catch (error) {
      debugPrint('Error loading invoices: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Item>> loadItems(int invoiceId) async {
    final data = await _dbHelper.getItems(invoiceId);
    return data.map(Item.fromMap).toList();
  }

  Future<Invoice?> addInvoice(Invoice invoice) async {
    _lastError = null;
    try {
      final saved = await _dbHelper.createInvoice(
        invoice.toMap(),
        invoice.items.map((item) => item.toMap()).toList(),
      );
      await loadInvoices();
      return Invoice.fromMap(saved);
    } catch (error) {
      _lastError = error.toString().replaceFirst('Bad state: ', '');
      debugPrint('Error adding invoice: $error');
      return null;
    }
  }

  Future<bool> updateInvoice(Invoice invoice) async {
    _lastError = null;
    try {
      final saved = await _dbHelper.replaceInvoice(
        invoice.id!,
        invoice.toMap(),
        invoice.items.map((item) => item.toMap()).toList(),
      );
      if (saved.isEmpty) return false;
      await loadInvoices();
      return true;
    } catch (error) {
      _lastError = error.toString().replaceFirst('Bad state: ', '');
      debugPrint('Error updating invoice: $error');
      return false;
    }
  }

  Future<bool> deleteInvoice(int id) async {
    try {
      await _dbHelper.deleteInvoice(id);
      await loadInvoices();
      return true;
    } catch (error) {
      debugPrint('Error deleting invoice: $error');
      return false;
    }
  }

  Future<bool> updateStatus(int id, InvoiceStatus status) async {
    try {
      await _dbHelper.updateInvoiceStatus(id, status.dbValue);
      await loadInvoices();
      return true;
    } catch (error) {
      debugPrint('Error updating invoice status: $error');
      return false;
    }
  }

  Future<void> searchInvoices(String query) async {
    _searchQuery = query.trim();
    await applyFilters();
  }

  Future<void> filterByStatus(InvoiceStatus? status) async {
    _filterStatus = status;
    await applyFilters();
  }

  Future<void> applyFilters() async {
    try {
      if (_searchQuery.isNotEmpty && _filterStatus != null) {
        final rows = await _dbHelper.searchInvoices(_searchQuery);
        _filteredInvoices = rows
            .map(Invoice.fromMap)
            .where((invoice) => _matchesStatus(invoice, _filterStatus))
            .toList();
      } else if (_searchQuery.isNotEmpty) {
        final rows = await _dbHelper.searchInvoices(_searchQuery);
        _filteredInvoices = rows.map(Invoice.fromMap).toList();
      } else if (_filterStatus != null) {
        _filteredInvoices = _invoices
            .where((invoice) => _matchesStatus(invoice, _filterStatus))
            .toList();
      } else {
        _filteredInvoices = [];
      }
    } catch (error) {
      debugPrint('Error applying invoice filters: $error');
    }
    notifyListeners();
  }

  bool _matchesStatus(Invoice invoice, InvoiceStatus? filter) {
    switch (filter) {
      case null:
        return true;
      case InvoiceStatus.paid:
        return invoice.status == InvoiceStatus.paid;
      case InvoiceStatus.unpaid:
        return invoice.status != InvoiceStatus.paid;
      case InvoiceStatus.overdue:
        return invoice.isOverdue;
    }
  }

  void resetFilters() {
    _searchQuery = '';
    _filterStatus = null;
    _filteredInvoices = [];
    notifyListeners();
  }

  Future<Map<String, dynamic>> getStats() => _dbHelper.getInvoiceStats();

  int get totalCount => _invoices.length;
  int get paidCount =>
      _invoices.where((invoice) => invoice.status == InvoiceStatus.paid).length;
  int get unpaidCount =>
      _invoices.where((invoice) => invoice.status != InvoiceStatus.paid).length;
  int get overdueCount =>
      _invoices.where((invoice) => invoice.isOverdue).length;

  double get totalRevenue => _invoices
      .where((invoice) => invoice.status == InvoiceStatus.paid)
      .fold(0, (sum, invoice) => sum + invoice.total);
}
