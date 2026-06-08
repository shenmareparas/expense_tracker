import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../viewmodels/transaction_viewmodel.dart';
import '../../viewmodels/category_viewmodel.dart';
import '../../models/transaction.dart';
import '../../models/category.dart';

class AnalyticsPage extends StatefulWidget {
  final ScrollController? scrollController;
  const AnalyticsPage({super.key, this.scrollController});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  String _selectedTimePeriod =
      '7days'; // '7days', '30days', 'month', 'year', 'custom'
  String _selectedType = 'expense'; // 'expense', 'income'
  String _selectedChartType =
      'trend'; // 'pie' (breakdown), 'trend' (daily trend)
  String? _selectedCategoryFilter; // null means 'All Categories'
  // touchedIndex / touchedBarIndex are now held inside _PieChartWidget and
  // _BarChartWidget sub-widgets so chart interactions don't trigger a full
  // analytics page rebuild with all its aggregation loops.

  // --- Memoization Cache ---
  List<TransactionModel>? _memoizedTransactions;
  List<CategoryModel>? _memoizedCategories;
  String? _memoizedSelectedType;
  String? _memoizedSelectedCategoryFilter;
  String? _memoizedSelectedTimePeriod;
  DateTime? _memoizedStartDate;
  DateTime? _memoizedEndDate;

  double _totalIncome = 0;
  double _totalExpense = 0;
  double _netBalance = 0;
  List<String> _allCategoryNames = [];
  List<TransactionModel> _filteredTransactions = [];
  List<MapEntry<String, double>> _sortedCategories = [];
  double _currentTotal = 0;
  List<MapEntry<DateTime, double>> _dailyData = [];
  List<MapEntry<String, double>> _sortedOverallCategories = [];

