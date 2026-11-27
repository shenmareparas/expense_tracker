import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/auth_viewmodel.dart';
import '../../views/home/home_page.dart';
import 'login_page.dart';
import 'update_password_page.dart';

/// Listens to auth state and routes to [LoginPage], [HomePage], or [UpdatePasswordPage].
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final isInRecoveryMode = context.select<AuthViewModel, bool>(
      (vm) => vm.isInRecoveryMode,
    );

    if (isInRecoveryMode) {
      return const UpdatePasswordPage();
    }

    return StreamBuilder<bool>(
      stream: context.read<AuthViewModel>().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final isAuthenticated = snapshot.data ?? false;

        if (isAuthenticated) {
          return const HomePage();
        }

        return const LoginPage();
      },
    );
  }
}
