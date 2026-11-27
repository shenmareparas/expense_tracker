import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/profile.dart';
import '../models/split_expense.dart';
import '../models/transaction.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../utils/exceptions.dart';
import 'transaction_viewmodel.dart';

/// Pre-aggregated balance summary between the current user and one partner.
class PartnerBalanceSummary {
  final double owedToUser;
  final double userOwes;
  final int splitCount;

  const PartnerBalanceSummary({
    this.owedToUser = 0.0,
    this.userOwes = 0.0,
    this.splitCount = 0,
  });

  double get net => owedToUser - userOwes;
}

/// ViewModel managing Split Expenses and user profiles.
class SplitViewModel extends ChangeNotifier {
  final DatabaseService? _dbService;
  final AuthService? _authServiceInstance;

  DatabaseService get _databaseService =>
      _dbService ?? DatabaseService.instance;
  AuthService get _authService => _authServiceInstance ?? AuthService.instance;

  SplitViewModel({DatabaseService? databaseService, AuthService? authService})
    : _dbService = databaseService,
      _authServiceInstance = authService;

  /// Cached SharedPreferences instance — avoids repeated `getInstance()` calls.
  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

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
  bool isCustomFriend(String friendId) =>
      _customProfiles.any((p) => p.id == friendId);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _mockUserId;
  String? get currentUserId => _mockUserId ?? _authService.currentUser?.id;

  @visibleForTesting
  void setMockData({
    List<SplitExpenseModel>? splitExpenses,
    String? mockUserId,
  }) {
    if (splitExpenses != null) _splitExpenses = splitExpenses;
    if (mockUserId != null) _mockUserId = mockUserId;
  }

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

  Map<String, PartnerBalanceSummary>? _partnerBalanceCache;
  String? _partnerBalanceCacheUserId;

  @override
  void notifyListeners() {
    _partnerBalanceCache = null;
    _partnerBalanceCacheUserId = null;
    super.notifyListeners();
  }

  /// Returns the pre-aggregated balance summary for [partnerId] in O(1) after
  /// a single O(splits) pass per state update.
  PartnerBalanceSummary getPartnerBalance(String partnerId) {
    final uid = currentUserId;
    if (uid == null) return const PartnerBalanceSummary();

    if (_partnerBalanceCache == null || _partnerBalanceCacheUserId != uid) {
      final map = <String, ({double owed, double owes, int count})>{};
      for (final s in _splitExpenses) {
        if (s.payerId == uid && s.borrowerId != uid) {
          final prev = map[s.borrowerId] ?? (owed: 0.0, owes: 0.0, count: 0);
          map[s.borrowerId] = (
            owed: prev.owed + (s.status == 'pending' ? s.amount : 0.0),
            owes: prev.owes,
            count: prev.count + 1,
          );
        } else if (s.borrowerId == uid && s.payerId != uid) {
          final prev = map[s.payerId] ?? (owed: 0.0, owes: 0.0, count: 0);
          map[s.payerId] = (
            owed: prev.owed,
            owes: prev.owes + (s.status == 'pending' ? s.amount : 0.0),
            count: prev.count + 1,
          );
        }
      }
      _partnerBalanceCache = map.map(
        (key, v) => MapEntry(
          key,
          PartnerBalanceSummary(
            owedToUser: v.owed,
            userOwes: v.owes,
            splitCount: v.count,
          ),
        ),
      );
      _partnerBalanceCacheUserId = uid;
    }

    return _partnerBalanceCache![partnerId] ?? const PartnerBalanceSummary();
  }

  /// Net balance (positive = you are owed money, negative = you owe money)
  double get netBalance => totalOwedToUser - totalUserOwes;

  // ── Actions ─────────────────────────────────────────────────────────

  Future<void> loadProfiles({bool forceRefresh = false}) async {
    try {
      _remoteProfiles = await _databaseService.getProfiles(
        forceRefresh: forceRefresh,
      );
    } catch (e) {
      _errorMessage = _mapError(e);
    }
    await loadCustomProfiles();
    notifyListeners();
  }

  Future<void> loadCustomProfiles() async {
    try {
      final prefs = await _getPrefs();
      final list = prefs.getStringList('custom_friend_profiles') ?? [];
      _customProfiles = list.map((item) {
        final jsonMap = jsonDecode(item) as Map<String, dynamic>;
        return ProfileModel.fromJson(jsonMap);
      }).toList();
    } catch (_) {}
  }

