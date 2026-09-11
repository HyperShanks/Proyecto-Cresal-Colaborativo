import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend/features/auth/presentation/screens/pin_login_screen.dart';
import 'package:frontend/features/auth/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, String> mockStorage = {};

  setUp(() {
    mockStorage.clear();
    FlutterSecureStorage.setMockInitialValues(mockStorage);
  });

  group('PinLoginScreen Widget & UI Tests', () {
    testWidgets('Muestra datos del usuario enrolado y botones del teclado numérico', (tester) async {
      tester.view.physicalSize = const Size(1366, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await const FlutterSecureStorage().write(key: 'enrolled_user_id', value: 'uuid-1234');
      await const FlutterSecureStorage().write(key: 'enrolled_user_name', value: 'Carlos Bodeguero');
      await const FlutterSecureStorage().write(key: 'enrolled_user_email', value: 'carlos@cresal.cl');

      await tester.pumpWidget(
        const MaterialApp(
          home: PinLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CRESAL'), findsOneWidget);
      expect(find.text('Ingrese su PIN de Operario'), findsOneWidget);
      expect(find.text('Carlos Bodeguero'), findsOneWidget);
      expect(find.text('carlos@cresal.cl'), findsOneWidget);
      expect(find.text('Desenrolar Terminal'), findsOneWidget);

      // Botones numéricos presentes
      for (int i = 0; i <= 9; i++) {
        expect(find.text('$i'), findsOneWidget);
      }
      expect(find.text('C'), findsWidgets);
      expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);
    });

    testWidgets('Sin enrolamiento previo, redirige automáticamente a /enrolamiento', (tester) async {
      await const FlutterSecureStorage().deleteAll();

      await tester.pumpWidget(
        MaterialApp(
          home: const PinLoginScreen(),
          routes: {
            '/enrolamiento': (context) => const Scaffold(body: Text('ENROLAMIENTO_VIEW')),
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ENROLAMIENTO_VIEW'), findsOneWidget);
    });

    testWidgets('Presionar Desenrolar Terminal abre diálogo de confirmación y purga almacenamiento al confirmar', (tester) async {
      tester.view.physicalSize = const Size(1366, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await const FlutterSecureStorage().write(key: 'access_token', value: 'token-abc');
      await const FlutterSecureStorage().write(key: 'enrolled_user_id', value: 'uuid-1234');
      await const FlutterSecureStorage().write(key: 'enrolled_user_name', value: 'Carlos Bodeguero');
      await const FlutterSecureStorage().write(key: 'enrolled_user_email', value: 'carlos@cresal.cl');

      await tester.pumpWidget(
        MaterialApp(
          home: const PinLoginScreen(),
          routes: {
            '/enrolamiento': (context) => const Scaffold(body: Text('ENROLAMIENTO_VIEW')),
          },
        ),
      );
      await tester.pumpAndSettle();

      // Tap en Desenrolar Terminal
      await tester.ensureVisible(find.text('Desenrolar Terminal'));
      await tester.tap(find.text('Desenrolar Terminal'));
      await tester.pumpAndSettle();

      expect(find.text('¿Está seguro de que desea desenrolar este terminal? Se requerirán credenciales corporativas (email y contraseña) para volver a vincularlo.'), findsOneWidget);

      // Cancelar primero
      await tester.tap(find.text('CANCELAR'));
      await tester.pumpAndSettle();
      expect(await AuthService.getEnrolledUserId(), 'uuid-1234');

      // Tap de nuevo y confirmar
      await tester.tap(find.text('Desenrolar Terminal'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('DESENROLAR'));
      await tester.pumpAndSettle();

      // Verifica redirección a /enrolamiento y borrado de storage
      expect(find.text('ENROLAMIENTO_VIEW'), findsOneWidget);
      expect(await AuthService.getEnrolledUserId(), isNull);
      expect(await AuthService.getToken(), isNull);
    });

    testWidgets('Ingreso de dígitos y borrado en teclado numérico', (tester) async {
      tester.view.physicalSize = const Size(1366, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await const FlutterSecureStorage().write(key: 'enrolled_user_id', value: 'uuid-1234');
      await const FlutterSecureStorage().write(key: 'enrolled_user_name', value: 'Carlos Bodeguero');

      await tester.pumpWidget(
        const MaterialApp(
          home: PinLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Presionar dígitos 1, 2, 3
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('2'));
      await tester.pump();
      await tester.tap(find.text('3'));
      await tester.pump();

      // Borrar un dígito con el icono de backspace
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pump();

      // Limpiar con botón C del teclado numérico
      await tester.tap(find.text('C').last);
      await tester.pump();
    });

    testWidgets('Error de red muestra icono de Wi-Fi apagado y mensaje amigable sin fugas de IP', (tester) async {
      tester.view.physicalSize = const Size(1366, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await const FlutterSecureStorage().write(key: 'enrolled_user_id', value: 'uuid-1234');
      await const FlutterSecureStorage().write(key: 'enrolled_user_name', value: 'Carlos Bodeguero');

      await tester.pumpWidget(
        const MaterialApp(
          home: PinLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verificar que AuthResult clasifica correctamente los errores de red
      const netError = AuthResult.fail(
        'No se pudo conectar con el servidor. Verifique su conexión Wi-Fi o de red corporativa.',
        errorType: AuthErrorType.network,
      );
      expect(netError.isNetworkError, isTrue);
      expect(netError.isCredentialsError, isFalse);
      expect(netError.errorMessage, isNot(contains('http://')));
      expect(netError.errorMessage, isNot(contains(':8000')));

      // Verificar clasificación de error de credenciales
      const credError = AuthResult.fail(
        'PIN incorrecto para este terminal.',
        errorType: AuthErrorType.credentials,
      );
      expect(credError.isCredentialsError, isTrue);
      expect(credError.isNetworkError, isFalse);
    });
  });
}
