// test/historial_screen_test.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:frontend/features/ventas/services/ordenes_service.dart';
import 'package:frontend/features/ventas/presentation/widgets/orden_card.dart';
import 'package:frontend/features/ventas/presentation/widgets/orden_detail_sheet.dart';
import 'package:frontend/features/ventas/presentation/widgets/historial_filtros_drawer.dart';
import 'package:frontend/features/ventas/presentation/screens/historial_screen.dart';

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

  final ordenMock = OrdenHistorialModel(
    idOrden: '3fa85f64-5717-4562-b3fc-2c963f66afa6',
    estadoOrden: 'Reservada',
    totalVenta: 520000,
    montoPendiente: 520000,
    qrTransaccionalSalida: 'ORD-TEST-001',
    fechaCreacion: '2026-08-14T10:30:00',
    totalItems: 2,
    cliente: const ClienteOrdenResumenModel(
      rutCliente: '18.765.432-1',
      nombres: 'Carlos',
      apellidos: 'González',
      telefono: '+56912345678',
      correo: 'carlos@correo.cl',
      comuna: 'Viña del Mar',
    ),
    despacho: const DespachoOrdenResumenModel(
      idDespacho: 'desp-001',
      direccionEnvio: 'Av. Libertad 1234, Depto 402',
      receptorNombres: 'Carlos González',
      receptorRut: '18.765.432-1',
      receptorTelefono: '+56912345678',
      estadoDespacho: 'Por Enviar',
    ),
    detalles: [
      DetalleOrdenItemModel(
        idDetalle: 'det-001',
        idActivo: 'act-001',
        titulo: 'Motor - Toyota Yaris 2018',
        skuQrFisico: 'MOT-TOY-YAR-001',
        notasPreparacion: 'Entregar con poleas y cables',
        cantidad: 1,
        precioUnitario: 500000,
        precioFinal: 500000,
        subtotal: 500000,
        esInventariado: true,
      ),
      DetalleOrdenItemModel(
        idDetalle: 'det-002',
        titulo: 'Líquido Refrigerante Premium',
        descripcionManual: 'Bidón 5L Verde',
        notasPreparacion: null,
        cantidad: 1,
        precioUnitario: 20000,
        precioFinal: 20000,
        subtotal: 20000,
        esInventariado: false,
      ),
    ],
  );

  group('OrdenHistorialModel Unit Tests', () {
    test('fromJson y getters parsean datos y formatos correctamente', () {
      final json = {
        'id_orden': '11111111-2222-3333-4444-555555555555',
        'estado_orden': 'Reservada',
        'total_venta': 520000,
        'monto_pendiente': 520000,
        'qr_transaccional_salida': 'ORD-A1B2C3D4',
        'fecha_creacion': '2026-08-14T14:30:00',
        'total_items': 1,
        'cliente': {
          'rut_cliente': '19.876.543-2',
          'nombres': 'María',
          'apellidos': 'Pérez',
          'telefono': '+56987654321',
          'correo': 'maria@correo.cl',
          'comuna': 'Valparaíso',
        },
        'despacho': {
          'id_despacho': 'd-1',
          'direccion_envio': 'Calle Prat 500',
          'receptor_nombres': 'María Pérez',
          'receptor_rut': '19.876.543-2',
          'receptor_telefono': '+56987654321',
          'estado_despacho': 'Por Enviar',
        },
        'detalles': [
          {
            'id_detalle': 'det-1',
            'id_activo': 'act-1',
            'titulo': 'Caja de Cambio - Toyota Yaris 2018',
            'sku_qr_fisico': 'CAJ-TOY-001',
            'notas_preparacion': 'Revisar sensor de retroceso',
            'cantidad': 1,
            'precio_unitario': 520000,
            'precio_final': 520000,
            'subtotal': 520000,
            'es_inventariado': true,
          }
        ],
      };

      final model = OrdenHistorialModel.fromJson(json);

      expect(model.idOrden, '11111111-2222-3333-4444-555555555555');
      expect(model.folioDisplay, 'ORD-A1B2C3D4');
      expect(model.esReservada, isTrue);
      expect(model.esPagada, isFalse);
      expect(model.esAnulada, isFalse);
      final dtEsperado = DateTime.parse('2026-08-14T14:30:00Z').toLocal();
      final dia = dtEsperado.day.toString().padLeft(2, '0');
      final mes = dtEsperado.month.toString().padLeft(2, '0');
      final anio = dtEsperado.year;
      final hora = dtEsperado.hour.toString().padLeft(2, '0');
      final min = dtEsperado.minute.toString().padLeft(2, '0');
      expect(model.fechaFormateada, '$dia/$mes/$anio $hora:$min');
      expect(model.cliente?.nombreCompleto, 'María Pérez');
      expect(model.despacho?.direccionEnvio, 'Calle Prat 500');
      expect(model.detalles.length, 1);
      expect(model.detalles.first.titulo, 'Caja de Cambio - Toyota Yaris 2018');
      expect(model.detalles.first.precioFinalFormateado, '\$520.000');
    });

    test('Estados Pagada y Anulada se evalúan correctamente', () {
      final ordenPagada = OrdenHistorialModel(
        idOrden: 'ord-p',
        estadoOrden: 'Pagada',
        totalVenta: 100000,
        montoPendiente: 0,
        totalItems: 1,
        detalles: [],
      );
      expect(ordenPagada.esPagada, isTrue);
      expect(ordenPagada.esReservada, isFalse);

      final ordenAnulada = OrdenHistorialModel(
        idOrden: 'ord-a',
        estadoOrden: 'Anulada',
        totalVenta: 100000,
        montoPendiente: 0,
        totalItems: 1,
        detalles: [],
      );
      expect(ordenAnulada.esAnulada, isTrue);
      expect(ordenAnulada.esReservada, isFalse);
    });
  });

  group('OrdenesService HTTP Client Tests', () {
    test('obtenerMisVentas retorna lista de OrdenHistorialModel en respuesta 200', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/api/v1/ordenes/mis-ventas'));
        final responseData = [
          {
            'id_orden': '3fa85f64-5717-4562-b3fc-2c963f66afa6',
            'estado_orden': 'Reservada',
            'total_venta': 520000,
            'monto_pendiente': 520000,
            'qr_transaccional_salida': 'ORD-TEST-001',
            'fecha_creacion': '2026-08-14T10:30:00',
            'total_items': 1,
            'detalles': [],
          }
        ];
        return http.Response(jsonEncode(responseData), 200);
      });

      final result = await OrdenesService.obtenerMisVentas(client: mockClient);

      expect(result.length, 1);
      expect(result.first.idOrden, '3fa85f64-5717-4562-b3fc-2c963f66afa6');
      expect(result.first.estadoOrden, 'Reservada');
    });

    test('anularOrden retorna respuesta exitosa en 200', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, contains('/anular'));
        return http.Response(
          jsonEncode({
            'id_orden': 'ord-1',
            'estado_orden': 'Anulada',
            'mensaje': 'Orden anulada exitosamente.',
            'activos_liberados': 1,
          }),
          200,
        );
      });

      final result = await OrdenesService.anularOrden('ord-1', client: mockClient);
      expect(result['estado_orden'], 'Anulada');
      expect(result['activos_liberados'], 1);
    });

    test('anularOrden lanza excepción descriptiva ante error 400', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Solo se pueden anular órdenes en estado Reservada'}),
          400,
        );
      });

      expect(
        () => OrdenesService.anularOrden('ord-1', client: mockClient),
        throwsA(isA<Exception>()),
      );
    });

    test('actualizarInstruccionesBodega envía payload y procesa 200', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, contains('/instrucciones'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['notas_preparacion'], 'Nueva nota técnica');

        return http.Response(
          jsonEncode({
            'id_orden': 'ord-1',
            'mensaje': 'Instrucciones actualizadas exitosamente.',
            'notas_preparacion': 'Nueva nota técnica',
            'detalles_actualizados': 1,
          }),
          200,
        );
      });

      final result = await OrdenesService.actualizarInstruccionesBodega(
        'ord-1',
        'Nueva nota técnica',
        client: mockClient,
      );

      expect(result['notas_preparacion'], 'Nueva nota técnica');
    });
  });

  group('OrdenCard Widget Tests', () {
    testWidgets('Renderiza Folio, Badge Reservada, Cliente, Ítems y Total', (tester) async {
      bool cardTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrdenCard(
              orden: ordenMock,
              onTap: () {
                cardTapped = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('ORD-TEST-001'), findsOneWidget);
      expect(find.text('Reservada'), findsOneWidget);
      expect(find.text('Carlos González (18.765.432-1)'), findsOneWidget);
      expect(find.text('2 ítems'), findsOneWidget);
      expect(find.text('Despacho: Av. Libertad 1234, Depto 402'), findsOneWidget);
      expect(find.text('\$520.000'), findsOneWidget);
      expect(find.text('Ver detalle'), findsOneWidget);

      await tester.tap(find.text('ORD-TEST-001'));
      await tester.pump();
      expect(cardTapped, isTrue);
    });

    testWidgets('OrdenCard muestra información completa de despacho y detalle resumido (máx 3 artículos truncados a 20 chars)', (tester) async {
      final ordenConDespachoYMuchosItems = OrdenHistorialModel(
        idOrden: 'ord-despacho-test',
        folio: 'ORD-DESP-777',
        estadoOrden: 'Pagada',
        totalVenta: 350000,
        montoPendiente: 0,
        totalItems: 4,
        fechaCreacion: '2026-09-15T10:00:00',
        cliente: const ClienteOrdenResumenModel(
          rutCliente: '11.111.111-1',
          nombres: 'Roberto',
          apellidos: 'Muñoz',
          telefono: '+56911111111',
        ),
        despacho: const DespachoOrdenResumenModel(
          idDespacho: 'desp-777',
          direccionEnvio: 'Calle Los Aromos 555',
          comunaDestino: 'Villa Alemana',
          receptorNombres: 'Pedro Pascal',
          receptorRut: '22.222.222-2',
          receptorTelefono: '+56922222222',
          empresaTransporte: 'Chilexpress',
          estadoDespacho: 'Por Enviar',
        ),
        detalles: [
          DetalleOrdenItemModel(
            idDetalle: 'd1',
            titulo: 'Amortiguador Delantero Izquierdo', // 32 caracteres > 20 -> "Amortiguador Delante..."
            cantidad: 1,
            precioFinal: 100000,
            subtotal: 100000,
            esInventariado: true,
          ),
          DetalleOrdenItemModel(
            idDetalle: 'd2',
            titulo: 'Filtro Aceite', // 13 caracteres <= 20
            cantidad: 2,
            precioFinal: 15000,
            subtotal: 30000,
            esInventariado: true,
          ),
          DetalleOrdenItemModel(
            idDetalle: 'd3',
            titulo: 'Pastillas de Freno Delanteras', // 29 caracteres > 20 -> "Pastillas de Freno D..."
            cantidad: 1,
            precioFinal: 45000,
            subtotal: 45000,
            esInventariado: true,
          ),
          DetalleOrdenItemModel(
            idDetalle: 'd4',
            titulo: 'Bujía de Encendido Iridium', // Cuarto artículo: no debe mostrarse, debe salir '...'
            cantidad: 4,
            precioFinal: 25000,
            subtotal: 100000,
            esInventariado: false,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrdenCard(orden: ordenConDespachoYMuchosItems),
          ),
        ),
      );

      // Verificación de Información Completa de Despacho
      expect(find.text('Datos de Despacho'), findsOneWidget);
      expect(find.text('Despacho: Calle Los Aromos 555 • Villa Alemana'), findsOneWidget);
      expect(find.text('Receptor: Pedro Pascal (22.222.222-2)'), findsOneWidget);
      expect(find.text('Tel: +56922222222 • Transporte: Chilexpress'), findsOneWidget);

      // Verificación de Detalle Resumido
      expect(find.text('Detalle Resumido:'), findsOneWidget);
      // Artículo 1: truncado a 20 chars ("Amortiguador Delante...")
      expect(find.text('Amortiguador Delante...'), findsOneWidget);
      // Artículo 2: con cantidad (x2)
      expect(find.text('Filtro Aceite (x2)'), findsOneWidget);
      // Artículo 3: truncado a 20 chars ("Pastillas de Freno D...")
      expect(find.text('Pastillas de Freno D...'), findsOneWidget);
      // Artículo 4: no se debe mostrar el nombre completo
      expect(find.text('Bujía de Encendido Iridium'), findsNothing);
      // Puntos suspensivos presentes
      expect(find.text('...'), findsOneWidget);
    });

    testWidgets('OrdenCard no muestra botón interactivo de despacho Por Enviar', (tester) async {
      final ordenDespacho = OrdenHistorialModel(
        idOrden: 'ord-888',
        folio: 'ORD-DESP-888',
        fechaCreacion: '2026-03-30T10:00:00Z',
        estadoOrden: 'Pagada',
        totalVenta: 150000,
        montoPendiente: 0,
        totalItems: 1,
        detalles: const [],
        despacho: const DespachoOrdenResumenModel(
          idDespacho: 'desp-888',
          direccionEnvio: 'Av Libertad 100',
          comunaDestino: 'Viña del Mar',
          receptorNombres: 'Juan Perez',
          receptorRut: '11.111.111-1',
          receptorTelefono: '+56911111111',
          empresaTransporte: 'Starken',
          estadoDespacho: 'Enviado',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrdenCard(orden: ordenDespacho),
          ),
        ),
      );

      expect(find.text('Datos de Despacho'), findsOneWidget);
      expect(find.text('Por Enviar'), findsNothing);
      expect(find.byIcon(Icons.sync_alt_rounded), findsNothing);
    });
  });

  group('OrdenDetailSheet Widget Tests', () {
    testWidgets('Renderiza desglose completo de líneas, notas técnicas y botones de acción', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrdenDetailSheet(
              orden: ordenMock,
            ),
          ),
        ),
      );

      // Encabezado
      expect(find.text('ORD-TEST-001'), findsOneWidget);
      expect(find.text('Datos del Cliente'), findsOneWidget);
      expect(find.text('Despacho a Domicilio'), findsOneWidget);

      // Líneas de detalle
      expect(find.text('Motor - Toyota Yaris 2018'), findsOneWidget);
      expect(find.text('SKU: MOT-TOY-YAR-001'), findsOneWidget);
      expect(find.text('Nota: Entregar con poleas y cables'), findsOneWidget);
      expect(find.text('Líquido Refrigerante Premium'), findsOneWidget);
      expect(find.text('Bidón 5L Verde'), findsOneWidget);

      // Total
      expect(find.text('\$520.000'), findsOneWidget);

      // Botones de acción condicionales (Solo para estado Reservada)
      expect(find.text('Editar Instrucciones a Bodega'), findsOneWidget);
      expect(find.text('Deshacer Orden (Liberar Stock)'), findsOneWidget);
    });

    testWidgets('Tap en Editar Instrucciones despliega AlertDialog con TextField', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrdenDetailSheet(
              orden: ordenMock,
            ),
          ),
        ),
      );

      await tester.ensureVisible(find.text('Editar Instrucciones a Bodega'));
      await tester.tap(find.text('Editar Instrucciones a Bodega'));
      await tester.pumpAndSettle();

      expect(find.text('Instrucciones a Bodega'), findsOneWidget);
      expect(find.text('Guardar'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);

      // Cancelar diálogo
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Instrucciones a Bodega'), findsNothing);
    });

    testWidgets('Tap en Deshacer Orden despliega AlertDialog de confirmación', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrdenDetailSheet(
              orden: ordenMock,
            ),
          ),
        ),
      );

      await tester.ensureVisible(find.text('Deshacer Orden (Liberar Stock)'));
      await tester.tap(find.text('Deshacer Orden (Liberar Stock)'));
      await tester.pumpAndSettle();

      expect(find.text('¿Deshacer esta Orden?'), findsOneWidget);
      expect(find.text('Confirmar Anulación'), findsOneWidget);
      expect(find.text('Volver'), findsOneWidget);

      // Volver
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();

      expect(find.text('¿Deshacer esta Orden?'), findsNothing);
    });

    testWidgets('Orden pagada de misceláneos muestra banner y botón MARCAR COMO ENTREGADO', (tester) async {
      final ordenMiscelaneo = OrdenHistorialModel(
        idOrden: 'ord-misc-001',
        estadoOrden: 'Pagada',
        totalVenta: 10000,
        montoPendiente: 0,
        totalItems: 1,
        fechaCreacion: '2026-09-13T10:00:00Z',
        detalles: [
          DetalleOrdenItemModel(
            idDetalle: 'det-misc-1',
            idCategoria: 5,
            nombreCategoria: 'Fijaciones',
            titulo: 'Perno',
            cantidad: 1,
            precioFinal: 10000,
            subtotal: 10000,
            esInventariado: false,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrdenDetailSheet(
              orden: ordenMiscelaneo,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Entrega Inmediata en Mesón'), findsNWidgets(2));
      expect(find.text('MARCAR COMO ENTREGADO'), findsOneWidget);
    });

    testWidgets('Orden mixta (Motor + Misceláneo) muestra badges diferenciados y banner de orden mixta', (tester) async {
      final ordenMixta = OrdenHistorialModel(
        idOrden: 'ord-mixta-001',
        estadoOrden: 'Pagada',
        totalVenta: 1690000,
        montoPendiente: 0,
        totalItems: 2,
        qrTransaccionalSalida: 'TX-QR-TEST-001',
        fechaCreacion: '2026-09-13T10:00:00Z',
        detalles: [
          DetalleOrdenItemModel(
            idDetalle: 'det-mot-1',
            idCategoria: 1,
            nombreCategoria: 'Motores',
            titulo: 'Motor Toyota Yaris 2018',
            cantidad: 1,
            precioFinal: 1680000,
            subtotal: 1680000,
            esInventariado: true,
          ),
          DetalleOrdenItemModel(
            idDetalle: 'det-perno-2',
            idCategoria: 5,
            nombreCategoria: 'Fijaciones',
            titulo: 'Perno',
            cantidad: 1,
            precioFinal: 10000,
            subtotal: 10000,
            esInventariado: false,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrdenDetailSheet(
              orden: ordenMixta,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Mixta'), findsOneWidget);
      expect(find.text('Retiro en Bodega (Barrera)'), findsOneWidget);
      expect(find.text('Entrega Inmediata en Mesón'), findsOneWidget);
      expect(find.text('Orden Mixta (Mesón + Bodega)'), findsOneWidget);
      expect(find.text('MARCAR COMO ENTREGADO'), findsNothing);
      expect(find.text('MOSTRAR QR DE ENTREGA (BODEGA)'), findsOneWidget);
    });
  });

  group('HistorialFiltrosDrawer Widget Tests', () {
    testWidgets('Renderiza opciones de período, estado y botones de acción', (tester) async {
      bool periodoVal = false;
      String? estadoVal;
      bool aplicado = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            endDrawer: HistorialFiltrosDrawer(
              verTodas: false,
              filtroEstado: null,
              onPeriodoChanged: (val) => periodoVal = val,
              onEstadoChanged: (val) => estadoVal = val,
              onAplicar: () => aplicado = true,
              onLimpiar: () {},
            ),
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                  child: const Text('Abrir Filtros'),
                ),
              ),
            ),
          ),
        ),
      );

      // Abrir endDrawer
      await tester.tap(find.text('Abrir Filtros'));
      await tester.pumpAndSettle();

      expect(find.text('Filtros de Órdenes'), findsOneWidget);
      expect(find.text('PERÍODO DE VENTA'), findsOneWidget);
      expect(find.text('Ventas de Hoy'), findsOneWidget);
      expect(find.text('Historial Completo'), findsOneWidget);
      expect(find.text('ESTADO DE LA ORDEN'), findsOneWidget);
      expect(find.text('Todas'), findsOneWidget);
      expect(find.text('Reservadas'), findsOneWidget);
      expect(find.text('Pagadas'), findsOneWidget);
      expect(find.text('Anuladas'), findsOneWidget);
      expect(find.text('Limpiar'), findsOneWidget);
      expect(find.text('Aplicar Filtros'), findsOneWidget);

      // Cambiar a Historial Completo
      await tester.tap(find.text('Historial Completo'));
      expect(periodoVal, isTrue);

      // Cambiar a Reservadas
      await tester.tap(find.text('Reservadas'));
      expect(estadoVal, 'Reservada');

      // Aplicar filtros
      await tester.tap(find.text('Aplicar Filtros'));
      await tester.pumpAndSettle();
      expect(aplicado, isTrue);
    });

    testWidgets('Botón Limpiar está siempre habilitado y dispara onLimpiar', (tester) async {
      bool limpiado = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            endDrawer: HistorialFiltrosDrawer(
              verTodas: false,
              filtroEstado: null,
              onPeriodoChanged: (_) {},
              onEstadoChanged: (_) {},
              onAplicar: () {},
              onLimpiar: () => limpiado = true,
            ),
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                  child: const Text('Abrir Filtros'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Filtros'));
      await tester.pumpAndSettle();

      final botonLimpiar = find.widgetWithText(OutlinedButton, 'Limpiar');
      expect(botonLimpiar, findsOneWidget);

      final outlinedBtn = tester.widget<OutlinedButton>(botonLimpiar);
      expect(outlinedBtn.onPressed, isNotNull);

      await tester.tap(botonLimpiar);
      await tester.pumpAndSettle();
      expect(limpiado, isTrue);
    });
  });

  group('HistorialScreen Widget Tests', () {
    testWidgets('Ordena órdenes colocando Completadas al final y Anuladas aún más al final', (tester) async {
      final ordenCompletada = OrdenHistorialModel(
        idOrden: 'comp-001',
        estadoOrden: 'Completada',
        totalVenta: 100000,
        montoPendiente: 0,
        qrTransaccionalSalida: 'ORD-COMP-001',
        fechaCreacion: '2026-08-16T15:00:00',
        totalItems: 1,
        cliente: const ClienteOrdenResumenModel(
          rutCliente: '1-9',
          nombres: 'Cliente',
          apellidos: 'Completado',
        ),
        detalles: [],
      );
      final ordenReservada = OrdenHistorialModel(
        idOrden: 'res-002',
        estadoOrden: 'Reservada',
        totalVenta: 150000,
        montoPendiente: 150000,
        qrTransaccionalSalida: 'ORD-RES-002',
        fechaCreacion: '2026-08-16T10:00:00',
        totalItems: 1,
        cliente: const ClienteOrdenResumenModel(
          rutCliente: '2-7',
          nombres: 'Cliente',
          apellidos: 'Reservado',
        ),
        detalles: [],
      );
      final ordenAnulada = OrdenHistorialModel(
        idOrden: 'anu-003',
        estadoOrden: 'Anulada',
        totalVenta: 80000,
        montoPendiente: 0,
        qrTransaccionalSalida: 'ORD-ANU-003',
        fechaCreacion: '2026-08-16T18:00:00',
        totalItems: 1,
        cliente: const ClienteOrdenResumenModel(
          rutCliente: '3-5',
          nombres: 'Cliente',
          apellidos: 'Anulado',
        ),
        detalles: [],
      );

      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: HistorialScreen(
            initialOrdenes: [ordenAnulada, ordenCompletada, ordenReservada],
          ),
        ),
      );

      expect(find.text('ORD-COMP-001'), findsOneWidget);
      expect(find.text('ORD-RES-002'), findsOneWidget);
      expect(find.text('ORD-ANU-003'), findsOneWidget);

      final topReservada = tester.getTopLeft(find.text('ORD-RES-002')).dy;
      final topCompletada = tester.getTopLeft(find.text('ORD-COMP-001')).dy;
      final topAnulada = tester.getTopLeft(find.text('ORD-ANU-003')).dy;

      // Activa (Reservada) antes que Completada, y Completada antes que Anulada (Anulada al final absoluto)
      expect(topReservada, lessThan(topCompletada));
      expect(topCompletada, lessThan(topAnulada));
    });
    final orden1 = ordenMock; // Carlos González, 18.765.432-1, Motor - Toyota Yaris 2018, ORD-TEST-001
    final orden2 = OrdenHistorialModel(
      idOrden: '7bb85f64-9999-4562-b3fc-2c963f66bb77',
      estadoOrden: 'Pagada',
      totalVenta: 780000,
      montoPendiente: 0,
      qrTransaccionalSalida: 'ORD-PAGADA-002',
      fechaCreacion: '2026-08-15T12:00:00',
      totalItems: 1,
      cliente: const ClienteOrdenResumenModel(
        rutCliente: '11.222.333-4',
        nombres: 'Andrea',
        apellidos: 'Valenzuela',
        telefono: '+56911223344',
      ),
      detalles: [
        DetalleOrdenItemModel(
          idDetalle: 'det-201',
          idActivo: 'act-201',
          titulo: 'Caja de Cambios - Nissan Versa 2021',
          skuQrFisico: 'CAJ-NIS-VER-001',
          cantidad: 1,
          precioFinal: 780000,
          subtotal: 780000,
          esInventariado: true,
        ),
      ],
    );

    testWidgets('Renderiza AppBar con botón de filtro y abre el EndDrawer', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HistorialScreen(),
        ),
      );

      expect(find.text('Mis Órdenes de Venta'), findsOneWidget);
      expect(find.byIcon(Icons.tune), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);

      // Tap en botón de filtro abre el endDrawer
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      expect(find.text('Filtros de Órdenes'), findsOneWidget);
      expect(find.text('PERÍODO DE VENTA'), findsOneWidget);
    });

    testWidgets('Barra de búsqueda filtra reactivamente por Folio, Cliente, RUT y Repuesto', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HistorialScreen(
            initialOrdenes: [orden1, orden2],
          ),
        ),
      );

      // Ambas órdenes visibles inicialmente
      expect(find.text('ORD-TEST-001'), findsOneWidget);
      expect(find.text('ORD-PAGADA-002'), findsOneWidget);
      expect(find.byKey(const Key('buscador_ordenes_textfield')), findsOneWidget);

      // 1. Filtrar por Nombre de Cliente "Andrea"
      await tester.enterText(find.byKey(const Key('buscador_ordenes_textfield')), 'Andrea');
      await tester.pump();
      expect(find.text('ORD-PAGADA-002'), findsOneWidget);
      expect(find.text('ORD-TEST-001'), findsNothing);

      // 2. Filtrar por RUT "18.765.432-1"
      await tester.enterText(find.byKey(const Key('buscador_ordenes_textfield')), '18765432-1');
      await tester.pump();
      expect(find.text('ORD-TEST-001'), findsOneWidget);
      expect(find.text('ORD-PAGADA-002'), findsNothing);

      // 3. Filtrar por Repuesto "Nissan Versa"
      await tester.enterText(find.byKey(const Key('buscador_ordenes_textfield')), 'Nissan Versa');
      await tester.pump();
      expect(find.text('ORD-PAGADA-002'), findsOneWidget);
      expect(find.text('ORD-TEST-001'), findsNothing);

      // 4. Filtrar por Folio "#PAGADA"
      await tester.enterText(find.byKey(const Key('buscador_ordenes_textfield')), '#PAGADA');
      await tester.pump();
      expect(find.text('ORD-PAGADA-002'), findsOneWidget);
      expect(find.text('ORD-TEST-001'), findsNothing);

      // 5. Búsqueda sin coincidencias despliega estado vacío descriptivo
      await tester.enterText(find.byKey(const Key('buscador_ordenes_textfield')), 'INEXISTENTE_999');
      await tester.pump();
      expect(find.text('ORD-TEST-001'), findsNothing);
      expect(find.text('ORD-PAGADA-002'), findsNothing);
      expect(find.text('No se encontraron órdenes que coincidan con la búsqueda'), findsOneWidget);

      // 6. Tap en botón limpiar restablece ambas órdenes
      await tester.tap(find.byKey(const Key('btn_limpiar_busqueda_ordenes')));
      await tester.pump();
      expect(find.text('ORD-TEST-001'), findsOneWidget);
      expect(find.text('ORD-PAGADA-002'), findsOneWidget);
    });

    testWidgets('Pestañas de Historial vs Por Asignar se renderizan y permiten alternar sección', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HistorialScreen(
            initialOrdenes: [orden1],
          ),
        ),
      );

      expect(find.text('Historial de Órdenes'), findsOneWidget);
      expect(find.text('Por Asignar'), findsOneWidget);
      expect(find.byKey(const Key('tab_seccion_normal')), findsOneWidget);
      expect(find.byKey(const Key('tab_seccion_por_asignar')), findsOneWidget);

      // Verificamos que inicialmente está en normal y renderiza la orden1
      expect(find.text('ORD-TEST-001'), findsOneWidget);
    });
  });
}

