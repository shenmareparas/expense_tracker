import 'package:material_ui/material_ui.dart';

import '../../../utils/haptics.dart';

import 'package:provider/provider.dart';

import '../../../models/profile.dart';
import '../../../models/split_expense.dart';
import '../../../models/transaction.dart';
import '../../../viewmodels/split_viewmodel.dart';
import '../../../viewmodels/transaction_viewmodel.dart';
import '../../../views/transaction/add_transaction_page.dart';
import '../../split/add_split_page.dart';
import '../../../utils/date_formatter.dart';

/// Displays the list of transactions with scroll-to-load-more pagination.
class TransactionListView extends StatefulWidget {
  final ScrollController? scrollController;
  const TransactionListView({super.key, this.scrollController});

  @override
  State<TransactionListView> createState() => _TransactionListViewState();
}

class _TransactionListViewState extends State<TransactionListView> {
  late final ScrollController _scrollController;

  List<TransactionModel>? _cachedPersonalTxs;
  List<SplitExpenseModel>? _cachedSplitExpenses;
  int _cachedSplitCount = -1;
  String? _cachedFilterType;
  List<String>? _cachedFilterCategories;
  String? _cachedPaymentMethod;
  DateTime? _cachedStartDate;
  DateTime? _cachedEndDate;
  String? _cachedSearchQuery;
  List<TransactionModel>? _cachedMergedTransactions;

