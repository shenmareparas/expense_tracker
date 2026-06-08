import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          icon: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              category == null ? Icons.category_rounded : Icons.edit_rounded,
              color: theme.colorScheme.primary,
              size: 32,
            ),
          ),
          title: Text(
            category == null ? 'Add Category' : 'Edit Category',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                maxLength: 40,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                decoration: InputDecoration(
                  labelText: 'Category Name',
                  hintText: 'e.g. Shopping, Travel',
                  counterText: '', // hide the character counter UI
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                textCapitalization: TextCapitalization.words,
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                side: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
            ),
            FilledButton(
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
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(category == null ? 'Add' : 'Save'),
            ),
          ],
        );
      },
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
              Tab(text: 'Expenses', icon: Icon(Icons.arrow_upward)),
              Tab(text: 'Income', icon: Icon(Icons.arrow_downward)),
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
                  ..sort(CategoryModel.sortWithOtherLast);
            final income =
                viewModel.categories.where((c) => c.type == 'income').toList()
                  ..sort(CategoryModel.sortWithOtherLast);

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
                  ? Icons.shopping_bag
                  : Icons.account_balance_wallet,
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
      onReorderItem: (oldIndex, newIndex) {
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
            leading: !isOther
                ? const Icon(Icons.drag_handle, color: Colors.grey, size: 20)
                : const SizedBox(width: 20),
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
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: () =>
                        _showDeleteConfirmation(context, viewModel, category),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => _showCategoryDialog(
                      category: category,
                      initialType: type,
                    ),
                  ),
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
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          icon: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.delete_rounded,
              color: Colors.red,
              size: 32,
            ),
          ),
          title: Text(
            'Delete Category',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'This will remove it from your categories list. Existing transactions in this category will not be deleted.',
            textAlign: TextAlign.center,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                side: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
            ),
            FilledButton(
              onPressed: () {
                viewModel.deleteCategory(category.id);
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.withValues(alpha: 0.1),
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Delete',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
