import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../views/home/home_page.dart';
import 'login_page.dart';

/// Listens to auth state and routes to either [LoginPage] or [HomePage].
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    return StreamBuilder<AuthState>(
      stream: authViewModel.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data?.session;

        if (session != null) {
          return const HomePage();
        }

        return const LoginPage();
      },
    );
  }
}
