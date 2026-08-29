// test/login_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend/features/auth/services/auth_service.dart';
import 'package:frontend/features/auth/presentation/screens/splash_screen.dart';
import 'package:frontend/features/home/presentation/screens/home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, String> mockStorage = {};

  setUp(() {
    mockStorage.clear();
    FlutterSecureStorage.setMockInitialValues(mockStorage);
  });

  group('AuthService - Role Resolution & Helper Tests', () {
    test('esModuloVentas retorna true para id_rol 2 (Vendedor), 6 (Jefe de Ventas) y 7 (VendedorOnline)', () async {
      // Test id_rol 2
      await const FlutterSecureStorage().write(key: 'user_id_rol', value: '2');
      await const FlutterSecureStorage().write(key: 'user_rol', value: 'Vendedor');
      expect(await AuthService.esModuloVentas(), isTrue);

      // Test id_rol 6
      await const FlutterSecureStorage().write(key: 'user_id_rol', value: '6');
      await const FlutterSecureStorage().write(key: 'user_rol', value: 'Jefe de Ventas');
      expect(await AuthService.esModuloVentas(), isTrue);

      // Test id_rol 7
      await const FlutterSecureStorage().write(key: 'user_id_rol', value: '7');
      await const FlutterSecureStorage().write(key: 'user_rol', value: 'Vendedor Online');
      expect(await AuthService.esModuloVentas(), isTrue);
    });

    test('esModuloVentas retorna false para id_rol 1 (Bodeguero) y 3 (Caja)', () async {
      await const FlutterSecureStorage().write(key: 'user_id_rol', value: '1');
      await const FlutterSecureStorage().write(key: 'user_rol', value: 'Bodeguero');
      expect(await AuthService.esModuloVentas(), isFalse);

      await const FlutterSecureStorage().write(key: 'user_id_rol', value: '3');
      await const FlutterSecureStorage().write(key: 'user_rol', value: 'Caja');
      expect(await AuthService.esModuloVentas(), isFalse);
    });

    test('esVendedorOnline retorna true solo para id_rol 7', () async {
      await const FlutterSecureStorage().write(key: 'user_id_rol', value: '7');
      expect(await AuthService.esVendedorOnline(), isTrue);

      await const FlutterSecureStorage().write(key: 'user_id_rol', value: '2');
      expect(await AuthService.esVendedorOnline(), isFalse);
    });
  });

  group('SplashScreen - Navigation Routing Tests', () {
    testWidgets('Sin enrolamiento ni sesión redirige a /enrolamiento', (tester) async {
      await const FlutterSecureStorage().deleteAll();

      await tester.pumpWidget(
        MaterialApp(
          home: const SplashScreen(),
          routes: {
            '/enrolamiento': (context) => const Scaffold(body: Text('ENROLAMIENTO_SCREEN')),
            '/login': (context) => const Scaffold(body: Text('LOGIN_SCREEN')),
            '/home': (context) => const Scaffold(body: Text('HOME_SCREEN')),
            '/ventas_main': (context) => const Scaffold(body: Text('VENTAS_MAIN_SCREEN')),
          },
        ),
      );

      // Avanzar tiempo del splash
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();

      expect(find.text('ENROLAMIENTO_SCREEN'), findsOneWidget);
    });

    testWidgets('Terminal enrolado sin sesión activa redirige a /login (PIN)', (tester) async {
      await const FlutterSecureStorage().deleteAll();
      await const FlutterSecureStorage().write(key: 'enrolled_user_id', value: 'user-uuid-123');
      await const FlutterSecureStorage().write(key: 'enrolled_user_email', value: 'operario@cresal.cl');

      await tester.pumpWidget(
        MaterialApp(
          home: const SplashScreen(),
          routes: {
            '/enrolamiento': (context) => const Scaffold(body: Text('ENROLAMIENTO_SCREEN')),
            '/login': (context) => const Scaffold(body: Text('LOGIN_SCREEN')),
            '/home': (context) => const Scaffold(body: Text('HOME_SCREEN')),
            '/ventas_main': (context) => const Scaffold(body: Text('VENTAS_MAIN_SCREEN')),
          },
        ),
      );

      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();

      expect(find.text('LOGIN_SCREEN'), findsOneWidget);
    });

    testWidgets('VendedorOnline (id_rol == 7) redirige a /ventas_main', (tester) async {
      await const FlutterSecureStorage().write(key: 'access_token', value: 'mock-token-7');
      await const FlutterSecureStorage().write(key: 'user_id_rol', value: '7');
      await const FlutterSecureStorage().write(key: 'user_rol', value: 'Vendedor Online');

      await tester.pumpWidget(
        MaterialApp(
          home: const SplashScreen(),
          routes: {
            '/login': (context) => const Scaffold(body: Text('LOGIN_SCREEN')),
            '/home': (context) => const Scaffold(body: Text('HOME_SCREEN')),
            '/ventas_main': (context) => const Scaffold(body: Text('VENTAS_MAIN_SCREEN')),
          },
        ),
      );

      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();

      expect(find.text('VENTAS_MAIN_SCREEN'), findsOneWidget);
    });

    testWidgets('Vendedor regular (id_rol == 2) redirige a /ventas_main', (tester) async {
      await const FlutterSecureStorage().write(key: 'access_token', value: 'mock-token-2');
      await const FlutterSecureStorage().write(key: 'user_id_rol', value: '2');
      await const FlutterSecureStorage().write(key: 'user_rol', value: 'Vendedor');

      await tester.pumpWidget(
        MaterialApp(
          home: const SplashScreen(),
          routes: {
            '/login': (context) => const Scaffold(body: Text('LOGIN_SCREEN')),
            '/home': (context) => const Scaffold(body: Text('HOME_SCREEN')),
            '/ventas_main': (context) => const Scaffold(body: Text('VENTAS_MAIN_SCREEN')),
          },
        ),
      );

      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();

      expect(find.text('VENTAS_MAIN_SCREEN'), findsOneWidget);
    });

    testWidgets('Bodeguero (id_rol == 1) redirige a /home', (tester) async {
      await const FlutterSecureStorage().write(key: 'access_token', value: 'mock-token-1');
      await const FlutterSecureStorage().write(key: 'user_id_rol', value: '1');
      await const FlutterSecureStorage().write(key: 'user_rol', value: 'Bodeguero');

      await tester.pumpWidget(
        MaterialApp(
          home: const SplashScreen(),
          routes: {
            '/login': (context) => const Scaffold(body: Text('LOGIN_SCREEN')),
            '/home': (context) => const Scaffold(body: Text('HOME_SCREEN')),
            '/ventas_main': (context) => const Scaffold(body: Text('VENTAS_MAIN_SCREEN')),
          },
        ),
      );

      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();

      expect(find.text('HOME_SCREEN'), findsOneWidget);
    });
  });

  group('HomeScreen - Guard Routing for Sales Roles', () {
    testWidgets('Usuario de ventas (id_rol == 7) es interceptado y redirigido a /ventas_main', (tester) async {
      await const FlutterSecureStorage().write(key: 'access_token', value: 'mock-token-7');
      await const FlutterSecureStorage().write(key: 'user_id_rol', value: '7');
      await const FlutterSecureStorage().write(key: 'user_rol', value: 'Vendedor Online');

      await tester.pumpWidget(
        MaterialApp(
          home: const HomeScreen(),
          routes: {
            '/login': (context) => const Scaffold(body: Text('LOGIN_SCREEN')),
            '/ventas_main': (context) => const Scaffold(body: Text('VENTAS_MAIN_SCREEN')),
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('VENTAS_MAIN_SCREEN'), findsOneWidget);
    });
  });
}
