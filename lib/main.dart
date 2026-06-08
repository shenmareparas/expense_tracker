import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app/supabase_config.dart';
import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  await SupabaseConfig.initialize();
  runApp(const MyApp());
}
