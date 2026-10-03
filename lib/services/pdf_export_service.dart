import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/transaction.dart';

/// Service responsible for generating, previewing, sharing, and saving PDF transaction statements.
class PdfExportService {
  PdfExportService._();
  static final PdfExportService instance = PdfExportService._();

  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  static final DateFormat _timeFormat = DateFormat('hh:mm a');
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: 'Rs. ',
    decimalDigits: 2,
  );

  /// Generates the PDF document bytes for the given list of transactions.
  Future<Uint8List> generateTransactionPdf({
    required List<TransactionModel> transactions,
    required String title,
    String? userEmail,
    String? userName,
    DateTime? startDate,
    DateTime? endDate,
    String? filterType,
    List<String>? filterCategories,
    String? filterPaymentMethod,
  }) async {
    final pdf = pw.Document();

    // Load custom fonts or standard fallback
    pw.Font fontRegular;
    pw.Font fontBold;
    try {
      final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      fontRegular = pw.Font.ttf(fontData);
      fontBold = fontRegular;
    } catch (_) {
      fontRegular = pw.Font.helvetica();
      fontBold = pw.Font.helveticaBold();
    }

    // Calculate Summary Metrics
    double totalIncome = 0;
    double totalExpense = 0;
    final Map<String, double> categoryBreakdown = {};

    for (final tx in transactions) {
      if (tx.type == 'income') {
        totalIncome += tx.amount;
      } else {
        totalExpense += tx.amount;
        categoryBreakdown[tx.category] =
            (categoryBreakdown[tx.category] ?? 0) + tx.amount;
      }
    }
    final double netBalance = totalIncome - totalExpense;

    // Theme Colors
    const primaryColor = PdfColor.fromInt(0xFF4F46E5);
    const incomeColor = PdfColor.fromInt(0xFF10B981);
    const expenseColor = PdfColor.fromInt(0xFFEF4444);
    const textDark = PdfColor.fromInt(0xFF111827);
    const textMuted = PdfColor.fromInt(0xFF6B7280);
    const tableHeaderBg = PdfColor.fromInt(0xFFF3F4F6);
    const stripeBg = PdfColor.fromInt(0xFFFAFAFA);
    const borderColor = PdfColor.fromInt(0xFFE5E7EB);

    final String dateRangeText = (startDate != null && endDate != null)
        ? '${_dateFormat.format(startDate)} - ${_dateFormat.format(endDate)}'
        : (startDate != null)
            ? 'From ${_dateFormat.format(startDate)}'
            : (endDate != null)
                ? 'Until ${_dateFormat.format(endDate)}'
                : 'All Time';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        maxPages: 200,
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),
        header: (context) => _buildHeader(
          title: title,
          userName: userName,
          userEmail: userEmail,
          dateRange: dateRangeText,
          primaryColor: primaryColor,
          textDark: textDark,
          textMuted: textMuted,
        ),
        footer: (context) => _buildFooter(
          context: context,
          textMuted: textMuted,
          borderColor: borderColor,
        ),
        build: (context) => [
          pw.SizedBox(height: 16),
          // Financial Summary Cards
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildMetricCard(
                  label: 'TOTAL INCOME',
                  value: _currencyFormat.format(totalIncome),
                  accentColor: incomeColor,
                  bgColor: const PdfColor.fromInt(0xFFF0FDF4),
                  fontBold: fontBold,
                  fontRegular: fontRegular,
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _buildMetricCard(
                  label: 'TOTAL EXPENSE',
                  value: _currencyFormat.format(totalExpense),
                  accentColor: expenseColor,
                  bgColor: const PdfColor.fromInt(0xFFFEF2F2),
                  fontBold: fontBold,
                  fontRegular: fontRegular,
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _buildMetricCard(
                  label: 'NET BALANCE',
                  value: '${netBalance >= 0 ? '+' : ''}${_currencyFormat.format(netBalance)}',
                  accentColor: netBalance >= 0 ? primaryColor : expenseColor,
                  bgColor: const PdfColor.fromInt(0xFFF8FAFC),
                  fontBold: fontBold,
                  fontRegular: fontRegular,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),

          // Applied Filters Summary Pill Bar
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFF9FAFB),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: borderColor, width: 0.8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Transactions: ${transactions.length} record${transactions.length == 1 ? '' : 's'}',
                  style: pw.TextStyle(
                    fontSize: 9,
                    font: fontBold,
                    color: textDark,
                  ),
                ),
                pw.Text(
                  'Filters: Type: ${filterType?.toUpperCase() ?? 'ALL'} | Payment: ${filterPaymentMethod?.toUpperCase() ?? 'ALL'}',
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    font: fontRegular,
                    color: textMuted,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Table
          if (transactions.isEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 40),
              alignment: pw.Alignment.center,
              child: pw.Text(
                'No transactions match the selected criteria.',
                style: pw.TextStyle(
                  color: textMuted,
                  fontSize: 12,
                  font: fontRegular,
                ),
              ),
            )
          else
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder(
                horizontalInside: pw.BorderSide(color: borderColor, width: 0.5),
                bottom: pw.BorderSide(color: borderColor, width: 1),
              ),
              headerStyle: pw.TextStyle(
                font: fontBold,
                fontSize: 8.5,
                color: const PdfColor.fromInt(0xFF374151),
                fontWeight: pw.FontWeight.bold,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: tableHeaderBg,
                borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(4)),
              ),
              headerHeight: 28,
              cellHeight: 28,
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              cellStyle: pw.TextStyle(
                font: fontRegular,
                fontSize: 8.5,
                color: textDark,
              ),
              rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
              oddRowDecoration: const pw.BoxDecoration(color: stripeBg),
              headers: <String>[
                'DATE',
                'CATEGORY',
                'DESCRIPTION',
                'METHOD',
                'TYPE',
                'AMOUNT',
              ],
              columnWidths: const {
                0: pw.FlexColumnWidth(2.0),
                1: pw.FlexColumnWidth(2.2),
                2: pw.FlexColumnWidth(3.4),
                3: pw.FlexColumnWidth(1.3),
                4: pw.FlexColumnWidth(1.4),
                5: pw.FlexColumnWidth(2.4),
              },
              cellAlignments: const {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerLeft,
                4: pw.Alignment.centerLeft,
                5: pw.Alignment.centerRight,
              },
              data: transactions.map((tx) {
                final isIncome = tx.type == 'income';
                final desc = (tx.description != null && tx.description!.trim().isNotEmpty)
                    ? tx.description!
                    : '—';
                return [
                  '${_dateFormat.format(tx.transactionDate)}\n${_timeFormat.format(tx.transactionDate)}',
                  tx.category,
                  desc,
                  tx.paymentMethod.toUpperCase(),
                  tx.type.toUpperCase(),
                  '${isIncome ? '+' : '-'} ${_currencyFormat.format(tx.amount)}',
                ];
              }).toList(),
            ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader({
    required String title,
    String? userName,
    String? userEmail,
    required String dateRange,
    required PdfColor primaryColor,
    required PdfColor textDark,
    required PdfColor textMuted,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFE5E7EB), width: 1.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'EXPENSE TRACKER',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor,
                  letterSpacing: 1.1,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: textDark,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Period: $dateRange',
                style: pw.TextStyle(fontSize: 8.5, color: textMuted),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              if (userName != null && userName.isNotEmpty)
                pw.Text(
                  userName,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: textDark,
                  ),
                ),
              if (userEmail != null && userEmail.isNotEmpty)
                pw.Text(
                  userEmail,
                  style: pw.TextStyle(fontSize: 8.5, color: textMuted),
                ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                style: pw.TextStyle(fontSize: 7.5, color: textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter({
    required pw.Context context,
    required PdfColor textMuted,
    required PdfColor borderColor,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12),
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: borderColor, width: 0.8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Expense Tracker Statement - Confidential',
            style: pw.TextStyle(fontSize: 8, color: textMuted),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: textMuted),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMetricCard({
    required String label,
    required String value,
    required PdfColor accentColor,
    required PdfColor bgColor,
    required pw.Font fontBold,
    required pw.Font fontRegular,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(
          color: PdfColor(
            accentColor.red,
            accentColor.green,
            accentColor.blue,
            0.4,
          ),
          width: 1,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 7.5,
              font: fontBold,
              color: accentColor,
              letterSpacing: 0.5,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12,
              font: fontBold,
              color: const PdfColor.fromInt(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  /// Writes PDF bytes to a temporary file.
  Future<File> _writeTempPdf(Uint8List bytes, String fileName) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Opens the PDF directly in the device's default viewer app.
  Future<OpenResult> viewPdf({
    required Uint8List bytes,
    String? fileName,
  }) async {
    final name = fileName ?? 'statement_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
    final file = await _writeTempPdf(bytes, name);
    return OpenFile.open(file.path);
  }

  /// Directly shares the PDF via native share sheet (e.g. WhatsApp, Email, AirDrop) without saving to storage.
  Future<ShareResult> sharePdf({
    required Uint8List bytes,
    String? fileName,
    String? subject,
    Rect? sharePositionOrigin,
  }) async {
    final name = fileName ?? 'statement_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
    final file = await _writeTempPdf(bytes, name);
    return SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf', name: name)],
        subject: subject ?? 'Transactions Statement',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  /// Saves the PDF to the user's Downloads or Documents directory.
  Future<String> savePdfToStorage({
    required Uint8List bytes,
    String? fileName,
  }) async {
    final name = fileName ?? 'statement_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
    Directory? dir;
    if (Platform.isAndroid) {
      dir = Directory('/storage/emulated/0/Download');
      if (!await dir.exists()) {
        dir = await getExternalStorageDirectory();
      }
    } else {
      dir = await getApplicationDocumentsDirectory();
    }
    dir ??= await getApplicationDocumentsDirectory();

    final filePath = '${dir.path}/$name';
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);
    return filePath;
  }
}
