// test/auditoria_salida_test.dart
// Suite de pruebas unitarias y de widgets para HU-3.6 (Fase 4): Auditoría de Salida y Dual-Scan en Bodega.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:frontend/features/alertas/models/tarea_alerta.dart';
import 'package:frontend/features/alertas/services/logistica_service.dart';
import 'package:frontend/features/alertas/presentation/screens/auditoria_salida_screen.dart';

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

  const mockTareaLiberada = TareaAlerta(
    idTarea: 'ORD-12345678',
    tipoAlerta: 'LIBERADA',
    ordenRef: 'ORDEN #EFA94DF2',
    tituloPieza: 'Motor - Toyota Yaris (2019)',
    ubicacion: 'P-03 - PL-07',
    notaEspecial: 'Entregar con alternador incluido',
    estadoBloqueo: null,
    accionRequerida: 'ESCANEAR EN BARRERA',
  );

  // ===========================================================================
  // 1. PRUEBAS DE MODELOS Y DTOs (HU-3.6)
  // ===========================================================================
  group('LogisticaService DTO & Model Tests', () {
    test('EscanearSalidaResponseModel.fromJson parsea datos correctamente', () {
      final jsonMock = {
        'id_orden': '3fa85f64-5717-4562-b3fc-2c963f66afa6',
        'folio': 'ORD-3FA85F64',
        'estado_orden': 'Completada',
        'id_bodeguero': '4b8a34e5-cd9d-4a18-bea2-9f5ee05a22f4',
        'bodeguero_nombre': 'Martín Bodeguero',
        'fecha_entrega': '2026-08-15T04:00:00',
        'activos_entregados': ['MOT-TOY-YAR-888'],
        'total_entregados': 1,
        'mensaje': '¡Entrega en barrera autorizada exitosamente!',
      };

      final model = EscanearSalidaResponseModel.fromJson(jsonMock);

      expect(model.idOrden, '3fa85f64-5717-4562-b3fc-2c963f66afa6');
      expect(model.folio, 'ORD-3FA85F64');
      expect(model.estadoOrden, 'Completada');
      expect(model.bodegueroNombre, 'Martín Bodeguero');
      expect(model.totalEntregados, 1);
      expect(model.activosEntregados, ['MOT-TOY-YAR-888']);
      expect(model.mensaje, '¡Entrega en barrera autorizada exitosamente!');
    });

    test('VerificarQrSalidaResponseModel.fromJson parsea ítems requeridos', () {
      final jsonMock = {
        'id_orden': '3fa85f64-5717-4562-b3fc-2c963f66afa6',
        'folio': 'ORD-3FA85F64',
        'estado_orden': 'Pagada',
        'total_venta': 500000,
        'monto_pendiente': 0,
        'id_sucursal': 1,
        'cliente_nombre': 'Roberto Gómez',
        'cliente_rut': '12.345.678-9',
        'total_items_fisicos': 1,
        'qr_transaccional_salida': 'TX-QR-3FA85F64-ABC123DEF456',
        'items_requeridos': [
          {
            'id_detalle': 'det-001',
            'id_activo': 'act-001',
            'titulo': 'Motor Toyota',
            'sku_qr_fisico': 'MOT-TOY-YAR-888',
            'es_inventariado': true,
            'ubicacion': 'P-03 - PL-07',
            'notas_preparacion': 'Revisar correas',
            'cantidad': 1,
            'precio_final': 500000,
          }
        ]
      };

      final model = VerificarQrSalidaResponseModel.fromJson(jsonMock);

      expect(model.folio, 'ORD-3FA85F64');
      expect(model.clienteNombre, 'Roberto Gómez');
      expect(model.totalItemsFisicos, 1);
      expect(model.itemsRequeridos.length, 1);
      expect(model.itemsRequeridos.first.skuQrFisico, 'MOT-TOY-YAR-888');
      expect(model.itemsRequeridos.first.esInventariado, true);
    });
  });

  // ===========================================================================
  // 2. PRUEBAS DE SERVICIO HTTP: LogisticaService
  // ===========================================================================
  group('LogisticaService HTTP Tests', () {
    test('escanearSalida exitoso retorna EscanearSalidaResponseModel', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/escanear-salida')) {
          final body = jsonDecode(request.body);
          expect(body['qr_transaccional_salida'], 'TX-QR-3FA85F64-ABC123DEF456');
          expect(body['skus_escaneados'], ['MOT-TOY-YAR-888']);

          return http.Response(
            jsonEncode({
              'id_orden': '3fa85f64-5717-4562-b3fc-2c963f66afa6',
              'folio': 'ORD-3FA85F64',
              'estado_orden': 'Completada',
              'id_bodeguero': '4b8a34e5-cd9d-4a18-bea2-9f5ee05a22f4',
              'bodeguero_nombre': 'Martín Bodeguero',
              'fecha_entrega': '2026-08-15T04:00:00',
              'activos_entregados': ['MOT-TOY-YAR-888'],
              'total_entregados': 1,
              'mensaje': '¡Entrega en barrera autorizada exitosamente!',
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final result = await LogisticaService.escanearSalida(
        qrTransaccionalSalida: 'TX-QR-3FA85F64-ABC123DEF456',
        skusEscaneados: ['MOT-TOY-YAR-888'],
        client: mockClient,
      );

      expect(result.estadoOrden, 'Completada');
      expect(result.totalEntregados, 1);
      expect(result.folio, 'ORD-3FA85F64');
    });

    test('escanearSalida con error 400 lanza Exception con detail', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'El repuesto con SKU \'SKU-AJENO\' no pertenece a esta orden.'}),
          400,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      expect(
        () async => await LogisticaService.escanearSalida(
          qrTransaccionalSalida: 'TX-QR-3FA85F64-ABC123DEF456',
          skusEscaneados: ['SKU-AJENO'],
          client: mockClient,
        ),
        throwsA(predicate((e) => e.toString().contains('no pertenece a esta orden'))),
      );
    });
  });

  // ===========================================================================
  // 3. PRUEBAS DE WIDGET: AuditoriaSalidaScreen (HU-3.6)
  // ===========================================================================
  group('AuditoriaSalidaScreen UI & Zero-Click Tests', () {
    testWidgets('Renderiza estructura inicial con tarjetas de escaneo vacías y retícula', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: AuditoriaSalidaScreen(tarea: mockTareaLiberada),
        ),
      );

      await tester.pump();

      // Cabecera y badges
      expect(find.text('AUDITORÍA DE SALIDA'), findsOneWidget);
      expect(find.text('ESCÁNER ACTIVO'), findsOneWidget);
      expect(find.text('1. Escanee QR de la Pieza Física'), findsOneWidget);
      expect(find.text('2. Escanee Ticket Digital (Tablet Vendedor)'), findsOneWidget);

      // Estado inicial: ninguno completo
      expect(find.text('LISTO'), findsNothing);
      expect(find.text('MATCH EXITOSO EN BARRERA'), findsNothing);
    });

    testWidgets('Captura de SKU físico actualiza Tarjeta 1 con chip y check', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: AuditoriaSalidaScreen(tarea: mockTareaLiberada),
        ),
      );

      await tester.pump();

      // Ingresar SKU en el simulador
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      await tester.enterText(textField, 'MOT-TOY-YAR-888');
      await tester.tap(find.text('Capturar'));
      await tester.pump();

      // Tarjeta 1 debe marcarse como lista y mostrar el chip
      expect(find.text('MOT-TOY-YAR-888'), findsOneWidget);
      expect(find.text('LISTO'), findsOneWidget);

      // Tarjeta 2 debe seguir esperando
      expect(find.text('Apunta a la pantalla del vendedor (TX-QR-...)'), findsOneWidget);
    });

    testWidgets('Captura de Token Digital actualiza Tarjeta 2', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: AuditoriaSalidaScreen(tarea: mockTareaLiberada),
        ),
      );

      await tester.pump();

      // Ingresar Token del Vendedor
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'TX-QR-170C311C-ABCD1234EF56');
      await tester.tap(find.text('Capturar'));
      await tester.pump();

      // Tarjeta 2 debe marcarse como lista
      expect(find.text('TX-QR-170C311C-ABCD1234EF56'), findsOneWidget);
      expect(find.text('LISTO'), findsOneWidget);
    });
  });
}
