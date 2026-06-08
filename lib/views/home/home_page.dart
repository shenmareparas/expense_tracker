import 'package:flutter/material.dart';
import '../../utils/haptics.dart';
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
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _transactionScrollController = ScrollController();
  final ScrollController _analyticsScrollController = ScrollController();
  final ScrollController _settingsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final transactionVM = Provider.of<TransactionViewModel>(
        context,
        listen: false,
      );
      if (transactionVM.transactions.isEmpty) {
        transactionVM.loadTransactions();
      }

      final categoryVM = Provider.of<CategoryViewModel>(context, listen: false);
      if (categoryVM.categories.isEmpty) {
        categoryVM.loadCategories();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _transactionScrollController.dispose();
    _analyticsScrollController.dispose();
    _settingsScrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    ScrollController? controller;
    switch (_selectedIndex) {
      case 0:
        controller = _transactionScrollController;
        break;
      case 1:
        controller = _analyticsScrollController;
        break;
      case 2:
        controller = _settingsScrollController;
        break;
    }

    if (controller != null && controller.hasClients) {
      controller.animateTo(
        0.0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onItemTapped(int index) {
    AppHaptics.selectionClick(context);
    if (_selectedIndex == index) {
      _scrollToTop();
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
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
        leading: _selectedIndex == 0
            ? (_isSearching
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _isSearching = false;
                          Provider.of<TransactionViewModel>(
                            context,
                            listen: false,
                          ).setSearchQuery('');
                        });
                      },
                    )
                  : IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () {
                        setState(() {
                          _isSearching = true;
                        });
                      },
                    ))
            : null,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search by amount or description...',
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  Provider.of<TransactionViewModel>(
                    context,
                    listen: false,
                  ).setSearchQuery(value);
                },
              )
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _scrollToTop,
                child: Text(_appBarTitle),
              ),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  Provider.of<TransactionViewModel>(
                    context,
                    listen: false,
                  ).setSearchQuery('');
                });
              },
            )
          else if (_selectedIndex == 0)
            Consumer<TransactionViewModel>(
              builder: (context, viewModel, child) {
                return IconButton(
                  icon: Badge(
                    isLabelVisible:
                        viewModel.filterType != null ||
                        viewModel.filterCategory != null ||
                        viewModel.filterStartDate != null ||
                        viewModel.filterEndDate != null,
                    smallSize: 8,
                    child: Icon(
                      Icons.filter_list,
                      color:
                          viewModel.filterType != null ||
                              viewModel.filterCategory != null ||
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
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (currentChild, previousChildren) {
          return currentChild ?? const SizedBox.shrink();
        },
        transitionBuilder: (child, animation) {
          final slideAnimation = Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(animation);

          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slideAnimation, child: child),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(_selectedIndex),
          child: [
            TransactionListView(scrollController: _transactionScrollController),
            AnalyticsPage(scrollController: _analyticsScrollController),
            SettingsPage(scrollController: _settingsScrollController),
          ][_selectedIndex],
        ),
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
      floatingActionButton: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: _selectedIndex == 0
            ? FloatingActionButton(
                key: const ValueKey('add_transaction_fab'),
                onPressed: () async {
                  AppHaptics.lightImpact(context);
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
            : const SizedBox.shrink(key: ValueKey('empty_fab')),
      ),
    );
  }
}