  String _generateLocalUuid() {
    // Use Random.secure() to ensure cryptographically random UUIDs.
    final random = Random.secure();
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
      final prefs = await _getPrefs();
      final encodedList = _customProfiles
          .map((p) => jsonEncode(p.toJson()))
          .toList();
      await prefs.setStringList('custom_friend_profiles', encodedList);
    } catch (_) {}

    return newProfile;
  }

  Future<void> deleteCustomProfile(String profileId) async {
    _customProfiles.removeWhere((p) => p.id == profileId);
    notifyListeners();

    try {
      final prefs = await _getPrefs();
      final encodedList = _customProfiles
          .map((p) => jsonEncode(p.toJson()))
          .toList();
      await prefs.setStringList('custom_friend_profiles', encodedList);
    } catch (_) {}
  }

  Future<void> loadSplitExpenses({bool forceRefresh = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _splitExpenses = List<SplitExpenseModel>.from(
        await _databaseService.getSplitExpenses(forceRefresh: forceRefresh),
      );
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

  /// Returns all sister split expenses belonging to the same overall bill/event.
  List<SplitExpenseModel> getSisterSplits(SplitExpenseModel split) {
    final list = _splitExpenses.where((s) {
      final samePayer = s.payerId == split.payerId;
      final sameDesc =
          s.description.trim().toLowerCase() ==
          split.description.trim().toLowerCase();
      final sameTotal = (s.totalAmount - split.totalAmount).abs() < 0.05;
      final sameDate =
          s.expenseDate.difference(split.expenseDate).inMinutes.abs() < 5;
      return samePayer && sameDesc && sameTotal && sameDate;
    }).toList();

    if (list.isEmpty || !list.any((s) => s.id == split.id)) {
      return [split];
    }
    return list;
  }

  Future<bool> updateSplitExpenseGroup({
    required List<String> oldSplitIds,
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
      // Batch-delete all old splits in a single round-trip instead of N sequential calls.
      await _databaseService.deleteSplitExpenses(oldSplitIds);
      _splitExpenses.removeWhere((s) => oldSplitIds.contains(s.id));

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
      await loadSplitExpenses();
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
        final partnerName = isPayer
            ? split.displayBorrower
            : split.displayPayer;
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
      } else if (newStatus == 'pending' && transactionVM != null) {
        // If split is reverted back to pending, look for and clean up any single settlement transaction
        final isPayer = split.payerId == uid;
        final partnerName = isPayer
            ? split.displayBorrower
            : split.displayPayer;
        final descToMatch = isPayer
            ? 'settlement from $partnerName for ${split.description}'
                  .toLowerCase()
            : 'settlement to $partnerName for ${split.description}'
                  .toLowerCase();

        final matchingTx = transactionVM.transactions
            .cast<TransactionModel?>()
            .firstWhere(
              (t) =>
                  t != null &&
                  (t.description?.toLowerCase() == descToMatch) &&
                  (t.amount - split.amount).abs() < 0.05,
              orElse: () => null,
            );

        if (matchingTx != null) {
          await transactionVM.deleteTransaction(matchingTx.id);
        }
      }
    } catch (e) {
      _splitExpenses[index] = backup;
      _errorMessage = _mapError(e);
      notifyListeners();
    }
  }

  static String extractSplitDescription(String txDesc) {
    var desc = txDesc.trim();
    if (desc.toLowerCase().startsWith('split:')) {
      desc = desc.substring(6).trim();
    }
    final parenIndex = desc.lastIndexOf(' (');
    if (parenIndex != -1 && desc.endsWith(')')) {
      desc = desc.substring(0, parenIndex).trim();
    }
    return desc;
  }

  /// Returns the current user's individual financial share for a split expense transaction,
  /// or null if the transaction is not recognized as a split expense.
  double? getUserShareForSplitTransaction(TransactionModel t) {
    final uid = currentUserId;
    if (uid == null) return null;

    final desc = t.description?.trim() ?? '';
    final isExplicitSplit = desc.toLowerCase().startsWith('split:');
    final cleanDesc = extractSplitDescription(desc).toLowerCase();

    // Match candidate splits where the current user was the payer
    final matchingSplits = _splitExpenses.where((s) {
      if (s.payerId != uid) return false;
      final sDesc = s.description.trim().toLowerCase();
      final descMatch =
          sDesc == cleanDesc ||
          (cleanDesc.isNotEmpty && sDesc.contains(cleanDesc)) ||
          (desc.isNotEmpty && desc.toLowerCase().contains(sDesc));
      if (!descMatch) return false;

      final dateDiff = s.expenseDate
          .difference(t.transactionDate)
          .inMinutes
          .abs();
      final amountMatch = (s.totalAmount - t.amount).abs() < 0.05;
      final sameDay =
          s.expenseDate.year == t.transactionDate.year &&
          s.expenseDate.month == t.transactionDate.month &&
          s.expenseDate.day == t.transactionDate.day;
      return amountMatch || dateDiff < 1440 || sameDay;
    }).toList();

    if (matchingSplits.isEmpty) {
      return isExplicitSplit ? t.amount : null;
    }

    // Sort candidates to pick the one closest in amount and time
    matchingSplits.sort((a, b) {
      final amountDiffA = (a.totalAmount - t.amount).abs();
      final amountDiffB = (b.totalAmount - t.amount).abs();
      if ((amountDiffA - amountDiffB).abs() > 0.05) {
        return amountDiffA.compareTo(amountDiffB);
      }
      final dateDiffA = a.expenseDate
          .difference(t.transactionDate)
          .inMinutes
          .abs();
      final dateDiffB = b.expenseDate
          .difference(t.transactionDate)
          .inMinutes
          .abs();
      return dateDiffA.compareTo(dateDiffB);
    });

    final targetSplit = matchingSplits.first;
    final sisterSplits = getSisterSplits(targetSplit);

    // Sum all portions owed by other participants
    final othersShare = sisterSplits
        .where((s) => s.borrowerId != uid)
        .fold(0.0, (sum, s) => sum + s.amount);

    final rawMyShare = targetSplit.totalAmount - othersShare;
    final myShare = rawMyShare < 0.0
        ? 0.0
        : (rawMyShare > targetSplit.totalAmount
              ? targetSplit.totalAmount
              : rawMyShare);

    return double.parse(myShare.toStringAsFixed(2));
  }

  /// Finds an underlying split expense matching a settlement expense transaction.
  SplitExpenseModel? findMatchingSplitForSettlement(TransactionModel t) {
    final uid = currentUserId;
    if (uid == null) return null;

    final desc = t.description?.trim().toLowerCase() ?? '';
    final forIndex = desc.indexOf(' for ');
    String targetDesc = '';
    if (forIndex != -1) {
      targetDesc = desc.substring(forIndex + 5).trim();
    }

    for (final s in _splitExpenses) {
      if (s.borrowerId == uid) {
        if (targetDesc.isNotEmpty &&
            s.description.trim().toLowerCase() == targetDesc) {
          return s;
        }
      }
    }

    if (targetDesc.isEmpty) {
      for (final s in _splitExpenses) {
        if (s.borrowerId == uid && (s.amount - t.amount).abs() < 0.05) {
          return s;
        }
      }
    }

    return null;
  }

  /// Returns synthetic transaction models for shared expenses where other users were the payer
  /// and the current user is the borrower, matching the given filter criteria.
  List<TransactionModel> getBorrowerSplitTransactions({
    String? type,
    List<String>? categories,
    String? paymentMethod,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
    List<TransactionModel>? existingTransactions,
  }) {
    final uid = currentUserId;
    if (uid == null) return [];

    // Borrower splits are split obligations ("You Owe"), not direct paid expenses or income.
    // They are only included when viewing all transactions (type == null) or filtering by 'split' / 'you_owe'.
    if (type != null &&
        type.toLowerCase() != 'split' &&
        type.toLowerCase() != 'you_owe') {
      return [];
    }

    final query = (searchQuery ?? '').trim().toLowerCase();
    final results = <TransactionModel>[];

    for (final s in _splitExpenses) {
      if (s.borrowerId != uid || s.payerId == uid || s.amount <= 0) {
        continue;
      }

      // Check date boundaries
      if (startDate != null && s.expenseDate.isBefore(startDate)) continue;
      if (endDate != null && s.expenseDate.isAfter(endDate)) continue;

      // Check category filters
      if (categories != null && categories.isNotEmpty) {
        final matchesCat = categories.any(
          (c) => c.trim().toLowerCase() == s.category.trim().toLowerCase(),
        );
        if (!matchesCat) continue;
      }

      // Check payment method
      if (paymentMethod != null &&
          paymentMethod.isNotEmpty &&
          paymentMethod != 'upi' &&
          paymentMethod != 'split') {
        continue;
      }

      String payerName = s.displayPayer;
      if (payerName == 'User') {
        final profile = profiles.cast<ProfileModel?>().firstWhere(
          (p) => p != null && p.id == s.payerId,
          orElse: () => null,
        );
        if (profile != null && profile.displayName.isNotEmpty) {
          payerName = profile.displayName;
        }
      }
      final cleanDesc = s.description.trim();
      final txDesc = cleanDesc.toLowerCase().startsWith('split:')
          ? cleanDesc
          : 'Split: $cleanDesc';

      // Check search query
      if (query.isNotEmpty) {
        final matchesDesc = txDesc.toLowerCase().contains(query);
        final matchesPayer = payerName.toLowerCase().contains(query);
        final matchesCat = s.category.toLowerCase().contains(query);
        final matchesAmount = s.amount.toString().contains(query);
        if (!matchesDesc && !matchesPayer && !matchesCat && !matchesAmount) {
          continue;
        }
      }

      // Check if already represented in personal transactions (defensive safeguard)
      if (existingTransactions != null) {
        final alreadyExists = existingTransactions.any((t) {
          if (t.type != 'expense') return false;
          final desc = (t.description ?? '').trim().toLowerCase();
          if (desc.startsWith('settlement') ||
              desc.startsWith('split settlement')) {
            return false;
          }
          final sDesc = s.description.trim().toLowerCase();
          final matchesDesc =
              desc == 'split: $sDesc' ||
              desc.startsWith('split: $sDesc') ||
              desc == sDesc;
          final matchesAmount = (t.amount - s.amount).abs() < 0.05;
          final matchesDate =
              s.expenseDate.difference(t.transactionDate).inMinutes.abs() < 120;
          return matchesDesc && (matchesAmount || matchesDate);
        });
        if (alreadyExists) continue;
      }

      results.add(
        TransactionModel(
          id: 'split_borrower_${s.id}',
          userId: uid,
          amount: s.amount,
          type: 'expense',
          category: s.category.trim().isEmpty ? 'General' : s.category,
          description: txDesc,
          paymentMethod: 'upi',
          transactionDate: s.expenseDate,
          createdAt: s.createdAt,
        ),
      );
    }

    return results;
  }

  /// Transforms raw transactions for personal spending analytics:
  /// 1. Split expenses where the user was the payer are adjusted to reflect only the user's out-of-pocket share (total - borrowers' shares).
  /// 2. If the user's share is 0 (e.g. paid on behalf of a partner), it is omitted from expense calculations.
  /// 3. Split expenses added by other users where the current user is a borrower are included under their category (e.g. 'Food').
  /// 4. Settlement reimbursements received from friends ('Settlement from ...') are excluded from income.
  /// 5. Settlements paid to friends ('Settlement to ...') are excluded from expenses to prevent double-counting with borrower split expenses.
  List<TransactionModel> transformTransactionsForAnalytics(
    List<TransactionModel> transactions, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final adjusted = <TransactionModel>[];

    for (final t in transactions) {
      final descLower = (t.description ?? '').trim().toLowerCase();

      // 1. Settlement reimbursements from friends are debt repayments, not earned income
      if (t.type == 'income' &&
          (descLower.startsWith('settlement from') ||
              descLower.startsWith('split settlement from'))) {
        continue;
      }

      // 2. Settlements paid to friends are debt payments for shared expenses.
      // Since the underlying borrower split expense is directly included with its true category and date below,
      // settlement payment transactions must be omitted to prevent double-counting.
      if (t.type == 'expense' &&
          (descLower.startsWith('settlement to') ||
              descLower.startsWith('split settlement to'))) {
        continue;
      }

      // 3. Split expenses where user was the payer
      if (t.type == 'expense') {
        final userShare = getUserShareForSplitTransaction(t);
        if (userShare != null) {
          if (userShare > 0) {
            adjusted.add(t.copyWith(amount: userShare));
          }
          // If userShare == 0, omit from personal spending analytics.
          continue;
        }
      }

      // 4. Regular personal transaction
      adjusted.add(t);
    }

    // 5. Include shared expenses where other users were the payer and current user is the borrower
    final borrowerSplits = getBorrowerSplitTransactions(
      startDate: startDate,
      endDate: endDate,
      existingTransactions: transactions,
    );
    adjusted.addAll(borrowerSplits);

    return adjusted;
  }

  Future<void> deleteSplitExpense(
    String id, {
    TransactionViewModel? transactionVM,
  }) async {
    final index = _splitExpenses.indexWhere((s) => s.id == id);
    if (index == -1) return;

    final backup = _splitExpenses[index];
    _splitExpenses.removeAt(index);
    notifyListeners();

    try {
      await _databaseService.deleteSplitExpense(id);

      final uid = currentUserId;
      if (uid != null && backup.payerId == uid && transactionVM != null) {
        // Check if other splits with the same description and date still exist
        final otherSplitsExist = _splitExpenses.any(
          (s) =>
              s.payerId == uid &&
              s.description.toLowerCase() == backup.description.toLowerCase() &&
              s.expenseDate.difference(backup.expenseDate).inMinutes.abs() < 5,
        );

        if (!otherSplitsExist) {
          final txList = transactionVM.transactions;
          final cleanDesc = backup.description.trim().toLowerCase();
          final matchingTx = txList.cast<TransactionModel?>().firstWhere(
            (t) =>
                t != null &&
                t.type == 'expense' &&
                ((t.description?.trim().toLowerCase() == 'split: $cleanDesc') ||
                    (t.description?.trim().toLowerCase().startsWith(
                          'split: $cleanDesc',
                        ) ??
                        false) ||
                    (t.description?.trim().toLowerCase() == cleanDesc)) &&
                (t.transactionDate
                            .difference(backup.expenseDate)
                            .inMinutes
                            .abs() <
                        120 ||
                    (t.amount - backup.totalAmount).abs() < 0.05),
            orElse: () => null,
          );

          if (matchingTx != null) {
            await transactionVM.deleteTransaction(matchingTx.id);
          }
        }
      }
    } catch (e) {
      _splitExpenses.insert(index, backup);
      _errorMessage = _mapError(e);
      notifyListeners();
    }
  }

  Future<void> deleteSplitsForTransaction(TransactionModel transaction) async {
    final uid = currentUserId;
    if (uid == null) return;
    final splitDesc = extractSplitDescription(transaction.description ?? '');
    if (splitDesc.isEmpty) return;

    final matchingSplits = _splitExpenses.where((s) {
      final matchesUser = s.payerId == uid || s.borrowerId == uid;
      final matchesDesc =
          s.description.trim().toLowerCase() == splitDesc.toLowerCase() ||
          (transaction.description?.toLowerCase().contains(
                s.description.toLowerCase(),
              ) ??
              false);
      final matchesDate =
          s.expenseDate
              .difference(transaction.transactionDate)
              .inMinutes
              .abs() <
          120;
      final matchesAmount = (s.totalAmount - transaction.amount).abs() < 0.05;
      return matchesUser && matchesDesc && (matchesDate || matchesAmount);
    }).toList();

    for (final s in matchingSplits) {
      await deleteSplitExpense(s.id);
    }
  }

  Future<void> updateSplitsForTransaction(TransactionModel transaction) async {
    final uid = currentUserId;
    if (uid == null) return;
    final splitDesc = extractSplitDescription(transaction.description ?? '');
    if (splitDesc.isEmpty) return;

    final matchingSplits = _splitExpenses.where((s) {
      final matchesUser = s.payerId == uid;
      final matchesDesc =
          s.description.trim().toLowerCase() == splitDesc.toLowerCase() ||
          (transaction.description?.toLowerCase().contains(
                s.description.toLowerCase(),
              ) ??
              false);
      final matchesDate =
          s.expenseDate
              .difference(transaction.transactionDate)
              .inMinutes
              .abs() <
          120;
      final matchesAmount = (s.totalAmount - transaction.amount).abs() < 0.05;
      return matchesUser && matchesDesc && (matchesDate || matchesAmount);
    }).toList();

    for (final s in matchingSplits) {
      final double newAmount;
      if (s.totalAmount > 0 && s.amount > 0) {
        final ratio = s.amount / s.totalAmount;
        newAmount = double.parse(
          (transaction.amount * ratio).toStringAsFixed(2),
        );
      } else {
        newAmount = s.amount;
      }

      await updateSplitExpense(
        id: s.id,
        borrowerId: s.borrowerId,
        amount: newAmount,
        totalAmount: transaction.amount,
        description: splitDesc,
        category: transaction.category,
        expenseDate: transaction.transactionDate,
        isPayer: true,
        payerId: s.payerId,
      );
    }
  }

  /// Tracks the most recent settlement batch per partner so we can undo specifically those expenses.
  final Map<String, _LastSettlementRecord> _lastSettlementByPartner = {};

  bool canUndoSettleUp(String partnerId) =>
      _lastSettlementByPartner.containsKey(partnerId);

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

    final pendingSplitIds = pendingSplits.map((s) => s.id).toList();

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
      // Batch-update all pending splits in a single round-trip instead of N sequential calls.
      await _databaseService.updateSplitExpenseStatusBatch(
        ids: pendingSplitIds,
        status: 'settled',
      );

      String? createdTxId;
      // Record a single consolidated personal settlement transaction
      if (netBalance != 0) {
        final isIncome = netBalance > 0;
        final amount = netBalance.abs();
        final name = partnerName ?? 'Friend';
        final description = isIncome
            ? 'Settlement from $name'
            : 'Settlement to $name';

        final newTx = await _databaseService.addTransaction(
          amount: amount,
          type: isIncome ? 'income' : 'expense',
          category: 'Other',
          description: description,
          paymentMethod: 'upi',
          transactionDate: DateTime.now(),
        );
        createdTxId = newTx.id;

        if (transactionVM != null) {
          transactionVM.loadTransactions();
        }
      }

      // Store record to allow targeted undo of only these settled expenses
      _lastSettlementByPartner[partnerId] = _LastSettlementRecord(
        partnerId: partnerId,
        settledSplitIds: pendingSplitIds,
        createdTransactionId: createdTxId,
        timestamp: DateTime.now(),
      );
      notifyListeners();
    } catch (e) {
      _errorMessage = _mapError(e);
      await loadSplitExpenses();
      notifyListeners();
    }
  }

  Future<void> undoLastSettleUp(
    String partnerId, {
    TransactionViewModel? transactionVM,
  }) async {
    final record = _lastSettlementByPartner[partnerId];
    if (record == null || record.settledSplitIds.isEmpty) return;

    final targetIds = record.settledSplitIds.toSet();

    // Optimistically revert only the split expenses from this specific settlement
    for (var i = 0; i < _splitExpenses.length; i++) {
      if (targetIds.contains(_splitExpenses[i].id)) {
        _splitExpenses[i] = _splitExpenses[i].copyWith(status: 'pending');
      }
    }
    notifyListeners();

    try {
      await _databaseService.updateSplitExpenseStatusBatch(
        ids: record.settledSplitIds,
        status: 'pending',
      );

      // Clean up the created personal settlement transaction
      if (record.createdTransactionId != null) {
        if (transactionVM != null) {
          await transactionVM.deleteTransaction(record.createdTransactionId!);
        } else {
          await _databaseService.deleteTransaction(
            record.createdTransactionId!,
          );
        }
      }

      _lastSettlementByPartner.remove(partnerId);
      notifyListeners();
    } catch (e) {
      _errorMessage = _mapError(e);
      await loadSplitExpenses();
      notifyListeners();
    }
  }

  Future<void> loadHiddenFriends() async {
    try {
      final prefs = await _getPrefs();
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
      final prefs = await _getPrefs();
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

/// Internal helper model to track the most recent settlement for a partner to enable targeted undo.
class _LastSettlementRecord {
  final String partnerId;
  final List<String> settledSplitIds;
  final String? createdTransactionId;
  final DateTime timestamp;

  _LastSettlementRecord({
    required this.partnerId,
    required this.settledSplitIds,
    this.createdTransactionId,
    required this.timestamp,
  });
}
