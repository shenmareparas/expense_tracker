import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_notifier.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../widgets/app_dropdown.dart';
import 'manage_categories_page.dart';

class SettingsPage extends StatelessWidget {
  final ThemeNotifier themeNotifier;

  const SettingsPage({required this.themeNotifier, super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const Text(
          'General',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.category_outlined),
          title: const Text('Manage Categories'),
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
        const Divider(),
        const SizedBox(height: 16),
        const Text(
          'Appearance',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.palette_outlined),
          title: const Text('Theme'),
          trailing: AppDropdownButton<ThemeMode>(
            value: themeNotifier.themeMode,
            onChanged: (ThemeMode? newMode) {
              if (newMode != null) {
                themeNotifier.setThemeMode(newMode);
              }
            },
            items: const [
              DropdownMenuItem(
                value: ThemeMode.system,
                child: Text('System Default'),
              ),
              DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
              DropdownMenuItem(
                value: ThemeMode.dark,
                child: Text('Dark (AMOLED)'),
              ),
            ],
          ),
        ),
        const Divider(),
        const SizedBox(height: 32),
        // Logout Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton.icon(
            onPressed: () {
              Provider.of<AuthViewModel>(context, listen: false).signOut();
            },
            icon: const Icon(Icons.logout, color: Colors.red),
            label: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.withValues(alpha: 0.1),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
