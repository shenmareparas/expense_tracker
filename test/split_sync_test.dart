import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/viewmodels/split_viewmodel.dart';
import 'package:expense_tracker/models/profile.dart';
import 'package:expense_tracker/models/split_expense.dart';
import 'package:expense_tracker/models/transaction.dart';

void main() {
  group('SplitViewModel.extractSplitDescription', () {
    test(
      'extracts description from standard split transaction description',
      () {
        expect(
          SplitViewModel.extractSplitDescription('Split: Dinner (Alice, Bob)'),
          'Dinner',
        );
        expect(
          SplitViewModel.extractSplitDescription('Split: Team Lunch (Charlie)'),
          'Team Lunch',
        );
        expect(
          SplitViewModel.extractSplitDescription('Split: Grocery'),
          'Grocery',
        );
        expect(
          SplitViewModel.extractSplitDescription('split: Movie tickets (Dave)'),
          'Movie tickets',
        );
      },
    );

    test('handles descriptions without Split prefix or partner suffixes', () {
      expect(
        SplitViewModel.extractSplitDescription('Dinner with friends'),
        'Dinner with friends',
      );
      expect(SplitViewModel.extractSplitDescription(''), '');
    });
  });

  group('SplitViewModel Analytics Calculations', () {
    late SplitViewModel viewModel;
    const currentUserId = 'user-123';
    const friendId = 'friend-456';
    const friendId2 = 'friend-789';
    final now = DateTime(2026, 11, 1, 14, 0);

    setUp(() {
      viewModel = SplitViewModel();
    });

    test(
      'calculates user share when user paid and split 50/50 with friend',
      () {
        final split = SplitExpenseModel(
          id: 'split-1',
          payerId: currentUserId,
          borrowerId: friendId,
          amount: 500.0,
          totalAmount: 1000.0,
          description: 'Dinner',
          category: 'Food',
          expenseDate: now,
          createdAt: now,
        );

        viewModel.setMockData(
          splitExpenses: [split],
          mockUserId: currentUserId,
        );

        final tx = TransactionModel(
          id: 'tx-1',
          userId: currentUserId,
          amount: 1000.0,
          type: 'expense',
          category: 'Food',
          description: 'Split: Dinner (Friend)',
          paymentMethod: 'upi',
          transactionDate: now,
          createdAt: now,
        );

        final share = viewModel.getUserShareForSplitTransaction(tx);
        expect(share, 500.0);
      },
    );

    test('calculates user share in multi-person split (3 people, unequal)', () {
      final split1 = SplitExpenseModel(
        id: 'split-1',
        payerId: currentUserId,
        borrowerId: friendId,
        amount: 400.0,
        totalAmount: 1200.0,
        description: 'Team Lunch',
        category: 'Food',
        expenseDate: now,
        createdAt: now,
      );
      final split2 = SplitExpenseModel(
        id: 'split-2',
        payerId: currentUserId,
        borrowerId: friendId2,
        amount: 500.0,
        totalAmount: 1200.0,
        description: 'Team Lunch',
        category: 'Food',
        expenseDate: now,
        createdAt: now,
      );

      viewModel.setMockData(
        splitExpenses: [split1, split2],
        mockUserId: currentUserId,
      );

      final tx = TransactionModel(
        id: 'tx-2',
        userId: currentUserId,
        amount: 1200.0,
        type: 'expense',
        category: 'Food',
        description: 'Split: Team Lunch (Alice, Bob)',
        paymentMethod: 'upi',
        transactionDate: now,
        createdAt: now,
      );

      final share = viewModel.getUserShareForSplitTransaction(tx);
      expect(share, 300.0);
    });

    test('returns 0 when partner owes full (user share is 0)', () {
      final split = SplitExpenseModel(
        id: 'split-full',
        payerId: currentUserId,
        borrowerId: friendId,
        amount: 500.0,
        totalAmount: 500.0,
        description: 'Movie ticket',
        category: 'Entertainment',
        expenseDate: now,
        createdAt: now,
      );

      viewModel.setMockData(splitExpenses: [split], mockUserId: currentUserId);

      final tx = TransactionModel(
        id: 'tx-full',
        userId: currentUserId,
        amount: 500.0,
        type: 'expense',
        category: 'Entertainment',
        description: 'Split: Movie ticket (Friend)',
        paymentMethod: 'upi',
        transactionDate: now,
        createdAt: now,
      );

      final share = viewModel.getUserShareForSplitTransaction(tx);
      expect(share, 0.0);
    });

    test('transformTransactionsForAnalytics adjusts split amounts and filters settlement income', () {
      final split = SplitExpenseModel(
        id: 'split-1',
        payerId: currentUserId,
        borrowerId: friendId,
        amount: 200.0,
        totalAmount: 600.0,
        description: 'Uber Ride',
        category: 'Transport',
        expenseDate: now,
        createdAt: now,
      );

      viewModel.setMockData(splitExpenses: [split], mockUserId: currentUserId);

      final splitTx = TransactionModel(
        id: 'tx-split',
        userId: currentUserId,
        amount: 600.0,
        type: 'expense',
        category: 'Transport',
        description: 'Split: Uber Ride (Bob)',
        paymentMethod: 'upi',
        transactionDate: now,
        createdAt: now,
      );

      final regularTx = TransactionModel(
        id: 'tx-normal',
        userId: currentUserId,
        amount: 50.0,
        type: 'expense',
        category: 'Food',
        description: 'Coffee',
        paymentMethod: 'upi',
        transactionDate: now,
        createdAt: now,
      );

      final settlementIncomeTx = TransactionModel(
        id: 'tx-settle-income',
        userId: currentUserId,
        amount: 200.0,
        type: 'income',
        category: 'General',
        description: 'Settlement from Bob',
        paymentMethod: 'upi',
        transactionDate: now,
        createdAt: now,
      );

      final regularIncomeTx = TransactionModel(
        id: 'tx-salary',
        userId: currentUserId,
        amount: 50000.0,
        type: 'income',
        category: 'Salary',
        description: 'Monthly Salary',
        paymentMethod: 'upi',
        transactionDate: now,
        createdAt: now,
      );

      final transformed = viewModel.transformTransactionsForAnalytics([
        splitTx,
        regularTx,
        settlementIncomeTx,
        regularIncomeTx,
      ]);

      final transformedSplit = transformed.firstWhere(
        (t) => t.id == 'tx-split',
      );
      expect(transformedSplit.amount, 400.0);

      final transformedRegular = transformed.firstWhere(
        (t) => t.id == 'tx-normal',
      );
      expect(transformedRegular.amount, 50.0);

      expect(transformed.any((t) => t.id == 'tx-settle-income'), false);
      expect(transformed.any((t) => t.id == 'tx-salary'), true);
    });

    test('includes other users split of food in analytics where current user is borrower', () {
      final borrowerSplit = SplitExpenseModel(
        id: 'split-alice-1',
        payerId: friendId,
        borrowerId: currentUserId,
        amount: 350.0,
        totalAmount: 700.0,
        description: 'Italian Dinner',
        category: 'Food',
        expenseDate: now,
        createdAt: now,
      );

      viewModel.setMockData(
        splitExpenses: [borrowerSplit],
        mockUserId: currentUserId,
      );

      final myOwnTx = TransactionModel(
        id: 'my-tx-1',
        userId: currentUserId,
        amount: 150.0,
        type: 'expense',
        category: 'Food',
        description: 'Lunch',
        paymentMethod: 'upi',
        transactionDate: now,
        createdAt: now,
      );

      final transformed = viewModel.transformTransactionsForAnalytics([
        myOwnTx,
      ]);

      final includedSplit = transformed.firstWhere(
        (t) => t.id == 'split_borrower_split-alice-1',
      );
      expect(includedSplit.amount, 350.0);
      expect(includedSplit.category, 'Food');
      expect(includedSplit.type, 'expense');
    });

    test('excludes settlement to friend expense to avoid double counting with borrower split', () {
      final borrowerSplit = SplitExpenseModel(
        id: 'split-alice-1',
        payerId: friendId,
        borrowerId: currentUserId,
        amount: 350.0,
        totalAmount: 700.0,
        description: 'Italian Dinner',
        category: 'Food',
        expenseDate: now,
        createdAt: now,
      );

      viewModel.setMockData(
        splitExpenses: [borrowerSplit],
        mockUserId: currentUserId,
      );

      final settlementExpenseTx = TransactionModel(
        id: 'tx-settle-expense',
        userId: currentUserId,
        amount: 350.0,
        type: 'expense',
        category: 'General',
        description: 'Settlement to Alice',
        paymentMethod: 'upi',
        transactionDate: now,
        createdAt: now,
      );

      final transformed = viewModel.transformTransactionsForAnalytics([
        settlementExpenseTx,
      ]);

      expect(transformed.any((t) => t.id == 'tx-settle-expense'), false);
      expect(
        transformed.any((t) => t.id == 'split_borrower_split-alice-1'),
        true,
      );
    });

    test(
      'respects date boundaries when including other users split expenses',
      () {
        final oldSplit = SplitExpenseModel(
          id: 'split-old',
          payerId: friendId,
          borrowerId: currentUserId,
          amount: 200.0,
          totalAmount: 400.0,
          description: 'Old Dinner',
          category: 'Food',
          expenseDate: DateTime(2026, 10, 1),
          createdAt: DateTime(2026, 10, 1),
        );

        final recentSplit = SplitExpenseModel(
          id: 'split-recent',
          payerId: friendId,
          borrowerId: currentUserId,
          amount: 300.0,
          totalAmount: 600.0,
          description: 'Recent Dinner',
          category: 'Food',
          expenseDate: DateTime(2026, 11, 2),
          createdAt: DateTime(2026, 11, 2),
        );

        viewModel.setMockData(
          splitExpenses: [oldSplit, recentSplit],
          mockUserId: currentUserId,
        );

        final transformed = viewModel.transformTransactionsForAnalytics(
          [],
          startDate: DateTime(2026, 11, 1),
          endDate: DateTime(2026, 11, 30, 23, 59, 59),
        );

        expect(
          transformed.any((t) => t.id == 'split_borrower_split-recent'),
          true,
        );
        expect(
          transformed.any((t) => t.id == 'split_borrower_split-old'),
          false,
        );
      },
    );
  });

  group('SplitViewModel.getBorrowerSplitTransactions', () {
    late SplitViewModel viewModel;
    const currentUserId = 'user-123';
    const friendId = 'friend-456';
    final now = DateTime(2026, 11, 1, 14, 0);

    setUp(() {
      viewModel = SplitViewModel();
    });

    test('returns synthesized transactions for split expenses where user is borrower without payer name in title', () {
      final split = SplitExpenseModel(
        id: 'split-101',
        payerId: friendId,
        borrowerId: currentUserId,
        amount: 250.0,
        totalAmount: 500.0,
        description: 'Groceries',
        category: 'Shopping',
        expenseDate: now,
        createdAt: now,
        payerName: 'Bob',
      );

      viewModel.setMockData(splitExpenses: [split], mockUserId: currentUserId);

      final txs = viewModel.getBorrowerSplitTransactions();
      expect(txs.length, 1);
      final t = txs.first;
      expect(t.id, 'split_borrower_split-101');
      expect(t.userId, currentUserId);
      expect(t.amount, 250.0);
      expect(t.type, 'expense');
      expect(t.category, 'Shopping');
      expect(t.description, 'Split: Groceries');
      expect(t.transactionDate, now);
    });

    test(
      'filters by category, payment method, date boundaries, and search query',
      () {
        final split1 = SplitExpenseModel(
          id: 'split-food',
          payerId: friendId,
          borrowerId: currentUserId,
          amount: 300.0,
          totalAmount: 600.0,
          description: 'Pizza',
          category: 'Food',
          expenseDate: DateTime(2026, 11, 2),
          createdAt: DateTime(2026, 11, 2),
          payerName: 'Bob',
        );
        final split2 = SplitExpenseModel(
          id: 'split-travel',
          payerId: friendId,
          borrowerId: currentUserId,
          amount: 150.0,
          totalAmount: 300.0,
          description: 'Metro pass',
          category: 'Travel',
          expenseDate: DateTime(2026, 11, 5),
          createdAt: DateTime(2026, 11, 5),
          payerName: 'Bob',
        );

        viewModel.setMockData(
          splitExpenses: [split1, split2],
          mockUserId: currentUserId,
        );

        final foodTxs = viewModel.getBorrowerSplitTransactions(
          categories: ['Food'],
        );
        expect(foodTxs.length, 1);
        expect(foodTxs.first.id, 'split_borrower_split-food');

        final searchTxs = viewModel.getBorrowerSplitTransactions(
          searchQuery: 'metro',
        );
        expect(searchTxs.length, 1);
        expect(searchTxs.first.id, 'split_borrower_split-travel');

        final payerSearchTxs = viewModel.getBorrowerSplitTransactions(
          searchQuery: 'bob',
        );
        expect(payerSearchTxs.length, 2);

        final incomeTxs = viewModel.getBorrowerSplitTransactions(
          type: 'income',
        );
        expect(incomeTxs.isEmpty, true);

        final expenseTxs = viewModel.getBorrowerSplitTransactions(
          type: 'expense',
        );
        expect(expenseTxs.isEmpty, true);

        final splitTxs = viewModel.getBorrowerSplitTransactions(type: 'split');
        expect(splitTxs.length, 2);

        final cashTxs = viewModel.getBorrowerSplitTransactions(
          paymentMethod: 'cash',
        );
        expect(cashTxs.isEmpty, true);
      },
    );

    test(
      'ignores split expenses if already present in existing transactions list',
      () {
        final split = SplitExpenseModel(
          id: 'split-food-1',
          payerId: friendId,
          borrowerId: currentUserId,
          amount: 200.0,
          totalAmount: 400.0,
          description: 'Snacks',
          category: 'Food',
          expenseDate: now,
          createdAt: now,
          payerName: 'Bob',
        );

        viewModel.setMockData(
          splitExpenses: [split],
          mockUserId: currentUserId,
        );

        final existingTx = TransactionModel(
          id: 'tx-existing',
          userId: currentUserId,
          amount: 200.0,
          type: 'expense',
          category: 'Food',
          description: 'Split: Snacks',
          paymentMethod: 'upi',
          transactionDate: now,
          createdAt: now,
        );

        final txs = viewModel.getBorrowerSplitTransactions(
          existingTransactions: [existingTx],
        );
        expect(txs.isEmpty, true);
      },
    );
  });

  group('SplitViewModel.orderedPartnerProfiles', () {
    test('places partners with split expenses above others and excludes current user', () {
      final viewModel = SplitViewModel();
      const currentUserId = 'user-me';
      final now = DateTime(2026, 11, 1, 14, 0);

      final profiles = [
        ProfileModel(id: currentUserId, email: 'me@example.com', name: 'Me'),
        ProfileModel(id: 'u-no-split-1', email: 'a@example.com', name: 'Alice'),
        ProfileModel(id: 'u-with-split-1', email: 'b@example.com', name: 'Bob'),
        ProfileModel(
          id: 'u-no-split-2',
          email: 'c@example.com',
          name: 'Charlie',
        ),
        ProfileModel(
          id: 'u-with-split-2',
          email: 'd@example.com',
          name: 'Dave',
        ),
      ];

      final splits = [
        SplitExpenseModel(
          id: 's1',
          payerId: currentUserId,
          borrowerId: 'u-with-split-1',
          amount: 100,
          totalAmount: 200,
          description: 'Lunch',
          status: 'pending',
          expenseDate: now,
          createdAt: now,
        ),
        SplitExpenseModel(
          id: 's2',
          payerId: 'u-with-split-2',
          borrowerId: currentUserId,
          amount: 50,
          totalAmount: 100,
          description: 'Coffee',
          status: 'settled',
          expenseDate: now,
          createdAt: now,
        ),
      ];

      viewModel.setMockData(
        profiles: profiles,
        splitExpenses: splits,
        mockUserId: currentUserId,
      );

      final orderedIds = viewModel.orderedPartnerProfiles
          .map((p) => p.id)
          .toList();
      expect(orderedIds, [
        'u-with-split-1',
        'u-with-split-2',
        'u-no-split-1',
        'u-no-split-2',
      ]);
    });
  });

  group('SplitViewModel.orderedPartnerProfiles', () {
    test(
      'places partners with split expenses above others and excludes current user',
      () {
        final viewModel = SplitViewModel();
        const currentUserId = 'user-me';
        final now = DateTime(2026, 11, 1, 14, 0);

        final profiles = [
          ProfileModel(id: currentUserId, email: 'me@example.com', name: 'Me'),
          ProfileModel(id: 'u-no-split-1', email: 'a@example.com', name: 'Alice'),
          ProfileModel(id: 'u-with-split-1', email: 'b@example.com', name: 'Bob'),
          ProfileModel(id: 'u-no-split-2', email: 'c@example.com', name: 'Charlie'),
          ProfileModel(id: 'u-with-split-2', email: 'd@example.com', name: 'Dave'),
        ];

        final splits = [
          SplitExpenseModel(
            id: 's1',
            payerId: currentUserId,
            borrowerId: 'u-with-split-1',
            amount: 100,
            totalAmount: 200,
            description: 'Lunch',
            status: 'pending',
            expenseDate: now,
            createdAt: now,
          ),
          SplitExpenseModel(
            id: 's2',
            payerId: 'u-with-split-2',
            borrowerId: currentUserId,
            amount: 50,
            totalAmount: 100,
            description: 'Coffee',
            status: 'settled',
            expenseDate: now,
            createdAt: now,
          ),
        ];

        viewModel.setMockData(
          profiles: profiles,
          splitExpenses: splits,
          mockUserId: currentUserId,
        );

        final orderedIds =
            viewModel.orderedPartnerProfiles.map((p) => p.id).toList();
        expect(orderedIds, [
          'u-with-split-1',
          'u-with-split-2',
          'u-no-split-1',
          'u-no-split-2',
        ]);
      },
    );
  });
}
