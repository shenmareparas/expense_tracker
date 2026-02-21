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
      return StatefulBuilder(
        builder: (context, setState) {
          final isIncomeFilter = viewModel.filterType == 'income';
          final isExpenseFilter = viewModel.filterType == 'expense';
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
                      selected: viewModel.filterType == null,
                      onSelected: (_) {
                        viewModel.setFilters(
                          type: null,
                          category: null,
                          startDate: viewModel.filterStartDate,
                          endDate: viewModel.filterEndDate,
                        );
                        setState(() {});
                      },
                    ),
                    FilterChip(
                      label: const Text('Income'),
                      selected: isIncomeFilter,
                      onSelected: (_) {
                        viewModel.setFilters(
                          type: 'income',
                          category: null,
                          startDate: viewModel.filterStartDate,
                          endDate: viewModel.filterEndDate,
                        );
                        setState(() {});
                      },
                    ),
                    FilterChip(
                      label: const Text('Expense'),
                      selected: isExpenseFilter,
                      onSelected: (_) {
                        viewModel.setFilters(
                          type: 'expense',
                          category: null,
                          startDate: viewModel.filterStartDate,
                          endDate: viewModel.filterEndDate,
                        );
                        setState(() {});
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (viewModel.filterType != null) ...[
                  const Text(
                    'Category',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  AppDropdown<String?>(
                    key: ValueKey(viewModel.filterCategory),
                    value: viewModel.filterCategory,
                    hint: 'All Categories',
                    prefixIcon: Icons.category_outlined,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All Categories'),
                      ),
                      ...(viewModel.filterType == 'income'
                              ? categoryViewModel.incomeCategories
                              : categoryViewModel.expenseCategories)
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          ),
                    ],
                    onChanged: (val) {
                      viewModel.setFilters(
                        type: viewModel.filterType,
                        category: val,
                        startDate: viewModel.filterStartDate,
                        endDate: viewModel.filterEndDate,
                      );
                      setState(() {});
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
                            initialDate:
                                viewModel.filterStartDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            viewModel.setFilters(
                              type: viewModel.filterType,
                              category: viewModel.filterCategory,
                              startDate: date,
                              endDate: viewModel.filterEndDate,
                            );
                            setState(() {});
                          }
                        },
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          viewModel.filterStartDate != null
                              ? '${viewModel.filterStartDate!.day}/${viewModel.filterStartDate!.month}/${viewModel.filterStartDate!.year}'
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
                            initialDate:
                                viewModel.filterEndDate ?? DateTime.now(),
                            firstDate:
                                viewModel.filterStartDate ?? DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            viewModel.setFilters(
                              type: viewModel.filterType,
                              category: viewModel.filterCategory,
                              startDate: viewModel.filterStartDate,
                              endDate: date,
                            );
                            setState(() {});
                          }
                        },
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          viewModel.filterEndDate != null
                              ? '${viewModel.filterEndDate!.day}/${viewModel.filterEndDate!.month}/${viewModel.filterEndDate!.year}'
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
                          viewModel.clearFilters();
                          setState(() {});
                        },
                        child: const Text('Clear All'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
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
