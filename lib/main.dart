// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'wrapper.dart';
import 'services/app_update_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
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
        visualDensity: VisualDensity.adaptivePlatformDensity,
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
