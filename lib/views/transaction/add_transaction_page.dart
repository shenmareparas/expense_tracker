import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/haptics.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/transaction_viewmodel.dart';
import '../../viewmodels/split_viewmodel.dart';
import '../../viewmodels/category_viewmodel.dart';
import '../../models/transaction.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/math_operations_bar.dart';
import '../../utils/date_formatter.dart';
import '../../utils/math_evaluator.dart';

class AddTransactionPage extends StatefulWidget {
  final TransactionModel? transaction;

  const AddTransactionPage({super.key, this.transaction});

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountFocusNode = FocusNode();

  String _type = 'expense';
  String _paymentMethod = 'upi';
  String? _category;
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

    if (widget.transaction != null) {
      _amountController.text = widget.transaction!.amount.toString();
      _descriptionController.text = widget.transaction!.description ?? '';
      _type = widget.transaction!.type;
      _paymentMethod = widget.transaction!.paymentMethod;
      _category = widget.transaction!.category;
      _selectedDate = widget.transaction!.transactionDate.toLocal();
      _selectedTime = TimeOfDay.fromDateTime(
        widget.transaction!.transactionDate.toLocal(),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final categoryViewModel = Provider.of<CategoryViewModel>(
        context,
        listen: false,
      );
      if (categoryViewModel.categories.isEmpty) {
        categoryViewModel.loadCategories();
      }

      // Set default category if not editing an existing transaction.
      if (widget.transaction == null && _category == null) {
        final categories = _type == 'income'
            ? categoryViewModel.incomeCategories
            : categoryViewModel.expenseCategories;
        if (categories.isNotEmpty) {
          setState(() {
            _category = categories.first;
          });
        }
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
        // If selected date is today and previously chosen time is in the future, clamp it to now.
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

  Future<void> _saveTransaction() async {
    _evaluateAmount();

    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter an amount')));
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid positive amount')),
      );
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a description')),
      );
      return;
    }

    if (_category == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a category')));
      return;
    }

    AppHaptics.mediumImpact(context);
    final viewModel = Provider.of<TransactionViewModel>(context, listen: false);

    try {
      final transactionDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      if (transactionDateTime.isAfter(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot add a transaction in the future.'),
          ),
        );
        return;
      }

      final success = widget.transaction == null
          ? await viewModel.addTransaction(
              amount: amount,
              type: _type,
              category: _category!,
              description: _descriptionController.text.trim(),
              paymentMethod: _paymentMethod,
              transactionDate: transactionDateTime,
            )
          : await viewModel.updateTransaction(
              id: widget.transaction!.id,
              amount: amount,
              type: _type,
              category: _category!,
              description: _descriptionController.text.trim().isEmpty
                  ? null
                  : _descriptionController.text.trim(),
              paymentMethod: _paymentMethod,
              transactionDate: transactionDateTime,
            );

      if (success && widget.transaction != null && mounted) {
        final splitVM = Provider.of<SplitViewModel>(context, listen: false);
        final updatedTx = widget.transaction!.copyWith(
          amount: amount,
          type: _type,
          category: _category!,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          paymentMethod: _paymentMethod,
          transactionDate: transactionDateTime,
        );
        await splitVM.updateSplitsForTransaction(updatedTx);
      }

      if (success && mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add transaction: $e')),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.transaction == null ? 'Add Transaction' : 'Edit Transaction',
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          if (widget.transaction != null)
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
              ),
              onPressed: () async {
                AppHaptics.vibrate(context);
                final viewModel = context.read<TransactionViewModel>();
                final splitVM = context.read<SplitViewModel>();
                final nav = Navigator.of(context);

                final isSplit = widget.transaction!.description != null &&
                    widget.transaction!.description!
                        .toLowerCase()
                        .startsWith('split:');
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Transaction'),
                    content: Text(
                      isSplit
                          ? 'Are you sure you want to delete this transaction? This will also remove the corresponding split expense.'
                          : 'Are you sure you want to delete this transaction?',
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
                  await viewModel.deleteTransaction(
                    widget.transaction!.id,
                    splitVM: splitVM,
                  );
                  if (mounted) {
                    nav.pop(true);
                  }
                }
              },
            ),
        ],
      ),
      body: Consumer<CategoryViewModel>(
        builder: (context, categoryViewModel, child) {
          final categories = _type == 'income'
              ? categoryViewModel.incomeCategories
              : categoryViewModel.expenseCategories;

          // Use Selector so we only rebuild when isSaving/isLoading changes,
          // not on every background transaction list update.
          return Selector<
            TransactionViewModel,
            ({bool isSaving, bool isLoading})
          >(
            selector: (_, vm) =>
                (isSaving: vm.isSaving, isLoading: vm.isLoading),
            builder: (context, state, _) {
              return state.isLoading && !state.isSaving
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                        children: [
                          // Type Toggle
                          Center(
                            child: SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                  value: 'expense',
                                  label: Text('Expense'),
                                  icon: Icon(Icons.arrow_upward),
                                ),
                                ButtonSegment(
                                  value: 'income',
                                  label: Text('Income'),
                                  icon: Icon(Icons.arrow_downward),
                                ),
                              ],
                              selected: {_type},
                              onSelectionChanged: (Set<String> newSelection) {
                                AppHaptics.selectionClick(context);
                                setState(() {
                                  _type = newSelection.first;
                                  final newCategories = _type == 'income'
                                      ? categoryViewModel.incomeCategories
                                      : categoryViewModel.expenseCategories;
                                  _category = newCategories.isNotEmpty
                                      ? newCategories.first
                                      : null;
                                });
                              },
                              style: SegmentedButton.styleFrom(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.surface.withValues(alpha: 0.5),
                                selectedBackgroundColor: _type == 'expense'
                                    ? Colors.red.withValues(alpha: 0.2)
                                    : Colors.green.withValues(alpha: 0.2),
                                selectedForegroundColor: _type == 'expense'
                                    ? Colors.red
                                    : Colors.green,
                                side: BorderSide(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outline.withValues(alpha: 0.1),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Inputs Card
                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                              side: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outline.withValues(alpha: 0.1),
                              ),
                            ),
                            color: Theme.of(context).colorScheme.surface
                                .withValues(
                                  alpha:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? 0.3
                                      : 0.8,
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
                                          Icons.account_balance_wallet,
                                        ).copyWith(
                                          prefixText: '₹ ',
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 24,
                                                vertical: 24,
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
                                  const SizedBox(height: 24),

                                  _buildSectionTitle('Description'),
                                  TextField(
                                    controller: _descriptionController,
                                    maxLength: 200,
                                    maxLengthEnforcement:
                                        MaxLengthEnforcement.enforced,
                                    decoration: _inputDecoration(
                                      'What was this for?',
                                      Icons.description,
                                    ).copyWith(counterText: ''),
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                  ),
                                  const SizedBox(height: 24),

                                  _buildSectionTitle('Category'),
                                  AppDropdown<String>(
                                    key: ValueKey(
                                      'category_dropdown_${_type}_$_category',
                                    ),
                                    value: _category,
                                    hint: 'Select Category',
                                    prefixIcon: Icons.category,
                                    items: (_category != null &&
                                            !categories.contains(_category)
                                        ? [_category!, ...categories]
                                        : categories)
                                        .map((String category) {
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
                                  const SizedBox(height: 24),

                                  _buildSectionTitle('Payment Method'),
                                  SegmentedButton<String>(
                                    segments: const [
                                      ButtonSegment(
                                        value: 'upi',
                                        label: Text('UPI'),
                                        icon: Icon(Icons.qr_code_2),
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
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.surface.withValues(alpha: 0.5),
                                      selectedBackgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.primary.withValues(alpha: 0.15),
                                      selectedForegroundColor: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      side: BorderSide(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.outline.withValues(alpha: 0.1),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  _buildSectionTitle('Date & Time'),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: () => _selectDate(context),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.05),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: Colors.transparent,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.calendar_today,
                                                  size: 20,
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    DateFormatter.formatDate(
                                                      _selectedDate,
                                                    ),
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
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
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.05),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: Colors.transparent,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.access_time,
                                                  size: 20,
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    _selectedTime.format(
                                                      context,
                                                    ),
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
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

                          const SizedBox(height: 48),

                          // Save Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: FilledButton(
                              onPressed: state.isSaving
                                  ? null
                                  : _saveTransaction,
                              style: FilledButton.styleFrom(
                                backgroundColor: _type == 'expense'
                                    ? Colors.red.withValues(alpha: 0.1)
                                    : Colors.green.withValues(alpha: 0.1),
                                foregroundColor: _type == 'expense'
                                    ? Colors.red
                                    : Colors.green,
                                shadowColor: Colors.transparent,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (state.isSaving) ...[
                                    SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              _type == 'expense'
                                                  ? Colors.red
                                                  : Colors.green,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                  ] else ...[
                                    Icon(
                                      widget.transaction == null
                                          ? Icons.check_circle_outline
                                          : Icons.update,
                                      size: 24,
                                      color: _type == 'expense'
                                          ? Colors.red
                                          : Colors.green,
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  Text(
                                    state.isSaving
                                        ? (widget.transaction == null
                                              ? 'Saving...'
                                              : 'Updating...')
                                        : (widget.transaction == null
                                              ? 'Save Transaction'
                                              : 'Update Transaction'),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _type == 'expense'
                                          ? Colors.red
                                          : Colors.green,
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
            );
          },
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
