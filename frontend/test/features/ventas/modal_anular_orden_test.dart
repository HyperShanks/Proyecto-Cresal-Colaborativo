import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:frontend/features/ventas/services/ventas_service.dart';
import 'package:frontend/features/ventas/presentation/widgets/modal_anular_orden.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'read') {
          return 'fake-test-jwt-token';
        }
        return null;
      },
    );
  });

  group('VentasService - Anulación ACID Unit Tests', () {
    test('anularOrden envía POST con motivo_anulacion y parsea 200', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, contains('/anular'));

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['motivo_anulacion'], 'Cliente solicitó desistimiento');

        return http.Response(
          jsonEncode({
            'id_orden': 'ord-123',
            'estado_orden': 'Anulada',
            'mensaje': 'Orden anulada, pagos reversados y tareas de reingreso generadas',
            'activos_liberados': 2,
            'pagos_reversados': 1,
            'motivo_anulacion': 'Cliente solicitó desistimiento',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final res = await VentasService.anularOrden(
        'ord-123',
        motivoAnulacion: 'Cliente solicitó desistimiento',
        client: mockClient,
      );

      expect(res['estado_orden'], 'Anulada');
      expect(res['pagos_reversados'], 1);
      expect(res['activos_liberados'], 2);
    });

    test('anularOrden lanza excepción descriptiva ante error 400', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'La orden ya se encuentra anulada.'}),
          400,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      expect(
        () => VentasService.anularOrden('ord-123', client: mockClient),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('ModalAnularOrden - Widget Tests', () {
    testWidgets('Renderiza elementos de advertencia, folio y campos', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    ModalAnularOrden.mostrar(
                      context,
                      idOrden: 'ord-abc-123',
                      folio: 'ORD-ABC12345',
                      clienteNombre: 'Juan Pérez',
                    );
                  },
                  child: const Text('Abrir Modal'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Modal'));
      await tester.pumpAndSettle();

      expect(find.text('¿Deshacer esta Orden?'), findsOneWidget);
      expect(find.text('Folio: ORD-ABC12345'), findsOneWidget);
      expect(find.text('Cliente: Juan Pérez'), findsOneWidget);
      expect(find.text('Confirmar Anulación'), findsOneWidget);
      expect(find.text('Volver'), findsOneWidget);
    });

    testWidgets('Permite cerrar el modal con botón Volver', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    ModalAnularOrden.mostrar(
                      context,
                      idOrden: 'ord-abc-123',
                      folio: 'ORD-ABC12345',
                    );
                  },
                  child: const Text('Abrir Modal'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Modal'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();

      expect(find.text('¿Deshacer esta Orden?'), findsNothing);
    });
  });
}
