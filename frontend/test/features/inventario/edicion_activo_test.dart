import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:frontend/features/inventario/services/inventario_service.dart';
import 'package:frontend/features/inventario/presentation/widgets/editar_activo_modal.dart';

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

  group('InventarioService.editarActivo - Unit Tests', () {
    test('editarActivo envía PATCH con datos correctos y retorna 200', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, contains('/api/v1/inventario/act-123'));
        expect(request.headers['Authorization'], 'Bearer fake-test-jwt-token');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['ubicacion_pasillo'], 'P-04');
        expect(body['ubicacion_pallet'], 'PL-15');
        expect(body['version_lock_esperado'], 1);

        return http.Response(
          jsonEncode({
            'id_activo': 'act-123',
            'sku_qr_fisico': 'MOT-TOY-001',
            'ubicacion_pasillo': 'P-04',
            'ubicacion_pallet': 'PL-15',
            'ubicacion_galpon': 'G-A',
            'observacion_estado': 'Verificado',
            'version_lock': 2,
            'mensaje': 'Activo actualizado exitosamente.',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final res = await InventarioService.editarActivo(
        'act-123',
        {
          'ubicacion_pasillo': 'P-04',
          'ubicacion_pallet': 'PL-15',
          'version_lock_esperado': 1,
        },
        client: mockClient,
      );

      expect(res['version_lock'], 2);
      expect(res['ubicacion_pasillo'], 'P-04');
      expect(res['ubicacion_pallet'], 'PL-15');
    });

    test('editarActivo maneja error 409 con mensaje estandarizado de concurrencia', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'detail':
                'La información de este repuesto fue modificada por otro usuario recientemente. Los datos se actualizarán ahora para que revises los cambios antes de volver a editar.',
          }),
          409,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      expect(
        () async => await InventarioService.editarActivo(
          'act-123',
          {'version_lock_esperado': 1},
          client: mockClient,
        ),
        throwsA(
          predicate((e) =>
              e.toString().contains('modificada por otro usuario recientemente')),
        ),
      );
    });

    test('editarActivo maneja error 400 de pieza vendida/despachada', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'detail':
                'Este artículo ya fue despachado o cobrado. Ya no es posible modificar su ubicación técnica.',
          }),
          400,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      expect(
        () async => await InventarioService.editarActivo(
          'act-123',
          {'version_lock_esperado': 1},
          client: mockClient,
        ),
        throwsA(
          predicate((e) =>
              e.toString().contains('ya fue despachado o cobrado')),
        ),
      );
    });
  });

  group('EditarActivoModal - Widget Tests & Dirty Check', () {
    final activoMotor = {
      'id_activo': 'act-999',
      'sku': 'MOT-123',
      'categoria': 'Motor',
      'pasillo': 'P-01',
      'pallet': 'PL-02',
      'galpon': 'G-Principal',
      'observacion': 'Excelente estado',
      'numero_motor': '1NZ-FE',
      'cilindrada': '1.5L',
      'version_lock': 1,
    };

    testWidgets('Renderiza campos iniciales de activo y especificaciones de motor', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditarActivoModal(activo: activoMotor),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Editar Información del Activo'), findsOneWidget);
      expect(find.text('SKU: MOT-123'), findsOneWidget);
      expect(find.text('P-01'), findsOneWidget);
      expect(find.text('PL-02'), findsOneWidget);
      expect(find.text('G-Principal'), findsOneWidget);
      expect(find.text('1NZ-FE'), findsOneWidget);
      expect(find.text('1.5L'), findsOneWidget);
      expect(find.text('Excelente estado'), findsOneWidget);
      expect(find.text('GUARDAR CAMBIOS'), findsOneWidget);
      expect(find.text('CANCELAR'), findsOneWidget);
    });

    testWidgets('Cancelar sin cambios cierra el modal sin diálogo de confirmación', (tester) async {
      bool dialogShown = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (_) => EditarActivoModal(activo: activoMotor),
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );

      // Abrir modal
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.text('CANCELAR'), findsOneWidget);

      // Tocar cancelar
      await tester.tap(find.text('CANCELAR'));
      await tester.pumpAndSettle();

      // No debe mostrar diálogo de cambios sin guardar
      expect(find.text('Tienes cambios sin guardar. ¿Estás seguro de que quieres salir y descartar las modificaciones?'), findsNothing);
      expect(dialogShown, isFalse);
    });

    testWidgets('Cancelar con formulario sucio activa diálogo de descarte', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (_) => EditarActivoModal(activo: activoMotor),
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );

      // Abrir modal
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      // Modificar el campo pasillo para ponerlo "sucio" (dirty)
      final pasilloField = find.widgetWithText(TextField, 'P-01');
      expect(pasilloField, findsOneWidget);
      await tester.enterText(pasilloField, 'P-99');
      await tester.pumpAndSettle();

      // Presionar CANCELAR
      await tester.tap(find.text('CANCELAR'));
      await tester.pumpAndSettle();

      // Debe aparecer el diálogo con el texto exigido en SPEC-HU-TAREA-11
      expect(find.text('Descartar cambios'), findsOneWidget);
      expect(
        find.text('Tienes cambios sin guardar. ¿Estás seguro de que quieres salir y descartar las modificaciones?'),
        findsOneWidget,
      );

      // Si se pulsa "Seguir editando", el diálogo se retira y permanece el modal
      await tester.tap(find.text('Seguir editando'));
      await tester.pumpAndSettle();

      expect(find.text('Descartar cambios'), findsNothing);
      expect(find.text('GUARDAR CAMBIOS'), findsOneWidget);

      // Ahora si se pulsa "CANCELAR" y luego "Descartar", el modal se cierra
      await tester.tap(find.text('CANCELAR'));
      await tester.pumpAndSettle();
      expect(find.text('Descartar cambios'), findsOneWidget);

      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();

      expect(find.text('Editar Información del Activo'), findsNothing);
    });
  });
}
