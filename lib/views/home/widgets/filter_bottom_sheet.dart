import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../viewmodels/transaction_viewmodel.dart';
import '../../../viewmodels/category_viewmodel.dart';

/// Shows the filter bottom sheet for transactions.
void showFilterBottomSheet(
  BuildContext context,
  TransactionViewModel viewModel,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
      String? selectedType = viewModel.filterType;
      String? selectedCategory = viewModel.filterCategory;
      DateTime? selectedStartDate = viewModel.filterStartDate;
      DateTime? selectedEndDate = viewModel.filterEndDate;

      return StatefulBuilder(
        builder: (context, setState) {
          final theme = Theme.of(context);
          final categoryViewModel = Provider.of<CategoryViewModel>(
            context,
            listen: false,
          );

          // Get categories list depending on the selected transaction type
          List<String> displayCategories;
          if (selectedType == 'income') {
            displayCategories = categoryViewModel.incomeCategories;
          } else if (selectedType == 'expense') {
            displayCategories = categoryViewModel.expenseCategories;
          } else {
            // If Type is 'All' (null), combine and deduplicate categories while maintaining settings order (expense first)
            displayCategories = {
              ...categoryViewModel.expenseCategories,
              ...categoryViewModel.incomeCategories,
            }.toList();
          }

          // Ensure selectedCategory is cleared if it doesn't exist in the currently selectable categories
          if (selectedCategory != null &&
              !displayCategories.contains(selectedCategory)) {
            selectedCategory = null;
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 12, // Reduced top padding to accommodate drag handle
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag Handle Indicator
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.4,
                        ),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),

                  // Header with Title and Close Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter Transactions',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: theme
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Type Label
                  Text(
                    'Transaction Type',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Customized Choice Chips
                  Row(
                    children: [
                      _buildTypeChip(
                        context: context,
                        label: 'All',
                        isSelected: selectedType == null,
                        selectedColor: theme.colorScheme.primary.withValues(
                          alpha: 0.15,
                        ),
                        textColor: theme.colorScheme.primary,
                        borderColor: theme.colorScheme.primary.withValues(
                          alpha: 0.5,
                        ),
                        onTap: () {
                          setState(() {
                            selectedType = null;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildTypeChip(
                        context: context,
                        label: 'Income',
                        isSelected: selectedType == 'income',
                        selectedColor: Colors.green.withValues(alpha: 0.15),
                        textColor: Colors.green.shade700,
                        borderColor: Colors.green.withValues(alpha: 0.5),
                        onTap: () {
                          setState(() {
                            selectedType = 'income';
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildTypeChip(
                        context: context,
                        label: 'Expense',
                        isSelected: selectedType == 'expense',
                        selectedColor: Colors.red.withValues(alpha: 0.15),
                        textColor: Colors.red.shade700,
                        borderColor: Colors.red.withValues(alpha: 0.5),
                        onTap: () {
                          setState(() {
                            selectedType = 'expense';
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Category Filter (Always Visible)
                  Text(
                    'Category',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: const Text('All Categories'),
                            selected: selectedCategory == null,
                            selectedColor: theme.colorScheme.primary.withValues(
                              alpha: 0.15,
                            ),
                            labelStyle: TextStyle(
                              fontWeight: selectedCategory == null
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: selectedCategory == null
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            onSelected: (selected) {
                              setState(() {
                                selectedCategory = null;
                              });
                            },
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100),
                            ),
                            showCheckmark: false,
                          ),
                        ),
                        ...displayCategories.map((category) {
                          final isSelected = selectedCategory == category;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(category),
                              selected: isSelected,
                              selectedColor: theme.colorScheme.primary
                                  .withValues(alpha: 0.15),
                              labelStyle: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                              onSelected: (selected) {
                                setState(() {
                                  selectedCategory = selected ? category : null;
                                });
                              },
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(100),
                              ),
                              showCheckmark: false,
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Date Range Label
                  Text(
                    'Date Range',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Quick Date Range Presets using sliding Period Selector
                  _DateRangeSelector(
                    startDate: selectedStartDate,
                    endDate: selectedEndDate,
                    onRangeChanged: (start, end) {
                      setState(() {
                        selectedStartDate = start;
                        selectedEndDate = end;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Date Fields Row
                  Row(
                    children: [
                      _buildDatePickerField(
                        context: context,
                        label: 'Start Date',
                        selectedDate: selectedStartDate,
                        onTap: () async {
                          final now = DateTime.now();
                          final today = DateTime(now.year, now.month, now.day);
                          final initialRange =
                              (selectedStartDate != null &&
                                  selectedEndDate != null)
                              ? DateTimeRange(
                                  start: selectedStartDate!,
                                  end: selectedEndDate!,
                                )
                              : DateTimeRange(
                                  start: today.subtract(
                                    const Duration(days: 7),
                                  ),
                                  end: today,
                                );

                          final DateTimeRange? picked =
                              await showDateRangePicker(
                                context: context,
                                firstDate: DateTime(2000),
                                lastDate: today,
                                initialDateRange: initialRange,
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      appBarTheme: AppBarTheme(
                                        backgroundColor: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        foregroundColor: Theme.of(
                                          context,
                                        ).colorScheme.onPrimary,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );

                          if (picked != null) {
                            setState(() {
                              selectedStartDate = picked.start;
                              selectedEndDate = picked.end;
                            });
                          }
                        },
                        onClear: () {
                          setState(() {
                            selectedStartDate = null;
                          });
                        },
                      ),
                      const SizedBox(width: 12),
                      _buildDatePickerField(
                        context: context,
                        label: 'End Date',
                        selectedDate: selectedEndDate,
                        onTap: () async {
                          final now = DateTime.now();
                          final today = DateTime(now.year, now.month, now.day);
                          final initialRange =
                              (selectedStartDate != null &&
                                  selectedEndDate != null)
                              ? DateTimeRange(
                                  start: selectedStartDate!,
                                  end: selectedEndDate!,
                                )
                              : DateTimeRange(
                                  start: today.subtract(
                                    const Duration(days: 7),
                                  ),
                                  end: today,
                                );

                          final DateTimeRange? picked =
                              await showDateRangePicker(
                                context: context,
                                firstDate: DateTime(2000),
                                lastDate: today,
                                initialDateRange: initialRange,
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      appBarTheme: AppBarTheme(
                                        backgroundColor: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        foregroundColor: Theme.of(
                                          context,
                                        ).colorScheme.onPrimary,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );

                          if (picked != null) {
                            setState(() {
                              selectedStartDate = picked.start;
                              selectedEndDate = picked.end;
                            });
                          }
                        },
                        onClear: () {
                          setState(() {
                            selectedEndDate = null;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              selectedType = null;
                              selectedCategory = null;
                              selectedStartDate = null;
                              selectedEndDate = null;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            side: BorderSide(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                          child: Text(
                            'Clear All',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
                            await viewModel.loadTransactions(
                              forceRefresh: true,
                            );
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Apply',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _buildTypeChip({
  required BuildContext context,
  required String label,
  required bool isSelected,
  required Color selectedColor,
  required Color textColor,
  required Color borderColor,
  required VoidCallback onTap,
}) {
  final theme = Theme.of(context);
  return Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? borderColor
                : theme.colorScheme.outline.withValues(alpha: 0.15),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? textColor : theme.colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
      ),
    ),
  );
}

Widget _buildDatePickerField({
  required BuildContext context,
  required String label,
  required DateTime? selectedDate,
  required VoidCallback onTap,
  required VoidCallback onClear,
}) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  return Expanded(
    child: Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selectedDate != null
                          ? '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'
                          : 'Select Date',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: selectedDate != null
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.4,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              if (selectedDate != null)
                GestureDetector(
                  onTap: () {
                    onClear();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      Icons.cancel_rounded,
                      size: 18,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _DateRangeSelector — replaces the IIFE that was previously inline in build().
//
// Holds the selected period string in its own local state and calls
// [onRangeChanged] with the computed start/end DateTimes whenever the user
// taps a preset or picks a custom range.
// ─────────────────────────────────────────────────────────────────────────────

typedef _RangeCallback = void Function(DateTime? start, DateTime? end);

class _DateRangeSelector extends StatefulWidget {
  const _DateRangeSelector({
    required this.startDate,
    required this.endDate,
    required this.onRangeChanged,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final _RangeCallback onRangeChanged;

  @override
  State<_DateRangeSelector> createState() => _DateRangeSelectorState();
}

class _DateRangeSelectorState extends State<_DateRangeSelector> {
  static const _periods = [
    {'id': '7days', 'label': '7 Days'},
    {'id': '30days', 'label': '30 Days'},
    {'id': 'month', 'label': 'Month'},
    {'id': 'year', 'label': 'Year'},
    {'id': 'custom', 'label': 'Custom'},
  ];

  /// Derives the active period label from the given start/end dates.
  String _derivePeriod(DateTime? start, DateTime? end) {
    if (start == null && end == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final endMatches =
        end != null &&
        end.day == todayEnd.day &&
        end.month == todayEnd.month &&
        end.year == todayEnd.year;

    if (!endMatches) return 'custom';
    if (start == today.subtract(const Duration(days: 6))) return '7days';
    if (start == today.subtract(const Duration(days: 29))) return '30days';
    if (start == DateTime(now.year, now.month, 1)) return 'month';
    if (start == DateTime(now.year, 1, 1)) return 'year';
    return 'custom';
  }

  void _applyPreset(String id) {
    if (id == 'custom') {
      _pickCustomRange();
      return;
    }

    final now = DateTime.now();
    final endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    late DateTime startDate;

    switch (id) {
      case '7days':
        startDate = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 6));
      case '30days':
        startDate = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 29));
      case 'month':
        startDate = DateTime(now.year, now.month, 1);
      case 'year':
        startDate = DateTime(now.year, 1, 1);
      default:
        return;
    }
    widget.onRangeChanged(startDate, endDate);
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: today,
      initialDateRange: DateTimeRange(
        start: widget.startDate ?? today.subtract(const Duration(days: 7)),
        end: widget.endDate ?? today,
      ),
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            appBarTheme: AppBarTheme(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      widget.onRangeChanged(
        picked.start,
        DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activePeriod = _derivePeriod(widget.startDate, widget.endDate);

    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: _periods.map((p) {
          final isSelected = activePeriod == p['id'];
          return Expanded(
            child: GestureDetector(
              onTap: () => _applyPreset(p['id']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.surface
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  p['label']!,
                  style: TextStyle(
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
