import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../viewmodels/transaction_viewmodel.dart';
import '../../../viewmodels/category_viewmodel.dart';
import '../../../widgets/app_dropdown.dart';

/// Shows the filter bottom sheet for transactions.
void showFilterBottomSheet(
  BuildContext context,
  TransactionViewModel viewModel,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      String? selectedType = viewModel.filterType;
      String? selectedCategory = viewModel.filterCategory;
      DateTime? selectedStartDate = viewModel.filterStartDate;
      DateTime? selectedEndDate = viewModel.filterEndDate;
      return StatefulBuilder(
        builder: (context, setState) {
          final isIncomeFilter = selectedType == 'income';
          final isExpenseFilter = selectedType == 'expense';
          final categoryViewModel = Provider.of<CategoryViewModel>(
            context,
            listen: false,
          );

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Filter Transactions',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Type',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: selectedType == null,
                      onSelected: (_) {
                        setState(() {
                          selectedType = null;
                          selectedCategory = null;
                        });
                      },
                    ),
                    FilterChip(
                      label: const Text('Income'),
                      selected: isIncomeFilter,
                      onSelected: (_) {
                        setState(() {
                          selectedType = 'income';
                          selectedCategory = null;
                        });
                      },
                    ),
                    FilterChip(
                      label: const Text('Expense'),
                      selected: isExpenseFilter,
                      onSelected: (_) {
                        setState(() {
                          selectedType = 'expense';
                          selectedCategory = null;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (selectedType != null) ...[
                  const Text(
                    'Category',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  AppDropdown<String?>(
                    key: ValueKey(selectedCategory),
                    value: selectedCategory,
                    hint: 'All Categories',
                    prefixIcon: Icons.category_outlined,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All Categories'),
                      ),
                      ...(selectedType == 'income'
                              ? categoryViewModel.incomeCategories
                              : categoryViewModel.expenseCategories)
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          ),
                    ],
                    onChanged: (val) {
                      setState(() {
                        selectedCategory = val;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                const Text(
                  'Date Range',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedStartDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() {
                              selectedStartDate = date;
                              if (selectedEndDate != null &&
                                  selectedEndDate!.isBefore(date)) {
                                selectedEndDate = date;
                              }
                            });
                          }
                        },
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          selectedStartDate != null
                              ? '${selectedStartDate!.day}/${selectedStartDate!.month}/${selectedStartDate!.year}'
                              : 'Start Date',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedEndDate ?? DateTime.now(),
                            firstDate: selectedStartDate ?? DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() {
                              selectedEndDate = date;
                            });
                          }
                        },
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          selectedEndDate != null
                              ? '${selectedEndDate!.day}/${selectedEndDate!.month}/${selectedEndDate!.year}'
                              : 'End Date',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            selectedType = null;
                            selectedCategory = null;
                            selectedStartDate = null;
                            selectedEndDate = null;
                          });
                        },
                        child: const Text('Clear All'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          viewModel.setFilters(
                            type: selectedType,
                            category: selectedCategory,
                            startDate: selectedStartDate,
                            endDate: selectedEndDate,
                          );
                          await viewModel.loadTransactions(forceRefresh: true);
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onPrimary,
                        ),
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      );
    },
  );
}
