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
      'marca': 'Toyota',
      'modelo': 'Corolla',
      'anio': 2021,
      'pasillo': 'P-01',
      'pallet': 'PL-02',
      'galpon': 'G-Principal',
      'observacion': 'Excelente estado',
      'numero_motor': '1NZ-FE',
      'cilindrada': '1.5L',
      'combustible': 'Gasolina',
      'transmision': 'Manual',
      'traccion': 'FWD',
      'version_lock': 1,
    };

    testWidgets('Renderiza campos iniciales de activo para edición de vehículo, ubicación y specs', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditarActivoModal(activo: activoMotor),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Editar Activo: Motor'), findsOneWidget);
      expect(find.text('SKU: MOT-123'), findsOneWidget);
      expect(find.text('Toyota'), findsOneWidget);
      expect(find.text('Corolla'), findsOneWidget);
      expect(find.text('2021'), findsOneWidget);
      expect(find.text('P-01'), findsOneWidget);
      expect(find.text('PL-02'), findsOneWidget);
      expect(find.text('G-Principal'), findsOneWidget);
      expect(find.text('1NZ-FE'), findsOneWidget);
      expect(find.text('1.5L'), findsOneWidget);
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
      expect(find.text('Descartar cambios'), findsNothing);
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

      // Debe aparecer el diálogo con el texto correspondiente
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

      expect(find.text('Editar Activo: Motor'), findsNothing);
    });

    testWidgets('Modificar marca o modelo activa dirty check y muestra diálogo', (tester) async {
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

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      // Modificar Marca
      final marcaField = find.widgetWithText(TextField, 'Toyota');
      expect(marcaField, findsOneWidget);
      await tester.enterText(marcaField, 'Nissan');
      await tester.pumpAndSettle();

      // Presionar CANCELAR
      await tester.tap(find.text('CANCELAR'));
      await tester.pumpAndSettle();

      expect(find.text('Descartar cambios'), findsOneWidget);
    });

    testWidgets('Permite editar cilindrada, transmisión y tracción en activos de categoría Caja', (tester) async {
      final activoCaja = {
        'id_activo': 'caj-555',
        'sku': 'CAJ-HON-001',
        'categoria': 'Caja de Cambio',
        'marca': 'Honda',
        'modelo': 'Civic',
        'anio': 2019,
        'pasillo': 'P-03',
        'pallet': 'PL-11',
        'galpon': 'G-1',
        'transmision': 'Manual',
        'traccion': 'FWD',
        'cilindrada': '2.0L',
        'combustible': 'Gasolina',
        'version_lock': 1,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditarActivoModal(activo: activoCaja),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Editar Activo: Caja de Cambio'), findsOneWidget);
      expect(find.text('Honda'), findsOneWidget);
      expect(find.text('Civic'), findsOneWidget);
      expect(find.text('2019'), findsOneWidget);
      expect(find.text('2.0L'), findsOneWidget);
      expect(find.text('ESPECIFICACIONES TÉCNICAS'), findsOneWidget);
    });
  });
}
