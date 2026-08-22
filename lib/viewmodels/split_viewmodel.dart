import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/profile.dart';
import '../models/split_expense.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../utils/exceptions.dart';
import 'transaction_viewmodel.dart';

/// ViewModel managing Split Expenses and user profiles.
class SplitViewModel extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService.instance;
  final AuthService _authService = AuthService.instance;

  List<ProfileModel> _remoteProfiles = [];
  List<ProfileModel> _customProfiles = [];

  List<ProfileModel> get profiles {
    // Combine remote and custom profiles without duplicates
    final combined = <ProfileModel>[..._remoteProfiles];
    for (final custom in _customProfiles) {
      if (!combined.any((p) => p.id == custom.id)) {
        combined.add(custom);
      }
    }
    return combined;
  }

  List<SplitExpenseModel> _splitExpenses = [];
  List<SplitExpenseModel> get splitExpenses => _splitExpenses;

  Set<String> _hiddenFriendIds = {};
  Set<String> get hiddenFriendIds => _hiddenFriendIds;

  bool isFriendHidden(String friendId) => _hiddenFriendIds.contains(friendId);
  bool isCustomFriend(String friendId) => _customProfiles.any((p) => p.id == friendId);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? get currentUserId => _authService.currentUser?.id;

  /// Display name of the currently signed-in user (name from metadata, or email prefix, or 'You').
  String get currentUserDisplayName {
    final user = _authService.currentUser;
    final name = user?.userMetadata?['name'] as String?;
    if (name != null && name.trim().isNotEmpty) return name;
    final email = user?.email ?? '';
    return email.isNotEmpty ? email.split('@').first : 'You';
  }

  /// Email of the currently signed-in user, or empty string.
  String get currentUserEmail => _authService.currentUser?.email ?? '';

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
      _remoteProfiles = await _databaseService.getProfiles();
    } catch (e) {
      _errorMessage = _mapError(e);
    }
    await loadCustomProfiles();
    notifyListeners();
  }

  Future<void> loadCustomProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('custom_friend_profiles') ?? [];
      _customProfiles = list.map((item) {
        final jsonMap = jsonDecode(item) as Map<String, dynamic>;
        return ProfileModel.fromJson(jsonMap);
      }).toList();
    } catch (_) {}
  }

  String _generateLocalUuid() {
    final random = Random();
    String hex(int length) => List.generate(
      length,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    return '${hex(8)}-${hex(4)}-4${hex(3)}-${(random.nextInt(4) + 8).toRadixString(16)}${hex(3)}-${hex(12)}';
  }

  Future<ProfileModel> addCustomProfile({
    required String name,
    String? email,
  }) async {
    final trimmedName = name.trim();
    final trimmedEmail = (email != null && email.trim().isNotEmpty)
        ? email.trim()
        : '${trimmedName.toLowerCase().replaceAll(RegExp(r'\s+'), '')}@friend.local';

    final newProfile = ProfileModel(
      id: _generateLocalUuid(),
      name: trimmedName,
      email: trimmedEmail,
    );

    _customProfiles.add(newProfile);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final encodedList = _customProfiles.map((p) => jsonEncode(p.toJson())).toList();
      await prefs.setStringList('custom_friend_profiles', encodedList);
    } catch (_) {}

    return newProfile;
  }

  Future<void> deleteCustomProfile(String profileId) async {
    _customProfiles.removeWhere((p) => p.id == profileId);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final encodedList = _customProfiles.map((p) => jsonEncode(p.toJson())).toList();
      await prefs.setStringList('custom_friend_profiles', encodedList);
    } catch (_) {}
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

  Future<bool> addCustomMultipleSplitExpenses({
    required List<Map<String, dynamic>> borrowerSplits,
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
      final newSplits = await _databaseService.addCustomMultipleSplitExpenses(
        borrowerSplits: borrowerSplits,
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

  Future<bool> updateSplitExpense({
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
    _isSaving = true;
    _errorMessage = null;

    final index = _splitExpenses.indexWhere((s) => s.id == id);
    SplitExpenseModel? backup;
    if (index != -1) {
      backup = _splitExpenses[index];
      final currentUserId = this.currentUserId;
      final actualPayerId = isPayer
          ? (currentUserId ?? backup.payerId)
          : (payerId ?? currentUserId ?? backup.payerId);
      final actualBorrowerId = isPayer
          ? borrowerId
          : (currentUserId ?? backup.borrowerId);

      _splitExpenses[index] = backup.copyWith(
        payerId: actualPayerId,
        borrowerId: actualBorrowerId,
        amount: amount,
        totalAmount: totalAmount,
        description: description,
        category: category,
        expenseDate: expenseDate,
      );
    }
    notifyListeners();

    try {
      final updatedSplit = await _databaseService.updateSplitExpense(
        id: id,
        borrowerId: borrowerId,
        amount: amount,
        totalAmount: totalAmount,
        description: description,
        category: category,
        expenseDate: expenseDate,
        isPayer: isPayer,
        payerId: payerId,
      );

      if (index != -1) {
        _splitExpenses[index] = updatedSplit;
      }
      return true;
    } catch (e) {
      if (index != -1 && backup != null) {
        _splitExpenses[index] = backup;
      }
      _errorMessage = _mapError(e);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> toggleSettled(
    SplitExpenseModel split, {
    TransactionViewModel? transactionVM,
  }) async {
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
        final description = isPayer
            ? 'Settlement from $partnerName for ${split.description}'
            : 'Settlement to $partnerName for ${split.description}';

        if (transactionVM != null) {
          await transactionVM.addTransaction(
            amount: split.amount,
            type: isPayer ? 'income' : 'expense',
            category: 'Other',
            description: description,
            paymentMethod: 'upi',
            transactionDate: DateTime.now(),
          );
        } else {
          await _databaseService.addTransaction(
            amount: split.amount,
            type: isPayer ? 'income' : 'expense',
            category: 'Other',
            description: description,
            paymentMethod: 'upi',
            transactionDate: DateTime.now(),
          );
        }
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

  Future<void> settleUpWithPartner(
    String partnerId, {
    String? partnerName,
    TransactionViewModel? transactionVM,
  }) async {
    final uid = currentUserId;
    if (uid == null) return;

    final pendingSplits = _splitExpenses.where((s) {
      return s.status == 'pending' &&
          ((s.payerId == uid && s.borrowerId == partnerId) ||
           (s.borrowerId == uid && s.payerId == partnerId));
    }).toList();

    if (pendingSplits.isEmpty) return;

    // Calculate net balance
    double sumOwedToUser = 0.0;
    double sumUserOwes = 0.0;
    for (final s in pendingSplits) {
      if (s.payerId == uid) {
        sumOwedToUser += s.amount;
      } else if (s.borrowerId == uid) {
        sumUserOwes += s.amount;
      }
    }
    final netBalance = sumOwedToUser - sumUserOwes;

    // Optimistically update status
    for (final s in pendingSplits) {
      final index = _splitExpenses.indexWhere((item) => item.id == s.id);
      if (index != -1) {
        _splitExpenses[index] = s.copyWith(status: 'settled');
      }
    }
    notifyListeners();

    try {
      for (final s in pendingSplits) {
        await _databaseService.updateSplitExpenseStatus(
          id: s.id,
          status: 'settled',
        );
      }

      // Record a single consolidated personal settlement transaction
      if (netBalance != 0) {
        final isIncome = netBalance > 0;
        final amount = netBalance.abs();
        final name = partnerName ?? 'Friend';
        final description = isIncome
            ? 'Settlement from $name'
            : 'Settlement to $name';

        if (transactionVM != null) {
          await transactionVM.addTransaction(
            amount: amount,
            type: isIncome ? 'income' : 'expense',
            category: 'Other',
            description: description,
            paymentMethod: 'upi',
            transactionDate: DateTime.now(),
          );
        } else {
          await _databaseService.addTransaction(
            amount: amount,
            type: isIncome ? 'income' : 'expense',
            category: 'Other',
            description: description,
            paymentMethod: 'upi',
            transactionDate: DateTime.now(),
          );
        }
      }
    } catch (e) {
      _errorMessage = _mapError(e);
      await loadSplitExpenses();
      notifyListeners();
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
