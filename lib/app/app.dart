import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../viewmodels/theme_viewmodel.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/transaction_viewmodel.dart';
import '../viewmodels/category_viewmodel.dart';
import '../views/auth/auth_gate.dart';

/// Root application widget with providers and theme configuration.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    GoogleFonts.config.allowRuntimeFetching = false;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => TransactionViewModel()),
        ChangeNotifierProvider(create: (_) => CategoryViewModel()),
        ChangeNotifierProvider(create: (_) => ThemeViewModel()),
      ],
      child: Consumer<ThemeViewModel>(
        builder: (context, themeService, _) {
          return MaterialApp(
            title: 'Expense Tracker',
            debugShowCheckedModeBanner: false,
            builder: (context, child) => GestureDetector(
              onTap: () {
                FocusManager.instance.primaryFocus?.unfocus();
              },
              child: child,
            ),
            themeMode: themeService.themeMode,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF4F46E5),
              ),
              useMaterial3: true,
              textTheme: GoogleFonts.interTextTheme(
                ThemeData.light().textTheme,
              ),
              appBarTheme: const AppBarTheme(
                centerTitle: true,
                elevation: 0,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
              ),
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: Colors.black,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF818CF8),
                brightness: Brightness.dark,
                surface: const Color(0xFF0A0A0A),
              ),
              textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
              appBarTheme: const AppBarTheme(
                centerTitle: true,
                elevation: 0,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                foregroundColor: Colors.white,
              ),
              cardTheme: CardThemeData(
                color: const Color(0xFF0A0A0A),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                ),
              ),
              useMaterial3: true,
            ),
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}
