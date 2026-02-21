import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/database_service.dart';

/// ViewModel for category management — extracted from TransactionViewModel.
class CategoryViewModel extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();

  List<CategoryModel> _categories = [];
  List<CategoryModel> get categories => _categories;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Sorted expense category names, with "Other" always last.
  List<String> get expenseCategories {
    final filtered = _categories.where((c) => c.type == 'expense').toList();
    filtered.sort((a, b) {
      if (a.name.toLowerCase() == 'other') return 1;
      if (b.name.toLowerCase() == 'other') return -1;
      return a.orderIndex.compareTo(b.orderIndex);
    });

    final names = filtered.map((c) => c.name).toList();
    if (!names.contains('Other')) names.add('Other');
    return names;
  }

  /// Sorted income category names, with "Other" always last.
  List<String> get incomeCategories {
    final filtered = _categories.where((c) => c.type == 'income').toList();
    filtered.sort((a, b) {
      if (a.name.toLowerCase() == 'other') return 1;
      if (b.name.toLowerCase() == 'other') return -1;
      return a.orderIndex.compareTo(b.orderIndex);
    });

    final names = filtered.map((c) => c.name).toList();
    if (!names.contains('Other')) names.add('Other');
    return names;
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
      String? oldName;
      try {
        oldName = _categories.firstWhere((c) => c.id == id).name;
      } catch (_) {}

      await _databaseService.updateCategory(
        id: id,
        name: name,
        type: type,
        oldName: oldName,
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
        _categories[indexInMain] = items[i].copyWith(orderIndex: i);
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
}
