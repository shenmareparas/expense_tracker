import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/transaction.dart';
import '../models/category.dart';

class DatabaseService {
  final _supabase = Supabase.instance.client;

  // Transactions
  Future<List<TransactionModel>> getTransactions() async {
    final response = await _supabase
        .from('transactions')
        .select()
        .order('transaction_date', ascending: false);

    return (response as List<dynamic>)
        .map((e) => TransactionModel.fromJson(e as Map<String, dynamic>))
        .toList();
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
      'transaction_date': transactionDate.toIso8601String(),
    });
  }

  Future<void> deleteTransaction(String id) async {
    await _supabase.from('transactions').delete().eq('id', id);
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
          'transaction_date': transactionDate.toIso8601String(),
        })
        .eq('id', id);
  }

  // Categories
  Future<List<CategoryModel>> getCategories() async {
    final response = await _supabase
        .from('categories')
        .select()
        .order('order_index', ascending: true);

    return (response as List<dynamic>)
        .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
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
    }
  }

  Future<void> reorderCategories(List<CategoryModel> categories) async {
    final List<Map<String, dynamic>> updates = [];
    for (int i = 0; i < categories.length; i++) {
      final json = categories[i].toJson();
      json['order_index'] = i;
      json.remove('created_at'); // Do not touch creation timestamp
      updates.add(json);
    }

    // Supabase upsert requires full non-null objects on insert-checks
    await _supabase.from('categories').upsert(updates);
  }

  Future<void> deleteCategory(String id) async {
    await _supabase.from('categories').delete().eq('id', id);
  }
}
