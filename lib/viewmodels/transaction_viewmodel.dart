import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';
import '../utils/exceptions.dart';
import 'split_viewmodel.dart';

/// ViewModel for transaction state management.
///
/// Supports server-side filtering and pagination. Computed aggregates
/// are cached and only recalculated when the underlying transaction
/// list changes.
class TransactionViewModel extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService.instance;

  List<TransactionModel> _transactions = [];
  List<TransactionModel> get transactions =>
      _hasAnalyticsSnapshot ? _analyticsTransactions : _transactions;

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

  List<String> _filterCategories = [];
  List<String> get filterCategories => _filterCategories;

  String? _filterPaymentMethod;
  String? get filterPaymentMethod => _filterPaymentMethod;

  DateTime? _filterStartDate;
  DateTime? get filterStartDate => _filterStartDate;

  DateTime? _filterEndDate;
  DateTime? get filterEndDate => _filterEndDate;

  DateTime? _analyticsStartDate;
  DateTime? get analyticsStartDate => _analyticsStartDate;

  DateTime? _analyticsEndDate;
  DateTime? get analyticsEndDate => _analyticsEndDate;

  void setFilters({
    String? type,
    List<String>? categories,
    String? paymentMethod,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    _filterType = type;
    _filterCategories = categories ?? [];
    _filterPaymentMethod = paymentMethod;
    _filterStartDate = startDate;
    _filterEndDate = endDate;
    _hasAnalyticsSnapshot = false;
    _analyticsTransactions = [];
    _analyticsStartDate = null;
    _analyticsEndDate = null;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _recomputeAggregates();
    notifyListeners();
  }

  void clearFilters() {
    _filterType = null;
    _filterCategories = [];
    _filterPaymentMethod = null;
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
    _hasMore = false;
    _hasAnalyticsSnapshot = false;
    _analyticsTransactions = [];
    notifyListeners();
    try {
      final result = await _databaseService.getTransactions(
        forceRefresh: forceRefresh,
        limit: null,
        offset: null,
        type: _filterType,
        categories: _filterCategories,
        paymentMethod: _filterPaymentMethod,
        startDate: _filterStartDate,
        endDate: _filterEndDate,
      );
      _transactions = List.from(result);

      _hasMore = false;
      _currentOffset = _transactions.length;
      _recomputeAggregates();
    } catch (e) {
      _errorMessage = _mapError(e);
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
        forceRefresh:
            false, // paginated requests naturally bypass the full cache
        limit: _pageSize,
        offset: _currentOffset,
        type: _filterType,
        categories: _filterCategories,
        paymentMethod: _filterPaymentMethod,
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
      _errorMessage = _mapError(e);
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
    String paymentMethod = 'upi',
    required DateTime transactionDate,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newTransaction = await _databaseService.addTransaction(
        amount: amount,
        type: type,
        category: category,
        description: description,
        paymentMethod: paymentMethod,
        transactionDate: transactionDate,
      );

      // Optimistic insert: add the returned model to the list and re-sort.
      // This prevents the heavy full-refresh network call.
      _transactions.add(newTransaction);
      _transactions.sort(
        (a, b) => b.transactionDate.compareTo(a.transactionDate),
      );

      _hasAnalyticsSnapshot = false;
      _analyticsTransactions = [];
      _recomputeAggregates();
      return true;
    } catch (e) {
      _errorMessage = _mapError(e);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  TransactionModel? findMatchingSplitTransaction({
    required String description,
    required DateTime expenseDate,
    double? totalAmount,
  }) {
    final cleanDesc = description.trim().toLowerCase();
    for (final t in _transactions) {
      if (t.type != 'expense') continue;
      final tDesc = (t.description ?? '').trim().toLowerCase();
      final matchesDesc = tDesc == 'split: $cleanDesc' ||
          tDesc.startsWith('split: $cleanDesc') ||
          tDesc == cleanDesc;
      if (!matchesDesc) continue;
      final dateDiff = t.transactionDate.difference(expenseDate).inMinutes.abs();
      final amountMatch = totalAmount == null || (t.amount - totalAmount).abs() < 0.05;
      if (dateDiff < 120 || amountMatch) {
        return t;
      }
    }
    return null;
  }

  Future<void> deleteTransaction(
    String id, {
    SplitViewModel? splitVM,
  }) async {
    final index = _transactions.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final backup = _transactions[index];
    _transactions.removeAt(index);
    _hasAnalyticsSnapshot = false;
    _analyticsTransactions = [];

    _recomputeAggregates();
    notifyListeners();

    try {
      if (splitVM != null &&
          backup.description != null &&
          backup.description!.toLowerCase().startsWith('split:')) {
        await splitVM.deleteSplitsForTransaction(backup);
      }
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
    String paymentMethod = 'upi',
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
        paymentMethod: paymentMethod,
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
        paymentMethod: paymentMethod,
        transactionDate: transactionDate,
      );
      // Optimistic update already applied above. DatabaseService.updateTransaction()
      // already calls _invalidateTransactionCache() internally — no extra action needed.
      return true;
    } catch (e) {
      if (backup != null) {
        _transactions[index] = backup;
        _recomputeAggregates();
        notifyListeners();
      }
      _errorMessage = _mapError(e);
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

  Future<void> loadAnalyticsSnapshot({
    DateTime? startDate,
    DateTime? endDate,
    bool forceRefresh = false,
  }) async {
    _errorMessage = null;
    _analyticsStartDate = startDate;
    _analyticsEndDate = endDate;
    try {
      final result = await _databaseService.getTransactions(
        forceRefresh: forceRefresh,
        limit: null,
        offset: null,
        type: null,
        categories: null,
        startDate: _analyticsStartDate,
        endDate: _analyticsEndDate,
      );
      _analyticsTransactions = List.from(result);
      _hasAnalyticsSnapshot = true;
      _recomputeAggregates();
      notifyListeners();
    } catch (e) {
      _errorMessage = _mapError(e);
      notifyListeners();
    }
  }

  /// Maps raw exceptions to user-friendly, non-leaky messages.
  String _mapError(Object error) {
    if (error is AppException) {
      return error.message;
    }
    return 'Something went wrong. Please try again.';
  }
}
