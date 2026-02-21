import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/theme_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/app_dropdown.dart';
import 'manage_categories_page.dart';

/// Settings page — accesses ThemeService via Provider instead of constructor.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        _buildSectionHeader(context, 'General'),
        _buildSettingsCard(
          context: context,
          children: [
            ListTile(
              leading: Icon(
                Icons.category_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text(
                'Manage Categories',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: const Text('Add or remove transaction categories'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManageCategoriesPage(),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 32),
        _buildSectionHeader(context, 'Appearance'),
        _buildSettingsCard(
          context: context,
          children: [
            ListTile(
              leading: Icon(
                Icons.palette_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text(
                'Theme',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              trailing: Consumer<ThemeService>(
                builder: (context, themeService, _) {
                  return AppDropdownButton<ThemeMode>(
                    value: themeService.themeMode,
                    onChanged: (ThemeMode? newMode) {
                      if (newMode != null) {
                        themeService.setThemeMode(newMode);
                      }
                    },
                    items: const [
                      DropdownMenuItem(
                        value: ThemeMode.system,
                        child: Text('System Default'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text('Light'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text('Dark'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 48),
        // Logout Section
        ElevatedButton.icon(
          onPressed: () {
            Provider.of<AuthViewModel>(context, listen: false).signOut();
          },
          icon: const Icon(Icons.logout, color: Colors.red),
          label: const Text(
            'Sign Out',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.withValues(alpha: 0.1),
            padding: const EdgeInsets.symmetric(vertical: 18),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsCard({
    required BuildContext context,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}
