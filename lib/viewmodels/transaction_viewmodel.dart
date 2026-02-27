import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';

/// ViewModel for transaction state management.
///
/// Supports server-side filtering and pagination. Computed aggregates
/// are cached and only recalculated when the underlying transaction
/// list changes.
class TransactionViewModel extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService.instance;

  List<TransactionModel> _transactions = [];
  List<TransactionModel> get transactions => _transactions;

  /// Returns transactions filtered by local search query.
  /// Server-side filters (type, category, date) are already applied.
  List<TransactionModel> _filteredTransactions = [];
  List<TransactionModel> get filteredTransactions => _filteredTransactions;

  static const int _pageSize = 20;
  int _currentOffset = 0;
  bool _hasMore = true;
  bool get hasMore => _hasMore;
  List<TransactionModel> _analyticsTransactions = [];
  bool _hasAnalyticsSnapshot = false;
  bool get hasAnalyticsSnapshot => _hasAnalyticsSnapshot;

  // ── Filter & Search State ─────────────────────────────────────────────

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

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
    _hasAnalyticsSnapshot = false;
    _analyticsTransactions = [];
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _recomputeAggregates();
    notifyListeners();
  }

  void clearFilters() {
    _filterType = null;
    _filterCategory = null;
    _filterStartDate = null;
    _filterEndDate = null;
    _searchQuery = '';
    _hasAnalyticsSnapshot = false;
    _analyticsTransactions = [];
    notifyListeners();
  }

  // ── Cached Computed Properties ────────────────────────────────────────

  double _totalIncome = 0;
  double get totalIncome => _totalIncome;

  double _totalExpense = 0;
  double get totalExpense => _totalExpense;

  double get totalBalance => _totalIncome - _totalExpense;

  Map<String, double> _expensesByCategory = {};
  Map<String, double> get expensesByCategory => _expensesByCategory;

  List<MapEntry<String, double>> _sortedExpensesByCategory = [];
  List<MapEntry<String, double>> get sortedExpensesByCategory =>
      _sortedExpensesByCategory;

  /// Recalculates all aggregates from the current transaction list.
  void _recomputeAggregates() {
    _totalIncome = 0;
    _totalExpense = 0;
    final map = <String, double>{};

    final source = _hasAnalyticsSnapshot
        ? _analyticsTransactions
        : _transactions;
    final data = _applySearch(source);

    for (final t in data) {
      if (t.type == 'income') {
        _totalIncome += t.amount;
      } else {
        _totalExpense += t.amount;
        map[t.category] = (map[t.category] ?? 0) + t.amount;
      }
    }

    _expensesByCategory = map;
    _sortedExpensesByCategory = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Cache the filtered list so the getter doesn't rebuild it every frame.
    _filteredTransactions = _applySearch(_transactions);
  }

  List<TransactionModel> _applySearch(List<TransactionModel> input) {
    if (_searchQuery.isEmpty) return input;

    final query = _searchQuery.toLowerCase();
    return input.where((t) {
      final matchesDescription =
          t.description?.toLowerCase().contains(query) ?? false;
      final matchesAmount = t.amount.toString().contains(query);
      return matchesDescription || matchesAmount;
    }).toList();
  }

  // ── Loading / Error State ─────────────────────────────────────────────

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ── Data Operations ───────────────────────────────────────────────────

  Future<void> loadTransactions({bool forceRefresh = false}) async {
    _isLoading = true;
    _errorMessage = null;
    _currentOffset = 0;
    _hasMore = true;
    _hasAnalyticsSnapshot = false;
    _analyticsTransactions = [];
    notifyListeners();
    try {
      final result = await _databaseService.getTransactions(
        forceRefresh: forceRefresh,
        limit: _pageSize,
        offset: 0,
        type: _filterType,
        category: _filterCategory,
        startDate: _filterStartDate,
        endDate: _filterEndDate,
      );
      _transactions = List.from(result);

      _hasMore = result.length == _pageSize;
      _currentOffset = _transactions.length;
      _recomputeAggregates();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads the next page of transactions and appends to the list.
  Future<void> loadMoreTransactions() async {
    if (_isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextBatch = await _databaseService.getTransactions(
        forceRefresh: true,
        limit: _pageSize,
        offset: _currentOffset,
        type: _filterType,
        category: _filterCategory,
        startDate: _filterStartDate,
        endDate: _filterEndDate,
      );
      _transactions.addAll(nextBatch);

      _hasMore = nextBatch.length == _pageSize;
      _currentOffset = _transactions.length;
      _hasAnalyticsSnapshot = false;
      _analyticsTransactions = [];
      _recomputeAggregates();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoadingMore = false;
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
    _isSaving = true;
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
      await loadTransactions(forceRefresh: true);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> deleteTransaction(String id) async {
    final index = _transactions.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final backup = _transactions[index];
    _transactions.removeAt(index);
    _hasAnalyticsSnapshot = false;
    _analyticsTransactions = [];

    _recomputeAggregates();
    notifyListeners();

    try {
      await _databaseService.deleteTransaction(id);
    } catch (e) {
      _transactions.insert(index, backup);
      _recomputeAggregates();
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
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    final index = _transactions.indexWhere((t) => t.id == id);
    TransactionModel? backup;

    if (index != -1) {
      backup = _transactions[index];
      final updated = backup.copyWith(
        amount: amount,
        type: type,
        category: category,
        description: description,
        transactionDate: transactionDate,
      );
      _transactions[index] = updated;
      _recomputeAggregates();
      notifyListeners();
    }

    try {
      await _databaseService.updateTransaction(
        id: id,
        amount: amount,
        type: type,
        category: category,
        description: description,
        transactionDate: transactionDate,
      );
      await loadTransactions(forceRefresh: true);
      return true;
    } catch (e) {
      if (backup != null) {
        _transactions[index] = backup;
        _recomputeAggregates();
        notifyListeners();
      }
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> clearCacheAndRefresh() async {
    _databaseService.clearCache();
    await loadTransactions(forceRefresh: true);
  }

  Future<void> loadAnalyticsSnapshot({bool forceRefresh = false}) async {
    _errorMessage = null;
    try {
      final result = await _databaseService.getTransactions(
        forceRefresh: forceRefresh,
        limit: null,
        offset: 0,
        type: _filterType,
        category: _filterCategory,
        startDate: _filterStartDate,
        endDate: _filterEndDate,
      );
      _analyticsTransactions = List.from(result);
      _hasAnalyticsSnapshot = true;
      _recomputeAggregates();
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }
}
