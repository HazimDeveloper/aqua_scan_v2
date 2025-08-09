// lib/main.dart - COMPLETELY REMOVED FIREBASE
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'screens/splash_screen.dart'; // Import the splash screen
import 'screens/simplified/role_selection_screen.dart';
import 'services/database_service.dart';
import 'services/storage_service.dart';
import 'services/location_service.dart';
import 'services/api_service.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // REMOVED: Firebase initialization completely

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // Using UiTM network IP address
  final apiBaseUrl = Platform.isAndroid 
      ? 'http://10.62.48.206:8000'  // Your Wi-Fi IPv4 address
      : 'http://localhost:8000';

  MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<DatabaseService>(
          create: (_) => DatabaseService(),
        ),
        Provider<StorageService>(
          create: (_) => StorageService(),
        ),
        Provider<LocationService>(
          create: (_) => LocationService(),
        ),
        Provider<ApiService>(
          create: (_) => ApiService(baseUrl: apiBaseUrl),
        ),
      ],
      child: MaterialApp(
        title: 'nadiAir',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        home: const SplashScreen(), // Changed from RoleSelectionScreen to SplashScreen
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}