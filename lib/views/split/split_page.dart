import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/profile.dart';
import '../../utils/haptics.dart';
import '../../viewmodels/split_viewmodel.dart';
import 'user_split_detail_page.dart';

/// Overview tab displaying a Friends list grouped by user.
class SplitPage extends StatefulWidget {
  final ScrollController? scrollController;
  const SplitPage({super.key, this.scrollController});

  @override
  State<SplitPage> createState() => _SplitPageState();
}

class _SplitPageState extends State<SplitPage> {
  late final ScrollController _scrollController;
  bool _showHiddenFriends = false;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final splitVM = Provider.of<SplitViewModel>(context, listen: false);
      splitVM.loadSplitExpenses();
      splitVM.loadProfiles();
      splitVM.loadHiddenFriends();
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

        final currentUserId = splitVM.currentUserId;
        // Filter out current user from profiles list
        final partnerProfiles = splitVM.profiles
            .where((p) => p.id != currentUserId)
            .toList();

        final visiblePartners = partnerProfiles
            .where((p) => !splitVM.isFriendHidden(p.id))
            .toList();
        final hiddenPartners = partnerProfiles
            .where((p) => splitVM.isFriendHidden(p.id))
            .toList();

        return RefreshIndicator(
          onRefresh: () async {
            await splitVM.loadSplitExpenses();
            await splitVM.loadProfiles();
            await splitVM.loadHiddenFriends();
          },
          child: ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            children: [
              // Overall Summary Card
              _buildSummaryCard(context, splitVM),
              const SizedBox(height: 24),

              // Title Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Friends',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    '${visiblePartners.length} visible',
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

              // List of Visible Friends / Partners
              if (visiblePartners.isEmpty && hiddenPartners.isEmpty)
                _buildEmptyState(context)
              else if (visiblePartners.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                    child: Text(
                      'All friends are hidden',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                )
              else
                ...visiblePartners.map((partner) {
                  return _buildPartnerTile(context, partner, splitVM);
                }),

              // ── Show / Collapse Hidden Friends Section ─────────────────────
              if (hiddenPartners.isNotEmpty) ...[
                const SizedBox(height: 16),
                Center(
                  child: InkWell(
                    onTap: () {
                      AppHaptics.selectionClick(context);
                      setState(() {
                        _showHiddenFriends = !_showHiddenFriends;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _showHiddenFriends
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _showHiddenFriends
                                ? 'Hide hidden friends (${hiddenPartners.length})'
                                : 'Show hidden friends (${hiddenPartners.length})',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_showHiddenFriends) ...[
                  const SizedBox(height: 8),
                  ...hiddenPartners.map((partner) {
                    return _buildPartnerTile(
                      context,
                      partner,
                      splitVM,
                      isHidden: true,
                    );
                  }),
                ],
              ],

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
    final isOwed = net > 0;
    final isSettledUp = net == 0;

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
                      'Overall Balance',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (isSettledUp)
                      const Text(
                        'You are all settled up!',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      )
                    else ...[
                      Text(
                        '${isOwed ? '+' : '-'}₹${net.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isOwed ? Colors.green.shade600 : Colors.red.shade600,
                        ),
                      ),
                      Text(
                        isOwed ? 'Overall, you are owed' : 'Overall, you owe',
                        style: TextStyle(
                          fontSize: 11,
                          color: isOwed ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSettledUp
                        ? Colors.grey.withValues(alpha: 0.1)
                        : (isOwed ? Colors.green : Colors.red)
                            .withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSettledUp
                        ? Icons.check_circle_outline
                        : (isOwed ? Icons.call_received : Icons.call_made),
                    color: isSettledUp
                        ? Colors.grey
                        : (isOwed ? Colors.green : Colors.red),
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
                      const Icon(Icons.arrow_downward, size: 16, color: Colors.green),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'You are owed',
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
                      const Icon(Icons.arrow_upward, size: 16, color: Colors.red),
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
              Icons.group_off_outlined,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'No friends registered yet',
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
              'When other users register in the app, they will appear here.',
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

  Widget _buildPartnerTile(
    BuildContext context,
    ProfileModel partner,
    SplitViewModel splitVM, {
    bool isHidden = false,
  }) {
    final theme = Theme.of(context);
    final currentUserId = splitVM.currentUserId;

    // Filter splits involving this partner
    final partnerSplits = splitVM.splitExpenses.where((s) {
      return (s.payerId == partner.id && s.borrowerId == currentUserId) ||
          (s.borrowerId == partner.id && s.payerId == currentUserId);
    }).toList();

    // Calculate net balance specifically with this partner
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

    final net = sumOwedToUser - sumUserOwes;
    final isOwed = net > 0;
    final isSettledUp = net == 0;

    return Opacity(
      opacity: isHidden ? 0.65 : 1.0,
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          onTap: () {
            AppHaptics.selectionClick(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserSplitDetailPage(partner: partner),
              ),
            );
          },
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            child: Text(
              partner.displayName.isNotEmpty
                  ? partner.displayName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  partner.displayName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isHidden) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.visibility_off_outlined,
                  size: 16,
                  color: Colors.orange,
                ),
              ],
            ],
          ),
          subtitle: Text(
            partnerSplits.isEmpty
                ? 'No shared expenses'
                : '${partnerSplits.length} shared ${partnerSplits.length == 1 ? 'expense' : 'expenses'}',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isSettledUp)
                    const Text(
                      'settled up',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    )
                  else ...[
                    Text(
                      isOwed ? 'owes you' : 'you owe',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      '₹${net.abs().toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isOwed
                            ? Colors.green.shade600
                            : Colors.red.shade600,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
