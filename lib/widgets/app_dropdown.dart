import 'package:flutter/material.dart';

class AppDropdown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final String? hint;
  final String? label;
  final ValueChanged<T?>? onChanged;
  final IconData? prefixIcon;

  const AppDropdown({
    super.key,
    required this.value,
    required this.items,
    this.hint,
    this.label,
    this.onChanged,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Ensure if value is non-null and not present in items, it is dynamically prepended so DropdownButton never crashes
    final hasValue = value == null || items.any((item) => item.value == value);
    final effectiveItems = List<DropdownMenuItem<T>>.from(items);
    if (!hasValue && value != null) {
      effectiveItems.insert(
        0,
        DropdownMenuItem<T>(
          value: value,
          child: Text(value.toString()),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              label!,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: theme.colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              if (prefixIcon != null) ...[
                Icon(prefixIcon, color: theme.colorScheme.primary, size: 22),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<T>(
                    value: value,
                    items: effectiveItems,
                    onChanged: onChanged,
                    hint: hint != null ? Text(hint!) : null,
                    isExpanded: true,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    dropdownColor: isDark
                        ? const Color(0xFF1A1A1A)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    underline: const SizedBox(),
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AppDropdownButton<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  const AppDropdownButton({
    super.key,
    required this.value,
    required this.items,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(12);

    final hasValue = items.any((item) => item.value == value);
    final effectiveItems = items.map((item) {
      return DropdownMenuItem<T>(
        value: item.value,
        child: DefaultTextStyle.merge(
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          child: item.child,
        ),
      );
    }).toList();

    if (!hasValue) {
      effectiveItems.insert(
        0,
        DropdownMenuItem<T>(
          value: value,
          child: DefaultTextStyle.merge(
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            child: Text(value.toString()),
          ),
        ),
      );
    }

    return DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        items: effectiveItems,
        onChanged: onChanged,
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: theme.colorScheme.onSurfaceVariant,
          size: 18,
        ),
        dropdownColor: theme.colorScheme.surface,
        borderRadius: borderRadius,
        elevation: 2,
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }
}
