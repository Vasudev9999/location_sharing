import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'wrapper.dart';
import 'services/app_update_manager.dart';
import 'services/background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize background location service
  try {
    await BackgroundLocationService.initialize();
    print('✅ Background service initialized');
  } catch (e) {
    print('❌ Failed to initialize background service: $e');
  }

  // FIX: Status Bar Visibility
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // Transparent background
      // For Android: Use Brightness.dark for BLACK icons
      statusBarIconBrightness: Brightness.dark,

      // For iOS: Use Brightness.light for BLACK icons (logic is inverted on iOS)
      statusBarBrightness: Brightness.light,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase Auth Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,

        // Ensure status bar style persists across pages
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF0F4F8),
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF1A1A1A)),
          titleTextStyle: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          // Enforce status bar style on AppBars too
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[100],
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16.0,
            horizontal: 16.0,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const _AppWithUpdateCheck(),
    );
  }
}

/// Wrapper widget that checks for updates after the first frame
class _AppWithUpdateCheck extends StatefulWidget {
  const _AppWithUpdateCheck({Key? key}) : super(key: key);

  @override
  State<_AppWithUpdateCheck> createState() => _AppWithUpdateCheckState();
}

class _AppWithUpdateCheckState extends State<_AppWithUpdateCheck> {
  @override
  void initState() {
    super.initState();
    // Check for updates after first frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppUpdateManager().checkAndShowUpdateIfAvailable(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const AuthWrapper();
  }
}
