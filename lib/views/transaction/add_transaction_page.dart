import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/transaction_viewmodel.dart';
import '../../viewmodels/category_viewmodel.dart';
import '../../models/transaction.dart';
import '../../widgets/app_dropdown.dart';
import '../../utils/date_formatter.dart';

class AddTransactionPage extends StatefulWidget {
  final TransactionModel? transaction;

  const AddTransactionPage({super.key, this.transaction});

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _type = 'expense';
  String? _category;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();

    if (widget.transaction != null) {
      _amountController.text = widget.transaction!.amount.toString();
      _descriptionController.text = widget.transaction!.description ?? '';
      _type = widget.transaction!.type;
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
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _saveTransaction() async {
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

    if (_category == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a category')));
      return;
    }

    final viewModel = Provider.of<TransactionViewModel>(context, listen: false);

    try {
      final transactionDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final success = widget.transaction == null
          ? await viewModel.addTransaction(
              amount: amount,
              type: _type,
              category: _category!,
              description: _descriptionController.text.trim().isEmpty
                  ? null
                  : _descriptionController.text.trim(),
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
              transactionDate: transactionDateTime,
            );

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
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: Theme.of(context).brightness == Brightness.dark
                ? [Colors.black, Colors.black]
                : [const Color(0xFFEEF2FF), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Consumer<CategoryViewModel>(
          builder: (context, categoryViewModel, child) {
            final categories = _type == 'income'
                ? categoryViewModel.incomeCategories
                : categoryViewModel.expenseCategories;

            if (_category == null || !categories.contains(_category)) {
              _category = categories.isNotEmpty ? categories.first : null;
            }

            final transactionViewModel = Provider.of<TransactionViewModel>(
              context,
            );
            final isSaving = transactionViewModel.isSaving;

            return transactionViewModel.isLoading && !isSaving
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(24, 120, 24, 24),
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
                        color: Theme.of(context).colorScheme.surface.withValues(
                          alpha: Theme.of(context).brightness == Brightness.dark
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
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration:
                                    _inputDecoration(
                                      '0.00',
                                      Icons.account_balance_wallet_outlined,
                                    ).copyWith(
                                      prefixText: '₹ ',
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 24,
                                          ),
                                    ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                              ),
                              const SizedBox(height: 24),

                              _buildSectionTitle('Description'),
                              TextField(
                                controller: _descriptionController,
                                decoration: _inputDecoration(
                                  'What was this for?',
                                  Icons.description_outlined,
                                ),
                                textCapitalization:
                                    TextCapitalization.sentences,
                              ),
                              const SizedBox(height: 24),

                              _buildSectionTitle('Category'),
                              AppDropdown<String>(
                                key: ValueKey('category_dropdown_$_type'),
                                value: _category,
                                hint: 'Select Category',
                                prefixIcon: Icons.category_outlined,
                                items: categories.map((String category) {
                                  return DropdownMenuItem(
                                    value: category,
                                    child: Text(category),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  if (newValue != null) {
                                    setState(() {
                                      _category = newValue;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 24),

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
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.05),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
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
                                            Text(
                                              DateFormatter.formatDate(
                                                _selectedDate,
                                              ),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
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
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.05),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
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
                                            Text(
                                              _selectedTime.format(context),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
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
                      Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            colors: _type == 'expense'
                                ? [
                                    const Color(0xFFFF5252),
                                    const Color(0xFFD32F2F),
                                  ]
                                : [
                                    const Color(0xFF4CAF50),
                                    const Color(0xFF2E7D32),
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (_type == 'expense'
                                          ? const Color(0xFFFF5252)
                                          : const Color(0xFF4CAF50))
                                      .withValues(
                                        alpha:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? 0.3
                                            : 0.5,
                                      ),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: isSaving ? null : _saveTransaction,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isSaving) ...[
                                const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(
                                          Colors.white,
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
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 12),
                              ],
                              Text(
                                isSaving
                                    ? (widget.transaction == null
                                        ? 'Saving...'
                                        : 'Updating...')
                                    : (widget.transaction == null
                                        ? 'Save Transaction'
                                        : 'Update Transaction'),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
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
