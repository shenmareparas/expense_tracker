import 'package:flutter/material.dart';
import '../utils/haptics.dart';
import '../utils/math_evaluator.dart';

class MathOperationsBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback? onOperationApplied;

  const MathOperationsBar({
    super.key,
    required this.controller,
    required this.focusNode,
    this.onOperationApplied,
  });

  void _onOperatorTap(BuildContext context, String op) {
    AppHaptics.selectionClick(context);
    String text = controller.text.trim();

    if (op == 'C') {
      controller.clear();
      focusNode.requestFocus();
      onOperationApplied?.call();
      return;
    }

    // If text is empty:
    if (text.isEmpty) {
      if (op == '−' || op == '-') {
        controller.text = '-';
        controller.selection = const TextSelection.collapsed(offset: 1);
      }
      focusNode.requestFocus();
      onOperationApplied?.call();
      return;
    }

    final displayOp = (op == '*') ? '×' : (op == '/') ? '÷' : (op == '-') ? '−' : op;

    // Check if text ends with an operator: e.g. "50 +" or "50 -" or "50 *" or "50 /"
    final trailingOpRegex = RegExp(r'[\+\-\*\/÷×−]\s*$');
    if (trailingOpRegex.hasMatch(text)) {
      // Replace trailing operator with the new one
      final cleanText = text.replaceAll(trailingOpRegex, '').trim();
      final newText = '$cleanText $displayOp ';
      controller.text = newText;
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: newText.length),
      );
      focusNode.requestFocus();
      onOperationApplied?.call();
      return;
    }

    // If there's an existing complete expression (e.g. "50 + 20"):
    // Evaluate it first, then append the new operator (like standard calculator)
    final hasExistingOp = RegExp(r'\d+\s*[\+\-\*\/÷×−]\s*\d+').hasMatch(text);
    if (hasExistingOp) {
      final result = MathEvaluator.evaluate(text);
      if (result != null && result > 0) {
        final formatted = MathEvaluator.format(result);
        final newText = '$formatted $displayOp ';
        controller.text = newText;
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: newText.length),
        );
        focusNode.requestFocus();
        onOperationApplied?.call();
        return;
      }
    }

    // Otherwise, append " op "
    final newText = '$text $displayOp ';
    controller.text = newText;
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: newText.length),
    );
    focusNode.requestFocus();
    onOperationApplied?.call();
  }

  void _applyCalculation(BuildContext context, double result) {
    AppHaptics.mediumImpact(context);
    final formatted = MathEvaluator.format(result);
    controller.text = formatted;
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: formatted.length),
    );
    focusNode.requestFocus();
    onOperationApplied?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final text = controller.text.trim();
    final hasOperator = RegExp(r'[+\-*/÷×−]').hasMatch(text);
    final evaluatedValue = hasOperator ? MathEvaluator.evaluate(text) : null;

    final operators = [
      {'label': '+', 'op': '+'},
      {'label': '−', 'op': '−'},
      {'label': '×', 'op': '×'},
      {'label': '÷', 'op': '÷'},
      {'label': 'C', 'op': 'C'},
    ];

    return TapRegion(
      groupId: EditableText,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: operators.map((item) {
                      final label = item['label']!;
                      final op = item['op']!;
                      final isClear = op == 'C';

                      final btnColor = isClear
                          ? (isDark
                              ? Colors.red.withValues(alpha: 0.2)
                              : Colors.red.withValues(alpha: 0.1))
                          : (isDark
                              ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7)
                              : theme.colorScheme.primaryContainer.withValues(alpha: 0.45));
                      final textColor = isClear
                          ? (isDark ? Colors.redAccent : Colors.red)
                          : theme.colorScheme.primary;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Material(
                          color: btnColor,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: () => _onOperatorTap(context, op),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              constraints: const BoxConstraints(
                                minWidth: 46,
                                minHeight: 42,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              if (evaluatedValue != null && evaluatedValue > 0) ...[
                const SizedBox(width: 8),
                Material(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => _applyCalculation(context, evaluatedValue),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      constraints: const BoxConstraints(minHeight: 42),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 16,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '= ₹${MathEvaluator.format(evaluatedValue)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
