import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import '../viewmodels/theme_viewmodel.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/transaction_viewmodel.dart';
import '../viewmodels/category_viewmodel.dart';
import '../viewmodels/split_viewmodel.dart';
import '../views/auth/auth_gate.dart';

/// Root application widget with providers and theme configuration.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => TransactionViewModel()),
        ChangeNotifierProvider(create: (_) => CategoryViewModel()),
        ChangeNotifierProvider(create: (_) => ThemeViewModel()),
        ChangeNotifierProvider(create: (_) => SplitViewModel()),
      ],
      child: Consumer<ThemeViewModel>(
        builder: (context, themeService, _) {
          return DynamicColorBuilder(
            builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
              ColorScheme lightColorScheme;
              ColorScheme darkColorScheme;

              if (themeService.useDynamicColor &&
                  lightDynamic != null &&
                  darkDynamic != null) {
                lightColorScheme = lightDynamic.harmonized();
                darkColorScheme = darkDynamic.harmonized().copyWith(
                      surface: const Color(0xFF0A0A0A),
                    );
              } else {
                lightColorScheme = ColorScheme.fromSeed(
                  seedColor: const Color(0xFF4F46E5),
                );
                darkColorScheme = ColorScheme.fromSeed(
                  seedColor: const Color(0xFF818CF8),
                  brightness: Brightness.dark,
                  surface: const Color(0xFF0A0A0A),
                );
              }

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
                  fontFamily: 'Roboto',
                  colorScheme: lightColorScheme,
                  useMaterial3: true,
                  appBarTheme: const AppBarTheme(
                    centerTitle: true,
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    systemOverlayStyle: SystemUiOverlayStyle(
                      statusBarColor: Colors.transparent,
                      statusBarIconBrightness: Brightness.dark,
                      statusBarBrightness: Brightness.light,
                    ),
                  ),
                ),
                darkTheme: ThemeData(
                  fontFamily: 'Roboto',
                  brightness: Brightness.dark,
                  scaffoldBackgroundColor: Colors.black,
                  colorScheme: darkColorScheme,
                  appBarTheme: const AppBarTheme(
                    centerTitle: true,
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    systemOverlayStyle: SystemUiOverlayStyle(
                      statusBarColor: Colors.transparent,
                      statusBarIconBrightness: Brightness.light,
                      statusBarBrightness: Brightness.dark,
                    ),
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
          );
        },
      ),
    );
  }
}
