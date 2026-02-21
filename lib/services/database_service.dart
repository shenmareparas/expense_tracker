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
    _cachedCategories = null;
    _categoriesFetchedAt = null;
  }

  // ── Transactions ─────────────────────────────────────────────────────

  Future<List<TransactionModel>> getTransactions({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _cachedTransactions != null &&
        _isCacheValid(_transactionsFetchedAt)) {
      return List.unmodifiable(_cachedTransactions!);
    }

    final response = await _supabase
        .from('transactions')
        .select()
        .order('transaction_date', ascending: false);

    _cachedTransactions = (response as List<dynamic>)
        .map((e) => TransactionModel.fromJson(e as Map<String, dynamic>))
        .toList();
    _transactionsFetchedAt = DateTime.now();

    return List.unmodifiable(_cachedTransactions!);
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
        .select()
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
