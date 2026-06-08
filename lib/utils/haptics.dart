import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../viewmodels/theme_viewmodel.dart';

/// Helper class to conditionally trigger haptic feedback based on user settings.
class AppHaptics {
  static void selectionClick(BuildContext context) {
    if (context.mounted &&
        Provider.of<ThemeViewModel>(context, listen: false).hapticEnabled) {
      HapticFeedback.selectionClick();
    }
  }

  static void lightImpact(BuildContext context) {
    if (context.mounted &&
        Provider.of<ThemeViewModel>(context, listen: false).hapticEnabled) {
      HapticFeedback.lightImpact();
    }
  }

  static void mediumImpact(BuildContext context) {
    if (context.mounted &&
        Provider.of<ThemeViewModel>(context, listen: false).hapticEnabled) {
      HapticFeedback.mediumImpact();
    }
  }

  static void vibrate(BuildContext context) {
    if (context.mounted &&
        Provider.of<ThemeViewModel>(context, listen: false).hapticEnabled) {
      HapticFeedback.vibrate();
    }
  }
}
