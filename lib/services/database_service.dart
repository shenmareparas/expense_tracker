import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/transaction.dart';
import '../models/category.dart';

/// Singleton database service with in-memory caching.
///
/// Caches fetched data for [_cacheTtl] to avoid redundant Supabase
/// round-trips on tab switches and widget rebuilds.
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  final _supabase = Supabase.instance.client;

  // ── Cache Configuration ──────────────────────────────────────────────

  static const _cacheTtl = Duration(seconds: 30);

  List<TransactionModel>? _cachedTransactions;
  DateTime? _transactionsFetchedAt;
  String? _cachedFilterKey;

  List<CategoryModel>? _cachedCategories;
  DateTime? _categoriesFetchedAt;

  bool _isCacheValid(DateTime? fetchedAt) {
    if (fetchedAt == null) return false;
    return DateTime.now().difference(fetchedAt) < _cacheTtl;
  }

  /// Clears all cached data. Useful on sign-out.
  void clearCache() {
    _cachedTransactions = null;
    _transactionsFetchedAt = null;
    _cachedFilterKey = null;
    _cachedCategories = null;
    _categoriesFetchedAt = null;
  }

  // ── Column selections ───────────────────────────────────────────────

  static const _transactionColumns =
      'id, user_id, amount, type, category, description, transaction_date, created_at';

  static const _categoryColumns =
      'id, user_id, name, type, order_index, created_at';

  // ── Transactions ─────────────────────────────────────────────────────

  /// Builds a cache key from filter parameters so we invalidate on
  /// filter changes.
  String _buildFilterKey({
    String? type,
    String? category,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return '${type ?? ''}_${category ?? ''}_${startDate?.toIso8601String() ?? ''}_${endDate?.toIso8601String() ?? ''}';
  }

  Future<List<TransactionModel>> getTransactions({
    bool forceRefresh = false,
    int? limit,
    int offset = 0,
    String? type,
    String? category,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final filterKey = _buildFilterKey(
      type: type,
      category: category,
      startDate: startDate,
      endDate: endDate,
    );

    // If cache is valid, return the sliced list
    if (!forceRefresh &&
        _cachedTransactions != null &&
        _isCacheValid(_transactionsFetchedAt) &&
        _cachedFilterKey == filterKey) {
      if (limit == null) {
        return List.unmodifiable(_cachedTransactions!);
      }
      return _cachedTransactions!.skip(offset).take(limit).toList();
    }

    var query = _supabase.from('transactions').select(_transactionColumns);

    // Server-side filtering
    if (type != null) {
      query = query.eq('type', type);
    }
    if (category != null) {
      query = query.eq('category', category);
    }
    if (startDate != null) {
      query = query.gte(
        'transaction_date',
        startDate.toUtc().toIso8601String(),
      );
    }
    if (endDate != null) {
      // Include the entire end date day
      final endOfDay = endDate.add(const Duration(days: 1));
      query = query.lt('transaction_date', endOfDay.toUtc().toIso8601String());
    }

    // Remove range limitation to fetch all matching transactions
    final response = await query.order('transaction_date', ascending: false);

    final transactions = (response as List<dynamic>)
        .map((e) => TransactionModel.fromJson(e as Map<String, dynamic>))
        .toList();

    // Cache all fetched data
    _cachedTransactions = transactions;
    _transactionsFetchedAt = DateTime.now();
    _cachedFilterKey = filterKey;

    if (limit == null) {
      return List.unmodifiable(transactions);
    }
    return transactions.skip(offset).take(limit).toList();
  }

  Future<void> addTransaction({
    required double amount,
    required String type,
    required String category,
    String? description,
    required DateTime transactionDate,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    await _supabase.from('transactions').insert({
      'user_id': user.id,
      'amount': amount,
      'type': type,
      'category': category,
      'description': description,
      'transaction_date': transactionDate.toUtc().toIso8601String(),
    });

    _invalidateTransactionCache();
  }

  Future<void> deleteTransaction(String id) async {
    await _supabase.from('transactions').delete().eq('id', id);
    _invalidateTransactionCache();
  }

  Future<void> updateTransaction({
    required String id,
    required double amount,
    required String type,
    required String category,
    String? description,
    required DateTime transactionDate,
  }) async {
    await _supabase
        .from('transactions')
        .update({
          'amount': amount,
          'type': type,
          'category': category,
          'description': description,
          'transaction_date': transactionDate.toUtc().toIso8601String(),
        })
        .eq('id', id);

    _invalidateTransactionCache();
  }

  void _invalidateTransactionCache() {
    _cachedTransactions = null;
    _transactionsFetchedAt = null;
    _cachedFilterKey = null;
  }

  // ── Categories ───────────────────────────────────────────────────────

  Future<List<CategoryModel>> getCategories({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedCategories != null &&
        _isCacheValid(_categoriesFetchedAt)) {
      return List.unmodifiable(_cachedCategories!);
    }

    final response = await _supabase
        .from('categories')
        .select(_categoryColumns)
        .order('order_index', ascending: true);

    _cachedCategories = (response as List<dynamic>)
        .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
    _categoriesFetchedAt = DateTime.now();

    return List.unmodifiable(_cachedCategories!);
  }

  Future<void> addCategory({
    required String name,
    required String type,
    int orderIndex = 0,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    await _supabase.from('categories').insert({
      'user_id': user.id,
      'name': name,
      'type': type,
      'order_index': orderIndex,
    });

    _invalidateCategoryCache();
  }

  /// Batch-inserts multiple categories in a single round-trip.
  Future<void> addCategories(List<Map<String, dynamic>> categories) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final rows = categories.map((cat) => {'user_id': user.id, ...cat}).toList();

    await _supabase.from('categories').insert(rows);
    _invalidateCategoryCache();
  }

  Future<void> updateCategory({
    required String id,
    required String name,
    required String type,
    int? orderIndex,
    String? oldName,
  }) async {
    final Map<String, dynamic> data = {'name': name, 'type': type};
    if (orderIndex != null) {
      data['order_index'] = orderIndex;
    }
    await _supabase.from('categories').update(data).eq('id', id);

    if (oldName != null && oldName != name) {
      await _supabase
          .from('transactions')
          .update({'category': name})
          .eq('category', oldName)
          .eq('type', type);

      _invalidateTransactionCache();
    }

    _invalidateCategoryCache();
  }

  Future<void> reorderCategories(List<CategoryModel> categories) async {
    final List<Map<String, dynamic>> updates = [];
    for (int i = 0; i < categories.length; i++) {
      final json = categories[i].toJson();
      json['order_index'] = i;
      json.remove('created_at'); // Do not touch creation timestamp
      updates.add(json);
    }

    await _supabase.from('categories').upsert(updates);
    _invalidateCategoryCache();
  }

  Future<void> deleteCategory(String id) async {
    await _supabase.from('categories').delete().eq('id', id);
    _invalidateCategoryCache();
  }

  void _invalidateCategoryCache() {
    _cachedCategories = null;
    _categoriesFetchedAt = null;
  }
}
