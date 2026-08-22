class SplitExpenseModel {
  final String id;
  final String payerId;
  final String borrowerId;
  final double amount;
  final double totalAmount;
  final String description;
  final String category;
  final String status; // 'pending' or 'settled'
  final DateTime expenseDate;
  final DateTime createdAt;

  // Optional profile models for UI display
  final String? payerEmail;
  final String? borrowerEmail;
  final String? payerName;
  final String? borrowerName;

  SplitExpenseModel({
    required this.id,
    required this.payerId,
    required this.borrowerId,
    required this.amount,
    required this.totalAmount,
    required this.description,
    this.category = 'General',
    this.status = 'pending',
    required this.expenseDate,
    required this.createdAt,
    this.payerEmail,
    this.borrowerEmail,
    this.payerName,
    this.borrowerName,
  });

  String get displayPayer {
    if (payerName != null && payerName!.trim().isNotEmpty) return payerName!;
    if (payerEmail != null && payerEmail!.trim().isNotEmpty) {
      return payerEmail!.split('@').first;
    }
    return 'User';
  }

  String get displayBorrower {
    if (borrowerName != null && borrowerName!.trim().isNotEmpty) {
      return borrowerName!;
    }
    if (borrowerEmail != null && borrowerEmail!.trim().isNotEmpty) {
      return borrowerEmail!.split('@').first;
    }
    return 'User';
  }

  factory SplitExpenseModel.fromJson(Map<String, dynamic> json) {
    return SplitExpenseModel(
      id: json['id'] as String,
      payerId: json['payer_id'] as String,
      borrowerId: json['borrower_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      totalAmount: (json['total_amount'] as num).toDouble(),
      description: json['description'] as String,
      category: (json['category'] as String?) ?? 'General',
      status: (json['status'] as String?) ?? 'pending',
      expenseDate: DateTime.parse(json['expense_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      payerEmail: json['payer_profile'] != null
          ? json['payer_profile']['email'] as String?
          : null,
      borrowerEmail: json['borrower_profile'] != null
          ? json['borrower_profile']['email'] as String?
          : null,
      payerName: json['payer_profile'] != null
          ? json['payer_profile']['name'] as String?
          : null,
      borrowerName: json['borrower_profile'] != null
          ? json['borrower_profile']['name'] as String?
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'payer_id': payerId,
      'borrower_id': borrowerId,
      'amount': amount,
      'total_amount': totalAmount,
      'description': description,
      'category': category,
      'status': status,
      'expense_date': expenseDate.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  SplitExpenseModel copyWith({
    String? id,
    String? payerId,
    String? borrowerId,
    double? amount,
    double? totalAmount,
    String? description,
    String? category,
    String? status,
    DateTime? expenseDate,
    DateTime? createdAt,
    String? payerEmail,
    String? borrowerEmail,
    String? payerName,
    String? borrowerName,
  }) {
    return SplitExpenseModel(
      id: id ?? this.id,
      payerId: payerId ?? this.payerId,
      borrowerId: borrowerId ?? this.borrowerId,
      amount: amount ?? this.amount,
      totalAmount: totalAmount ?? this.totalAmount,
      description: description ?? this.description,
      category: category ?? this.category,
      status: status ?? this.status,
      expenseDate: expenseDate ?? this.expenseDate,
      createdAt: createdAt ?? this.createdAt,
      payerEmail: payerEmail ?? this.payerEmail,
      borrowerEmail: borrowerEmail ?? this.borrowerEmail,
      payerName: payerName ?? this.payerName,
      borrowerName: borrowerName ?? this.borrowerName,
    );
  }

  @override
  bool operator ==(Object other) => other is SplitExpenseModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
