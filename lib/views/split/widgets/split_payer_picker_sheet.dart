import 'package:material_ui/material_ui.dart';

import '../../../models/profile.dart';
import '../../../utils/haptics.dart';

/// Modal bottom sheet for selecting who paid for a split expense.
class SplitPayerPickerSheet extends StatelessWidget {
  final List<ProfileModel> selectedPartners;
  final String currentUserName;
  final bool iPaid;
  final ProfileModel? payerPartner;
  final Widget Function({
    required BuildContext context,
    required String name,
    double radius,
    bool isCurrentUser,
  })
  avatarBuilder;
  final void Function(bool iPaid, ProfileModel? payerPartner) onSelectPayer;

  const SplitPayerPickerSheet({
    super.key,
    required this.selectedPartners,
    required this.currentUserName,
    required this.iPaid,
    required this.payerPartner,
    required this.avatarBuilder,
    required this.onSelectPayer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A0A0A) : theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(
            alpha: isDark ? 0.15 : 0.08,
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: isDark ? 0.3 : 0.6,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.payments_rounded,
                          color: theme.colorScheme.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Choose Payer',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: theme.colorScheme.onSurface,
                      ),
                      onPressed: () => Navigator.pop(context),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...selectedPartners.map((partner) {
                        final isSelected =
                            !iPaid && payerPartner?.id == partner.id;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 4,
                          ),
                          leading: avatarBuilder(
                            context: context,
                            name: partner.displayName,
                            radius: 18,
                          ),
                          title: Text(
                            partner.displayName,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(
                                  Icons.check_circle_rounded,
                                  color: theme.colorScheme.primary,
                                )
                              : null,
                          onTap: () {
                            AppHaptics.selectionClick(context);
                            onSelectPayer(false, partner);
                            Navigator.pop(context);
                          },
                        );
                      }),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        leading: avatarBuilder(
                          context: context,
                          name: currentUserName,
                          radius: 18,
                          isCurrentUser: true,
                        ),
                        title: Text(
                          '$currentUserName (You)',
                          style: TextStyle(
                            fontWeight: iPaid
                                ? FontWeight.bold
                                : FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                        trailing: iPaid
                            ? Icon(
                                Icons.check_circle_rounded,
                                color: theme.colorScheme.primary,
                              )
                            : null,
                        onTap: () {
                          AppHaptics.selectionClick(context);
                          onSelectPayer(true, null);
                          Navigator.pop(context);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
