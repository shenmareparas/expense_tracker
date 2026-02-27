import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../viewmodels/transaction_viewmodel.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  int touchedIndex = -1;

  final List<Color> _chartColors = [
    const Color(0xFF60A5FA), // Blue 400
    const Color(0xFFF87171), // Red 400
    const Color(0xFF34D399), // Emerald 400
    const Color(0xFFFBBF24), // Amber 400
    const Color(0xFFA78BFA), // Violet 400
    const Color(0xFF2DD4BF), // Teal 400
    const Color(0xFFF472B6), // Pink 400
    const Color(0xFF818CF8), // Indigo 400
    const Color(0xFFFB923C), // Orange 400
    const Color(0xFF22D3EE), // Cyan 400
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<TransactionViewModel>(
        context,
        listen: false,
      ).loadAnalyticsSnapshot();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.isLoading && viewModel.transactions.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (viewModel.errorMessage != null && viewModel.transactions.isEmpty) {
          return Center(child: Text('Error: ${viewModel.errorMessage}'));
        }

        if (viewModel.transactions.isEmpty) {
          return const Center(child: Text('No transactions to analyze.'));
        }

        final totalIncome = viewModel.totalIncome;
        final totalExpense = viewModel.totalExpense;
        final netBalance = viewModel.totalBalance;
        final sortedCategories = viewModel.sortedExpensesByCategory;

        return RefreshIndicator(
          onRefresh: () async {
            await viewModel.loadTransactions(forceRefresh: true);
            await viewModel.loadAnalyticsSnapshot(forceRefresh: true);
          },
          child: ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              _buildSummaryRow(context, totalIncome, totalExpense, netBalance),
              const SizedBox(height: 32),

              if (totalExpense > 0) ...[
                const Text(
                  'Expense Breakdown',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 250,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            touchCallback:
                                (FlTouchEvent event, pieTouchResponse) {
                                  setState(() {
                                    if (!event.isInterestedForInteractions ||
                                        pieTouchResponse == null ||
                                        pieTouchResponse.touchedSection ==
                                            null) {
                                      touchedIndex = -1;
                                      return;
                                    }
                                    touchedIndex = pieTouchResponse
                                        .touchedSection!
                                        .touchedSectionIndex;
                                  });
                                },
                          ),
                          borderData: FlBorderData(show: false),
                          sectionsSpace: 2,
                          centerSpaceRadius: 70,
                          sections: _showingSections(
                            context,
                            sortedCategories,
                            totalExpense,
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          Text(
                            '₹${totalExpense.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                ...List.generate(sortedCategories.length, (i) {
                  final entry = sortedCategories[i];
                  final color = _chartColors[i % _chartColors.length];
                  final percentage = (entry.value / totalExpense) * 100;
                  final isTouched = i == touchedIndex;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 16.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isTouched
                            ? color
                            : Theme.of(
                                context,
                              ).colorScheme.outline.withValues(alpha: 0.1),
                        width: isTouched ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).shadowColor.withValues(alpha: 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.category, color: color),
                      ),
                      title: Text(
                        entry.key,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      trailing: Text(
                        '₹${entry.value.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                }),
              ] else ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'No expenses to analyze for the selected period.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(
    BuildContext context,
    double income,
    double expense,
    double balance,
  ) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 8),
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
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.account_balance_wallet,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '₹${balance.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                context,
                'Income',
                income,
                Icons.arrow_downward,
                Colors.green.shade400,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSummaryCard(
                context,
                'Expense',
                expense,
                Icons.arrow_upward,
                Colors.red.shade400,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    double amount,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _showingSections(
    BuildContext context,
    List<MapEntry<String, double>> categories,
    double totalExpense,
  ) {
    return List.generate(categories.length, (i) {
      final isTouched = i == touchedIndex;
      final fontSize = isTouched ? 16.0 : 0.0;
      final radius = isTouched ? 60.0 : 50.0;
      final color = _chartColors[i % _chartColors.length];

      final entry = categories[i];
      final percentage = (entry.value / totalExpense) * 100;

      return PieChartSectionData(
        color: color,
        value: entry.value,
        title: '${percentage.toStringAsFixed(0)}%',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: const [Shadow(color: Colors.black26, blurRadius: 2)],
        ),
        badgeWidget: isTouched
            ? Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 4),
                  ],
                ),
                child: Icon(Icons.category, size: 20, color: color),
              )
            : null,
        badgePositionPercentageOffset: .98,
      );
    });
  }
}
