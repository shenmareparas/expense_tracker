import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';
import '../models/split_expense.dart';
import '../services/database_service.dart';
import '../utils/exceptions.dart';

/// ViewModel managing Split Expenses and user profiles.
class SplitViewModel extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  List<ProfileModel> _profiles = [];
  List<ProfileModel> get profiles => _profiles;

  List<SplitExpenseModel> _splitExpenses = [];
  List<SplitExpenseModel> get splitExpenses => _splitExpenses;

  Set<String> _hiddenFriendIds = {};
  Set<String> get hiddenFriendIds => _hiddenFriendIds;

  bool isFriendHidden(String friendId) => _hiddenFriendIds.contains(friendId);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? get currentUserId => _supabase.auth.currentUser?.id;

  // ── Computed Balances ───────────────────────────────────────────────

  /// Amount others owe the current user (where status == 'pending' and payer == currentUser)
  double get totalOwedToUser {
    final uid = currentUserId;
    if (uid == null) return 0.0;
    double sum = 0.0;
    for (final s in _splitExpenses) {
      if (s.status == 'pending' && s.payerId == uid) {
        sum += s.amount;
      }
    }
    return sum;
  }

  /// Amount current user owes others (where status == 'pending' and borrower == currentUser)
  double get totalUserOwes {
    final uid = currentUserId;
    if (uid == null) return 0.0;
    double sum = 0.0;
    for (final s in _splitExpenses) {
      if (s.status == 'pending' && s.borrowerId == uid) {
        sum += s.amount;
      }
    }
    return sum;
  }

  /// Net balance (positive = you are owed money, negative = you owe money)
  double get netBalance => totalOwedToUser - totalUserOwes;

  // ── Actions ─────────────────────────────────────────────────────────

  Future<void> loadProfiles() async {
    try {
      _profiles = await _databaseService.getProfiles();
      notifyListeners();
    } catch (e) {
      _errorMessage = _mapError(e);
    }
  }

  Future<void> loadSplitExpenses() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _splitExpenses = await _databaseService.getSplitExpenses();
    } catch (e) {
      _errorMessage = _mapError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addSplitExpense({
    required String borrowerId,
    required double amount,
    required double totalAmount,
    required String description,
    String category = 'General',
    required DateTime expenseDate,
    bool isPayer = true,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newSplit = await _databaseService.addSplitExpense(
        borrowerId: borrowerId,
        amount: amount,
        totalAmount: totalAmount,
        description: description,
        category: category,
        expenseDate: expenseDate,
        isPayer: isPayer,
      );

      _splitExpenses.insert(0, newSplit);
      return true;
    } catch (e) {
      _errorMessage = _mapError(e);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> addMultipleSplitExpenses({
    required List<String> borrowerIds,
    required double perPersonAmount,
    required double totalAmount,
    required String description,
    String category = 'General',
    required DateTime expenseDate,
    bool isPayer = true,
    String? payerId,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newSplits = await _databaseService.addMultipleSplitExpenses(
        borrowerIds: borrowerIds,
        perPersonAmount: perPersonAmount,
        totalAmount: totalAmount,
        description: description,
        category: category,
        expenseDate: expenseDate,
        isPayer: isPayer,
        payerId: payerId,
      );

      _splitExpenses.insertAll(0, newSplits);
      return true;
    } catch (e) {
      _errorMessage = _mapError(e);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> toggleSettled(SplitExpenseModel split) async {
    final uid = currentUserId;
    if (uid == null) return;
    if (split.payerId != uid && split.borrowerId != uid) return;

    final newStatus = split.status == 'pending' ? 'settled' : 'pending';
    final index = _splitExpenses.indexWhere((s) => s.id == split.id);
    if (index == -1) return;

    final backup = _splitExpenses[index];
    _splitExpenses[index] = split.copyWith(status: newStatus);
    notifyListeners();

    try {
      await _databaseService.updateSplitExpenseStatus(
        id: split.id,
        status: newStatus,
      );

      if (newStatus == 'settled') {
        final isPayer = split.payerId == uid;
        final partnerName = isPayer ? split.displayBorrower : split.displayPayer;
        await _databaseService.addTransaction(
          amount: split.amount,
          type: isPayer ? 'income' : 'expense',
          category: 'General',
          description: isPayer
              ? 'Settlement from $partnerName for ${split.description}'
              : 'Settlement to $partnerName for ${split.description}',
          paymentMethod: 'upi',
          transactionDate: DateTime.now(),
        );
      }
    } catch (e) {
      _splitExpenses[index] = backup;
      _errorMessage = _mapError(e);
      notifyListeners();
    }
  }

  Future<void> deleteSplitExpense(String id) async {
    final index = _splitExpenses.indexWhere((s) => s.id == id);
    if (index == -1) return;

    final backup = _splitExpenses[index];
    _splitExpenses.removeAt(index);
    notifyListeners();

    try {
      await _databaseService.deleteSplitExpense(id);
    } catch (e) {
      _splitExpenses.insert(index, backup);
      _errorMessage = _mapError(e);
      notifyListeners();
    }
  }

  Future<void> settleUpWithPartner(String partnerId) async {
    final uid = currentUserId;
    if (uid == null) return;

    final pendingSplits = _splitExpenses.where((s) {
      return s.status == 'pending' &&
          ((s.payerId == uid && s.borrowerId == partnerId) ||
           (s.borrowerId == uid && s.payerId == partnerId));
    }).toList();

    for (final s in pendingSplits) {
      await toggleSettled(s);
    }
  }

  Future<void> loadHiddenFriends() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('hidden_friend_ids') ?? [];
      _hiddenFriendIds = list.toSet();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> toggleHideFriend(String friendId) async {
    if (_hiddenFriendIds.contains(friendId)) {
      _hiddenFriendIds.remove(friendId);
    } else {
      _hiddenFriendIds.add(friendId);
    }
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('hidden_friend_ids', _hiddenFriendIds.toList());
    } catch (_) {}
  }

  String _mapError(Object error) {
    if (error is AppException) {
      return error.message;
    }
    return 'Error: $error';
  }
}
