import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/transaction.dart';
import '../../../viewmodels/transaction_viewmodel.dart';
import '../../../views/transaction/add_transaction_page.dart';
import '../../../utils/date_formatter.dart';

/// Displays the list of transactions with scroll-to-load-more pagination.
class TransactionListView extends StatefulWidget {
  const TransactionListView({super.key});

  @override
  State<TransactionListView> createState() => _TransactionListViewState();
}

class _TransactionListViewState extends State<TransactionListView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final viewModel = Provider.of<TransactionViewModel>(
        context,
        listen: false,
      );
      if (!viewModel.isLoadingMore && viewModel.hasMore) {
        viewModel.loadMoreTransactions();
      }
    }
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

        final transactions = viewModel.filteredTransactions;
        if (transactions.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => viewModel.loadTransactions(forceRefresh: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              children: [
                const SizedBox(height: 120),
                _buildEmptyState(context),
                const SizedBox(height: 80),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => viewModel.loadTransactions(forceRefresh: true),
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16.0),
            // +1 for a trailing widget (loading indicator or spacing)
            itemCount: transactions.length + 1,
            itemBuilder: (context, index) {
              if (index == transactions.length) {
                // Bottom widget
                if (viewModel.isLoadingMore) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                // Extra space for FAB
                return const SizedBox(height: 80);
              }

              return _buildTransactionItem(
                context,
                transactions[index],
                viewModel,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 80,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 24),
            Text(
              'No transactions yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to add your first expense or income.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(
    BuildContext context,
    TransactionModel t,
    TransactionViewModel viewModel,
  ) {
    final isIncome = t.type == 'income';
    return Dismissible(
      key: Key(t.id),
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16.0),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Transaction'),
            content: const Text(
              'Are you sure you want to delete this transaction?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) async {
        await viewModel.deleteTransaction(t.id);
      },
      child: Card(
        clipBehavior: Clip.hardEdge,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddTransactionPage(transaction: t),
              ),
            );
            if (result == true) {
              if (context.mounted) {
                Provider.of<TransactionViewModel>(
                  context,
                  listen: false,
                ).loadTransactions();
              }
            }
          },
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isIncome
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isIncome ? Icons.arrow_downward : Icons.arrow_upward,
              color: isIncome ? Colors.green : Colors.red,
            ),
          ),
          title: Text(
            (t.description != null && t.description!.isNotEmpty)
                ? t.description!
                : t.category,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (t.description != null && t.description!.isNotEmpty)
                Text(
                  t.category,
                  style: const TextStyle(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              Text(
                DateFormatter.formatDateTime(t.transactionDate.toLocal()),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          isThreeLine: t.description != null && t.description!.isNotEmpty,
          trailing: Text(
            '${isIncome ? '+' : '-'}₹${t.amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: isIncome ? Colors.green.shade600 : Colors.red.shade500,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}
