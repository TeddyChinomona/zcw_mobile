// lib/main.dart
//
// Application entry point.
// Sets up the ChangeNotifierProvider tree and launches the app.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import './screens/splash_screen.dart';
import './services/crime_provider.dart';
import './theme/app_theme.dart';

void main() {
  // Ensure Flutter's binding is ready before calling platform channels
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait-up to avoid map re-layout jank on rotation
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Make the status bar transparent so the green app bar bleeds into it
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const ZimCrimeWatchApp());
}

class ZimCrimeWatchApp extends StatelessWidget {
  const ZimCrimeWatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // CrimeProvider is created here at the root so every screen
      // can access it via context.watch / context.read without re-fetching
      create: (_) => CrimeProvider(),
      child: MaterialApp(
        title: 'ZimCrimeWatch',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
