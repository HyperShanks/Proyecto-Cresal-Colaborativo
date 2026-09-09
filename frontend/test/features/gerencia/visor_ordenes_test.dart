// frontend/test/features/gerencia/visor_ordenes_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/caja/models/historial_caja_model.dart';
import 'package:frontend/features/caja/presentation/widgets/detalle_auditoria_dialog.dart';
import 'package:frontend/features/caja/presentation/widgets/historial_tabla_view.dart';
import 'package:frontend/features/gerencia/presentation/screens/ordenes_gerencia_view.dart';
import 'package:frontend/features/gerencia/presentation/widgets/auditoria_detalle_dialog.dart';
import 'package:frontend/features/gerencia/presentation/widgets/auditoria_tabla_view.dart';
import 'package:frontend/features/gerencia/presentation/widgets/panel_filtros_avanzados.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockItem1 = HistorialOrdenItemModel(
    idOrden: 'ord-001-uuid',
    folio: 'ORD-AUD-001',
    tipoOperacion: 'VENTA',
    emiteQr: true,
    fechaIso: '2026-09-07T10:30:00Z',
    hora: '10:30',
    fechaHoraFormateada: '07/09/2026 10:30',
    clienteNombre: 'Juan Carlos Pérez Cotapos',
    clienteRut: '12.345.678-9',
    vendedorNombre: 'Pedro Vendedor',
    cajeraNombre: 'Lorena Valenzuela',
    estadoOrden: 'Pagada',
    modalidadPago: 'unico',
    metodosResumen: 'Efectivo \$85.000',
    totalVenta: 85000,
    abonoPrevio: 0,
    totalLiquidado: 85000,
    montoPendiente: 0,
    idSucursal: 1,
    sucursalNombre: 'Casa Matriz (Viña)',
    desglosePagos: [
      HistorialPagoDetalleModel(
        idTransaccion: 'tx-001',
        metodoPago: 'Efectivo',
        monto: 85000,
      ),
    ],
    articulos: [
      HistorialArticuloModel(
        cantidad: 1,
        tipo: 'INVENTARIADO',
        descripcion: 'Amortiguador Delantero',
        sku: 'AMORT-FRON-001',
        precio: 85000,
        subtotal: 85000,
      ),
    ],
    historialMovimientos: [
      HistorialMovimientoModel(
        hora: '10:30',
        evento: 'Venta cerrada y pagada 100% en caja',
      ),
    ],
  );

  final mockItem2 = HistorialOrdenItemModel(
    idOrden: 'ord-002-uuid',
    folio: 'ORD-AUD-002',
    tipoOperacion: 'RESERVA',
    emiteQr: false,
    fechaIso: '2026-09-07T11:00:00Z',
    hora: '11:00',
    fechaHoraFormateada: '07/09/2026 11:00',
    clienteNombre: 'María Ignacia González Silva',
    clienteRut: '19.876.543-2',
    vendedorNombre: 'Pedro Vendedor',
    cajeraNombre: 'Lorena Valenzuela',
    estadoOrden: 'Reservada',
    modalidadPago: 'unico',
    metodosResumen: 'Transferencia \$100.000',
    totalVenta: 150000,
    abonoPrevio: 100000,
    totalLiquidado: 100000,
    montoPendiente: 50000,
    idSucursal: 2,
    sucursalNombre: 'Patio Desarme (Limache)',
    desglosePagos: [
      HistorialPagoDetalleModel(
        idTransaccion: 'tx-002',
        metodoPago: 'Transferencia',
        monto: 100000,
      ),
    ],
    articulos: [
      HistorialArticuloModel(
        cantidad: 1,
        tipo: 'INVENTARIADO',
        descripcion: 'Bandeja de Suspensión Derecha',
        sku: 'BAND-SUSP-002',
        precio: 150000,
        subtotal: 150000,
      ),
    ],
    historialMovimientos: [
      HistorialMovimientoModel(
        hora: '11:00',
        evento: 'Abono recibido por reserva de repuesto',
      ),
    ],
  );

  group('1. PanelFiltrosAvanzados (HU-5.2)', () {
    testWidgets('Renderiza controles de filtrado multidimensional según prototipo',
        (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = TextEditingController();
      String periodo = 'todos';
      String estado = 'todos';
      String metodo = 'todos';
      bool limpioTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PanelFiltrosAvanzados(
              busquedaController: controller,
              onBusquedaChanged: (_) {},
              periodoSeleccionado: periodo,
              onPeriodoChanged: (p) => periodo = p,
              estadoSeleccionado: estado,
              onEstadoChanged: (e) => estado = e,
              metodoPagoSeleccionado: metodo,
              onMetodoPagoChanged: (m) => metodo = m,
              onLimpiar: () => limpioTriggered = true,
            ),
          ),
        ),
      );

      // Verificamos placeholder predictivo
      expect(
        find.text('Buscar por Folio, Cliente, RUT o Vendedor...'),
        findsOneWidget,
      );

      // Verificamos botones de período predeterminado
      expect(find.text('Hoy'), findsOneWidget);
      expect(find.text('Esta Semana'), findsOneWidget);
      expect(find.text('Este Mes'), findsOneWidget);
      expect(find.text('Todo'), findsOneWidget);

      // Verificamos selects
      expect(find.text('Estado: Todos'), findsOneWidget);
      expect(find.text('Método: Todos'), findsOneWidget);

      // Verificamos botón Limpiar y su callback
      final btnLimpiar = find.text('Limpiar');
      expect(btnLimpiar, findsOneWidget);
      await tester.tap(btnLimpiar);
      expect(limpioTriggered, isTrue);

      // Verificamos interacción con período 'Hoy'
      await tester.tap(find.text('Hoy'));
      expect(periodo, 'hoy');
    });
  });

  group('2. AuditoriaTablaView (10 Columnas del Mockup Oficial HU-5.2)', () {
    testWidgets(
        'Renderiza las 10 columnas exactas del mockup, columna PENDIENTE dedicada e ícono de ojo',
        (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      HistorialOrdenItemModel? ordenAuditada;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 600,
              child: AuditoriaTablaView(
                items: [mockItem1, mockItem2],
                paginaActual: 1,
                totalPaginas: 1,
                totalRegistros: 2,
                totalConsolidado: 235000,
                onCambiarPagina: (_) {},
                onVerDetalle: (orden) => ordenAuditada = orden,
              ),
            ),
          ),
        ),
      );

      // 1. Verificamos las 10 cabeceras oficiales del mockup
      expect(find.text('FOLIO'), findsOneWidget);
      expect(find.text('FECHA / HORA'), findsOneWidget);
      expect(find.text('CLIENTE / RUT'), findsOneWidget);
      expect(find.text('SUCURSAL'), findsOneWidget);
      expect(find.text('VENDEDOR / CAJERA'), findsOneWidget);
      expect(find.text('MÉTODO DE PAGO'), findsOneWidget);
      expect(find.text('TOTAL VENTA'), findsOneWidget);
      expect(find.text('PENDIENTE'), findsOneWidget);
      expect(find.text('ESTADO OFICIAL'), findsOneWidget);
      expect(find.text('ACCIONES'), findsOneWidget);

      // 2. Verificamos celdas de las órdenes
      expect(find.text('ORD-AUD-001'), findsOneWidget);
      expect(find.text('ORD-AUD-002'), findsOneWidget);
      expect(find.text('Casa Matriz (Viña)'), findsOneWidget);
      expect(find.text('Patio Desarme (Limache)'), findsOneWidget);

      // 3. Verificamos columna PENDIENTE: '—' para orden 1 pagada, y '$50.000' para orden 2 abonada
      expect(find.text('—'), findsOneWidget);
      expect(find.text('\$50.000'), findsOneWidget);

      // 4. Verificamos botones de acción "Auditar" con ícono de ojo
      final botonesAuditar = find.text('Auditar');
      expect(botonesAuditar, findsNWidgets(2));
      expect(find.byIcon(Icons.visibility_outlined), findsNWidgets(2));

      // 5. Verificamos pie de tabla integrado
      expect(find.textContaining('Mostrando '), findsOneWidget);
      expect(find.textContaining('Total Consolidado en Vista: '), findsOneWidget);

      // 6. Verificamos clic en auditar la primera orden
      await tester.tap(botonesAuditar.first);
      expect(ordenAuditada, isNotNull);
      expect(ordenAuditada!.folio, 'ORD-AUD-001');
    });
  });

  group('3. AuditoriaDetalleDialog (Modal Forense Oficial del Mockup HU-5.2)', () {
    testWidgets('Muestra cabecera oficial, tarjetas, artículos con badge 1x, pagos y botón Cerrar',
        (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AuditoriaDetalleDialog.show(context, mockItem1),
                child: const Text('Abrir Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Modal'));
      await tester.pumpAndSettle();

      // 1. Verificamos cabecera oficial
      expect(find.text('AUDITORÍA DE VENTA'), findsOneWidget);
      expect(find.text('ORD-AUD-001'), findsOneWidget);

      // 2. Verificamos tarjeta de Cliente y Responsables
      expect(find.text('CLIENTE'), findsOneWidget);
      expect(find.text('Juan Carlos Pérez Cotapos'), findsOneWidget);
      expect(find.text('RESPONSABLES'), findsOneWidget);
      expect(find.textContaining('Pedro Vendedor'), findsOneWidget);

      // 3. Verificamos desglose de artículos con badge 1x
      expect(find.text('ARTÍCULOS Y REPUESTOS'), findsOneWidget);
      expect(find.text('1x'), findsOneWidget);
      expect(find.text('Amortiguador Delantero'), findsOneWidget);
      expect(find.text('SKU: AMORT-FRON-001'), findsOneWidget);

      // 4. Verificamos desglose de pagos y total liquidado
      expect(find.text('DESGLOSE EXACTO DE PAGOS'), findsOneWidget);
      expect(find.text('TOTAL LIQUIDADO:'), findsOneWidget);

      // 5. Verificamos línea de tiempo
      expect(find.text('LÍNEA DE TIEMPO / MOVIMIENTOS'), findsOneWidget);

      // 6. Verificamos botón de cierre
      expect(find.text('Cerrar'), findsOneWidget);
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();

      // Verificamos que el modal se cerró
      expect(find.text('AUDITORÍA DE VENTA'), findsNothing);
    });
  });

  group('4. OrdenesGerenciaView (Integración de Pantalla)', () {
    testWidgets('Renderiza barra de filtros, banner de total consolidado y estado',
        (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OrdenesGerenciaView(idSucursalInicial: null),
          ),
        ),
      );

      // Verificamos que se renderiza la barra de filtros
      expect(
        find.text('Buscar por Folio, Cliente, RUT o Vendedor...'),
        findsOneWidget,
      );

      // Verificamos que inicialmente muestra el indicador de carga
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
