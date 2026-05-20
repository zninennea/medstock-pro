// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/tenant_provider.dart';
import 'providers/product_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // For web, use different initialization
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } else {
    await Firebase.initializeApp();
  }

  debugPrint('✅ Firebase initialized successfully!');

  final prefs = await SharedPreferences.getInstance();

  runApp(MedStockPro(prefs: prefs));

  // Add error handling for web
  if (kIsWeb) {
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.dumpErrorToConsole(details);
      // You can also send to analytics
    };
  }
}

class MedStockPro extends StatelessWidget {
  final SharedPreferences prefs;

  const MedStockPro({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(prefs)),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => TenantProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'MedStock Pro',
            debugShowCheckedModeBanner: false,
            theme: ThemeData.light().copyWith(
              primaryColor: Colors.blue.shade600,
              scaffoldBackgroundColor: Colors.grey.shade50,
              cardColor: Colors.white,
              colorScheme: ColorScheme.light(
                primary: Colors.blue.shade600,
                secondary: Colors.indigo.shade600,
                surface: Colors.white,
                onSurface: Colors.grey.shade900,
              ),
            ),
            darkTheme: ThemeData.dark().copyWith(
              primaryColor: Colors.blue.shade400,
              scaffoldBackgroundColor: Colors.grey.shade900,
              cardColor: Colors.grey.shade800,
              colorScheme: ColorScheme.dark(
                primary: Colors.blue.shade400,
                secondary: Colors.indigo.shade400,
                surface: Colors.grey.shade800,
                onSurface: Colors.grey.shade100,
              ),
            ),
            themeMode: themeProvider.themeMode,
            home: Consumer<AuthProvider>(
              builder: (context, authProvider, _) {
                if (authProvider.isLoggedIn) {
                  return const MainScreen();
                }
                return const AuthScreen();
              },
            ),
          );
        },
      ),
    );
  }
}
