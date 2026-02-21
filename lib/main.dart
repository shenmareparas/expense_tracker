import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/add_transaction_page.dart';
import 'pages/analytics_page.dart';
import 'pages/settings_page.dart';
import 'services/theme_notifier.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/transaction_viewmodel.dart';
import 'widgets/app_dropdown.dart';

final themeNotifier = ThemeNotifier();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://spxvkxmpcgxbmsneffgo.supabase.co',
    anonKey: 'sb_publishable_Yi8cw2XgJ9SvVz7g9o5hgg_I9zR227S',
  );
  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => TransactionViewModel()),
      ],
      child: ListenableBuilder(
        listenable: themeNotifier,
        builder: (context, _) {
          return MaterialApp(
            title: 'Expense Tracker',
            debugShowCheckedModeBanner: false,
            themeMode: themeNotifier.themeMode,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: Colors.black,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.deepPurple,
                brightness: Brightness.dark,
                surface: Colors.black,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              cardTheme: const CardThemeData(color: Color(0xFF1A1A1A)),
              useMaterial3: true,
            ),
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      // Listen to auth state changes
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data?.session;

        // If session exists, user is signed in
        if (session != null) {
          return const HomePage();
        }

        // Otherwise, show login page
        return const LoginPage();
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;

  Future<void> _submit() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);

    bool success;
    if (_isSignUp) {
      if (_nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Name is required')));
        return;
      }
      success = await authViewModel.signUp(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration successful. Welcome!')),
        );
      }
    } else {
      success = await authViewModel.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    }

    if (!success && mounted) {
      if (authViewModel.errorMessage != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(authViewModel.errorMessage!)));
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isSignUp = !_isSignUp;
    });
    Provider.of<AuthViewModel>(context, listen: false).clearError();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              Theme.of(context).colorScheme.surface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Expense Tracker',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _isSignUp ? 'Create your account' : 'Welcome Back',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 48),
                if (_isSignUp) ...[
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                    ),
                    keyboardType: TextInputType.name,
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 32),
                Consumer<AuthViewModel>(
                  builder: (context, authState, child) {
                    if (authState.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onPrimary,
                          ),
                          child: Text(
                            _isSignUp ? 'Sign Up' : 'Sign In',
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _toggleMode,
                          child: RichText(
                            text: TextSpan(
                              text: _isSignUp
                                  ? "Already have an account? "
                                  : "Don't have an account? ",
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              children: [
                                TextSpan(
                                  text: _isSignUp ? 'Sign In' : 'Sign Up',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TransactionViewModel>(
        context,
        listen: false,
      ).loadInitialData();
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  String get _appBarTitle {
    switch (_selectedIndex) {
      case 0:
        return 'Transactions';
      case 1:
        return 'Analytics';
      case 2:
        return 'Settings';
      default:
        return 'Expense Tracker';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle),
        actions: [
          if (_selectedIndex == 0)
            Consumer<TransactionViewModel>(
              builder: (context, viewModel, child) {
                return IconButton(
                  icon: Icon(
                    Icons.filter_list,
                    color:
                        viewModel.filterType != null ||
                            viewModel.filterStartDate != null ||
                            viewModel.filterEndDate != null
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  onPressed: () => _showFilterBottomSheet(context, viewModel),
                );
              },
            ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildDashboard(),
          const AnalyticsPage(),
          SettingsPage(themeNotifier: themeNotifier),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddTransactionPage(),
                  ),
                );
                if (result == true) {
                  if (context.mounted) {
                    Provider.of<TransactionViewModel>(
                      context,
                      listen: false,
                    ).loadTransactions();
                  }
                }
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildDashboard() {
    return Consumer<TransactionViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.isLoading && viewModel.transactions.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (viewModel.errorMessage != null && viewModel.transactions.isEmpty) {
          return Center(child: Text('Error: ${viewModel.errorMessage}'));
        }

        final transactions = viewModel.filteredTransactions;

        return RefreshIndicator(
          onRefresh: () => viewModel.loadInitialData(),
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              if (transactions.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text('No transactions yet.'),
                  ),
                )
              else
                ...transactions.take(10).map((t) {
                  final isIncome = t.type == 'income';
                  return Dismissible(
                    key: Key(t.id),
                    background: Container(
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16.0),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (direction) async {
                      return await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Transaction'),
                          content: const Text(
                            'Are you sure you want to delete this transaction?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                    },
                    onDismissed: (_) async {
                      await viewModel.deleteTransaction(t.id);
                    },
                    child: Card(
                      elevation: 0,
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  AddTransactionPage(transaction: t),
                            ),
                          );
                          if (result == true) {
                            if (context.mounted) {
                              Provider.of<TransactionViewModel>(
                                context,
                                listen: false,
                              ).loadTransactions();
                            }
                          }
                        },
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isIncome
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.red.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isIncome
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: isIncome ? Colors.green : Colors.red,
                          ),
                        ),
                        title: Text(
                          (t.description != null && t.description!.isNotEmpty)
                              ? t.description!
                              : t.category,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (t.description != null &&
                                t.description!.isNotEmpty)
                              Text(
                                t.category,
                                style: const TextStyle(fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            Text(
                              '${t.transactionDate.year}-${t.transactionDate.month.toString().padLeft(2, '0')}-${t.transactionDate.day.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        isThreeLine:
                            t.description != null && t.description!.isNotEmpty,
                        trailing: Text(
                          '${isIncome ? '+' : '-'}₹${t.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: isIncome ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 80), // Padding for FAB
            ],
          ),
        );
      },
    );
  }

  void _showFilterBottomSheet(
    BuildContext context,
    TransactionViewModel viewModel,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final isIncomeFilter = viewModel.filterType == 'income';
            final isExpenseFilter = viewModel.filterType == 'expense';

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Filter Transactions',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Type',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: viewModel.filterType == null,
                        onSelected: (_) {
                          viewModel.setFilters(
                            type: null,
                            category: null,
                            startDate: viewModel.filterStartDate,
                            endDate: viewModel.filterEndDate,
                          );
                          setState(() {});
                        },
                      ),
                      FilterChip(
                        label: const Text('Income'),
                        selected: isIncomeFilter,
                        onSelected: (_) {
                          viewModel.setFilters(
                            type: 'income',
                            category: null,
                            startDate: viewModel.filterStartDate,
                            endDate: viewModel.filterEndDate,
                          );
                          setState(() {});
                        },
                      ),
                      FilterChip(
                        label: const Text('Expense'),
                        selected: isExpenseFilter,
                        onSelected: (_) {
                          viewModel.setFilters(
                            type: 'expense',
                            category: null,
                            startDate: viewModel.filterStartDate,
                            endDate: viewModel.filterEndDate,
                          );
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (viewModel.filterType != null) ...[
                    const Text(
                      'Category',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    AppDropdown<String?>(
                      key: ValueKey(viewModel.filterCategory),
                      value: viewModel.filterCategory,
                      hint: 'All Categories',
                      prefixIcon: Icons.category_outlined,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Categories'),
                        ),
                        ...(viewModel.filterType == 'income'
                                ? viewModel.incomeCategories
                                : viewModel.expenseCategories)
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            ),
                      ],
                      onChanged: (val) {
                        viewModel.setFilters(
                          type: viewModel.filterType,
                          category: val,
                          startDate: viewModel.filterStartDate,
                          endDate: viewModel.filterEndDate,
                        );
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text(
                    'Date Range',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate:
                                  viewModel.filterStartDate ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2101),
                            );
                            if (date != null) {
                              viewModel.setFilters(
                                type: viewModel.filterType,
                                category: viewModel.filterCategory,
                                startDate: date,
                                endDate: viewModel.filterEndDate,
                              );
                              setState(() {});
                            }
                          },
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(
                            viewModel.filterStartDate != null
                                ? '${viewModel.filterStartDate!.day}/${viewModel.filterStartDate!.month}/${viewModel.filterStartDate!.year}'
                                : 'Start Date',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate:
                                  viewModel.filterEndDate ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2101),
                            );
                            if (date != null) {
                              viewModel.setFilters(
                                type: viewModel.filterType,
                                category: viewModel.filterCategory,
                                startDate: viewModel.filterStartDate,
                                endDate: date,
                              );
                              setState(() {});
                            }
                          },
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(
                            viewModel.filterEndDate != null
                                ? '${viewModel.filterEndDate!.day}/${viewModel.filterEndDate!.month}/${viewModel.filterEndDate!.year}'
                                : 'End Date',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            viewModel.clearFilters();
                            setState(() {});
                          },
                          child: const Text('Clear All'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onPrimary,
                          ),
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
