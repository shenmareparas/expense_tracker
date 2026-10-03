import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';

import '../../../models/transaction.dart';
import '../../../services/auth_service.dart';
import '../../../services/pdf_export_service.dart';
import '../../../utils/haptics.dart';
import '../../../viewmodels/category_viewmodel.dart';
import '../../../viewmodels/transaction_viewmodel.dart';

/// Bottom sheet dialog allowing users to configure filters and export transactions to PDF.
void showExportPdfBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => const _ExportPdfSheet(),
  );
}

class _ExportPdfSheet extends StatefulWidget {
  const _ExportPdfSheet();

  @override
  State<_ExportPdfSheet> createState() => _ExportPdfSheetState();
}

class _ExportPdfSheetState extends State<_ExportPdfSheet> {
  // Filters
  String _datePreset = 'This Month'; // 'All Time', 'This Month', 'Last Month', 'This Year', 'Custom'
  DateTime? _startDate;
  DateTime? _endDate;

  String? _selectedType; // null = all, 'expense', 'income'
  String? _selectedPaymentMethod; // null = all, 'upi', 'cash'
  final Set<String> _selectedCategories = {};

  bool _isGenerating = false;
  String _activeAction = ''; // 'view', 'share', 'save'

  @override
  void initState() {
    super.initState();
    _applyDatePreset('This Month');
  }

  void _applyDatePreset(String preset) {
    final now = DateTime.now();
    setState(() {
      _datePreset = preset;
      if (preset == 'This Month') {
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
      } else if (preset == 'Last Month') {
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        _startDate = DateTime(lastMonth.year, lastMonth.month, 1);
        _endDate = DateTime(lastMonth.year, lastMonth.month + 1, 0, 23, 59, 59, 999);
      } else if (preset == 'This Year') {
        _startDate = DateTime(now.year, 1, 1);
        _endDate = DateTime(now.year, 12, 31, 23, 59, 59, 999);
      } else if (preset == 'All Time') {
        _startDate = null;
        _endDate = null;
      }
    });
  }