  final List<Color> _chartColors = [
    const Color(0xFF6366F1), // Indigo
    const Color(0xFFEF4444), // Red
    const Color(0xFF10B981), // Emerald
    const Color(0xFFF59E0B), // Amber
    const Color(0xFF8B5CF6), // Violet
    const Color(0xFF14B8A6), // Teal
    const Color(0xFFEC4899), // Pink
    const Color(0xFF3B82F6), // Blue
    const Color(0xFFF97316), // Orange
    const Color(0xFF06B6D4), // Cyan
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyFiltersSilently(_selectedTimePeriod);
    });
  }

  void _applyFiltersSilently(String period) {
    if (period == 'custom') {
      return; // Custom is handled in the date picker callback
    }

    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate = DateTime(now.year, now.month, now.day);

    switch (period) {
      case '7days':
        startDate = endDate.subtract(const Duration(days: 6));
        break;
      case '30days':
        startDate = endDate.subtract(const Duration(days: 29));
        break;
      case 'month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      case 'year':
        startDate = DateTime(now.year, 1, 1);
        break;
      default:
        startDate = endDate.subtract(const Duration(days: 6));
    }

    final vm = Provider.of<TransactionViewModel>(context, listen: false);
    vm.loadAnalyticsSnapshot(startDate: startDate, endDate: endDate);
  }

  void _changeTimePeriod(String period) {
    setState(() {
      _selectedTimePeriod = period;
      _selectedCategoryFilter = null;
    });
    _applyFiltersSilently(period);
  }

  Future<void> _selectCustomDateRange() async {
    final vm = Provider.of<TransactionViewModel>(context, listen: false);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initialRange = DateTimeRange(
      start:
          vm.analyticsStartDate != null &&
              !vm.analyticsStartDate!.isAfter(today)
          ? vm.analyticsStartDate!
          : today.subtract(const Duration(days: 7)),
      end: vm.analyticsEndDate != null && !vm.analyticsEndDate!.isAfter(today)
          ? vm.analyticsEndDate!
          : today,
    );

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: today,
      initialDateRange: initialRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            appBarTheme: AppBarTheme(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedTimePeriod = 'custom';
        _selectedCategoryFilter = null;
      });
      vm.loadAnalyticsSnapshot(startDate: picked.start, endDate: picked.end);
    }
  }

  List<MapEntry<DateTime, double>> _getDailyData(
    List<TransactionModel> transactions,
    String type,
    String period,
    DateTime? customStart,
    DateTime? customEnd,
  ) {
    final now = DateTime.now();
    DateTime endDate = DateTime(now.year, now.month, now.day);
    DateTime startDate;

    if (period == 'custom' && customStart != null && customEnd != null) {
      startDate = DateTime(
        customStart.year,
        customStart.month,
        customStart.day,
      );
      endDate = DateTime(customEnd.year, customEnd.month, customEnd.day);
    } else {
      switch (period) {
        case '7days':
          startDate = endDate.subtract(const Duration(days: 6));
          break;
        case '30days':
          startDate = endDate.subtract(const Duration(days: 29));
          break;
        case 'month':
          startDate = DateTime(now.year, now.month, 1);
          break;
        case 'year':
          startDate = DateTime(now.year, 1, 1);
          break;
        default:
          startDate = endDate.subtract(const Duration(days: 6));
      }
    }

    final Map<DateTime, double> dailyMap = {};
    final totalDays = endDate.difference(startDate).inDays;
    final bool useMonthlyGrouping = period == 'year' || totalDays > 65;

    if (useMonthlyGrouping) {
      // Group by monthly buckets
      // Determine the range of months
      DateTime currentMonth = DateTime(startDate.year, startDate.month, 1);
      DateTime targetMonth = DateTime(endDate.year, endDate.month, 1);

      while (!currentMonth.isAfter(targetMonth)) {
        dailyMap[currentMonth] = 0.0;
        currentMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
      }

      for (final t in transactions) {
        if (t.type == type) {
          final transactionMonth = DateTime(
            t.transactionDate.year,
            t.transactionDate.month,
            1,
          );
          if (dailyMap.containsKey(transactionMonth)) {
            dailyMap[transactionMonth] = dailyMap[transactionMonth]! + t.amount;
          }
        }
      }
    } else {
      // Group by daily buckets
      DateTime current = startDate;
      while (!current.isAfter(endDate)) {
        dailyMap[DateTime(current.year, current.month, current.day)] = 0.0;
        current = current.add(const Duration(days: 1));
      }

      for (final t in transactions) {
        if (t.type == type) {
          final dateKey = DateTime(
            t.transactionDate.year,
            t.transactionDate.month,
            t.transactionDate.day,
          );
          if (dailyMap.containsKey(dateKey)) {
            dailyMap[dateKey] = dailyMap[dateKey]! + t.amount;
          }
        }
      }
    }

    final sortedEntries = dailyMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return sortedEntries;
  }

  Map<String, double> _getCategoriesData(
    List<TransactionModel> transactions,
    String type,
  ) {
    final map = <String, double>{};
    for (final t in transactions) {
      if (t.type == type) {
        map[t.category] = (map[t.category] ?? 0.0) + t.amount;
      }
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<TransactionViewModel, CategoryViewModel>(
      builder: (context, viewModel, categoryViewModel, child) {
        final transactions = viewModel.transactions;

        if (viewModel.isLoading && transactions.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (viewModel.errorMessage != null && transactions.isEmpty) {
          return Center(child: Text('Error: ${viewModel.errorMessage}'));
        }

        bool shouldRecompute =
            _memoizedTransactions != transactions ||
            _memoizedCategories != categoryViewModel.categories ||
            _memoizedSelectedType != _selectedType ||
            _memoizedSelectedCategoryFilter != _selectedCategoryFilter ||
            _memoizedSelectedTimePeriod != _selectedTimePeriod ||
            _memoizedStartDate != viewModel.analyticsStartDate ||
            _memoizedEndDate != viewModel.analyticsEndDate;

        if (shouldRecompute) {
          _memoizedTransactions = transactions;
          _memoizedCategories = categoryViewModel.categories;
          _memoizedSelectedType = _selectedType;
          _memoizedSelectedCategoryFilter = _selectedCategoryFilter;
          _memoizedSelectedTimePeriod = _selectedTimePeriod;
          _memoizedStartDate = viewModel.analyticsStartDate;
          _memoizedEndDate = viewModel.analyticsEndDate;

          _totalIncome = 0;
          _totalExpense = 0;
          for (final t in transactions) {
            if (t.type == 'income') {
              _totalIncome += t.amount;
            } else {
              _totalExpense += t.amount;
            }
          }
          _netBalance = _totalIncome - _totalExpense;

          _allCategoryNames = _selectedType == 'income'
              ? List.from(categoryViewModel.incomeCategories)
              : List.from(categoryViewModel.expenseCategories);

          if (_allCategoryNames.isEmpty) {
            _allCategoryNames =
                transactions
                    .where((t) => t.type == _selectedType)
                    .map((t) => t.category)
                    .toSet()
                    .toList()
                  ..sort();
          }

          _filteredTransactions = _selectedCategoryFilter == null
              ? transactions
              : transactions
                    .where((t) => t.category == _selectedCategoryFilter)
                    .toList();

          final categoriesMap = _getCategoriesData(
            _filteredTransactions,
            _selectedType,
          );
          _sortedCategories = categoriesMap.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          _currentTotal = categoriesMap.values.fold(
            0.0,
            (sum, val) => sum + val,
          );

          _dailyData = _getDailyData(
            _filteredTransactions,
            _selectedType,
            _selectedTimePeriod,
            viewModel.analyticsStartDate,
            viewModel.analyticsEndDate,
          );

          final overallCategoriesMap = _getCategoriesData(
            transactions,
            _selectedType,
          );
          _sortedOverallCategories = overallCategoriesMap.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
        }

        return RefreshIndicator(
          onRefresh: () async {
            await viewModel.loadTransactions(forceRefresh: true);
            await categoryViewModel.loadCategories(forceRefresh: true);
            _applyFiltersSilently(_selectedTimePeriod);
          },
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.all(20.0),
            children: [
              _buildTimePeriodSelector(),
              if (_selectedTimePeriod == 'custom' &&
                  viewModel.analyticsStartDate != null &&
                  viewModel.analyticsEndDate != null) ...[
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      'Range: ${DateFormat('yMMMd').format(viewModel.analyticsStartDate!)} - ${DateFormat('yMMMd').format(viewModel.analyticsEndDate!)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _buildCategoryChipsRow(_allCategoryNames),
              const SizedBox(height: 20),
              _buildBalanceSummaryCard(
                context,
                _totalIncome,
                _totalExpense,
                _netBalance,
              ),
              const SizedBox(height: 24),
              _buildChartCard(
                context,
                _currentTotal,
                _sortedCategories,
                _dailyData,
                viewModel,
              ),
              const SizedBox(height: 24),
              if (_currentTotal > 0) ...[
                const SizedBox(height: 24),
                _buildInsightsSection(
                  _dailyData,
                  _sortedCategories,
                  _currentTotal,
                ),
                const SizedBox(height: 24),
                _buildCategoryBreakdownList(
                  context,
                  _sortedOverallCategories,
                  transactions,
                ),
              ] else ...[
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 48,
                      horizontal: 24,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.insights_outlined,
                          size: 64,
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No transactions found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedCategoryFilter == null
                              ? 'Try changing the time frame or adding new transactions.'
                              : 'No data for category "$_selectedCategoryFilter" in this period.',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 48),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimePeriodSelector() {
    final periods = [
      {'id': '7days', 'label': '7 Days'},
      {'id': '30days', 'label': '30 Days'},
      {'id': 'month', 'label': 'Month'},
      {'id': 'year', 'label': 'Year'},
      {'id': 'custom', 'label': 'Custom'},
    ];

    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: periods.map((p) {
          final isSelected = _selectedTimePeriod == p['id'];
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (p['id'] == 'custom') {
                  _selectCustomDateRange();
                } else {
                  _changeTimePeriod(p['id']!);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.surface
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
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryChipsRow(List<String> categories) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: const Text('All Categories'),
              selected: _selectedCategoryFilter == null,
              selectedColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.15),
              labelStyle: TextStyle(
                fontWeight: _selectedCategoryFilter == null
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: _selectedCategoryFilter == null
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              onSelected: (selected) {
                setState(() {
                  _selectedCategoryFilter = null;
                });
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
              showCheckmark: false,
            ),
          ),
          ...categories.map((category) {
            final isSelected = _selectedCategoryFilter == category;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text(category),
                selected: isSelected,
                selectedColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onSelected: (selected) {
                  setState(() {
                    _selectedCategoryFilter = selected ? category : null;
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
    );
  }

  Widget _buildBalanceSummaryCard(
    BuildContext context,
    double income,
    double expense,
    double balance,
  ) {
    final bool isPositive = balance >= 0;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [
                    const Color(
                      0xFF131524,
                    ), // Extremely deep premium indigo/navy
                    const Color(0xFF090A10), // Midnight obsidian
                  ]
                : [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.8),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          border: isDark
              ? Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.25),
                  width: 1.5,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.12)
                  : Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Net Balance',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive ? Icons.trending_up : Icons.trending_down,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isPositive ? 'Surplus' : 'Deficit',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '₹${balance.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_downward,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Income',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '₹${income.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_upward,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Expenses',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '₹${expense.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(
    BuildContext context,
    double total,
    List<MapEntry<String, double>> categories,
    List<MapEntry<DateTime, double>> dailyData,
    TransactionViewModel viewModel,
  ) {
    final String subtitleText = _selectedCategoryFilter == null
        ? 'Total: ₹${total.toStringAsFixed(0)}'
        : 'Category "$_selectedCategoryFilter": ₹${total.toStringAsFixed(0)}';

    return RepaintBoundary(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedType == 'expense'
                              ? 'Expense Analysis'
                              : 'Income Analysis',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitleText,
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _buildTypeAndChartToggles(),
                ],
              ),
              const SizedBox(height: 24),
              if (total == 0)
                const SizedBox(
                  height: 220,
                  child: Center(
                    child: Text(
                      'No data available for this selection',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else if (_selectedChartType == 'pie')
                _buildPieChart(context, total, categories)
              else
                _buildDailyTrendChart(context, dailyData, viewModel),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeAndChartToggles() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Expense/Income toggle icon
        IconButton(
          onPressed: () {
            setState(() {
              _selectedType = _selectedType == 'expense' ? 'income' : 'expense';
              _selectedCategoryFilter = null;
            });
          },
          icon: Icon(
            _selectedType == 'expense'
                ? Icons.arrow_upward
                : Icons.arrow_downward,
            color: _selectedType == 'expense' ? Colors.red : Colors.green,
            size: 20,
          ),
          tooltip: 'Toggle Income/Expense',
          style: IconButton.styleFrom(
            backgroundColor: _selectedType == 'expense'
                ? Colors.red.withValues(alpha: 0.08)
                : Colors.green.withValues(alpha: 0.08),
            padding: const EdgeInsets.all(8),
          ),
        ),
        const SizedBox(width: 8),
        // Chart Type toggle button
        IconButton(
          onPressed: () {
            setState(() {
              _selectedChartType = _selectedChartType == 'pie'
                  ? 'trend'
                  : 'pie';
            });
          },
          icon: Icon(
            _selectedChartType == 'pie' ? Icons.bar_chart : Icons.pie_chart,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          tooltip: _selectedChartType == 'pie'
              ? 'Show Trend Chart'
              : 'Show Pie Chart',
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.08),
            padding: const EdgeInsets.all(8),
          ),
        ),
      ],
    );
  }

  Widget _buildPieChart(
    BuildContext context,
    double total,
    List<MapEntry<String, double>> categories,
  ) {
    return _PieChartWidget(
      total: total,
      categories: categories,
      chartColors: _chartColors,
    );
  }

  Widget _buildDailyTrendChart(
    BuildContext context,
    List<MapEntry<DateTime, double>> dailyData,
    TransactionViewModel viewModel,
  ) {
    return _BarChartWidget(
      dailyData: dailyData,
      viewModel: viewModel,
      selectedTimePeriod: _selectedTimePeriod,
    );
  }

  Widget _buildInsightsSection(
    List<MapEntry<DateTime, double>> dailyData,
    List<MapEntry<String, double>> categories,
    double total,
  ) {
    // 1. Average daily transaction
    final positiveDays = dailyData.where((e) => e.value > 0).length;
    final averageDaily = positiveDays > 0 ? total / positiveDays : 0.0;

    // 2. Highest Single Day
    MapEntry<DateTime, double>? highestDay;
    if (dailyData.isNotEmpty) {
      highestDay = dailyData.reduce(
        (curr, next) => curr.value > next.value ? curr : next,
      );
    }

    // 3. Most Expensive Category
    final highestCategory = categories.isNotEmpty ? categories.first : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4.0),
          child: Text(
            'Financial Insights',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.35,
          children: [
            _buildInsightCard(
              title: _selectedType == 'expense'
                  ? 'Daily Spend Avg'
                  : 'Daily Income Avg',
              value: '₹${averageDaily.toStringAsFixed(0)}',
              subtitle: 'On active days',
              icon: Icons.calendar_today,
              color: Colors.blue.shade400,
            ),
            _buildInsightCard(
              title: 'Highest Day',
              value: highestDay != null && highestDay.value > 0
                  ? '₹${highestDay.value.toStringAsFixed(0)}'
                  : '₹0',
              subtitle: highestDay != null && highestDay.value > 0
                  ? DateFormat('MMM d').format(highestDay.key)
                  : 'No transactions',
              icon: Icons.star,
              color: Colors.amber.shade500,
            ),
            _buildInsightCard(
              title: _selectedCategoryFilter == null
                  ? 'Top Category'
                  : 'Selected Category',
              value:
                  _selectedCategoryFilter ??
                  (highestCategory != null ? highestCategory.key : 'None'),
              subtitle:
                  _selectedCategoryFilter == null && highestCategory != null
                  ? '${((highestCategory.value / total) * 100).toStringAsFixed(0)}% of total'
                  : _selectedCategoryFilter != null
                  ? 'Drilled down active'
                  : 'No entries',
              icon: Icons.category,
              color: Colors.indigo.shade400,
            ),
            _buildInsightCard(
              title: 'Data Points',
              value: '${dailyData.length} Points',
              subtitle: 'Selected timeframe',
              icon: Icons.analytics,
              color: Colors.teal.shade400,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInsightCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.4),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdownList(
    BuildContext context,
    List<MapEntry<String, double>> categories,
    List<TransactionModel> rawTransactions,
  ) {
    // We calculate percentages based on overall transactions for that type,
    // so the breakdown bars remain proportional even when clicked!
    final overallMap = _getCategoriesData(rawTransactions, _selectedType);
    final double overallTotal = overallMap.values.fold(
      0.0,
      (sum, val) => sum + val,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4.0),
          child: Text(
            'Category Breakdown',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(categories.length, (i) {
          final entry = categories[i];
          final color = _chartColors[i % _chartColors.length];
          final percentage = overallTotal > 0
              ? (entry.value / overallTotal) * 100
              : 0.0;
          final isSelected = _selectedCategoryFilter == entry.key;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 12.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.08),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                onTap: () {
                  setState(() {
                    _selectedCategoryFilter = isSelected ? null : entry.key;
                  });
                },
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.category, color: color, size: 20),
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '₹${entry.value.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: overallTotal > 0
                            ? entry.value / overallTotal
                            : 0.0,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.06),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${percentage.toStringAsFixed(1)}% of type total',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _PieChartWidget extends StatefulWidget {
  final double total;
  final List<MapEntry<String, double>> categories;
  final List<Color> chartColors;

  const _PieChartWidget({
    required this.total,
    required this.categories,
    required this.chartColors,
  });

  @override
  State<_PieChartWidget> createState() => _PieChartWidgetState();
}

class _PieChartWidgetState extends State<_PieChartWidget> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  // Ignore scroll/pan gestures to keep list scrolling buttery smooth
                  if (event is FlPanStartEvent ||
                      event is FlPanUpdateEvent ||
                      event is FlPanEndEvent) {
                    return;
                  }

                  final int newIndex;
                  if (!event.isInterestedForInteractions ||
                      pieTouchResponse == null ||
                      pieTouchResponse.touchedSection == null) {
                    newIndex = -1;
                  } else {
                    newIndex =
                        pieTouchResponse.touchedSection!.touchedSectionIndex;
                  }

                  if (touchedIndex != newIndex) {
                    setState(() {
                      touchedIndex = newIndex;
                    });
                  }
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 3,
              centerSpaceRadius: 65,
              sections: List.generate(widget.categories.length, (i) {
                final isTouched = i == touchedIndex;
                final radius = isTouched ? 45.0 : 35.0;
                final color = widget.chartColors[i % widget.chartColors.length];
                final entry = widget.categories[i];
                final percentage = (entry.value / widget.total) * 100;

                return PieChartSectionData(
                  color: color,
                  value: entry.value,
                  title: isTouched ? '${percentage.toStringAsFixed(1)}%' : '',
                  radius: radius,
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                touchedIndex == -1
                    ? 'Average'
                    : widget.categories[touchedIndex].key,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                touchedIndex == -1
                    ? '₹${(widget.total / (widget.categories.isEmpty ? 1 : widget.categories.length)).toStringAsFixed(0)}'
                    : '₹${widget.categories[touchedIndex].value.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarChartWidget extends StatefulWidget {
  final List<MapEntry<DateTime, double>> dailyData;
  final TransactionViewModel viewModel;
  final String selectedTimePeriod;

  const _BarChartWidget({
    required this.dailyData,
    required this.viewModel,
    required this.selectedTimePeriod,
  });

  @override
  State<_BarChartWidget> createState() => _BarChartWidgetState();
}

class _BarChartWidgetState extends State<_BarChartWidget> {
  int touchedBarIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.dailyData.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(child: Text('No daily data points')),
      );
    }

    final double maxVal = widget.dailyData
        .map((e) => e.value)
        .fold(1.0, (prev, element) => element > prev ? element : prev);
    final double yAxisMax = maxVal * 1.15;

    // Detect if we are using monthly bucket formatting
    final DateTime start =
        widget.viewModel.filterStartDate ??
        DateTime.now().subtract(const Duration(days: 7));
    final DateTime end = widget.viewModel.filterEndDate ?? DateTime.now();
    final bool isMonthlyFormatted =
        widget.selectedTimePeriod == 'year' ||
        end.difference(start).inDays > 65;

    return SizedBox(
      height: 220,
      child: Padding(
        padding: const EdgeInsets.only(top: 16.0, right: 8.0),
        child: BarChart(
          BarChartData(
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) =>
                    Theme.of(context).colorScheme.surfaceContainer,
                tooltipBorder: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.1),
                ),
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final entry = widget.dailyData[groupIndex];
                  final String dateStr = isMonthlyFormatted
                      ? DateFormat('MMMM yyyy').format(entry.key)
                      : DateFormat('MMM d, yyyy').format(entry.key);
                  return BarTooltipItem(
                    '$dateStr\n',
                    TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    children: <TextSpan>[
                      TextSpan(
                        text: '₹${rod.toY.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  );
                },
              ),
              touchCallback: (FlTouchEvent event, barTouchResponse) {
                // Ignore scroll/pan gestures to keep list scrolling buttery smooth
                if (event is FlPanStartEvent ||
                    event is FlPanUpdateEvent ||
                    event is FlPanEndEvent) {
                  return;
                }

                final int newIndex;
                if (!event.isInterestedForInteractions ||
                    barTouchResponse == null ||
                    barTouchResponse.spot == null) {
                  newIndex = -1;
                } else {
                  newIndex = barTouchResponse.spot!.touchedBarGroupIndex;
                }

                if (touchedBarIndex != newIndex) {
                  setState(() {
                    touchedBarIndex = newIndex;
                  });
                }
              },
            ),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    final int idx = value.toInt();
                    if (idx < 0 || idx >= widget.dailyData.length) {
                      return const SizedBox();
                    }

                    bool shouldShowLabel = false;
                    final totalPoints = widget.dailyData.length;
                    if (totalPoints <= 8) {
                      shouldShowLabel = true;
                    } else if (totalPoints <= 16) {
                      shouldShowLabel = idx % 2 == 0;
                    } else {
                      shouldShowLabel = idx % (totalPoints ~/ 5) == 0;
                    }

                    if (!shouldShowLabel) {
                      return const SizedBox();
                    }

                    final entry = widget.dailyData[idx];
                    final text = isMonthlyFormatted
                        ? DateFormat('MMM').format(entry.key)
                        : DateFormat('d/M').format(entry.key);

                    return SideTitleWidget(
                      meta: meta,
                      child: Text(
                        text,
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  },
                  reservedSize: 22,
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 42,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    if (value == 0) return const SizedBox();
                    String text = '';
                    if (value >= 100000) {
                      text = '${(value / 100000).toStringAsFixed(1)}L';
                    } else if (value >= 1000) {
                      text = '${(value / 1000).toStringAsFixed(0)}k';
                    } else {
                      text = value.toStringAsFixed(0);
                    }
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(
                        text,
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                          fontSize: 9,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: yAxisMax / 4 > 0 ? yAxisMax / 4 : 1.0,
              getDrawingHorizontalLine: (value) => FlLine(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.05),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(widget.dailyData.length, (i) {
              final entry = widget.dailyData[i];
              final bool isAnyTouched = touchedBarIndex != -1;
              final bool isTouched = i == touchedBarIndex;

              final Color barColor = isAnyTouched
                  ? (isTouched
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.3))
                  : Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.85);

              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: entry.value,
                    color: barColor,
                    width: widget.dailyData.length > 20 ? 6 : 12,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: yAxisMax,
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.02),
                    ),
                  ),
                ],
              );
            }),
            maxY: yAxisMax,
          ),
        ),
      ),
    );
  }
}
