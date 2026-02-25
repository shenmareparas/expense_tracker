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

  List<TransactionModel> _allTransactions = [];
  List<TransactionModel> get allTransactions => _allTransactions;

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
    // We use allTransactions for analytics aggregates, so they show the correct totals
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
    if (_searchQuery.isEmpty) return _allTransactions;

    final query = _searchQuery.toLowerCase();
    return _allTransactions.where((t) {
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
      // Fetch all transactions without limit to compute aggregates properly
      // DatabaseService will cache this internally
      final result = await _databaseService.getTransactions(
        forceRefresh: forceRefresh,
        limit: null,
        offset: 0,
        type: _filterType,
        category: _filterCategory,
        startDate: _filterStartDate,
        endDate: _filterEndDate,
      );
      _allTransactions = List.from(result);
      _transactions = _allTransactions.take(_pageSize).toList();

      _hasMore = _allTransactions.length > _pageSize;
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
      // Small delay for UI smoothness
      await Future.delayed(const Duration(milliseconds: 100));

      // Slice from the pre-loaded allTransactions list
      final nextBatch = _allTransactions
          .skip(_currentOffset)
          .take(_pageSize)
          .toList();
      _transactions.addAll(nextBatch);

      _hasMore = _transactions.length < _allTransactions.length;
      _currentOffset = _transactions.length;
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
    _allTransactions.insert(0, optimistic);
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
      _allTransactions.removeWhere((t) => t.id == tempId);
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
    final allIndex = _allTransactions.indexWhere((t) => t.id == id);
    if (index == -1 && allIndex == -1) return;

    TransactionModel? backup;
    if (index != -1) {
      backup = _transactions[index];
      _transactions.removeAt(index);
    }
    if (allIndex != -1) {
      backup ??= _allTransactions[allIndex];
      _allTransactions.removeAt(allIndex);
    }

    _recomputeAggregates();
    notifyListeners();

    try {
      await _databaseService.deleteTransaction(id);
    } catch (e) {
      // Revert if failed
      if (backup != null) {
        if (index != -1) _transactions.insert(index, backup);
        if (allIndex != -1) _allTransactions.insert(allIndex, backup);
      }
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
    final allIndex = _allTransactions.indexWhere((t) => t.id == id);
    TransactionModel? backup;

    if (allIndex != -1) {
      backup = _allTransactions[allIndex];
      final updated = backup.copyWith(
        amount: amount,
        type: type,
        category: category,
        description: description,
        transactionDate: transactionDate,
      );
      _allTransactions[allIndex] = updated;
      if (index != -1) {
        _transactions[index] = updated;
      }
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
      if (backup != null) {
        if (allIndex != -1) _allTransactions[allIndex] = backup;
        if (index != -1) _transactions[index] = backup;
        _recomputeAggregates();
      }
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
