import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/splash_screen.dart';
import 'features/auth/presentation/pin_login_screen.dart';
import 'features/home/presentation/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cresal Capstone',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark, // Oscuro por defecto industrial

      // Pantalla inicial: Splash que decide la ruta según sesión
      home: const SplashScreen(),

      // Rutas nombradas de la aplicación
      routes: {
        '/login': (context) => const PinLoginScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}
