import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/profile.dart';
import '../../models/split_expense.dart';
import '../../utils/date_formatter.dart';
import '../../utils/haptics.dart';
import '../../utils/math_evaluator.dart';
import '../../viewmodels/category_viewmodel.dart';
import '../../viewmodels/split_viewmodel.dart';
import '../../viewmodels/transaction_viewmodel.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/math_operations_bar.dart';

enum SplitMode {
  equally,
  youOweFull,
  partnerOwesFull,
  exactAmounts,
  percentages,
  shares,
}

class AddSplitPage extends StatefulWidget {
  final ProfileModel? initialPartner;
  final SplitExpenseModel? splitExpense;

  const AddSplitPage({super.key, this.initialPartner, this.splitExpense});

  @override
  State<AddSplitPage> createState() => _AddSplitPageState();
}

class _AddSplitPageState extends State<AddSplitPage> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountFocusNode = FocusNode();

  String? _category;
  String _paymentMethod = 'upi';
  final List<ProfileModel> _selectedPartners = [];
  bool _iPaid = true;
  ProfileModel? _payerPartner;
  SplitMode _splitMode = SplitMode.equally;

  // Track who is included in equal split
  bool _includeMeInSplit = true;
  final Set<String> _includedPartnerIds = {};

  // Custom Split Mode State: key is partner.id or 'current_user' for current user
  final Map<String, double> _exactAmounts = {};
  final Map<String, double> _percentages = {};
  final Map<String, int> _shares = {};
  final Map<String, TextEditingController> _exactAmountControllers = {};
  final Map<String, TextEditingController> _percentageControllers = {};

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();

    _amountFocusNode.addListener(() {
      if (!_amountFocusNode.hasFocus) {
        _evaluateAmount();
      }
      if (mounted) setState(() {});
    });

    if (widget.splitExpense != null) {
      final s = widget.splitExpense!;
      _amountController.text = MathEvaluator.format(s.totalAmount);
      _descriptionController.text = s.description;
      _category = s.category;
      _selectedDate = s.expenseDate.toLocal();
      _selectedTime = TimeOfDay.fromDateTime(s.expenseDate.toLocal());
    }

    if (widget.initialPartner != null) {
      _selectedPartners.add(widget.initialPartner!);
      _payerPartner = widget.initialPartner;
      _includedPartnerIds.add(widget.initialPartner!.id);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final categoryVM = Provider.of<CategoryViewModel>(context, listen: false);
      if (categoryVM.categories.isEmpty) {
        categoryVM.loadCategories();
      }

      final splitVM = Provider.of<SplitViewModel>(context, listen: false);
      splitVM.loadHiddenFriends();
      if (splitVM.profiles.isEmpty) {
        splitVM.loadProfiles();
      }

      // Initialize partner and payer state if editing an existing split expense
      if (widget.splitExpense != null) {
        final s = widget.splitExpense!;
        final sisterSplits = splitVM.getSisterSplits(s);
        final currentUserId = splitVM.currentUserId;
        final isUserPayer = s.payerId == currentUserId;

        _iPaid = isUserPayer;
        _selectedPartners.clear();
        _includedPartnerIds.clear();

        for (final split in sisterSplits) {
          final partnerId = isUserPayer ? split.borrowerId : split.payerId;
          final ProfileModel partner;
          final foundPartner = splitVM.profiles
              .cast<ProfileModel?>()
              .firstWhere((p) => p?.id == partnerId, orElse: () => null);

          if (foundPartner != null) {
            partner = foundPartner;
          } else {
            final email = isUserPayer
                ? (split.borrowerEmail ?? '')
                : (split.payerEmail ?? '');
            final name = isUserPayer ? split.borrowerName : split.payerName;
            partner = ProfileModel(id: partnerId, email: email, name: name);
          }

          if (!_selectedPartners.any((p) => p.id == partner.id)) {
            _selectedPartners.add(partner);
          }
          _includedPartnerIds.add(partner.id);

          _exactAmounts[partnerId] = split.amount;
          _exactAmountControllers[partnerId] = TextEditingController(
            text: MathEvaluator.format(split.amount),
          );

          final pct = split.totalAmount > 0
              ? (split.amount / split.totalAmount) * 100.0
              : 0.0;
          _percentages[partnerId] = pct;
          _percentageControllers[partnerId] = TextEditingController(
            text: pct.toStringAsFixed(1),
          );

          _shares[partnerId] = 1;
        }

        if (!isUserPayer && _selectedPartners.isNotEmpty) {
          _payerPartner = _selectedPartners.first;
        } else {
          _payerPartner = null;
        }

        final totalBorrowersShare = sisterSplits.fold<double>(
          0.0,
          (sum, sp) => sum + sp.amount,
        );
        final userRetainedShare = s.totalAmount - totalBorrowersShare;

        if (userRetainedShare > 0.01) {
          _includeMeInSplit = true;
          _exactAmounts['current_user'] = userRetainedShare;
          _exactAmountControllers['current_user'] = TextEditingController(
            text: MathEvaluator.format(userRetainedShare),
          );
          final userPct = s.totalAmount > 0
              ? (userRetainedShare / s.totalAmount) * 100.0
              : 0.0;
          _percentages['current_user'] = userPct;
          _percentageControllers['current_user'] = TextEditingController(
            text: userPct.toStringAsFixed(1),
          );
          _shares['current_user'] = 1;
        } else {
          _includeMeInSplit = false;
        }

        if (sisterSplits.length == 1 &&
            (s.amount - s.totalAmount).abs() < 0.05) {
          _splitMode = isUserPayer
              ? SplitMode.partnerOwesFull
              : SplitMode.youOweFull;
        } else {
          final totalMembers =
              _includedPartnerIds.length + (_includeMeInSplit ? 1 : 0);
          final equalShare =
              totalMembers > 0 ? (s.totalAmount / totalMembers) : 0.0;
          final allEqual = sisterSplits.every(
            (sp) => (sp.amount - equalShare).abs() < 0.05,
          );

          if (allEqual) {
            _splitMode = SplitMode.equally;
          } else {
            _splitMode = SplitMode.exactAmounts;
          }
        }

        if (mounted) setState(() {});
      }

      if (_category == null && categoryVM.expenseCategories.isNotEmpty) {
        setState(() {
          _category = categoryVM.expenseCategories.contains('Food')
              ? 'Food'
              : categoryVM.expenseCategories.first;
        });
      }
    });
  }

  void _evaluateAmount() {
    final text = _amountController.text.trim();
    if (text.isEmpty) return;
    final result = MathEvaluator.evaluate(text);
    if (result != null && result > 0) {
      final formatted = MathEvaluator.format(result);
      if (_amountController.text != formatted) {
        _amountController.text = formatted;
        _amountController.selection = TextSelection.fromPosition(
          TextPosition(offset: formatted.length),
        );
        if (mounted) setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _amountFocusNode.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    for (final c in _exactAmountControllers.values) {
      c.dispose();
    }
    for (final c in _percentageControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _totalAmount =>
      MathEvaluator.evaluate(_amountController.text) ??
      double.tryParse(_amountController.text) ??
      0.0;

  int get _includedMembersCount {
    int count = _includeMeInSplit ? 1 : 0;
    count += _selectedPartners
        .where((p) => _includedPartnerIds.contains(p.id))
        .length;
    return count > 0 ? count : 1;
  }

  double get _perPersonShare {
    if (_totalAmount <= 0) return 0.0;
    if (_splitMode == SplitMode.youOweFull ||
        _splitMode == SplitMode.partnerOwesFull) {
      return _totalAmount;
    }
    return _totalAmount / _includedMembersCount;
  }

  // Exact Amounts Helpers
  double _getExactAmount(String id) => _exactAmounts[id] ?? 0.0;
  double get _totalExactAmountsAllocated {
    double sum = 0;
    if (_includeMeInSplit) sum += _getExactAmount('current_user');
    for (final p in _selectedPartners) {
      if (_includedPartnerIds.contains(p.id)) sum += _getExactAmount(p.id);
    }
    return sum;
  }

  double get _exactAmountsRemaining =>
      _totalAmount - _totalExactAmountsAllocated;

  // Percentage Helpers
  double _getPercentage(String id) => _percentages[id] ?? 0.0;
  double get _totalPercentagesAllocated {
    double sum = 0;
    if (_includeMeInSplit) sum += _getPercentage('current_user');
    for (final p in _selectedPartners) {
      if (_includedPartnerIds.contains(p.id)) sum += _getPercentage(p.id);
    }
    return sum;
  }

  double get _percentagesRemaining => 100.0 - _totalPercentagesAllocated;

  // Shares Helpers
  int _getShares(String id) => _shares[id] ?? 1;
  int get _totalSharesAllocated {
    int sum = 0;
    if (_includeMeInSplit) sum += _getShares('current_user');
    for (final p in _selectedPartners) {
      if (_includedPartnerIds.contains(p.id)) sum += _getShares(p.id);
    }
    return sum > 0 ? sum : 1;
  }

  double _getShareAmountForId(String id) {
    if (_totalAmount <= 0) return 0.0;
    final shareCount = _getShares(id);
    return (_totalAmount * shareCount) / _totalSharesAllocated;
  }

  double _getComputedShareForMember(String id) {
    if (_splitMode == SplitMode.equally) {
      final isIncluded = id == 'current_user'
          ? _includeMeInSplit
          : _includedPartnerIds.contains(id);
      return isIncluded ? _perPersonShare : 0.0;
    } else if (_splitMode == SplitMode.exactAmounts) {
      return _getExactAmount(id);
    } else if (_splitMode == SplitMode.percentages) {
      return (_totalAmount * _getPercentage(id)) / 100.0;
    } else if (_splitMode == SplitMode.shares) {
      return _getShareAmountForId(id);
    } else {
      return _perPersonShare;
    }
  }

  void _initializeCustomSplitState() {
    final count = _includedMembersCount;
    final defaultEqualAmount = count > 0 ? _totalAmount / count : 0.0;
    final defaultEqualPct = count > 0 ? 100.0 / count : 0.0;

    final allMemberIds = [
      'current_user',
      ..._selectedPartners.map((p) => p.id),
    ];

    if (_exactAmounts.isEmpty) {
      for (final id in allMemberIds) {
        _exactAmounts[id] = defaultEqualAmount;
        _exactAmountControllers.putIfAbsent(
          id,
          () => TextEditingController(
            text: defaultEqualAmount > 0
                ? defaultEqualAmount.toStringAsFixed(2)
                : '',
          ),
        );
      }
    } else {
      for (final id in allMemberIds) {
        final val = _exactAmounts[id] ?? 0.0;
        _exactAmountControllers.putIfAbsent(
          id,
          () => TextEditingController(
            text: val > 0 ? val.toStringAsFixed(2) : '',
          ),
        );
      }
    }

    if (_percentages.isEmpty) {
      for (final id in allMemberIds) {
        _percentages[id] = defaultEqualPct;
        _percentageControllers.putIfAbsent(
          id,
          () => TextEditingController(
            text: defaultEqualPct > 0 ? defaultEqualPct.toStringAsFixed(1) : '',
          ),
        );
      }
    } else {
      for (final id in allMemberIds) {
        final val = _percentages[id] ?? 0.0;
        _percentageControllers.putIfAbsent(
          id,
          () => TextEditingController(
            text: val > 0 ? val.toStringAsFixed(1) : '',
          ),
        );
      }
    }

    if (_shares.isEmpty) {
      for (final id in allMemberIds) {
        _shares[id] = 1;
      }
    }
  }

  String get _payerDisplayName {
    if (_iPaid) return 'you';
    return _payerPartner?.displayName ?? 'partner';
  }

  String get _splitModeSummary {
    switch (_splitMode) {
      case SplitMode.equally:
        return 'equally';
      case SplitMode.youOweFull:
        final partnerName = _selectedPartners.isNotEmpty
            ? _selectedPartners.first.displayName
            : 'partner';
        return 'you owe $partnerName full';
      case SplitMode.partnerOwesFull:
        final partnerName = _selectedPartners.isNotEmpty
            ? _selectedPartners.first.displayName
            : 'partner';
        return '$partnerName owes you full';
      case SplitMode.exactAmounts:
        return 'by exact amounts';
      case SplitMode.percentages:
        return 'by %';
      case SplitMode.shares:
        return 'by shares';
    }
  }

  String get _splitCalculationSubtext {
    if (_totalAmount <= 0) return '(₹0.00/person)';
    if (_splitMode == SplitMode.youOweFull) {
      final partnerName = _selectedPartners.isNotEmpty
          ? _selectedPartners.first.displayName
          : 'partner';
      return '(You owe $partnerName ₹${_totalAmount.toStringAsFixed(2)})';
    }
    if (_splitMode == SplitMode.partnerOwesFull) {
      final partnerName = _selectedPartners.isNotEmpty
          ? _selectedPartners.first.displayName
          : 'partner';
      return '($partnerName owes you ₹${_totalAmount.toStringAsFixed(2)})';
    }
    if (_splitMode == SplitMode.exactAmounts) {
      return '(₹${_totalExactAmountsAllocated.toStringAsFixed(2)} of ₹${_totalAmount.toStringAsFixed(2)})';
    }
    if (_splitMode == SplitMode.percentages) {
      return '(${_totalPercentagesAllocated.toStringAsFixed(1)}% of 100%)';
    }
    if (_splitMode == SplitMode.shares) {
      return '($_totalSharesAllocated ${_totalSharesAllocated == 1 ? "share" : "shares"} total)';
    }
    return '(₹${_perPersonShare.toStringAsFixed(2)}/person)';
  }

  bool get _isFormValid {
    if (_totalAmount <= 0) return false;
    if (_descriptionController.text.trim().isEmpty) return false;
    if (_category == null || _category!.trim().isEmpty) return false;
    if (_selectedPartners.isEmpty) return false;
    if (!_iPaid && _payerPartner == null) return false;
    if (_splitMode == SplitMode.exactAmounts &&
        _exactAmountsRemaining.abs() > 0.05) {
      return false;
    }
    if (_splitMode == SplitMode.percentages &&
        _percentagesRemaining.abs() > 0.5) {
      return false;
    }
    return true;
  }

  // ── Helper Avatar Builder ───────────────────────────────────────────────

  Widget _buildAvatar({
    required BuildContext context,
    required String name,
    double radius = 14,
    bool isCurrentUser = false,
  }) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final secondary = theme.colorScheme.secondary;

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isCurrentUser
              ? [primary, primary.withValues(alpha: 0.7)]
              : [secondary, primary.withValues(alpha: 0.8)],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ── Date and Time Pickers ───────────────────────────────────────────────

  Future<void> _selectDate(BuildContext context) async {
    AppHaptics.selectionClick(context);
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isAfter(now) ? now : _selectedDate,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        if (DateUtils.isSameDay(_selectedDate, now)) {
          final chosenDateTime = DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
            _selectedTime.hour,
            _selectedTime.minute,
          );
          if (chosenDateTime.isAfter(now)) {
            _selectedTime = TimeOfDay.fromDateTime(now);
          }
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    AppHaptics.selectionClick(context);
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      final now = DateTime.now();
      final chosenDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        picked.hour,
        picked.minute,
      );
      if (chosenDateTime.isAfter(now)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot select a future time.')),
          );
        }
        return;
      }
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  // ── Modals / Bottom Sheets ──────────────────────────────────────────────

  void _showAddPartnerSheet(SplitViewModel splitVM) {
    AppHaptics.selectionClick(context);
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final allProfiles = splitVM.profiles
                .where((p) => !splitVM.isFriendHidden(p.id))
                .toList();

            final filteredProfiles = searchQuery.trim().isEmpty
                ? allProfiles
                : allProfiles.where((p) {
                    final q = searchQuery.toLowerCase();
                    return p.displayName.toLowerCase().contains(q) ||
                        p.email.toLowerCase().contains(q);
                  }).toList();

            final selectedCount = _selectedPartners.length;

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.82,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0A0A0A)
                    : theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(
                    alpha: isDark ? 0.15 : 0.08,
                  ),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(
                            alpha: isDark ? 0.3 : 0.6,
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.group_add_rounded,
                                  color: theme.colorScheme.primary,
                                  size: 24,
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Add Friends to Split',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    Text(
                                      selectedCount == 0
                                          ? 'Tap friends to select'
                                          : '$selectedCount friend${selectedCount > 1 ? 's' : ''} selected',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                color: theme.colorScheme.onSurface,
                              ),
                              onPressed: () => Navigator.pop(ctx),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ),

                      // Search bar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search friends...',
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 20,
                            ),
                            suffixIcon: searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.clear_rounded,
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      setModalState(() {
                                        searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.4),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (val) {
                            setModalState(() {
                              searchQuery = val;
                            });
                          },
                        ),
                      ),

                      // Add New Person Action Tile
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 2,
                        ),
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.15,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person_add_alt_1_rounded,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          'Add new person',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          'Add someone not registered yet',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        onTap: () {
                          _showAddNewPersonDialog(
                            splitVM,
                            onAdded: () {
                              setModalState(() {});
                            },
                          );
                        },
                      ),
                      Divider(
                        height: 1,
                        color: theme.colorScheme.outline.withValues(
                          alpha: 0.12,
                        ),
                      ),

                      // Friends List with multi-select checkboxes
                      if (filteredProfiles.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Text(
                            searchQuery.isNotEmpty
                                ? 'No friends found matching "$searchQuery"'
                                : 'No friends available. Add someone above!',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        )
                      else
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: filteredProfiles.length,
                            separatorBuilder: (context, index) => Divider(
                              height: 1,
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.08,
                              ),
                            ),
                            itemBuilder: (context, index) {
                              final partner = filteredProfiles[index];
                              final isSelected = _selectedPartners.any(
                                (p) => p.id == partner.id,
                              );

                              return ListTile(
                                selected: isSelected,
                                selectedTileColor: theme.colorScheme.primary
                                    .withValues(
                                      alpha: isDark ? 0.12 : 0.06,
                                    ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 4,
                                ),
                                leading: _buildAvatar(
                                  context: context,
                                  name: partner.displayName,
                                  radius: 18,
                                ),
                                title: Text(
                                  partner.displayName,
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : null,
                                  ),
                                ),
                                subtitle: Text(
                                  partner.email,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                                trailing: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : Colors.transparent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.outline
                                              .withValues(alpha: 0.4),
                                      width: 2,
                                    ),
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check_rounded,
                                          size: 18,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                onTap: () {
                                  AppHaptics.selectionClick(context);
                                  setState(() {
                                    if (isSelected) {
                                      _selectedPartners.removeWhere(
                                        (p) => p.id == partner.id,
                                      );
                                      _includedPartnerIds.remove(partner.id);
                                      if (_payerPartner?.id == partner.id) {
                                        _payerPartner =
                                            _selectedPartners.isNotEmpty
                                                ? _selectedPartners.first
                                                : null;
                                      }
                                    } else {
                                      _selectedPartners.add(partner);
                                      _includedPartnerIds.add(partner.id);
                                      if (!_iPaid && _payerPartner == null) {
                                        _payerPartner = partner;
                                      }
                                    }
                                  });
                                  setModalState(() {});
                                },
                              );
                            },
                          ),
                        ),

                      // Bottom "Done" Action Bar
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0A0A0A)
                              : theme.colorScheme.surface,
                          border: Border(
                            top: BorderSide(
                              color: theme.colorScheme.outline.withValues(
                                alpha: isDark ? 0.15 : 0.08,
                              ),
                            ),
                          ),
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton(
                            onPressed: () {
                              AppHaptics.lightImpact(context);
                              Navigator.pop(ctx);
                            },
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              selectedCount > 0
                                  ? 'Done ($selectedCount Selected)'
                                  : 'Done',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddNewPersonDialog(
    SplitViewModel splitVM, {
    VoidCallback? onAdded,
  }) {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        final theme = Theme.of(dialogCtx);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          icon: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_add_rounded,
              color: theme.colorScheme.primary,
              size: 32,
            ),
          ),
          title: Text(
            'Add Person',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter the name of the person you want to split expenses with.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Person Name',
                    hintText: 'e.g. John Doe',
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    filled: true,
                    fillColor: theme.colorScheme.onSurface.withValues(
                      alpha: 0.05,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  AppHaptics.mediumImpact(context);
                  final name = nameController.text.trim();
                  final newProfile = await splitVM.addCustomProfile(name: name);
                  if (mounted) {
                    setState(() {
                      if (!_selectedPartners.any(
                        (p) => p.id == newProfile.id,
                      )) {
                        _selectedPartners.add(newProfile);
                      }
                      _includedPartnerIds.add(newProfile.id);
                      if (!_iPaid && _payerPartner == null) {
                        _payerPartner = newProfile;
                      }
                    });
                    onAdded?.call();
                  }
                  if (dialogCtx.mounted) {
                    Navigator.pop(dialogCtx);
                  }
                }
              },
              child: const Text('Add & Select'),
            ),
          ],
        );
      },
    );
  }

  void _showChoosePayerSheet() {
    AppHaptics.selectionClick(context);
    final splitVM = context.read<SplitViewModel>();
    final currentUserName = splitVM.currentUserDisplayName;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0A0A0A) : theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(
                alpha: isDark ? 0.15 : 0.08,
              ),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: isDark ? 0.3 : 0.6,
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.payments_rounded,
                              color: theme.colorScheme.primary,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Choose Payer',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: theme.colorScheme.onSurface,
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),

                  // List of Partners
                  ..._selectedPartners.map((partner) {
                    final isSelected =
                        !_iPaid && _payerPartner?.id == partner.id;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      leading: _buildAvatar(
                        context: context,
                        name: partner.displayName,
                        radius: 18,
                      ),
                      title: Text(
                        partner.displayName,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: theme.colorScheme.primary,
                            )
                          : null,
                      onTap: () {
                        AppHaptics.selectionClick(context);
                        setState(() {
                          _iPaid = false;
                          _payerPartner = partner;
                        });
                        Navigator.pop(ctx);
                      },
                    );
                  }),

                  // You (Current User)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    leading: _buildAvatar(
                      context: context,
                      name: currentUserName,
                      radius: 18,
                      isCurrentUser: true,
                    ),
                    title: Text(
                      '$currentUserName (You)',
                      style: TextStyle(
                        fontWeight: _iPaid ? FontWeight.bold : FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    trailing: _iPaid
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      AppHaptics.selectionClick(context);
                      setState(() {
                        _iPaid = true;
                        _payerPartner = null;
                      });
                      Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showChooseSplitOptionsSheet() {
    AppHaptics.selectionClick(context);
    final partnerName = _selectedPartners.isNotEmpty
        ? _selectedPartners.first.displayName
        : 'partner';
    final amountFormatted = _totalAmount > 0
        ? _totalAmount.toStringAsFixed(2)
        : '0.00';
    final currentUserName = context
        .read<SplitViewModel>()
        .currentUserDisplayName;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final theme = Theme.of(modalContext);
            final isDark = theme.brightness == Brightness.dark;

            return Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0A0A0A)
                    : theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(
                    alpha: isDark ? 0.15 : 0.08,
                  ),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(modalContext).viewInsets.bottom,
                  ),
                  child: SafeArea(
                    top: false,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer
                                  .withValues(alpha: isDark ? 0.3 : 0.6),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(28),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.call_split_rounded,
                                      color: theme.colorScheme.primary,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Choose Split Options',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.close_rounded,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  onPressed: () => Navigator.pop(ctx),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // 3 Preset Options
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildPresetButton(
                                  context: modalContext,
                                  label: 'Split the expense',
                                  isSelected: _splitMode == SplitMode.equally,
                                  onTap: () {
                                    AppHaptics.selectionClick(context);
                                    setState(
                                      () => _splitMode = SplitMode.equally,
                                    );
                                    setModalState(() {});
                                  },
                                ),
                                const SizedBox(height: 8),

                                _buildPresetButton(
                                  context: modalContext,
                                  label:
                                      'You owe $partnerName ₹$amountFormatted',
                                  isSelected:
                                      _splitMode == SplitMode.youOweFull,
                                  onTap: () {
                                    AppHaptics.selectionClick(context);
                                    setState(() {
                                      _splitMode = SplitMode.youOweFull;
                                      _iPaid = false;
                                      if (_selectedPartners.isNotEmpty) {
                                        _payerPartner = _selectedPartners.first;
                                      }
                                    });
                                    setModalState(() {});
                                  },
                                ),
                                const SizedBox(height: 8),

                                _buildPresetButton(
                                  context: modalContext,
                                  label:
                                      '$partnerName owes you ₹$amountFormatted',
                                  isSelected:
                                      _splitMode == SplitMode.partnerOwesFull,
                                  onTap: () {
                                    AppHaptics.selectionClick(context);
                                    setState(() {
                                      _splitMode = SplitMode.partnerOwesFull;
                                      _iPaid = true;
                                    });
                                    setModalState(() {});
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),
                          Divider(
                            height: 1,
                            color: theme.colorScheme.outline.withValues(
                              alpha: 0.1,
                            ),
                          ),

                          // Split Mode Icons Bar
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : theme.colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: theme.colorScheme.outline.withValues(
                                    alpha: 0.1,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  _buildModeTabIcon(
                                    context: modalContext,
                                    label: '=',
                                    isSelected: _splitMode == SplitMode.equally,
                                    onTap: () {
                                      AppHaptics.selectionClick(context);
                                      setState(
                                        () => _splitMode = SplitMode.equally,
                                      );
                                      setModalState(() {});
                                    },
                                  ),
                                  _buildModeTabIcon(
                                    context: modalContext,
                                    label: '1.23',
                                    isSelected:
                                        _splitMode == SplitMode.exactAmounts,
                                    onTap: () {
                                      AppHaptics.selectionClick(context);
                                      setState(() {
                                        _splitMode = SplitMode.exactAmounts;
                                        _initializeCustomSplitState();
                                      });
                                      setModalState(() {});
                                    },
                                  ),
                                  _buildModeTabIcon(
                                    context: modalContext,
                                    label: '%',
                                    isSelected:
                                        _splitMode == SplitMode.percentages,
                                    onTap: () {
                                      AppHaptics.selectionClick(context);
                                      setState(() {
                                        _splitMode = SplitMode.percentages;
                                        _initializeCustomSplitState();
                                      });
                                      setModalState(() {});
                                    },
                                  ),
                                  _buildModeTabIcon(
                                    context: modalContext,
                                    label: '===',
                                    isSelected: _splitMode == SplitMode.shares,
                                    onTap: () {
                                      AppHaptics.selectionClick(context);
                                      setState(() {
                                        _splitMode = SplitMode.shares;
                                        _initializeCustomSplitState();
                                      });
                                      setModalState(() {});
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Mode Title and Remaining Balance / Status Pill
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 6,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _splitMode == SplitMode.equally
                                      ? 'Split equally'
                                      : _splitMode == SplitMode.exactAmounts
                                      ? 'Split by exact amounts'
                                      : _splitMode == SplitMode.percentages
                                      ? 'Split by percentages'
                                      : _splitMode == SplitMode.shares
                                      ? 'Split by shares'
                                      : 'Split expense',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_splitMode == SplitMode.exactAmounts)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          _exactAmountsRemaining.abs() <= 0.05
                                          ? Colors.green.withValues(alpha: 0.15)
                                          : Colors.orange.withValues(
                                              alpha: 0.15,
                                            ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _exactAmountsRemaining.abs() <= 0.05
                                          ? '₹0.00 left'
                                          : (_exactAmountsRemaining > 0
                                                ? '₹${_exactAmountsRemaining.toStringAsFixed(2)} left'
                                                : '₹${(-_exactAmountsRemaining).toStringAsFixed(2)} over'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            _exactAmountsRemaining.abs() <= 0.05
                                            ? Colors.green
                                            : Colors.orange,
                                      ),
                                    ),
                                  )
                                else if (_splitMode == SplitMode.percentages)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _percentagesRemaining.abs() <= 0.5
                                          ? Colors.green.withValues(alpha: 0.15)
                                          : Colors.orange.withValues(
                                              alpha: 0.15,
                                            ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _percentagesRemaining.abs() <= 0.5
                                          ? '0% left'
                                          : (_percentagesRemaining > 0
                                                ? '${_percentagesRemaining.toStringAsFixed(1)}% left'
                                                : '${(-_percentagesRemaining).toStringAsFixed(1)}% over'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            _percentagesRemaining.abs() <= 0.5
                                            ? Colors.green
                                            : Colors.orange,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // Members Rows for Selected Mode
                          if (_splitMode == SplitMode.equally) ...[
                            // Members Checkboxes & Share Amount
                            ..._selectedPartners.map((partner) {
                              final isIncluded = _includedPartnerIds.contains(
                                partner.id,
                              );
                              final share = isIncluded ? _perPersonShare : 0.0;
                              return CheckboxListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                activeColor: theme.colorScheme.primary,
                                value: isIncluded,
                                onChanged: (val) {
                                  AppHaptics.selectionClick(context);
                                  setState(() {
                                    if (val == true) {
                                      _includedPartnerIds.add(partner.id);
                                    } else {
                                      if (_includedMembersCount > 1) {
                                        _includedPartnerIds.remove(partner.id);
                                      }
                                    }
                                  });
                                  setModalState(() {});
                                },
                                secondary: _buildAvatar(
                                  context: context,
                                  name: partner.displayName,
                                  radius: 18,
                                ),
                                title: Text(
                                  partner.displayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  '₹${share.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: isIncluded
                                        ? (isDark
                                              ? Colors.white70
                                              : Colors.black87)
                                        : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }),

                            // Current User Checkbox
                            CheckboxListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              activeColor: theme.colorScheme.primary,
                              value: _includeMeInSplit,
                              onChanged: (val) {
                                AppHaptics.selectionClick(context);
                                setState(() {
                                  if (val == true) {
                                    _includeMeInSplit = true;
                                  } else {
                                    if (_includedMembersCount > 1) {
                                      _includeMeInSplit = false;
                                    }
                                  }
                                });
                                setModalState(() {});
                              },
                              secondary: _buildAvatar(
                                context: context,
                                name: currentUserName,
                                radius: 18,
                                isCurrentUser: true,
                              ),
                              title: Text(
                                '$currentUserName (You)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '₹${(_includeMeInSplit ? _perPersonShare : 0.0).toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: _includeMeInSplit
                                      ? (isDark
                                            ? Colors.white70
                                            : Colors.black87)
                                      : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ] else if (_splitMode == SplitMode.exactAmounts) ...[
                            // Exact Amount Rows
                            ..._selectedPartners.map((partner) {
                              return _buildExactAmountRow(
                                context: modalContext,
                                id: partner.id,
                                name: partner.displayName,
                                isCurrentUser: false,
                                setModalState: setModalState,
                              );
                            }),
                            _buildExactAmountRow(
                              context: modalContext,
                              id: 'current_user',
                              name: '$currentUserName (You)',
                              isCurrentUser: true,
                              setModalState: setModalState,
                            ),
                          ] else if (_splitMode == SplitMode.percentages) ...[
                            // Percentage Rows
                            ..._selectedPartners.map((partner) {
                              return _buildPercentageRow(
                                context: modalContext,
                                id: partner.id,
                                name: partner.displayName,
                                isCurrentUser: false,
                                setModalState: setModalState,
                              );
                            }),
                            _buildPercentageRow(
                              context: modalContext,
                              id: 'current_user',
                              name: '$currentUserName (You)',
                              isCurrentUser: true,
                              setModalState: setModalState,
                            ),
                          ] else if (_splitMode == SplitMode.shares) ...[
                            // Shares Rows
                            ..._selectedPartners.map((partner) {
                              return _buildSharesRow(
                                context: modalContext,
                                id: partner.id,
                                name: partner.displayName,
                                isCurrentUser: false,
                                setModalState: setModalState,
                              );
                            }),
                            _buildSharesRow(
                              context: modalContext,
                              id: 'current_user',
                              name: '$currentUserName (You)',
                              isCurrentUser: true,
                              setModalState: setModalState,
                            ),
                          ],

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildExactAmountRow({
    required BuildContext context,
    required String id,
    required String name,
    required bool isCurrentUser,
    required StateSetter setModalState,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentVal = _getExactAmount(id);
    final controller = _exactAmountControllers.putIfAbsent(
      id,
      () => TextEditingController(
        text: currentVal > 0 ? currentVal.toStringAsFixed(2) : '',
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          _buildAvatar(
            context: context,
            name: name,
            radius: 18,
            isCurrentUser: isCurrentUser,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 110,
            height: 40,
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
                hintText: '0.00',
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : theme.colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.4,
                      ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) {
                final parsed = double.tryParse(val) ?? 0.0;
                _exactAmounts[id] = parsed;
                setState(() {});
                setModalState(() {});
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPercentageRow({
    required BuildContext context,
    required String id,
    required String name,
    required bool isCurrentUser,
    required StateSetter setModalState,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentVal = _getPercentage(id);
    final computedAmt = (_totalAmount * currentVal) / 100.0;
    final controller = _percentageControllers.putIfAbsent(
      id,
      () => TextEditingController(
        text: currentVal > 0 ? currentVal.toStringAsFixed(1) : '',
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          _buildAvatar(
            context: context,
            name: name,
            radius: 18,
            isCurrentUser: isCurrentUser,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '₹${computedAmt.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 90,
            height: 40,
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              decoration: InputDecoration(
                suffixText: ' %',
                suffixStyle: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
                hintText: '0',
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : theme.colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.4,
                      ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) {
                final parsed = double.tryParse(val) ?? 0.0;
                _percentages[id] = parsed;
                setState(() {});
                setModalState(() {});
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSharesRow({
    required BuildContext context,
    required String id,
    required String name,
    required bool isCurrentUser,
    required StateSetter setModalState,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentShares = _getShares(id);
    final shareAmt = _getShareAmountForId(id);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          _buildAvatar(
            context: context,
            name: name,
            radius: 18,
            isCurrentUser: isCurrentUser,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '₹${shareAmt.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.4,
                    ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_rounded, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: () {
                    if (currentShares > 0) {
                      AppHaptics.selectionClick(context);
                      setState(() {
                        _shares[id] = currentShares - 1;
                      });
                      setModalState(() {});
                    }
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '$currentShares',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_rounded, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: () {
                    AppHaptics.selectionClick(context);
                    setState(() {
                      _shares[id] = currentShares + 1;
                    });
                    setModalState(() {});
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButton({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : theme.colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      )),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(
                    alpha: isDark ? 0.2 : 0.15,
                  ),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildModeTabIcon({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF1E1E1E) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }

  // ── Save Logic ──────────────────────────────────────────────────────────

  Future<void> _saveEntry() async {
    _evaluateAmount();
    if (!_isFormValid) return;

    AppHaptics.mediumImpact(context);

    final splitVM = Provider.of<SplitViewModel>(context, listen: false);
    final transactionVM = Provider.of<TransactionViewModel>(
      context,
      listen: false,
    );

    try {
      final amount = _totalAmount;
      final description = _descriptionController.text.trim().isEmpty
          ? 'Split Expense'
          : _descriptionController.text.trim();

      final entryDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      if (entryDateTime.isAfter(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot add an entry in the future.')),
        );
        return;
      }

      final currentUserId = splitVM.currentUserId;
      final List<String> borrowerIds;
      final String? explicitPayerId;

      if (_splitMode == SplitMode.youOweFull) {
        explicitPayerId = _payerPartner?.id;
        borrowerIds = currentUserId != null ? [currentUserId] : [];
      } else if (_splitMode == SplitMode.partnerOwesFull) {
        explicitPayerId = currentUserId;
        borrowerIds = _selectedPartners.map((p) => p.id).toList();
      } else {
        // Equal split
        if (_iPaid) {
          explicitPayerId = currentUserId;
          borrowerIds = _selectedPartners
              .where((p) => _includedPartnerIds.contains(p.id))
              .map((p) => p.id)
              .toList();
        } else {
          explicitPayerId = _payerPartner?.id;
          final list = <String>[];
          if (_includeMeInSplit && currentUserId != null) {
            list.add(currentUserId);
          }
          for (final p in _selectedPartners) {
            if (p.id != explicitPayerId && _includedPartnerIds.contains(p.id)) {
              list.add(p.id);
            }
          }
          borrowerIds = list;
        }
      }

      final isEditing = widget.splitExpense != null;
      final bool splitSuccess;

      final splitsList = <Map<String, dynamic>>[];
      if (_splitMode == SplitMode.exactAmounts ||
          _splitMode == SplitMode.percentages ||
          _splitMode == SplitMode.shares) {
        // Build custom borrower splits
        for (final bId in borrowerIds) {
          final share = _getComputedShareForMember(bId);
          if (share > 0) {
            splitsList.add({'borrower_id': bId, 'amount': share});
          }
        }
      } else {
        for (final bId in borrowerIds) {
          splitsList.add({'borrower_id': bId, 'amount': _perPersonShare});
        }
      }

      if (isEditing) {
        final origSisterSplits = splitVM.getSisterSplits(widget.splitExpense!);
        final oldIds = origSisterSplits.map((s) => s.id).toList();

        splitSuccess = await splitVM.updateSplitExpenseGroup(
          oldSplitIds: oldIds,
          borrowerSplits: splitsList,
          totalAmount: amount,
          description: description,
          category: _category ?? 'General',
          expenseDate: entryDateTime,
          isPayer: _iPaid,
          payerId: explicitPayerId,
        );
      } else {
        splitSuccess = await splitVM.addCustomMultipleSplitExpenses(
          borrowerSplits: splitsList,
          totalAmount: amount,
          description: description,
          category: _category ?? 'General',
          expenseDate: entryDateTime,
          isPayer: _iPaid,
          payerId: explicitPayerId,
        );
      }

      if (!splitSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                splitVM.errorMessage ?? 'Failed to save split expense.',
              ),
            ),
          );
        }
        return;
      }

      // Sync personal transaction with the split expense
      final partnerNames = _selectedPartners
          .map((p) => p.displayName)
          .join(', ');
      final txDescription = 'Split: $description ($partnerNames)';

      if (isEditing) {
        final origSplit = widget.splitExpense!;
        final existingTx = transactionVM.findMatchingSplitTransaction(
          description: origSplit.description,
          expenseDate: origSplit.expenseDate,
          totalAmount: origSplit.totalAmount,
        );

        if (_iPaid && _totalAmount > 0) {
          if (existingTx != null) {
            await transactionVM.updateTransaction(
              id: existingTx.id,
              amount: _totalAmount,
              type: 'expense',
              category: _category ?? 'General',
              description: txDescription,
              paymentMethod: _paymentMethod,
              transactionDate: entryDateTime,
            );
          } else {
            await transactionVM.addTransaction(
              amount: _totalAmount,
              type: 'expense',
              category: _category ?? 'General',
              description: txDescription,
              paymentMethod: _paymentMethod,
              transactionDate: entryDateTime,
            );
          }
        } else {
          // If user didn't pay, remove any personal transaction that was previously logged
          if (existingTx != null) {
            await transactionVM.deleteTransaction(existingTx.id);
          }
        }
      } else {
        // When the user paid the merchant on new split creation
        if (_iPaid && _totalAmount > 0) {
          await transactionVM.addTransaction(
            amount: _totalAmount,
            type: 'expense',
            category: _category ?? 'General',
            description: txDescription,
            paymentMethod: _paymentMethod,
            transactionDate: entryDateTime,
          );
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save entry: $e')));
      }
    }
  }

  // ── Build Main UI ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEditing = widget.splitExpense != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Split Expense' : 'Add Split Expense'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
              ),
              onPressed: () async {
                AppHaptics.vibrate(context);
                final splitVM = context.read<SplitViewModel>();
                final transactionVM = context.read<TransactionViewModel>();
                final nav = Navigator.of(context);

                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Split Expense'),
                    content: const Text(
                      'Are you sure you want to delete this split expense? This will also remove the corresponding personal transaction.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red.withValues(alpha: 0.1),
                          foregroundColor: Colors.red,
                        ),
                        child: const Text(
                          'Delete',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );

                if (confirm == true && mounted) {
                  final origSisterSplits =
                      splitVM.getSisterSplits(widget.splitExpense!);
                  for (final s in origSisterSplits) {
                    await splitVM.deleteSplitExpense(
                      s.id,
                      transactionVM: transactionVM,
                    );
                  }
                  if (mounted) {
                    nav.pop(true);
                  }
                }
              },
            ),
        ],
      ),
      body: Consumer2<CategoryViewModel, SplitViewModel>(
        builder: (context, categoryVM, splitVM, child) {
          final isSaving = splitVM.isSaving;
          final categories = categoryVM.expenseCategories;

          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              children: [
                // ── 1. "With you and:" Bar (Split Feature #1) ───────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(
                      alpha: isDark ? 0.35 : 0.85,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(
                        alpha: isDark ? 0.15 : 0.08,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 15,
                            color: theme.colorScheme.onSurface,
                          ),
                          children: const [
                            TextSpan(text: 'With '),
                            TextSpan(
                              text: 'you',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: ' and: '),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ..._selectedPartners.map((partner) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: Container(
                                    padding: const EdgeInsets.fromLTRB(
                                      4,
                                      3,
                                      6,
                                      3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF1E1E1E)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: theme.colorScheme.outline
                                            .withValues(
                                              alpha: isDark ? 0.2 : 0.15,
                                            ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildAvatar(
                                          context: context,
                                          name: partner.displayName,
                                          radius: 10,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          partner.displayName,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        InkWell(
                                          onTap: () {
                                            AppHaptics.selectionClick(context);
                                            setState(() {
                                              _selectedPartners.remove(partner);
                                              _includedPartnerIds.remove(
                                                partner.id,
                                              );
                                              if (_payerPartner == partner) {
                                                _payerPartner =
                                                    _selectedPartners.isNotEmpty
                                                    ? _selectedPartners.first
                                                    : null;
                                              }
                                            });
                                          },
                                          child: const Icon(
                                            Icons.close_rounded,
                                            size: 14,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),

                              // Add button
                              InkWell(
                                onTap: () => _showAddPartnerSheet(splitVM),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.add_rounded,
                                        size: 15,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Add',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── 2. Add Transaction Style Inputs Card ───────────────────
                Card(
                  elevation: 0,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(
                      color: theme.colorScheme.outline.withValues(
                        alpha: isDark ? 0.15 : 0.08,
                      ),
                    ),
                  ),
                  color: theme.colorScheme.surface.withValues(
                    alpha: isDark ? 0.35 : 0.85,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSectionTitle('Amount'),
                        TextField(
                          controller: _amountController,
                          focusNode: _amountFocusNode,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _evaluateAmount(),
                          onTapOutside: (_) {
                            _evaluateAmount();
                            FocusScope.of(context).unfocus();
                          },
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration:
                              _inputDecoration(
                                '0.00',
                                Icons.account_balance_wallet_rounded,
                              ).copyWith(
                                prefixText: '₹ ',
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 20,
                                ),
                              ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9+\-*/÷×−().\s]'),
                            ),
                          ],
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          child: _amountFocusNode.hasFocus
                              ? MathOperationsBar(
                                  controller: _amountController,
                                  focusNode: _amountFocusNode,
                                  onOperationApplied: () {
                                    if (mounted) setState(() {});
                                  },
                                )
                              : const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 20),

                        _buildSectionTitle('Description'),
                        TextField(
                          controller: _descriptionController,
                          onChanged: (_) => setState(() {}),
                          maxLength: 200,
                          maxLengthEnforcement: MaxLengthEnforcement.enforced,
                          decoration: _inputDecoration(
                            'What was this for?',
                            Icons.description_rounded,
                          ).copyWith(counterText: ''),
                          textCapitalization: TextCapitalization.sentences,
                        ),
                        const SizedBox(height: 20),

                        _buildSectionTitle('Category'),
                        AppDropdown<String>(
                          value: _category,
                          hint: 'Select Category',
                          prefixIcon: Icons.category_rounded,
                          items: categories.map((String category) {
                            return DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              AppHaptics.selectionClick(context);
                              setState(() {
                                _category = newValue;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 20),

                        _buildSectionTitle('Payment Method'),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'upi',
                              label: Text('UPI'),
                              icon: Icon(Icons.qr_code_2_rounded),
                            ),
                            ButtonSegment(
                              value: 'cash',
                              label: Text('Cash'),
                              icon: Icon(Icons.payments_outlined),
                            ),
                          ],
                          selected: {_paymentMethod},
                          onSelectionChanged: (Set<String> newSelection) {
                            AppHaptics.selectionClick(context);
                            setState(() {
                              _paymentMethod = newSelection.first;
                            });
                          },
                          style: SegmentedButton.styleFrom(
                            backgroundColor: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : theme.colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.5),
                            selectedBackgroundColor:
                                theme.colorScheme.primaryContainer,
                            selectedForegroundColor:
                                theme.colorScheme.onPrimaryContainer,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        _buildSectionTitle('Date & Time'),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _selectDate(context),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.transparent,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today_rounded,
                                        size: 20,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          DateFormatter.formatDate(
                                            _selectedDate,
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: InkWell(
                                onTap: () => _selectTime(context),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.transparent,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.access_time_rounded,
                                        size: 20,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _selectedTime.format(context),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── 3. Split Sentence Selector Card (Split Feature #2) ──────
                Card(
                  elevation: 0,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(
                      color: theme.colorScheme.outline.withValues(
                        alpha: isDark ? 0.15 : 0.08,
                      ),
                    ),
                  ),
                  color: theme.colorScheme.surface.withValues(
                    alpha: isDark ? 0.35 : 0.85,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 24,
                    ),
                    child: Column(
                      children: [
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 10,
                          children: [
                            Text(
                              'Paid by',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            _buildPill(
                              text: _payerDisplayName,
                              onTap: _showChoosePayerSheet,
                            ),
                            Text(
                              'and split',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            _buildPill(
                              text: _splitModeSummary,
                              onTap: _showChooseSplitOptionsSheet,
                            ),
                            Text(
                              '.',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: isDark ? 0.15 : 0.08,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.25,
                              ),
                            ),
                          ),
                          child: Text(
                            _splitCalculationSubtext,
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // ── 4. Unified Full-Width Save Button ──────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: (_isFormValid && !isSaving) ? _saveEntry : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      disabledBackgroundColor: theme.colorScheme.onSurface
                          .withValues(alpha: 0.12),
                      disabledForegroundColor: theme.colorScheme.onSurface
                          .withValues(alpha: 0.38),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isSaving) ...[
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                theme.colorScheme.onPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ] else ...[
                          const Icon(Icons.check_circle_outline, size: 24),
                          const SizedBox(width: 12),
                        ],
                        Text(
                          isSaving
                              ? (isEditing ? 'Updating...' : 'Saving...')
                              : (isEditing
                                    ? 'Update Split Expense'
                                    : 'Save Split Expense'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
    );
  }

  // ── Helper Widgets ─────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      hintText: label,
      prefixIcon: Icon(
        icon,
        size: 22,
        color: Theme.of(context).colorScheme.primary,
      ),
      filled: true,
      fillColor: Theme.of(
        context,
      ).colorScheme.onSurface.withValues(alpha: 0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    );
  }

  Widget _buildPill({required String text, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(
            alpha: isDark ? 0.2 : 0.1,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(
              alpha: isDark ? 0.6 : 0.45,
            ),
            width: 1.5,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
