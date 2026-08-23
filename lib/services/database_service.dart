import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/profile.dart';
import '../models/split_expense.dart';
import '../utils/connectivity_checker.dart';
import '../utils/exceptions.dart';

/// Singleton database service with in-memory caching.
///
/// All **read** methods use a differentiated TTL cache to avoid redundant
/// Supabase round-trips on tab switches and widget rebuilds.
/// All **write** methods use [_executeMutation], which performs a pre-flight
/// connectivity check so a [NetworkException] is surfaced immediately when
/// the device is offline instead of waiting for a TCP timeout (~30 s).
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  final _supabase = Supabase.instance.client;

  Exception _mapError(Object error) {
    if (error is SocketException) {
      return const NetworkException(
        'Check your internet connection and try again.',
      );
    }
    if (error is PostgrestException) {
      return DataException('Database error: ${error.message}');
    }
    if (error is AuthException) {
      return const AppAuthException('Session expired. Please sign in again.');
    }
    if (error is AppException) {
      return error;
    }
    return const DataException('Something went wrong. Please try again.');
  }

  /// Executes [action] and maps any thrown exception to a typed [AppException].
  Future<T> _execute<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      throw _mapError(e);
    }
  }

  /// Like [_execute] but performs a pre-flight connectivity check first.
  ///
  /// Used for all write operations so a [NetworkException] is thrown
  /// immediately when the device is offline, without waiting for a TCP timeout.
  Future<T> _executeMutation<T>(Future<T> Function() action) async {
    if (!await ConnectivityChecker.isConnected()) {
      throw const NetworkException(
        'No internet connection. Please check your connection and try again.',
      );
    }
    return _execute(action);
  }

  // ── Cache Configuration ──────────────────────────────────────────────

  /// Transactions and split expenses change frequently; use a short TTL.
  static const _transactionCacheTtl = Duration(minutes: 2);

  /// Categories rarely change; a longer TTL avoids redundant fetches.
  static const _categoryCacheTtl = Duration(minutes: 15);

  /// Profiles almost never change; a long TTL is safe.
  static const _profilesCacheTtl = Duration(minutes: 10);

  /// Split expenses can change via settle-up; keep TTL moderate.
  static const _splitCacheTtl = Duration(minutes: 2);

  List<TransactionModel>? _cachedTransactions;
  DateTime? _transactionsFetchedAt;
  String? _cachedFilterKey;

  /// In-flight request deduplicator — prevents concurrent callers from each
  /// firing their own network request before the first one resolves.
  Completer<List<TransactionModel>>? _ongoingTransactionFetch;

  List<CategoryModel>? _cachedCategories;
  DateTime? _categoriesFetchedAt;

  List<SplitExpenseModel>? _cachedSplitExpenses;
  DateTime? _splitExpensesFetchedAt;
  Completer<List<SplitExpenseModel>>? _ongoingSplitFetch;

  List<ProfileModel>? _cachedProfiles;
  DateTime? _profilesFetchedAt;
  Completer<List<ProfileModel>>? _ongoingProfilesFetch;

  bool _isCacheValid(DateTime? fetchedAt, Duration ttl) {
    if (fetchedAt == null) return false;
    return DateTime.now().difference(fetchedAt) < ttl;
  }

  void _invalidateSplitCache() {
    _cachedSplitExpenses = null;
    _splitExpensesFetchedAt = null;
  }

  // ── Transactions ─────────────────────────────────────────────────────

  static const _transactionColumns =
      'id, user_id, amount, type, category, description, payment_method, transaction_date, created_at';

  /// Clears all in-memory caches. Call on sign-out to prevent cross-user leakage.
  void clearCache() {
    _cachedTransactions = null;
    _transactionsFetchedAt = null;
    _cachedFilterKey = null;
    _cachedCategories = null;
    _categoriesFetchedAt = null;
    _cachedSplitExpenses = null;
    _splitExpensesFetchedAt = null;
    _cachedProfiles = null;
    _profilesFetchedAt = null;
  }

  Future<List<TransactionModel>> getTransactions({
    bool forceRefresh = false,
    String? type,
    List<String>? categories,
    String? paymentMethod,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    int? offset,
  }) async {
    final filterKey = [
      type ?? '',
      (categories ?? []).join(','),
      paymentMethod ?? '',
      startDate?.toIso8601String() ?? '',
      endDate?.toIso8601String() ?? '',
    ].join('|');

    final canUseCache =
        !forceRefresh &&
        _cachedTransactions != null &&
        _isCacheValid(_transactionsFetchedAt, _transactionCacheTtl) &&
        _cachedFilterKey == filterKey;

    if (canUseCache) {
      return List.unmodifiable(_cachedTransactions!);
    }

    Completer<List<TransactionModel>>? completer;

    if (_ongoingTransactionFetch != null && !forceRefresh) {
      return _ongoingTransactionFetch!.future;
    }

    if (!forceRefresh) {
      completer = Completer<List<TransactionModel>>();
      _ongoingTransactionFetch = completer;
    }

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw const UnauthenticatedException();

      var query = _supabase
          .from('transactions')
          .select(_transactionColumns)
          .eq('user_id', userId);

      if (type != null) query = query.eq('type', type);
      if (categories != null && categories.isNotEmpty) {
        query = query.inFilter('category', categories);
      }
      if (paymentMethod != null) {
        query = query.eq('payment_method', paymentMethod);
      }
      if (startDate != null) {
        query = query.gte(
          'transaction_date',
          startDate.toUtc().toIso8601String(),
        );
      }
      if (endDate != null) {
        query = query.lte(
          'transaction_date',
          endDate.toUtc().toIso8601String(),
        );
      }

      var orderedQuery = query.order('transaction_date', ascending: false);
      if (limit != null) orderedQuery = orderedQuery.limit(limit);
      if (offset != null) orderedQuery = orderedQuery.range(offset, offset + (limit ?? 50) - 1);

      final response = await orderedQuery;

      final transactions = (response as List<dynamic>)
          .map((e) => TransactionModel.fromJson(e as Map<String, dynamic>))
          .toList();

      if (!forceRefresh) {
        _cachedTransactions = transactions;
        _transactionsFetchedAt = DateTime.now();
        _cachedFilterKey = filterKey;
        final result = List<TransactionModel>.unmodifiable(transactions);
        completer?.complete(result);
        return result;
      }
      return transactions;
    } catch (e) {
      final mapped = _mapError(e);
      completer?.completeError(mapped);
      throw mapped;
    } finally {
      if (_ongoingTransactionFetch == completer) {
        _ongoingTransactionFetch = null;
      }
    }
  }

  Future<TransactionModel> addTransaction({
    required double amount,
    required String type,
    required String category,
    String? description,
    String paymentMethod = 'upi',
    required DateTime transactionDate,
  }) async {
    return _executeMutation(() async {
      final user = _supabase.auth.currentUser;
      if (user == null) throw const UnauthenticatedException();

      final response = await _supabase
          .from('transactions')
          .insert({
            'user_id': user.id,
            'amount': amount,
            'type': type,
            'category': category,
            'description': description,
            'payment_method': paymentMethod,
            'transaction_date': transactionDate.toUtc().toIso8601String(),
          })
          .select(_transactionColumns)
          .single();

      _invalidateTransactionCache();
      return TransactionModel.fromJson(response);
    });
  }

  Future<void> deleteTransaction(String id) async {
    return _executeMutation(() async {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw const UnauthenticatedException();
      await _supabase
          .from('transactions')
          .delete()
          .eq('id', id)
          .eq('user_id', userId); // defense-in-depth: ensures user owns this row
      _invalidateTransactionCache();
    });
  }

  Future<void> updateTransaction({
    required String id,
    required double amount,
    required String type,
    required String category,
    String? description,
    String paymentMethod = 'upi',
    required DateTime transactionDate,
  }) async {
    return _executeMutation(() async {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw const UnauthenticatedException();
      await _supabase
          .from('transactions')
          .update({
            'amount': amount,
            'type': type,
            'category': category,
            'description': description,
            'payment_method': paymentMethod,
            'transaction_date': transactionDate.toUtc().toIso8601String(),
          })
          .eq('id', id)
          .eq('user_id', userId); // defense-in-depth: ensures user owns this row

      _invalidateTransactionCache();
    });
  }

  void _invalidateTransactionCache() {
    _cachedTransactions = null;
    _transactionsFetchedAt = null;
    _cachedFilterKey = null;
  }

  // ── Categories ───────────────────────────────────────────────────────

  static const _categoryColumns = 'id, user_id, name, type, order_index, created_at';

  Future<List<CategoryModel>> getCategories({bool forceRefresh = false}) async {
    return _execute(() async {
      if (!forceRefresh &&
          _cachedCategories != null &&
          _isCacheValid(_categoriesFetchedAt, _categoryCacheTtl)) {
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
    });
  }

  Future<void> addCategory({
    required String name,
    required String type,
    int orderIndex = 0,
  }) async {
    return _executeMutation(() async {
      final user = _supabase.auth.currentUser;
      if (user == null) throw const UnauthenticatedException();

      await _supabase.from('categories').insert({
        'user_id': user.id,
        'name': name,
        'type': type,
        'order_index': orderIndex,
      });

      _invalidateCategoryCache();
    });
  }

  /// Batch-inserts multiple categories in a single round-trip.
  Future<void> addCategories(List<Map<String, dynamic>> categories) async {
    return _executeMutation(() async {
      final user = _supabase.auth.currentUser;
      if (user == null) throw const UnauthenticatedException();

      final rows = categories
          .map((cat) => {'user_id': user.id, ...cat})
          .toList();

      await _supabase.from('categories').insert(rows);
      _invalidateCategoryCache();
    });
  }

  Future<void> updateCategory({
    required String id,
    required String name,
    required String type,
    int? orderIndex,
    String? oldName,
  }) async {
    return _executeMutation(() async {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw const UnauthenticatedException();
      final Map<String, dynamic> data = {'name': name, 'type': type};
      if (orderIndex != null) {
        data['order_index'] = orderIndex;
      }
      await _supabase
          .from('categories')
          .update(data)
          .eq('id', id)
          .eq('user_id', userId); // defense-in-depth: ensures user owns this row

      if (oldName != null && oldName != name) {
        await _supabase
            .from('transactions')
            .update({'category': name})
            .eq('category', oldName)
            .eq('type', type)
            .eq('user_id', userId);

        _invalidateTransactionCache();
      }

      _invalidateCategoryCache();
    });
  }

  /// Batch-updates [order_index] for the given categories in a single upsert.
  /// Sends only {id, order_index} — the minimum required fields — to avoid
  /// accidentally overwriting other columns.
  Future<void> reorderCategories(List<CategoryModel> categories) async {
    return _executeMutation(() async {
      final updates = <Map<String, dynamic>>[
        for (int i = 0; i < categories.length; i++)
          {'id': categories[i].id, 'order_index': i},
      ];

      await _supabase.from('categories').upsert(updates, onConflict: 'id');
      _invalidateCategoryCache();
    });
  }

  Future<void> deleteCategory(String id) async {
    return _executeMutation(() async {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw const UnauthenticatedException();
      await _supabase
          .from('categories')
          .delete()
          .eq('id', id)
          .eq('user_id', userId); // defense-in-depth: ensures user owns this row
      _invalidateCategoryCache();
    });
  }

  void _invalidateCategoryCache() {
    _cachedCategories = null;
    _categoriesFetchedAt = null;
  }

  // ── Profiles & Split Expenses ───────────────────────────────────────

  Future<List<ProfileModel>> getProfiles({bool forceRefresh = false}) async {
    final canUseCache =
        !forceRefresh &&
        _cachedProfiles != null &&
        _isCacheValid(_profilesFetchedAt, _profilesCacheTtl);

    if (canUseCache) {
      return List.unmodifiable(_cachedProfiles!);
    }

    if (_ongoingProfilesFetch != null) {
      return _ongoingProfilesFetch!.future;
    }

    final completer = Completer<List<ProfileModel>>();
    _ongoingProfilesFetch = completer;

    try {
      final list = await _execute(() async {
        final currentUserId = _supabase.auth.currentUser?.id;
        final response = await _supabase
            .from('profiles')
            .select('id, email, name')
            .order('name', ascending: true);

        final parsed = (response as List<dynamic>)
            .map((e) => ProfileModel.fromJson(e as Map<String, dynamic>))
            .where((p) => p.id != currentUserId) // Exclude current logged in user
            .toList();

        return parsed;
      });

      _cachedProfiles = list;
      _profilesFetchedAt = DateTime.now();
      completer.complete(list);
      return list;
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _ongoingProfilesFetch = null;
    }
  }

  Future<List<SplitExpenseModel>> getSplitExpenses({
    bool forceRefresh = false,
  }) async {
    final canUseCache =
        !forceRefresh &&
        _cachedSplitExpenses != null &&
        _isCacheValid(_splitExpensesFetchedAt, _splitCacheTtl);

    if (canUseCache) {
      return List.unmodifiable(_cachedSplitExpenses!);
    }

    if (_ongoingSplitFetch != null) {
      return _ongoingSplitFetch!.future;
    }

    final completer = Completer<List<SplitExpenseModel>>();
    _ongoingSplitFetch = completer;

    try {
      final splits = await _execute(() async {
        final userId = _supabase.auth.currentUser?.id;
        if (userId == null) throw const UnauthenticatedException();

        final response = await _supabase
            .from('split_expenses')
            .select()
            .or('payer_id.eq.$userId,borrower_id.eq.$userId')
            .order('expense_date', ascending: false);

        // Reuse the cached profiles list to avoid a redundant round-trip.
        // getProfiles() will return the in-memory cache if still valid.
        final profileList = await getProfiles(forceRefresh: false);
        final profilesMap = {
          for (final p in profileList) p.id: p.toJson(),
        };

        final result = (response as List<dynamic>).map((e) {
          final map = Map<String, dynamic>.from(e as Map<String, dynamic>);
          final payerId = map['payer_id'] as String?;
          final borrowerId = map['borrower_id'] as String?;
          if (payerId != null && profilesMap.containsKey(payerId)) {
            map['payer_profile'] = profilesMap[payerId];
          }
          if (borrowerId != null && profilesMap.containsKey(borrowerId)) {
            map['borrower_profile'] = profilesMap[borrowerId];
          }
          return SplitExpenseModel.fromJson(map);
        }).toList();

        return result;
      });

      _cachedSplitExpenses = splits;
      _splitExpensesFetchedAt = DateTime.now();
      completer.complete(splits);
      return splits;
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _ongoingSplitFetch = null;
    }
  }

  Future<SplitExpenseModel> addSplitExpense({
    required String borrowerId,
    required double amount,
    required double totalAmount,
    required String description,
    String category = 'General',
    required DateTime expenseDate,
    bool isPayer = true, // If true, current user paid; if false, borrower paid.
  }) async {
    return _executeMutation(() async {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) throw const UnauthenticatedException();

      final payerId = isPayer ? currentUserId : borrowerId;
      final actualBorrowerId = isPayer ? borrowerId : currentUserId;

      final response = await _supabase
          .from('split_expenses')
          .insert({
            'payer_id': payerId,
            'borrower_id': actualBorrowerId,
            'amount': amount,
            'total_amount': totalAmount,
            'description': description,
            'category': category,
            'status': 'pending',
            'expense_date': expenseDate.toUtc().toIso8601String(),
          })
          .select()
          .single();

      _invalidateSplitCache();
      return SplitExpenseModel.fromJson(response);
    });
  }

  Future<List<SplitExpenseModel>> addMultipleSplitExpenses({
    required List<String> borrowerIds,
    required double perPersonAmount,
    required double totalAmount,
    required String description,
    String category = 'General',
    required DateTime expenseDate,
    bool isPayer = true,
    String? payerId,
  }) async {
    return _executeMutation(() async {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) throw const UnauthenticatedException();

      final actualPayerId = isPayer ? currentUserId : (payerId ?? currentUserId);

      final rows = <Map<String, dynamic>>[];
      for (final bId in borrowerIds) {
        if (bId == actualPayerId) continue;
        rows.add({
          'payer_id': actualPayerId,
          'borrower_id': bId,
          'amount': perPersonAmount,
          'total_amount': totalAmount,
          'description': description,
          'category': category,
          'status': 'pending',
          'expense_date': expenseDate.toUtc().toIso8601String(),
        });
      }

      if (rows.isEmpty) return [];

      final response = await _supabase
          .from('split_expenses')
          .insert(rows)
          .select();

      final list = (response as List<dynamic>)
          .map((e) => SplitExpenseModel.fromJson(e as Map<String, dynamic>))
          .toList();

      _invalidateSplitCache();
      return list;
    });
  }

  Future<List<SplitExpenseModel>> addCustomMultipleSplitExpenses({
    required List<Map<String, dynamic>> borrowerSplits, // [{ 'borrower_id': '...', 'amount': 123.45 }]
    required double totalAmount,
    required String description,
    String category = 'General',
    required DateTime expenseDate,
    bool isPayer = true,
    String? payerId,
  }) async {
    return _executeMutation(() async {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) throw const UnauthenticatedException();

      final actualPayerId = isPayer ? currentUserId : (payerId ?? currentUserId);

      final rows = <Map<String, dynamic>>[];
      for (final split in borrowerSplits) {
        final bId = split['borrower_id'] as String;
        final amount = (split['amount'] as num).toDouble();
        if (bId == actualPayerId || amount <= 0) continue;
        rows.add({
          'payer_id': actualPayerId,
          'borrower_id': bId,
          'amount': amount,
          'total_amount': totalAmount,
          'description': description,
          'category': category,
          'status': 'pending',
          'expense_date': expenseDate.toUtc().toIso8601String(),
        });
      }

      if (rows.isEmpty) return [];

      final response = await _supabase
          .from('split_expenses')
          .insert(rows)
          .select();

      final list = (response as List<dynamic>)
          .map((e) => SplitExpenseModel.fromJson(e as Map<String, dynamic>))
          .toList();

      _invalidateSplitCache();
      return list;
    });
  }

  Future<SplitExpenseModel> updateSplitExpense({
    required String id,
    required String borrowerId,
    required double amount,
    required double totalAmount,
    required String description,
    String category = 'General',
    required DateTime expenseDate,
    bool isPayer = true,
    String? payerId,
  }) async {
    return _executeMutation(() async {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) throw const UnauthenticatedException();

      final actualPayerId = isPayer
          ? currentUserId
          : (payerId ?? currentUserId);
      final actualBorrowerId = isPayer ? borrowerId : currentUserId;

      final response = await _supabase
          .from('split_expenses')
          .update({
            'payer_id': actualPayerId,
            'borrower_id': actualBorrowerId,
            'amount': amount,
            'total_amount': totalAmount,
            'description': description,
            'category': category,
            'expense_date': expenseDate.toUtc().toIso8601String(),
          })
          .eq('id', id)
          .or('payer_id.eq.$currentUserId,borrower_id.eq.$currentUserId')
          .select()
          .single();

      // Reuse the cached profiles list to avoid a redundant round-trip.
      final profileList = await getProfiles(forceRefresh: false);
      final profilesMap = {
        for (final p in profileList) p.id: p.toJson(),
      };

      final map = Map<String, dynamic>.from(response);
      final pId = map['payer_id'] as String?;
      final bId = map['borrower_id'] as String?;
      if (pId != null && profilesMap.containsKey(pId)) {
        map['payer_profile'] = profilesMap[pId];
      }
      if (bId != null && profilesMap.containsKey(bId)) {
        map['borrower_profile'] = profilesMap[bId];
      }

      _invalidateSplitCache();
      return SplitExpenseModel.fromJson(map);
    });
  }

  Future<void> updateSplitExpenseStatus({
    required String id,
    required String status,
  }) async {
    return _executeMutation(() async {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw const UnauthenticatedException();

      await _supabase
          .from('split_expenses')
          .update({'status': status})
          .eq('id', id)
          .or('payer_id.eq.$userId,borrower_id.eq.$userId');

      _invalidateSplitCache();
    });
  }

  Future<void> deleteSplitExpense(String id) async {
    return _executeMutation(() async {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw const UnauthenticatedException();

      final response = await _supabase
          .from('split_expenses')
          .delete()
          .eq('id', id)
          .or('payer_id.eq.$userId,borrower_id.eq.$userId')
          .select();

      if ((response as List).isEmpty) {
        throw const DataException(
          'Failed to delete split expense: record not found or permission denied.',
        );
      }

      _invalidateSplitCache();
    });
  }

  /// Batch-deletes multiple split expenses in a single round-trip.
  /// Used when editing a split group to replace old records atomically.
  Future<void> deleteSplitExpenses(List<String> ids) async {
    if (ids.isEmpty) return;
    return _executeMutation(() async {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw const UnauthenticatedException();

      await _supabase
          .from('split_expenses')
          .delete()
          .inFilter('id', ids)
          .or('payer_id.eq.$userId,borrower_id.eq.$userId');

      _invalidateSplitCache();
    });
  }

  /// Batch-updates the status of multiple split expenses in a single round-trip.
  /// Used by settle-up flows to avoid N sequential API calls.
  Future<void> updateSplitExpenseStatusBatch({
    required List<String> ids,
    required String status,
  }) async {
    if (ids.isEmpty) return;
    return _executeMutation(() async {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw const UnauthenticatedException();

      await _supabase
          .from('split_expenses')
          .update({'status': status})
          .inFilter('id', ids)
          .or('payer_id.eq.$userId,borrower_id.eq.$userId');

      _invalidateSplitCache();
    });
  }
}
