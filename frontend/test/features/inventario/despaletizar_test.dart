import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:frontend/features/inventario/services/inventario_service.dart';
import 'package:frontend/features/inventario/presentation/widgets/dialogo_despaletizar.dart';

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

  group('InventarioService.despaletizarActivo - Unit Tests', () {
    test('despaletizarActivo envía POST y retorna respuesta exitosa', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, contains('/api/v1/inventario/act-123/despaletizar'));
        expect(request.headers['Authorization'], 'Bearer fake-test-jwt-token');

        return http.Response(
          jsonEncode({
            'id_activo': 'act-123',
            'sku_qr_fisico': 'MOT-2686',
            'id_estado': 5,
            'mensaje': 'Activo despaletizado exitosamente.',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final res = await InventarioService.despaletizarActivo('act-123', client: mockClient);
      expect(res['id_estado'], 5);
      expect(res['sku_qr_fisico'], 'MOT-2686');
      expect(res['mensaje'], contains('despaletizado exitosamente'));
    });

    test('despaletizarActivo propaga error de repuesto vendido o inválido', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'detail': 'No es posible despaletizar un repuesto en estado Vendido.',
          }),
          400,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      expect(
        () async => await InventarioService.despaletizarActivo('act-vendido', client: mockClient),
        throwsA(
          predicate((e) => e.toString().contains('No es posible despaletizar')),
        ),
      );
    });
  });

  group('DialogoDespaletizar - Widget & Timer Tests', () {
    testWidgets('Botón de confirmación inicia deshabilitado con contador de 5s', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DialogoDespaletizar(
              idActivo: 'act-999',
              sku: 'MOT-2686',
              categoria: 'Motor',
              numeroIngreso: '2686',
            ),
          ),
        ),
      );

      // Estado inicial (0 segundos transcurridos):
      expect(find.text('Despaletizar Repuesto'), findsOneWidget);
      expect(find.text('Folio Ingreso: 2686'), findsOneWidget);
      expect(find.text('CONFIRMAR (5s)'), findsOneWidget);

      final confirmBtn = tester.widget<ElevatedButton>(
        find.byKey(const Key('btn_confirmar_despaletizado')),
      );
      expect(confirmBtn.onPressed, isNull, reason: 'El botón debe estar deshabilitado al inicio');

      // Avanzar 1 segundo:
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('CONFIRMAR (4s)'), findsOneWidget);
      final confirmBtn1s = tester.widget<ElevatedButton>(
        find.byKey(const Key('btn_confirmar_despaletizado')),
      );
      expect(confirmBtn1s.onPressed, isNull);

      // Avanzar los 4 segundos restantes (total 5s):
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('CONFIRMAR DESPALETIZADO'), findsOneWidget);
      expect(find.text('Verificación completa. Ya puedes confirmar.'), findsOneWidget);

      final confirmBtn5s = tester.widget<ElevatedButton>(
        find.byKey(const Key('btn_confirmar_despaletizado')),
      );
      expect(confirmBtn5s.onPressed, isNotNull, reason: 'El botón debe habilitarse tras 5 segundos');
    });

    testWidgets('Botón Cancelar siempre está disponible y cierra el diálogo', (tester) async {
      bool? resultado;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  resultado = await DialogoDespaletizar.mostrar(
                    context,
                    idActivo: 'act-999',
                    sku: 'MOT-2686',
                    categoria: 'Motor',
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.text('CANCELAR'), findsOneWidget);

      // Cancelar de inmediato mientras está en cuenta regresiva
      await tester.tap(find.byKey(const Key('btn_cancelar_despaletizado')));
      await tester.pumpAndSettle();

      expect(find.text('Despaletizar Repuesto'), findsNothing);
      expect(resultado, isFalse);
    });
  });
}
