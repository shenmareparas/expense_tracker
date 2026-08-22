import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/split_expense.dart';
import '../../utils/date_formatter.dart';
import '../../utils/haptics.dart';
import '../../viewmodels/split_viewmodel.dart';

/// Overview tab for managing Split Expenses between users.
class SplitPage extends StatefulWidget {
  final ScrollController? scrollController;
  const SplitPage({super.key, this.scrollController});

  @override
  State<SplitPage> createState() => _SplitPageState();
}

class _SplitPageState extends State<SplitPage> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final splitVM = Provider.of<SplitViewModel>(context, listen: false);
      splitVM.loadSplitExpenses();
      splitVM.loadProfiles();
    });
  }

  @override
  void dispose() {
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SplitViewModel>(
      builder: (context, splitVM, child) {
        if (splitVM.isLoading && splitVM.splitExpenses.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: () => splitVM.loadSplitExpenses(),
          child: ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            children: [
              // Summary Card (Net Balance)
              _buildSummaryCard(context, splitVM),
              const SizedBox(height: 24),

              // Title Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Split Expenses',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    '${splitVM.splitExpenses.length} records',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // List of Splits
              if (splitVM.splitExpenses.isEmpty)
                _buildEmptyState(context)
              else
                ...splitVM.splitExpenses.map((split) {
                  return _buildSplitTile(context, split, splitVM);
                }),

              const SizedBox(height: 80), // Padding for FAB
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(BuildContext context, SplitViewModel splitVM) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final net = splitVM.netBalance;
    final isOwed = net >= 0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      color: theme.colorScheme.surface.withValues(alpha: isDark ? 0.3 : 0.9),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Net Balance',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${isOwed ? '+' : '-'}₹${net.abs().toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isOwed ? Colors.green.shade600 : Colors.red.shade600,
                      ),
                    ),
                    Text(
                      isOwed ? 'You are overall owed' : 'You overall owe',
                      style: TextStyle(
                        fontSize: 11,
                        color: isOwed ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isOwed ? Colors.green : Colors.red)
                        .withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isOwed ? Icons.call_received : Icons.call_made,
                    color: isOwed ? Colors.green : Colors.red,
                    size: 28,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.arrow_downward, size: 16, color: Colors.green),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Owed to you',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          Text(
                            '₹${splitVM.totalOwedToUser.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.arrow_upward, size: 16, color: Colors.red),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'You owe',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          Text(
                            '₹${splitVM.totalUserOwes.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.red,
                            ),
                          ),
                        ],
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

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          children: [
            Icon(
              Icons.call_split_rounded,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'No split expenses yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to split a bill with registered Supabase users.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSplitTile(
    BuildContext context,
    SplitExpenseModel split,
    SplitViewModel splitVM,
  ) {
    final theme = Theme.of(context);
    final isPayer = split.payerId == splitVM.currentUserId;
    final partnerName = isPayer
        ? split.displayBorrower
        : split.displayPayer;
    final isSettled = split.status == 'settled';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isSettled
                ? Colors.grey.withValues(alpha: 0.15)
                : (isPayer
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1)),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isSettled
                ? Icons.check_circle
                : (isPayer ? Icons.arrow_downward : Icons.arrow_upward),
            color: isSettled
                ? Colors.grey
                : (isPayer ? Colors.green : Colors.red),
            size: 22,
          ),
        ),
        title: Text(
          split.description,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: isSettled ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isPayer ? 'You paid for $partnerName' : '$partnerName paid',
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              DateFormatter.formatDate(split.expenseDate.toLocal()),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isPayer ? '+' : '-'}₹${split.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isSettled
                    ? Colors.grey
                    : (isPayer ? Colors.green.shade600 : Colors.red.shade600),
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () {
                AppHaptics.selectionClick(context);
                splitVM.toggleSettled(split);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isSettled
                      ? Colors.grey.withValues(alpha: 0.15)
                      : Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isSettled ? 'Settled' : 'Mark Settled',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSettled ? Colors.grey : Colors.orange.shade800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
