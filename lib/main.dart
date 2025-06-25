// lib/main.dart - COMPLETELY REMOVED FIREBASE
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'screens/simplified/role_selection_screen.dart';
import 'services/database_service.dart';
import 'services/storage_service.dart';
import 'services/location_service.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // REMOVED: Firebase initialization completely
  // No Firebase needed for local storage version
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final apiBaseUrl = 'http://172.20.10.3:8000'; // Replace with your API URL

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
        title: 'AquaScan - Local Storage',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        home: RoleSelectionScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}