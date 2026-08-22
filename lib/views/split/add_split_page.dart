import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/profile.dart';
import '../../utils/date_formatter.dart';
import '../../utils/haptics.dart';
import '../../viewmodels/category_viewmodel.dart';
import '../../viewmodels/split_viewmodel.dart';
import '../../viewmodels/transaction_viewmodel.dart';
import '../../widgets/app_dropdown.dart';

class AddSplitPage extends StatefulWidget {
  final ProfileModel? initialPartner;

  const AddSplitPage({super.key, this.initialPartner});

  @override
  State<AddSplitPage> createState() => _AddSplitPageState();
}

class _AddSplitPageState extends State<AddSplitPage> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _category;
  final List<ProfileModel> _selectedPartners = [];
  bool _iPaid = true;
  ProfileModel? _payerPartner;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  bool get _isFormValid {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return false;
    if (_descriptionController.text.trim().isEmpty) return false;
    if (_category == null || _category!.trim().isEmpty) return false;
    if (_selectedPartners.isEmpty) return false;
    if (!_iPaid && _payerPartner == null) return false;
    return true;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialPartner != null) {
      _selectedPartners.add(widget.initialPartner!);
      _payerPartner = widget.initialPartner;
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
          _category = categoryVM.expenseCategories.first;
        });
      }
    });
  }

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

  Future<void> _saveEntry() async {
    if (!_isFormValid) return;

    AppHaptics.mediumImpact(context);

    final splitVM = Provider.of<SplitViewModel>(context, listen: false);
    final transactionVM = Provider.of<TransactionViewModel>(
      context,
      listen: false,
    );

    try {
      final amount = double.tryParse(_amountController.text) ?? 0.0;
      final description = _descriptionController.text.trim().isEmpty
          ? 'Split Expense'
          : _descriptionController.text.trim();
      final totalPeople = _selectedPartners.length + 1;
      final perPersonShare = amount > 0 ? (amount / totalPeople) : 0.0;

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

      if (_iPaid) {
        explicitPayerId = currentUserId;
        borrowerIds = _selectedPartners.map((p) => p.id).toList();
      } else {
        explicitPayerId = _payerPartner?.id;
        final list = <String>[];
        if (currentUserId != null) {
          list.add(currentUserId);
        }
        for (final p in _selectedPartners) {
          if (p.id != explicitPayerId) {
            list.add(p.id);
          }
        }
        borrowerIds = list;
      }

      final splitSuccess = await splitVM.addMultipleSplitExpenses(
        borrowerIds: borrowerIds,
        perPersonAmount: perPersonShare,
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

      // Automatically record user's out-of-pocket share as a transaction
      final partnerNames = _selectedPartners
          .map((p) => p.displayName)
          .join(', ');
      final txDescription = _iPaid
          ? 'Split: $description ($partnerNames)'
          : 'Split: $description (Paid by ${_payerPartner?.displayName ?? 'Partner'})';

      await transactionVM.addTransaction(
        amount: perPersonShare,
        type: 'expense',
        category: _category ?? 'General',
        description: txDescription,
        paymentMethod: 'upi',
        transactionDate: entryDateTime,
      );

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

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Split Expense'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
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
            final categories = categoryVM.expenseCategories;
            final profiles = splitVM.profiles;
            final isSaving = splitVM.isSaving;
            final availableProfiles = profiles
                .where(
                  (p) =>
                      !_selectedPartners.contains(p) &&
                      !splitVM.isFriendHidden(p.id),
                )
                .toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 120, 24, 24),
              children: [
                // ── SECTION 1: Transaction Details ──────────────────────────
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.1),
                    ),
                  ),
                  color: theme.colorScheme.surface.withValues(
                    alpha: isDark ? 0.3 : 0.8,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.receipt_long_rounded,
                              color: theme.colorScheme.primary,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Transaction Details',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),

                        _buildSectionTitle('Amount'),
                        TextField(
                          controller: _amountController,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration:
                              _inputDecoration(
                                '0.00',
                                Icons.account_balance_wallet,
                              ).copyWith(
                                prefixText: '₹ ',
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 24,
                                ),
                              ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'),
                            ),
                          ],
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
                            Icons.description,
                          ).copyWith(counterText: ''),
                          textCapitalization: TextCapitalization.sentences,
                        ),
                        const SizedBox(height: 20),

                        _buildSectionTitle('Category'),
                        AppDropdown<String>(
                          value: _category,
                          hint: 'Select Category',
                          prefixIcon: Icons.category,
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
                                        Icons.calendar_today,
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
                                        Icons.access_time,
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
                const SizedBox(height: 20),

                // ── SECTION 2: Split Details ────────────────────────────────
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.1),
                    ),
                  ),
                  color: theme.colorScheme.surface.withValues(
                    alpha: isDark ? 0.3 : 0.8,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.groups_rounded,
                              color: theme.colorScheme.primary,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Split Details',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),

                        _buildSectionTitle('Split With Users'),
                        if (profiles.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Loading registered users...',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        else ...[
                          AppDropdown<ProfileModel>(
                            value: null,
                            hint: availableProfiles.isEmpty
                                ? 'All users selected'
                                : 'Select user to split with',
                            prefixIcon: Icons.person_add,
                            items: availableProfiles.map((ProfileModel p) {
                              return DropdownMenuItem<ProfileModel>(
                                value: p,
                                child: Text(p.displayName),
                              );
                            }).toList(),
                            onChanged: (ProfileModel? selected) {
                              if (selected != null) {
                                AppHaptics.selectionClick(context);
                                setState(() {
                                  _selectedPartners.add(selected);
                                  if (!_iPaid && _payerPartner == null) {
                                    _payerPartner = selected;
                                  }
                                });
                              }
                            },
                          ),
                          if (_selectedPartners.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _selectedPartners.map((p) {
                                return InputChip(
                                  label: Text(p.displayName),
                                  onDeleted: () {
                                    AppHaptics.selectionClick(context);
                                    setState(() {
                                      _selectedPartners.remove(p);
                                      if (_payerPartner == p) {
                                        _payerPartner =
                                            _selectedPartners.isNotEmpty
                                            ? _selectedPartners.first
                                            : null;
                                      }
                                    });
                                  },
                                  deleteIconColor: theme.colorScheme.primary,
                                  selected: true,
                                  selectedColor: theme.colorScheme.primary
                                      .withValues(alpha: 0.15),
                                  labelStyle: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                        const SizedBox(height: 20),

                        _buildSectionTitle('Who Paid?'),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                              value: true,
                              label: Text('You Paid'),
                              icon: Icon(Icons.arrow_upward),
                            ),
                            ButtonSegment(
                              value: false,
                              label: Text('They Paid'),
                              icon: Icon(Icons.arrow_downward),
                            ),
                          ],
                          selected: {_iPaid},
                          onSelectionChanged: (val) {
                            AppHaptics.selectionClick(context);
                            setState(() {
                              _iPaid = val.first;
                              if (!_iPaid &&
                                  _selectedPartners.isNotEmpty &&
                                  (_payerPartner == null ||
                                      !_selectedPartners.contains(
                                        _payerPartner,
                                      ))) {
                                _payerPartner = _selectedPartners.first;
                              }
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

                        if (!_iPaid) ...[
                          const SizedBox(height: 20),
                          _buildSectionTitle('Select Who Paid'),
                          if (_selectedPartners.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                'Please select at least one user above first.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange,
                                ),
                              ),
                            )
                          else
                            AppDropdown<ProfileModel>(
                              value: _selectedPartners.contains(_payerPartner)
                                  ? _payerPartner
                                  : _selectedPartners.first,
                              hint: 'Select Who Paid',
                              prefixIcon: Icons.payments,
                              items: _selectedPartners.map((ProfileModel p) {
                                return DropdownMenuItem<ProfileModel>(
                                  value: p,
                                  child: Text(p.displayName),
                                );
                              }).toList(),
                              onChanged: (ProfileModel? selected) {
                                if (selected != null) {
                                  AppHaptics.selectionClick(context);
                                  setState(() {
                                    _payerPartner = selected;
                                  });
                                }
                              },
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Unified Save Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: (isSaving || !_isFormValid) ? null : _saveEntry,
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
}
