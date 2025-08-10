// lib/main.dart - UPDATED: Direct to User Screen
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'screens/splash_screen.dart';
import 'screens/simplified/simple_user_screen.dart'; // Import user screen
import 'services/database_service.dart';
import 'services/storage_service.dart';
import 'services/location_service.dart';
import 'services/api_service.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final apiBaseUrl = Platform.isAndroid 
      ? 'http://10.62.48.206:8000'
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
        home: const SplashScreen(), // Keep splash, but it will go to user screen
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}