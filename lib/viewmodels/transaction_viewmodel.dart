import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../services/database_service.dart';

class TransactionViewModel extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();

  List<TransactionModel> _transactions = [];
  List<TransactionModel> get transactions => _transactions;

  List<CategoryModel> _categories = [];
  List<CategoryModel> get categories => _categories;

  // Filter States
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
      if (_filterType != null && t.type != _filterType) {
        return false;
      }
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

  List<String> get expenseCategories {
    final filtered = _categories.where((c) => c.type == 'expense').toList();
    // Sort so "Other" is always last
    filtered.sort((a, b) {
      if (a.name.toLowerCase() == 'other') return 1;
      if (b.name.toLowerCase() == 'other') return -1;
      return a.orderIndex.compareTo(b.orderIndex);
    });

    final names = filtered.map((c) => c.name).toList();
    if (!names.contains('Other')) names.add('Other');
    return names;
  }

  List<String> get incomeCategories {
    final filtered = _categories.where((c) => c.type == 'income').toList();
    // Sort so "Other" is always last
    filtered.sort((a, b) {
      if (a.name.toLowerCase() == 'other') return 1;
      if (b.name.toLowerCase() == 'other') return -1;
      return a.orderIndex.compareTo(b.orderIndex);
    });

    final names = filtered.map((c) => c.name).toList();
    if (!names.contains('Other')) names.add('Other');
    return names;
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

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

  Future<void> loadInitialData() async {
    _isLoading = true;
    notifyListeners();
    await Future.wait([loadTransactions(), loadCategories()]);
    _isLoading = false;
    notifyListeners();
  }

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

  Future<void> loadCategories() async {
    _errorMessage = null;
    try {
      _categories = await _databaseService.getCategories();
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
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> seedDefaultCategories() async {
    _isLoading = true;
    notifyListeners();

    try {
      final defaults = [
        {'name': 'Food', 'type': 'expense'},
        {'name': 'Transport', 'type': 'expense'},
        {'name': 'Bills', 'type': 'expense'},
        {'name': 'Entertainment', 'type': 'expense'},
        {'name': 'Other', 'type': 'expense'},
        {'name': 'Salary', 'type': 'income'},
        {'name': 'Freelance', 'type': 'income'},
        {'name': 'Investments', 'type': 'income'},
        {'name': 'Other', 'type': 'income'},
      ];

      for (int i = 0; i < defaults.length; i++) {
        final cat = defaults[i];
        // Check if already exists
        final exists = _categories.any(
          (c) =>
              c.name.toLowerCase() == cat['name']!.toLowerCase() &&
              c.type == cat['type'],
        );
        if (!exists) {
          await _databaseService.addCategory(
            name: cat['name']!,
            type: cat['type']!,
            orderIndex: i,
          );
        }
      }
      await loadCategories();
    } catch (e) {
      _errorMessage = 'Failed to seed default categories';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addCategory({required String name, required String type}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final orderIndex = _categories.where((c) => c.type == type).length;
      await _databaseService.addCategory(
        name: name,
        type: type,
        orderIndex: orderIndex,
      );
      await loadCategories();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateCategory({
    required String id,
    required String name,
    required String type,
  }) async {
    if (name.toLowerCase() == 'other') return false; // Protect "Other"

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _databaseService.updateCategory(id: id, name: name, type: type);
      await loadCategories();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> reorderCategories(
    String type,
    int oldIndex,
    int newIndex,
  ) async {
    final filtered = _categories.where((c) => c.type == type).toList()
      ..sort((a, b) {
        if (a.name.toLowerCase() == 'other') return 1;
        if (b.name.toLowerCase() == 'other') return -1;
        return a.orderIndex.compareTo(b.orderIndex);
      });

    if (newIndex > oldIndex) newIndex -= 1;

    if (oldIndex >= filtered.length) return;
    if (filtered[oldIndex].name.toLowerCase() == 'other') {
      return; // Cannot move "Other"
    }

    // Prevent dragging beyond custom items
    final customItemsCount = filtered
        .where((c) => c.name.toLowerCase() != 'other')
        .length;
    if (newIndex >= customItemsCount) {
      newIndex = customItemsCount > 0 ? customItemsCount - 1 : 0;
    }

    final items = filtered
        .where((c) => c.name.toLowerCase() != 'other')
        .toList();
    if (oldIndex >= items.length || newIndex >= items.length) return;

    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);

    // Optimistic update locally
    for (int i = 0; i < items.length; i++) {
      final indexInMain = _categories.indexWhere((c) => c.id == items[i].id);
      if (indexInMain != -1) {
        _categories[indexInMain] = CategoryModel(
          id: items[i].id,
          userId: items[i].userId,
          name: items[i].name,
          type: items[i].type,
          orderIndex: i,
          createdAt: items[i].createdAt,
        );
      }
    }

    notifyListeners();

    try {
      await _databaseService.reorderCategories(items);
      await loadCategories();
    } catch (e) {
      _errorMessage = 'Failed to reorder categories';
      await loadCategories(); // revert optimistic update
    }
  }

  Future<void> deleteCategory(String id) async {
    final cat = _categories.firstWhere((c) => c.id == id);
    if (cat.name.toLowerCase() == 'other') return; // Protect "Other"

    _isLoading = true;
    notifyListeners();
    try {
      await _databaseService.deleteCategory(id);
      await loadCategories();
    } catch (e) {
      _errorMessage = 'Failed to delete category';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