  List<TransactionModel> _resolveMergedTransactions(
    TransactionViewModel viewModel,
    SplitViewModel splitViewModel,
  ) {
    final personalTxs = viewModel.filteredTransactions;
    final splits = splitViewModel.splitExpenses;
    if (_cachedMergedTransactions != null &&
        identical(_cachedPersonalTxs, personalTxs) &&
        identical(_cachedSplitExpenses, splits) &&
        _cachedSplitCount == splits.length &&
        _cachedFilterType == viewModel.filterType &&
        identical(_cachedFilterCategories, viewModel.filterCategories) &&
        _cachedPaymentMethod == viewModel.filterPaymentMethod &&
        _cachedStartDate == viewModel.filterStartDate &&
        _cachedEndDate == viewModel.filterEndDate &&
        _cachedSearchQuery == viewModel.searchQuery) {
      return _cachedMergedTransactions!;
    }

    final borrowerSplitTxs = splitViewModel.getBorrowerSplitTransactions(
      type: viewModel.filterType,
      categories: viewModel.filterCategories,
      paymentMethod: viewModel.filterPaymentMethod,
      startDate: viewModel.filterStartDate,
      endDate: viewModel.filterEndDate,
      searchQuery: viewModel.searchQuery,
      existingTransactions: personalTxs,
    );

    final merged = <TransactionModel>[...personalTxs, ...borrowerSplitTxs]
      ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));

    _cachedPersonalTxs = personalTxs;
    _cachedSplitExpenses = splits;
    _cachedSplitCount = splits.length;
    _cachedFilterType = viewModel.filterType;
    _cachedFilterCategories = viewModel.filterCategories;
    _cachedPaymentMethod = viewModel.filterPaymentMethod;
    _cachedStartDate = viewModel.filterStartDate;
    _cachedEndDate = viewModel.filterEndDate;
    _cachedSearchQuery = viewModel.searchQuery;
    _cachedMergedTransactions = merged;
    return merged;
  }

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
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
    return Consumer2<TransactionViewModel, SplitViewModel>(
      builder: (context, viewModel, splitViewModel, child) {
        if (viewModel.isLoading && viewModel.transactions.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (viewModel.errorMessage != null && viewModel.transactions.isEmpty) {
          return Center(child: Text('Error: ${viewModel.errorMessage}'));
        }

        final transactions = _resolveMergedTransactions(
          viewModel,
          splitViewModel,
        );

        if (transactions.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async {
              await viewModel.loadTransactions(forceRefresh: true);
              await splitViewModel.loadSplitExpenses(forceRefresh: true);
            },
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
          onRefresh: () async {
            await viewModel.loadTransactions(forceRefresh: true);
            await splitViewModel.loadSplitExpenses(forceRefresh: true);
          },
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
                splitViewModel,
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
              Icons.receipt_long,
              size: 80,
              color: Theme.of(context).colorScheme.primary
                  .withValues(alpha: 0.2),
            ),
            const SizedBox(height: 24),
            Text(
              'No transactions yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface
                    .withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to add your first expense or income.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface
                    .withValues(alpha: 0.5),
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
    SplitViewModel splitViewModel,
  ) {
    final isIncome = t.type == 'income';
    final isBorrowerSplit = t.id.startsWith('split_borrower_');
    final isPayerSplit =
        (t.description != null &&
            t.description!.toLowerCase().startsWith('split:')) ||
        t.paymentMethod == 'split';
    final isSplit = isBorrowerSplit || isPayerSplit;
    SplitExpenseModel? borrowerSplit;
    if (isBorrowerSplit) {
      final splitId = t.id.substring('split_borrower_'.length);
      borrowerSplit = splitViewModel.splitExpenses
          .cast<SplitExpenseModel?>()
          .firstWhere((s) => s != null && s.id == splitId, orElse: () => null);
    }
    final isSettled = borrowerSplit?.status == 'settled';
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          builder: (context) {
            final theme = Theme.of(context);
            return AlertDialog(
              icon: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  color: Colors.red,
                  size: 32,
                ),
              ),
              title: Text(
                isBorrowerSplit ? 'Delete Split Expense' : 'Delete Transaction',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                isBorrowerSplit
                    ? 'Are you sure you want to delete this shared split expense? This action cannot be undone.'
                    : 'Are you sure you want to delete this transaction? This action cannot be undone.',
                textAlign: TextAlign.center,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              actionsAlignment: MainAxisAlignment.spaceEvenly,
              actions: [
                OutlinedButton(
                  onPressed: () {
                    AppHaptics.selectionClick(context);
                    Navigator.pop(context, false);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    side: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
                ),
                FilledButton(
                  onPressed: () {
                    AppHaptics.vibrate(context);
                    Navigator.pop(context, true);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.1),
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Delete',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (_) async {
        final splitVM = context.read<SplitViewModel>();
        if (isBorrowerSplit) {
          final splitId = t.id.substring('split_borrower_'.length);
          await splitVM.deleteSplitExpense(splitId, transactionVM: viewModel);
        } else {
          await viewModel.deleteTransaction(t.id, splitVM: splitVM);
        }
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
            AppHaptics.lightImpact(context);
            final splitVM = context.read<SplitViewModel>();

            if (isBorrowerSplit) {
              final matchingSplit = borrowerSplit;
              if (matchingSplit != null) {
                final isUserPayer =
                    matchingSplit.payerId == splitVM.currentUserId;
                final partnerId = isUserPayer
                    ? matchingSplit.borrowerId
                    : matchingSplit.payerId;
                ProfileModel? partner;
                try {
                  partner = splitVM.profiles.firstWhere(
                    (p) => p.id == partnerId,
                  );
                } catch (_) {
                  partner = ProfileModel(
                    id: partnerId,
                    name: isUserPayer
                        ? matchingSplit.borrowerName
                        : matchingSplit.payerName,
                    email:
                        (isUserPayer
                            ? matchingSplit.borrowerEmail
                            : matchingSplit.payerEmail) ??
                        '',
                  );
                }

                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddSplitPage(
                      initialPartner: partner,
                      splitExpense: matchingSplit,
                    ),
                  ),
                );

                if (result == true && context.mounted) {
                  viewModel.loadTransactions();
                  splitVM.loadSplitExpenses();
                }
              }
              return;
            }

            if (t.description != null &&
                t.description!.toLowerCase().startsWith('split:')) {
              final splitDesc = SplitViewModel.extractSplitDescription(
                t.description!,
              );
              final matchingSplit = splitVM.splitExpenses
                  .cast<SplitExpenseModel?>()
                  .firstWhere(
                    (s) =>
                        s != null &&
                        (s.description.trim().toLowerCase() ==
                                splitDesc.toLowerCase() ||
                            (t.description?.toLowerCase().contains(
                                  s.description.toLowerCase(),
                                ) ??
                                false)) &&
                        (s.expenseDate
                                    .difference(t.transactionDate)
                                    .inMinutes
                                    .abs() <
                                120 ||
                            (s.totalAmount - t.amount).abs() < 0.05),
                    orElse: () => null,
                  );

              if (matchingSplit != null) {
                final isUserPayer =
                    matchingSplit.payerId == splitVM.currentUserId;
                final partnerId = isUserPayer
                    ? matchingSplit.borrowerId
                    : matchingSplit.payerId;
                ProfileModel? partner;
                try {
                  partner = splitVM.profiles.firstWhere(
                    (p) => p.id == partnerId,
                  );
                } catch (_) {
                  partner = ProfileModel(
                    id: partnerId,
                    name: isUserPayer
                        ? matchingSplit.borrowerName
                        : matchingSplit.payerName,
                    email:
                        (isUserPayer
                            ? matchingSplit.borrowerEmail
                            : matchingSplit.payerEmail) ??
                        '',
                  );
                }

                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddSplitPage(
                      initialPartner: partner,
                      splitExpense: matchingSplit,
                    ),
                  ),
                );

                if (result == true && context.mounted) {
                  viewModel.loadTransactions();
                  splitVM.loadSplitExpenses();
                }
                return;
              }
            }

            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddTransactionPage(transaction: t),
              ),
            );
            if (result == true) {
              if (context.mounted) {
                viewModel.loadTransactions();
                splitVM.loadSplitExpenses();
              }
            }
          },
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isBorrowerSplit
                  ? (isSettled
                        ? Colors.grey.withValues(alpha: 0.12)
                        : (isDark
                              ? Colors.orange.withValues(alpha: 0.18)
                              : Colors.orange.withValues(alpha: 0.12)))
                  : (isIncome
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isBorrowerSplit
                  ? (isSettled
                        ? Icons.check_circle_outline_rounded
                        : Icons.call_split_rounded)
                  : isSplit
                  ? Icons.call_split_rounded
                  : (isIncome ? Icons.arrow_downward : Icons.arrow_upward),
              color: isBorrowerSplit
                  ? (isSettled
                        ? Colors.grey
                        : (isDark
                              ? Colors.orange.shade300
                              : Colors.orange.shade700))
                  : (isIncome ? Colors.green : Colors.red),
            ),
          ),
          title: Text(
            isBorrowerSplit
                ? _cleanBorrowerSplitTitle(
                    borrowerSplit?.description ?? t.description ?? '',
                    fallbackCategory: borrowerSplit?.category ?? t.category,
                  )
                : ((t.description != null && t.description!.isNotEmpty)
                      ? t.description!
                      : t.category),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              decoration: isSettled ? TextDecoration.lineThrough : null,
              color: isSettled ? Colors.grey : null,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isBorrowerSplit && borrowerSplit != null)
                Text(
                  isSettled
                      ? '${borrowerSplit.category} • Settled with ${borrowerSplit.displayPayer}'
                      : '${borrowerSplit.category} • ${borrowerSplit.displayPayer} paid ₹${borrowerSplit.totalAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              else if (t.description != null && t.description!.isNotEmpty)
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
          isThreeLine: true,
          trailing: isBorrowerSplit
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isSettled
                            ? Colors.grey.withValues(alpha: 0.15)
                            : (isDark
                                  ? Colors.orange.withValues(alpha: 0.2)
                                  : Colors.orange.withValues(alpha: 0.12)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isSettled ? 'Settled' : 'You Owe',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isSettled
                              ? Colors.grey
                              : (isDark
                                    ? Colors.orange.shade300
                                    : Colors.orange.shade800),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '₹${t.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: isSettled
                            ? Colors.grey
                            : (isDark
                                  ? Colors.orange.shade300
                                  : Colors.orange.shade700),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                )
              : Text(
                  '${isIncome ? '+' : '-'}₹${t.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: isIncome
                        ? Colors.green.shade600
                        : Colors.red.shade500,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
        ),
      ),
    );
  }

  String _cleanBorrowerSplitTitle(
    String raw, {
    required String fallbackCategory,
  }) {
    var title = raw.trim();
    final parenIdx = title.lastIndexOf('(');
    if (parenIdx != -1 && title.endsWith(')')) {
      title = title.substring(0, parenIdx).trim();
    }
    if (title.isEmpty) {
      title = fallbackCategory.trim();
    }
    if (!title.toLowerCase().startsWith('split:')) {
      title = 'Split: $title';
    }
    return title;
  }
}
