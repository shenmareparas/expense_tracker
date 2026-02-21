import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/category_viewmodel.dart';
import '../../models/category.dart';

class ManageCategoriesPage extends StatefulWidget {
  const ManageCategoriesPage({super.key});

  @override
  State<ManageCategoriesPage> createState() => _ManageCategoriesPageState();
}

class _ManageCategoriesPageState extends State<ManageCategoriesPage> {
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CategoryViewModel>(context, listen: false).loadCategories();
    });
  }

  void _showCategoryDialog({
    CategoryModel? category,
    required String initialType,
  }) {
    if (category != null) {
      _nameController.text = category.name;
    } else {
      _nameController.clear();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(category == null ? 'Add Category' : 'Edit Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Category Name',
                hintText: 'e.g. Shopping, Travel',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = _nameController.text.trim();
              if (name.isEmpty) return;

              final viewModel = Provider.of<CategoryViewModel>(
                context,
                listen: false,
              );
              bool success;
              if (category == null) {
                success = await viewModel.addCategory(
                  name: name,
                  type: initialType,
                );
              } else {
                success = await viewModel.updateCategory(
                  id: category.id,
                  name: name,
                  type: initialType,
                );
              }

              if (success && mounted) {
                _nameController.clear();
                if (context.mounted) {
                  Navigator.pop(context);
                }
              }
            },
            child: Text(category == null ? 'Add' : 'Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manage Categories'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Expenses', icon: Icon(Icons.upload_outlined)),
              Tab(text: 'Income', icon: Icon(Icons.download_outlined)),
            ],
          ),
        ),
        body: Consumer<CategoryViewModel>(
          builder: (context, viewModel, child) {
            if (viewModel.isLoading && viewModel.categories.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            final expenses =
                viewModel.categories.where((c) => c.type == 'expense').toList()
                  ..sort((a, b) {
                    if (a.name.toLowerCase() == 'other') return 1;
                    if (b.name.toLowerCase() == 'other') return -1;
                    return a.orderIndex.compareTo(b.orderIndex);
                  });
            final income =
                viewModel.categories.where((c) => c.type == 'income').toList()
                  ..sort((a, b) {
                    if (a.name.toLowerCase() == 'other') return 1;
                    if (b.name.toLowerCase() == 'other') return -1;
                    return a.orderIndex.compareTo(b.orderIndex);
                  });

            return TabBarView(
              children: [
                _buildCategoryList(expenses, viewModel, 'expense'),
                _buildCategoryList(income, viewModel, 'income'),
              ],
            );
          },
        ),
        floatingActionButton: Builder(
          builder: (context) => FloatingActionButton.extended(
            onPressed: () {
              final tabIndex = DefaultTabController.of(context).index;
              _showCategoryDialog(
                initialType: tabIndex == 0 ? 'expense' : 'income',
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Category'),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryList(
    List<CategoryModel> categories,
    CategoryViewModel viewModel,
    String type,
  ) {
    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == 'expense'
                  ? Icons.shopping_bag_outlined
                  : Icons.account_balance_wallet_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No $type categories yet.',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => viewModel.seedDefaultCategories(),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Add Default Categories'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _showCategoryDialog(initialType: type),
              icon: const Icon(Icons.add),
              label: const Text('Create Custom Category'),
            ),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      itemCount: categories.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      onReorder: (oldIndex, newIndex) {
        viewModel.reorderCategories(type, oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final category = categories[index];
        final isOther = category.name.toLowerCase() == 'other';

        return Card(
          key: ValueKey(category.id),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          elevation: 0,
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: isOther
                ? const CircleAvatar(
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.more_horiz, color: Colors.white),
                  )
                : CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    child: Text(
                      category.name[0].toUpperCase(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
            title: Text(
              category.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isOther ? Colors.grey : null,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isOther) ...[
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () => _showCategoryDialog(
                      category: category,
                      initialType: type,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                    onPressed: () =>
                        _showDeleteConfirmation(context, viewModel, category),
                  ),
                  const Icon(Icons.drag_handle, color: Colors.grey, size: 20),
                ] else
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Text(
                      'Default',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    CategoryViewModel viewModel,
    CategoryModel category,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text(
          'Are you sure you want to delete "${category.name}"? Transactions using this category will not be deleted, but they will logic reference a missing category.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              viewModel.deleteCategory(category.id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
