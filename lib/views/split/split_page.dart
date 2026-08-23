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
            await splitVM.loadSplitExpenses(forceRefresh: true);
            await splitVM.loadProfiles(forceRefresh: true);
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
                  Row(
                    children: [
                      Text(
                        'Friends',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${visiblePartners.length} visible)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => _showAddFriendDialog(context, splitVM),
                    icon: const Icon(Icons.person_add_outlined, size: 16),
                    label: const Text('Add Friend'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      visualDensity: VisualDensity.compact,
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
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.5),
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
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _showHiddenFriends
                                ? 'Hide hidden friends (${hiddenPartners.length})'
                                : 'Show hidden friends (${hiddenPartners.length})',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.5),
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
    final totalOwed = splitVM.totalOwedToUser;
    final totalOwes = splitVM.totalUserOwes;
    final isOwed = net > 0;
    final isSettledUp = net == 0;
    final totalVolume = totalOwed + totalOwes;
    final owedRatio = totalVolume > 0
        ? (totalOwed / totalVolume).clamp(0.0, 1.0)
        : 0.5;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF1E2038), // Deep premium indigo/navy
                  const Color(0xFF0F101C), // Midnight obsidian
                ]
              : [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.85),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: isDark
            ? Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                width: 1.5,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? theme.colorScheme.primary.withValues(alpha: 0.15)
                : theme.colorScheme.primary.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: "Overall Balance" + Status Tag
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Overall Balance',
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
                      isSettledUp
                          ? Icons.check_circle_outline
                          : (isOwed
                                ? Icons.arrow_downward
                                : Icons.arrow_upward),
                      color: isSettledUp
                          ? Colors.white.withValues(alpha: 0.8)
                          : (isOwed
                                ? Colors.greenAccent
                                : const Color(0xFFFF8A80)),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isSettledUp
                          ? 'Settled'
                          : (isOwed ? 'You are owed' : 'You owe'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Rolling/Tweening Amount Text (matches Analytics card animation)
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: net.abs()),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              final prefix = isSettledUp ? '' : (isOwed ? '+' : '-');
              return Text(
                '$prefix₹${value.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              );
            },
          ),
          const SizedBox(height: 4),

          Text(
            isSettledUp
                ? 'All shared expenses are settled up'
                : (isOwed
                      ? 'Total amount friends owe you'
                      : 'Total amount you owe to friends'),
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),

          // Visual Split Balance Ratio Bar (when dues exist)
          if (totalVolume > 0) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                height: 6,
                width: double.infinity,
                color: Colors.white.withValues(alpha: 0.12),
                child: Row(
                  children: [
                    if (totalOwed > 0)
                      Expanded(
                        flex: (owedRatio * 100).round().clamp(1, 99),
                        child: Container(color: Colors.greenAccent),
                      ),
                    if (totalOwes > 0)
                      Expanded(
                        flex: ((1.0 - owedRatio) * 100).round().clamp(1, 99),
                        child: Container(color: const Color(0xFFFF8A80)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            const SizedBox(height: 20),
          ],

          // Sub-Cards: Breakdown for "You are owed" and "You owe"
          Row(
            children: [
              // You are owed Sub-Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_downward,
                          size: 14,
                          color: Colors.greenAccent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'You are owed',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹${totalOwed.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // You owe Sub-Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF8A80).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_upward,
                          size: 14,
                          color: Color(0xFFFF8A80),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'You owe',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹${totalOwes.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
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
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'No friends registered yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When other users register in the app, they will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 6,
          ),
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
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
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

  void _showAddFriendDialog(BuildContext context, SplitViewModel splitVM) {
    AppHaptics.selectionClick(context);
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        final theme = Theme.of(dialogCtx);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          icon: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_add_rounded,
              color: theme.colorScheme.primary,
              size: 32,
            ),
          ),
          title: Text(
            'Add Friend',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Add someone to split expenses with, even if they are not on the app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Friend Name',
                    hintText: 'e.g. Alex Smith',
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    filled: true,
                    fillColor: theme.colorScheme.onSurface.withValues(
                      alpha: 0.05,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  AppHaptics.mediumImpact(context);
                  final name = nameController.text.trim();
                  await splitVM.addCustomProfile(name: name);
                  if (dialogCtx.mounted) {
                    Navigator.pop(dialogCtx);
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$name added to friends'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
              child: const Text('Add Friend'),
            ),
          ],
        );
      },
    );
  }
}
