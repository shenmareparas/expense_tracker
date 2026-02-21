import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/transaction_viewmodel.dart';
import '../../viewmodels/category_viewmodel.dart';
import '../../views/transaction/add_transaction_page.dart';
import '../../views/analytics/analytics_page.dart';
import '../../views/settings/settings_page.dart';
import 'widgets/transaction_list.dart';
import 'widgets/filter_bottom_sheet.dart';

/// Main home page with bottom navigation.
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
      ).loadTransactions();
      Provider.of<CategoryViewModel>(context, listen: false).loadCategories();
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
                  icon: Badge(
                    isLabelVisible:
                        viewModel.filterType != null ||
                        viewModel.filterStartDate != null ||
                        viewModel.filterEndDate != null,
                    smallSize: 8,
                    child: Icon(
                      Icons.filter_list,
                      color:
                          viewModel.filterType != null ||
                              viewModel.filterStartDate != null ||
                              viewModel.filterEndDate != null
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  onPressed: () => showFilterBottomSheet(context, viewModel),
                );
              },
            ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          TransactionListView(),
          AnalyticsPage(),
          SettingsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Transactions',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
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
}