  Future<void> _selectCustomDateRange() async {
    AppHaptics.selectionClick(context);
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      initialDateRange: (_startDate != null && _endDate != null)
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(
              start: DateTime(now.year, now.month, 1),
              end: now,
            ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: Theme.of(context).colorScheme.primary,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _datePreset = 'Custom';
        _startDate = DateTime(picked.start.year, picked.start.month, picked.start.day, 0, 0, 0);
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59, 999);
      });
    }
  }

  List<TransactionModel> _getFilteredTransactions(List<TransactionModel> all) {
    return all.where((tx) {
      // Date filter
      if (_startDate != null && tx.transactionDate.isBefore(_startDate!)) {
        return false;
      }
      if (_endDate != null && tx.transactionDate.isAfter(_endDate!)) {
        return false;
      }

      // Type filter
      if (_selectedType != null && tx.type != _selectedType) {
        return false;
      }

      // Payment Method filter
      if (_selectedPaymentMethod != null &&
          tx.paymentMethod.toLowerCase() != _selectedPaymentMethod!.toLowerCase()) {
        return false;
      }

      // Categories filter
      if (_selectedCategories.isNotEmpty &&
          !_selectedCategories.contains(tx.category)) {
        return false;
      }

      return true;
    }).toList();
  }

  Future<void> _handleExport(String action) async {
    final txVm = Provider.of<TransactionViewModel>(context, listen: false);

    setState(() {
      _isGenerating = true;
      _activeAction = action;
    });

    try {
      final matching = await txVm.fetchTransactionsForExport(
        type: _selectedType,
        categories: _selectedCategories.isEmpty ? null : _selectedCategories.toList(),
        paymentMethod: _selectedPaymentMethod,
        startDate: _startDate,
        endDate: _endDate,
      );

      if (matching.isEmpty) {
        if (mounted) {
          _showStatusToast(
            context,
            message: 'No transactions found matching the selected filters.',
            icon: Icons.info_outline_rounded,
            isError: true,
          );
        }
        return;
      }

      final user = AuthService.instance.currentUser;
      final userName = user?.userMetadata?['name'] as String? ??
          user?.userMetadata?['full_name'] as String? ??
          '';
      final userEmail = user?.email ?? '';

      final title = _datePreset == 'Custom'
          ? 'Transaction Statement'
          : 'Statement - $_datePreset';

      final pdfBytes = await PdfExportService.instance.generateTransactionPdf(
        transactions: matching,
        title: title,
        userName: userName,
        userEmail: userEmail,
        startDate: _startDate,
        endDate: _endDate,
        filterType: _selectedType,
        filterCategories: _selectedCategories.isEmpty ? null : _selectedCategories.toList(),
        filterPaymentMethod: _selectedPaymentMethod,
      );

      final fileName = 'ExpenseTracker_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';

      if (!mounted) return;

      if (action == 'view') {
        AppHaptics.selectionClick(context);
        final result = await PdfExportService.instance.viewPdf(
          bytes: pdfBytes,
          fileName: fileName,
        );
        if (result.type != ResultType.done && mounted) {
          _showStatusToast(
            context,
            message: 'Could not open PDF: ${result.message}',
            icon: Icons.warning_amber_rounded,
            isError: true,
          );
        } else if (mounted) {
          _showStatusToast(
            context,
            message: 'Opening PDF document...',
            icon: Icons.visibility_rounded,
            isError: false,
          );
        }
      } else if (action == 'share') {
        AppHaptics.mediumImpact(context);
        final box = context.findRenderObject() as RenderBox?;
        final origin = box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null;

        await PdfExportService.instance.sharePdf(
          bytes: pdfBytes,
          fileName: fileName,
          subject: 'Expense Tracker Statement ($title)',
          sharePositionOrigin: origin,
        );
        if (mounted) {
          _showStatusToast(
            context,
            message: 'Sharing statement...',
            icon: Icons.share_rounded,
            isError: false,
          );
        }
      } else if (action == 'save') {
        AppHaptics.vibrate(context);
        final path = await PdfExportService.instance.savePdfToStorage(
          bytes: pdfBytes,
          fileName: fileName,
        );
        if (mounted) {
          _showStatusToast(
            context,
            message: 'PDF saved successfully to:\n$path',
            icon: Icons.check_circle_rounded,
            isError: false,
            duration: const Duration(seconds: 4),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showStatusToast(
          context,
          message: 'Failed to export PDF: $e',
          icon: Icons.error_outline_rounded,
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _activeAction = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final txVm = Provider.of<TransactionViewModel>(context);
    final catVm = Provider.of<CategoryViewModel>(context);

    final matchingTransactions = _getFilteredTransactions(txVm.transactions);
    double matchingTotal = 0;
    for (final tx in matchingTransactions) {
      matchingTotal += (tx.type == 'income' ? tx.amount : -tx.amount);
    }

    final availableCategories = _selectedType == 'income'
        ? catVm.incomeCategories
        : _selectedType == 'expense'
            ? catVm.expenseCategories
            : {...catVm.expenseCategories, ...catVm.incomeCategories}.toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),

              // Title and Live Metrics Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.picture_as_pdf_rounded,
                        color: colorScheme.onPrimaryContainer,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Export Statement',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${matchingTransactions.length} transactions selected',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Net Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: (matchingTotal >= 0
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444))
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: (matchingTotal >= 0
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444))
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '${matchingTotal >= 0 ? '+' : '-'}₹${matchingTotal.abs().toStringAsFixed(0)}',
                        style: TextStyle(
                          color: matchingTotal >= 0
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 16),

              // Middle Scrollable Options
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date Range Section
                      _buildSectionHeader('DATE RANGE'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...['This Month', 'Last Month', 'This Year', 'All Time'].map((preset) {
                            final isSelected = _datePreset == preset;
                            return ChoiceChip(
                              label: Text(preset),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  AppHaptics.selectionClick(context);
                                  _applyDatePreset(preset);
                                }
                              },
                            );
                          }),
                          ActionChip(
                            avatar: Icon(
                              Icons.calendar_today_rounded,
                              size: 14,
                              color: _datePreset == 'Custom'
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                            label: Text(
                              _datePreset == 'Custom' && _startDate != null && _endDate != null
                                  ? '${DateFormat('d MMM').format(_startDate!)} - ${DateFormat('d MMM').format(_endDate!)}'
                                  : 'Custom Range...',
                            ),
                            side: _datePreset == 'Custom'
                                ? BorderSide(color: colorScheme.primary, width: 1.5)
                                : null,
                            onPressed: _selectCustomDateRange,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Transaction Type Section
                      _buildSectionHeader('TRANSACTION TYPE'),
                      SegmentedButton<String?>(
                        segments: const [
                          ButtonSegment(value: null, label: Text('All')),
                          ButtonSegment(value: 'expense', label: Text('Expenses')),
                          ButtonSegment(value: 'income', label: Text('Income')),
                        ],
                        selected: {_selectedType},
                        onSelectionChanged: (Set<String?> newSelection) {
                          AppHaptics.selectionClick(context);
                          setState(() {
                            _selectedType = newSelection.first;
                            _selectedCategories.clear();
                          });
                        },
                      ),
                      const SizedBox(height: 18),

                      // Payment Method Section
                      _buildSectionHeader('PAYMENT METHOD'),
                      Row(
                        children: [
                          _buildFilterPill(
                            label: 'All Methods',
                            isSelected: _selectedPaymentMethod == null,
                            onTap: () {
                              AppHaptics.selectionClick(context);
                              setState(() => _selectedPaymentMethod = null);
                            },
                          ),
                          const SizedBox(width: 8),
                          _buildFilterPill(
                            label: 'UPI',
                            isSelected: _selectedPaymentMethod == 'upi',
                            onTap: () {
                              AppHaptics.selectionClick(context);
                              setState(() => _selectedPaymentMethod = 'upi');
                            },
                          ),
                          const SizedBox(width: 8),
                          _buildFilterPill(
                            label: 'Cash',
                            isSelected: _selectedPaymentMethod == 'cash',
                            onTap: () {
                              AppHaptics.selectionClick(context);
                              setState(() => _selectedPaymentMethod = 'cash');
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Categories Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionHeader('CATEGORIES'),
                          if (_selectedCategories.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                AppHaptics.selectionClick(context);
                                setState(() => _selectedCategories.clear());
                              },
                              child: Text(
                                'Clear selection',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: availableCategories.map((cat) {
                          final isSelected = _selectedCategories.contains(cat);
                          return FilterChip(
                            label: Text(cat, style: const TextStyle(fontSize: 12)),
                            selected: isSelected,
                            visualDensity: VisualDensity.compact,
                            onSelected: (selected) {
                              AppHaptics.selectionClick(context);
                              setState(() {
                                if (selected) {
                                  _selectedCategories.add(cat);
                                } else {
                                  _selectedCategories.remove(cat);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // Bottom Action Buttons: View, Share (Direct), Save
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // View PDF Button
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _isGenerating ? null : () => _handleExport('view'),
                        icon: _isGenerating && _activeAction == 'view'
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.visibility_outlined, size: 20),
                        label: const Text(
                          'View PDF',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Direct Share PDF Button (Primary)
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _isGenerating ? null : () => _handleExport('share'),
                        icon: _isGenerating && _activeAction == 'share'
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.share_outlined, size: 20),
                        label: const Text(
                          'Share PDF',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Save to Storage Button (Secondary icon action)
                    IconButton.filledTonal(
                      tooltip: 'Save to Device Storage',
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _isGenerating ? null : () => _handleExport('save'),
                      icon: _isGenerating && _activeAction == 'save'
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_rounded, size: 22),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildFilterPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
    );
  }

  OverlayEntry? _activeToastEntry;

  void _showStatusToast(
    BuildContext context, {
    required String message,
    required IconData icon,
    required bool isError,
    Duration duration = const Duration(seconds: 3),
  }) {
    _activeToastEntry?.remove();
    _activeToastEntry = null;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;
    // Position cleanly below typical AppBar height (top padding + ~56px)
    final topOffset = topPadding + 60.0;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _TopToastWidget(
        topOffset: topOffset,
        message: message,
        icon: icon,
        isError: isError,
        isDark: isDark,
        onDismiss: () {
          entry.remove();
          if (_activeToastEntry == entry) {
            _activeToastEntry = null;
          }
        },
      ),
    );

    _activeToastEntry = entry;
    overlay.insert(entry);

    Future.delayed(duration, () {
      if (entry.mounted) {
        entry.remove();
        if (_activeToastEntry == entry) {
          _activeToastEntry = null;
        }
      }
    });
  }

  @override
  void dispose() {
    _activeToastEntry?.remove();
    _activeToastEntry = null;
    super.dispose();
  }
}

class _TopToastWidget extends StatefulWidget {
  final double topOffset;
  final String message;
  final IconData icon;
  final bool isError;
  final bool isDark;
  final VoidCallback onDismiss;

  const _TopToastWidget({
    required this.topOffset,
    required this.message,
    required this.icon,
    required this.isError,
    required this.isDark,
    required this.onDismiss,
  });

  @override
  State<_TopToastWidget> createState() => _TopToastWidgetState();
}

class _TopToastWidgetState extends State<_TopToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.isError
        ? const Color(0xFFEF4444).withValues(alpha: 0.5)
        : const Color(0xFF10B981).withValues(alpha: 0.5);

    final bgColor = widget.isError
        ? (widget.isDark ? const Color(0xFF2A1515) : const Color(0xFFFEF2F2))
        : (widget.isDark ? const Color(0xFF1E2038) : const Color(0xFFF0FDF4));

    final accentColor =
        widget.isError ? const Color(0xFFEF4444) : const Color(0xFF10B981);

    return Positioned(
      top: widget.topOffset,
      left: 16,
      right: 16,
      child: Material(
        type: MaterialType.transparency,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: GestureDetector(
              onTap: widget.onDismiss,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.icon,
                        size: 18,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: widget.isDark
                              ? Colors.white
                              : const Color(0xFF111827),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
