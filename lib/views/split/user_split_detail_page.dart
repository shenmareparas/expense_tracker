import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/profile.dart';
import '../../models/split_expense.dart';
import '../../utils/date_formatter.dart';
import '../../utils/haptics.dart';
import '../../viewmodels/split_viewmodel.dart';
import '../../viewmodels/transaction_viewmodel.dart';
import 'add_split_page.dart';

/// Detail page displaying shared split expenses with a specific partner.
class UserSplitDetailPage extends StatelessWidget {
  final ProfileModel partner;

  const UserSplitDetailPage({super.key, required this.partner});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<SplitViewModel>(
      builder: (context, splitVM, child) {
        final currentUserId = splitVM.currentUserId;

        // Filter splits involving this partner and current user
        final partnerSplits = splitVM.splitExpenses.where((s) {
          return (s.payerId == partner.id && s.borrowerId == currentUserId) ||
              (s.borrowerId == partner.id && s.payerId == currentUserId);
        }).toList();

        // Calculate net balance with this partner
        double sumOwedToUser = 0.0;
        double sumUserOwes = 0.0;

        for (final s in partnerSplits) {
          if (s.status == 'pending') {
            if (s.payerId == currentUserId) {
              sumOwedToUser += s.amount;
            } else if (s.borrowerId == currentUserId) {
              sumUserOwes += s.amount;
            }
          }
        }

        final netBalance = sumOwedToUser - sumUserOwes;
        final isOwed = netBalance > 0;
        final isSettledUp = netBalance == 0;

        return Scaffold(
          appBar: AppBar(
            title: Text(partner.displayName),
            elevation: 0,
            backgroundColor: Colors.transparent,
            actions: [
              IconButton(
                icon: Icon(
                  splitVM.isFriendHidden(partner.id)
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: splitVM.isFriendHidden(partner.id)
                      ? Colors.orange
                      : null,
                ),
                tooltip: splitVM.isFriendHidden(partner.id)
                    ? 'Unhide Friend'
                    : 'Hide Friend',
                onPressed: () async {
                  AppHaptics.lightImpact(context);
                  await splitVM.toggleHideFriend(partner.id);
                  if (context.mounted) {
                    final isHidden = splitVM.isFriendHidden(partner.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isHidden
                              ? '${partner.displayName} hidden from split list'
                              : '${partner.displayName} is now visible',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          extendBodyBehindAppBar: true,
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [Colors.black, Colors.black]
                    : [const Color(0xFFEEF2FF), Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 110, 16, 24),
              children: [
                // ── Partner Header Summary Card ──────────────────────────────
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.1),
                    ),
                  ),
                  color: theme.colorScheme.surface.withValues(
                    alpha: isDark ? 0.3 : 0.85,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: theme.colorScheme.primary
                                  .withValues(alpha: 0.15),
                              child: Text(
                                partner.displayName.isNotEmpty
                                    ? partner.displayName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    partner.displayName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    partner.email,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  if (isSettledUp)
                                    Text(
                                      'You and ${partner.displayName} are settled up',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey,
                                      ),
                                    )
                                  else
                                    Text(
                                      isOwed
                                          ? 'owes you ₹${netBalance.abs().toStringAsFixed(2)}'
                                          : 'you owe ₹${netBalance.abs().toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: isOwed
                                            ? Colors.green.shade600
                                            : Colors.red.shade600,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Action Buttons Row (Settle Up & Add Expense)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: (!isSettledUp)
                                    ? () async {
                                        AppHaptics.mediumImpact(context);
                                        final txVM =
                                            Provider.of<TransactionViewModel>(
                                          context,
                                          listen: false,
                                        );
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (dialogCtx) => AlertDialog(
                                            icon: Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: theme.colorScheme.primary
                                                    .withValues(alpha: 0.1),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.payments_rounded,
                                                color:
                                                    theme.colorScheme.primary,
                                                size: 32,
                                              ),
                                            ),
                                            title: Text(
                                              'Settle Up with ${partner.displayName}',
                                              style: theme.textTheme.titleLarge
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                            content: Text(
                                              'Record a settlement of ₹${netBalance.abs().toStringAsFixed(2)} with ${partner.displayName}? This will mark all pending split expenses as settled.',
                                              textAlign: TextAlign.center,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(28),
                                            ),
                                            actionsAlignment:
                                                MainAxisAlignment.spaceEvenly,
                                            actions: [
                                              OutlinedButton(
                                                onPressed: () => Navigator.pop(
                                                  dialogCtx,
                                                  false,
                                                ),
                                                child: const Text('Cancel'),
                                              ),
                                              FilledButton(
                                                onPressed: () => Navigator.pop(
                                                  dialogCtx,
                                                  true,
                                                ),
                                                child: const Text('Settle Up'),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirm == true) {
                                          await splitVM.settleUpWithPartner(
                                            partner.id,
                                            partnerName: partner.displayName,
                                            transactionVM: txVM,
                                          );
                                        }
                                      }
                                    : null,
                                icon: const Icon(
                                  Icons.check_circle_outline,
                                  size: 18,
                                ),
                                label: const Text('Settle Up'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () async {
                                  AppHaptics.lightImpact(context);
                                  final res = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          AddSplitPage(initialPartner: partner),
                                    ),
                                  );
                                  if (res == true && context.mounted) {
                                    splitVM.loadSplitExpenses();
                                    Provider.of<TransactionViewModel>(
                                      context,
                                      listen: false,
                                    ).loadTransactions();
                                  }
                                },
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add Expense'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
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
                const SizedBox(height: 20),

                // ── Expenses List Header ────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Shared Expenses',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${partnerSplits.length} entries',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Shared Expenses List ─────────────────────────────────────
                if (partnerSplits.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 48,
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No shared expenses yet',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...partnerSplits.map((split) {
                    return _buildSplitTile(context, split, splitVM);
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSplitTile(
    BuildContext context,
    SplitExpenseModel split,
    SplitViewModel splitVM,
  ) {
    final theme = Theme.of(context);
    final isPayer = split.payerId == splitVM.currentUserId;
    final partnerName = isPayer ? split.displayBorrower : split.displayPayer;
    final isSettled = split.status == 'settled';

    return Dismissible(
      key: Key(split.id),
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
            final dialogTheme = Theme.of(context);
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
                'Delete Split Expense',
                style: dialogTheme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: const Text(
                'Are you sure you want to delete this split expense? This action cannot be undone.',
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
                      color: dialogTheme.colorScheme.outline.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: dialogTheme.colorScheme.onSurface),
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
        await splitVM.deleteSplitExpense(split.id);
      },
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        clipBehavior: Clip.antiAlias,
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
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
                  ? Icons.check_circle_outline
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
                isPayer
                    ? 'You paid ₹${split.totalAmount.toStringAsFixed(2)}'
                    : '$partnerName paid ₹${split.totalAmount.toStringAsFixed(2)}',
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
                isSettled ? 'settled' : (isPayer ? 'you lent' : 'you borrowed'),
                style: TextStyle(
                  fontSize: 11,
                  color: isSettled
                      ? Colors.grey
                      : (isPayer ? Colors.green.shade700 : Colors.red.shade700),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '₹${split.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isSettled
                      ? Colors.grey
                      : (isPayer ? Colors.green.shade600 : Colors.red.shade600),
                  decoration: isSettled ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
