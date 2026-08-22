import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/profile.dart';
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

  const AddSplitPage({super.key, this.initialPartner});

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
    return '(₹${_perPersonShare.toStringAsFixed(2)}/person)';
  }

  bool get _isFormValid {
    if (_totalAmount <= 0) return false;
    if (_descriptionController.text.trim().isEmpty) return false;
    if (_category == null || _category!.trim().isEmpty) return false;
    if (_selectedPartners.isEmpty) return false;
    if (!_iPaid && _payerPartner == null) return false;
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
    final available = splitVM.profiles
        .where(
          (p) =>
              !_selectedPartners.contains(p) && !splitVM.isFriendHidden(p.id),
        )
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                            Icons.person_add_rounded,
                            color: theme.colorScheme.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Add Friends to Split',
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
                if (available.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text(
                      'No other friends available to add.',
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
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: available.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: theme.colorScheme.outline.withValues(
                          alpha: 0.08,
                        ),
                      ),
                      itemBuilder: (ctx, index) {
                        final partner = available[index];
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
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            partner.email,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                          trailing: Icon(
                            Icons.add_circle_rounded,
                            color: theme.colorScheme.primary,
                          ),
                          onTap: () {
                            AppHaptics.selectionClick(context);
                            setState(() {
                              _selectedPartners.add(partner);
                              _includedPartnerIds.add(partner.id);
                              if (!_iPaid && _payerPartner == null) {
                                _payerPartner = partner;
                              }
                            });
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
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
                  final isSelected = !_iPaid && _payerPartner?.id == partner.id;
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
    final currentUserName = context.read<SplitViewModel>().currentUserDisplayName;

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
                                Icons.call_split_rounded,
                                color: theme.colorScheme.primary,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Choose Split Options',
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
                              setState(() => _splitMode = SplitMode.equally);
                              setModalState(() {});
                            },
                          ),
                          const SizedBox(height: 8),

                          _buildPresetButton(
                            context: modalContext,
                            label: 'You owe $partnerName ₹$amountFormatted',
                            isSelected: _splitMode == SplitMode.youOweFull,
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
                            label: '$partnerName owes you ₹$amountFormatted',
                            isSelected: _splitMode == SplitMode.partnerOwesFull,
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
                      color: theme.colorScheme.outline.withValues(alpha: 0.1),
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
                                setState(() => _splitMode = SplitMode.equally);
                                setModalState(() {});
                              },
                            ),
                            _buildModeTabIcon(
                              context: modalContext,
                              label: '1.23',
                              isSelected: _splitMode == SplitMode.exactAmounts,
                              onTap: () {
                                AppHaptics.selectionClick(context);
                                setState(
                                  () => _splitMode = SplitMode.exactAmounts,
                                );
                                setModalState(() {});
                              },
                            ),
                            _buildModeTabIcon(
                              context: modalContext,
                              label: '%',
                              isSelected: _splitMode == SplitMode.percentages,
                              onTap: () {
                                AppHaptics.selectionClick(context);
                                setState(
                                  () => _splitMode = SplitMode.percentages,
                                );
                                setModalState(() {});
                              },
                            ),
                            _buildModeTabIcon(
                              context: modalContext,
                              label: '===',
                              isSelected: _splitMode == SplitMode.shares,
                              onTap: () {
                                AppHaptics.selectionClick(context);
                                setState(() => _splitMode = SplitMode.shares);
                                setModalState(() {});
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Mode Title
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 6,
                      ),
                      child: Text(
                        _splitMode == SplitMode.equally
                            ? 'Split equally'
                            : _splitMode == SplitMode.exactAmounts
                            ? 'Split by exact amounts'
                            : _splitMode == SplitMode.percentages
                            ? 'Split by percentages'
                            : 'Split by shares',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

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
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '₹${share.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: isIncluded
                                ? (isDark ? Colors.white70 : Colors.black87)
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
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '₹${(_includeMeInSplit ? _perPersonShare : 0.0).toStringAsFixed(2)}',
                        style: TextStyle(
                          color: _includeMeInSplit
                              ? (isDark ? Colors.white70 : Colors.black87)
                              : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
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

      final splitSuccess = await splitVM.addMultipleSplitExpenses(
        borrowerIds: borrowerIds,
        perPersonAmount: _perPersonShare,
        totalAmount: amount,
        description: description,
        category: _category ?? 'General',
        expenseDate: entryDateTime,
        isPayer: _iPaid,
        payerId: explicitPayerId,
      );

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

      // When the user paid the merchant, record the total bill amount paid out of pocket
      if (_iPaid && _totalAmount > 0) {
        final partnerNames = _selectedPartners
            .map((p) => p.displayName)
            .join(', ');
        final txDescription = 'Split: $description ($partnerNames)';

        await transactionVM.addTransaction(
          amount: _totalAmount,
          type: 'expense',
          category: _category ?? 'General',
          description: txDescription,
          paymentMethod: _paymentMethod,
          transactionDate: entryDateTime,
        );
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

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Add Split Expense'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [Colors.black, Colors.black]
                : [const Color(0xFFEEF2FF), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Consumer2<CategoryViewModel, SplitViewModel>(
          builder: (context, categoryVM, splitVM, child) {
            final isSaving = splitVM.isSaving;
            final categories = categoryVM.expenseCategories;

            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 110, 24, 24),
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
                          keyboardType: TextInputType.text,
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
                            backgroundColor: theme.colorScheme.surface
                                .withValues(alpha: 0.5),
                            selectedBackgroundColor: theme.colorScheme.primary
                                .withValues(alpha: 0.15),
                            selectedForegroundColor: theme.colorScheme.primary,
                            side: BorderSide(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.1,
                              ),
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
                          isSaving ? 'Saving...' : 'Save Split Expense',
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
