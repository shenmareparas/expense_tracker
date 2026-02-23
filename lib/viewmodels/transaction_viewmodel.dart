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
  List<TransactionModel> get filteredTransactions =>
      _searchFilteredTransactions;

  static const int _pageSize = 20;
  int _currentOffset = 0;
  bool _hasMore = true;
  bool get hasMore => _hasMore;

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
    // Re-load from server with new filters, reset pagination
    loadTransactions(forceRefresh: true);
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearFilters() {
    _filterType = null;
    _filterCategory = null;
    _filterStartDate = null;
    _filterEndDate = null;
    _searchQuery = '';
    loadTransactions(forceRefresh: true);
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

    // Apply local search filter on top of server-filtered results
    final data = _searchFilteredTransactions;

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
  }

  /// Returns transactions filtered by the local search query.
  /// Server-side filters (type, category, date) are already applied.
  List<TransactionModel> get _searchFilteredTransactions {
    if (_searchQuery.isEmpty) return _transactions;

    final query = _searchQuery.toLowerCase();
    return _transactions.where((t) {
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

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ── Data Operations ───────────────────────────────────────────────────

  Future<void> loadTransactions({bool forceRefresh = false}) async {
    _isLoading = true;
    _errorMessage = null;
    _currentOffset = 0;
    _hasMore = true;
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
      _hasMore = result.length >= _pageSize;
      _currentOffset = result.length;
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
      final result = await _databaseService.getTransactions(
        forceRefresh: true,
        limit: _pageSize,
        offset: _currentOffset,
        type: _filterType,
        category: _filterCategory,
        startDate: _filterStartDate,
        endDate: _filterEndDate,
      );
      _transactions.addAll(result);
      _hasMore = result.length >= _pageSize;
      _currentOffset += result.length;
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
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Optimistic local insert
    final tempId = 'temp_${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = TransactionModel(
      id: tempId,
      userId: '',
      amount: amount,
      type: type,
      category: category,
      description: description,
      transactionDate: transactionDate,
      createdAt: DateTime.now(),
    );

    _transactions.insert(0, optimistic);
    _recomputeAggregates();
    _isLoading = false;
    notifyListeners();

    try {
      await _databaseService.addTransaction(
        amount: amount,
        type: type,
        category: category,
        description: description,
        transactionDate: transactionDate,
      );
      // Refresh to get server-assigned ID
      await loadTransactions(forceRefresh: true);
      return true;
    } catch (e) {
      // Revert optimistic insert
      _transactions.removeWhere((t) => t.id == tempId);
      _recomputeAggregates();
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
    _recomputeAggregates();
    notifyListeners();

    try {
      await _databaseService.deleteTransaction(id);
    } catch (e) {
      // Revert if failed
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
    _isLoading = true;
    _errorMessage = null;

    // Optimistic local update
    final index = _transactions.indexWhere((t) => t.id == id);
    TransactionModel? backup;
    if (index != -1) {
      backup = _transactions[index];
      _transactions[index] = backup.copyWith(
        amount: amount,
        type: type,
        category: category,
        description: description,
        transactionDate: transactionDate,
      );
      _recomputeAggregates();
    }
    _isLoading = false;
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
      // Refresh to get latest server state
      await loadTransactions(forceRefresh: true);
      return true;
    } catch (e) {
      // Revert optimistic update
      if (backup != null && index != -1) {
        _transactions[index] = backup;
        _recomputeAggregates();
      }
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
