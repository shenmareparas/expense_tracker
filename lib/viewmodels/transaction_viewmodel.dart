import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';

/// ViewModel for transaction state management.
/// Category-related logic is in [CategoryViewModel].
class TransactionViewModel extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();

  List<TransactionModel> _transactions = [];
  List<TransactionModel> get transactions => _transactions;

  // ── Filter State ──────────────────────────────────────────────────────

  String? _filterType;
  String? get filterType => _filterType;

  String? _filterCategory;
  String? get filterCategory => _filterCategory;

  DateTime? _filterStartDate;
  DateTime? get filterStartDate => _filterStartDate;

  DateTime? _filterEndDate;
  DateTime? get filterEndDate => _filterEndDate;

  void setFilters({
    String? type,
    String? category,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    _filterType = type;
    _filterCategory = category;
    _filterStartDate = startDate;
    _filterEndDate = endDate;
    notifyListeners();
  }

  void clearFilters() {
    _filterType = null;
    _filterCategory = null;
    _filterStartDate = null;
    _filterEndDate = null;
    notifyListeners();
  }

  List<TransactionModel> get filteredTransactions {
    return _transactions.where((t) {
      if (_filterType != null && t.type != _filterType) return false;
      if (_filterCategory != null && t.category != _filterCategory) {
        return false;
      }
      if (_filterStartDate != null &&
          t.transactionDate.isBefore(_filterStartDate!)) {
        return false;
      }
      if (_filterEndDate != null &&
          t.transactionDate.isAfter(
            _filterEndDate!.add(const Duration(days: 1)),
          )) {
        return false;
      }
      return true;
    }).toList();
  }

  // ── Loading / Error State ─────────────────────────────────────────────

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ── Computed Properties ───────────────────────────────────────────────

  double get totalBalance => totalIncome - totalExpense;

  double get totalIncome => _transactions
      .where((t) => t.type == 'income')
      .fold(0.0, (sum, t) => sum + t.amount);

  double get totalExpense => _transactions
      .where((t) => t.type == 'expense')
      .fold(0.0, (sum, t) => sum + t.amount);

  Map<String, double> get expensesByCategory {
    final map = <String, double>{};
    for (final t in _transactions.where((t) => t.type == 'expense')) {
      map[t.category] = (map[t.category] ?? 0) + t.amount;
    }
    return map;
  }

  List<MapEntry<String, double>> get sortedExpensesByCategory {
    final map = expensesByCategory;
    return map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  // ── Data Operations ───────────────────────────────────────────────────

  Future<void> loadTransactions() async {
    _errorMessage = null;
    try {
      _transactions = await _databaseService.getTransactions();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  Future<bool> addTransaction({
    required double amount,
    required String type,
    required String category,
    String? description,
    required DateTime transactionDate,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _databaseService.addTransaction(
        amount: amount,
        type: type,
        category: category,
        description: description,
        transactionDate: transactionDate,
      );
      await loadTransactions();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> deleteTransaction(String id) async {
    // Optimistic delete
    final index = _transactions.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final backup = _transactions[index];
    _transactions.removeAt(index);
    notifyListeners();

    try {
      await _databaseService.deleteTransaction(id);
    } catch (e) {
      // Revert if failed
      _transactions.insert(index, backup);
      _errorMessage = 'Failed to delete transaction';
      notifyListeners();
    }
  }

  Future<bool> updateTransaction({
    required String id,
    required double amount,
    required String type,
    required String category,
    String? description,
    required DateTime transactionDate,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _databaseService.updateTransaction(
        id: id,
        amount: amount,
        type: type,
        category: category,
        description: description,
        transactionDate: transactionDate,
      );
      await loadTransactions();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
