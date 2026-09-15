import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/caja/models/cobro_pendiente_model.dart';
import 'package:frontend/features/caja/models/cobro_model.dart';
import 'package:frontend/features/caja/models/historial_caja_model.dart';
import 'package:frontend/features/caja/services/caja_service.dart';
import 'package:frontend/features/caja/presentation/providers/caja_provider.dart';
import 'package:frontend/features/caja/presentation/widgets/panel_detalle_cobro.dart';

class MockCajaService implements ICajaService {
  List<CobroPendienteModel> dummyItems = [];
  bool registrarCobroLlamado = false;
  RegistrarCobroRequestModel? ultimoRequest;
  bool shouldFail = false;

  @override
  Future<List<CobroPendienteModel>> obtenerCobrosPendientes({
    required int sucursalId,
    String? busqueda,
    String? tipoOperacion,
  }) async {
    if (shouldFail) {
      throw Exception('Fallo de conexión simulado');
    }
    return dummyItems;
  }

  @override
  Future<RegistrarCobroResponseModel> registrarCobro(
    RegistrarCobroRequestModel request,
  ) async {
    registrarCobroLlamado = true;
    ultimoRequest = request;

    if (shouldFail) {
      throw Exception('Error simulado al registrar cobro');
    }

    return RegistrarCobroResponseModel(
      success: true,
      mensaje: 'Cobro registrado exitosamente',
      folio: 'ORD-9780',
      montoCobrado: request.montoDeclarado,
      nuevoSaldoPendiente: 0,
      estadoActualizado: 'Pagada',
      transaccionesIds: ['tx-123-abc'],
      qrGenerado: 'TX-QR-3FA85F64-ABC123DEF456',
    );
  }

  @override
  Future<ValidarActivoBackorderResponseModel> validarActivoBackorder(
    ValidarActivoBackorderRequestModel request,
  ) async {
    return ValidarActivoBackorderResponseModel(
      coincide: true,
      discrepancias: [],
      mensaje: 'Activo válido',
      activoDetalle: ActivoDetalleBackorderModel(
        sku: request.skuActivo,
        marca: 'Hyundai',
        modelo: 'Tucson',
        anio: 2022,
      ),
    );
  }

  @override
  Future<HistorialCajaResponseModel> obtenerHistorialCaja({
    required int sucursalId,
    String periodo = 'HOY',
    String? fechaDesde,
    String? fechaHasta,
    String estadoOrden = 'TODOS',
    String metodoPago = 'TODOS',
    String? busqueda,
    int? montoMin,
    int? montoMax,
    String? idCajera,
    String? idVendedor,
    int pagina = 1,
    int limite = 20,
  }) async {
    return HistorialCajaResponseModel.empty();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockCajaService mockService;
  late CajaProvider provider;
  late CobroPendienteModel sampleVenta;
  late CobroPendienteModel sampleBackorder;

  setUp(() {
    mockService = MockCajaService();
    provider = CajaProvider(cajaService: mockService);

    sampleVenta = CobroPendienteModel(
      idReferencia: '3fa85f64-5717-4562-b3fc-2c963f66afa6',
      folioDocumento: 'ORD-9780',
      tipoOperacion: 'VENTA',
      estadoDocumento: 'Reservada',
      clienteNombre: 'Cristobal Alejandro Espinoza Perez',
      clienteRut: '14.892.401-2',
      vendedorNombre: 'Juaquin Leiva',
      fechaEmision: DateTime.now().subtract(const Duration(minutes: 15)),
      fechaEmisionFormateada: '21/08/2026',
      horaEmisionFormateada: '11:38',
      totalOperacion: 650000,
      abonoPrevio: 150000,
      montoACobrar: 500000,
      articulos: [
        ArticuloResumenModel(
          cantidad: 1,
          tipo: 'INVENTARIADO',
          descripcion: 'Motor MG ZS 1.5 VTi-Tech Completo',
          sku: 'MOT-MG-ZS-15-089',
          precio: 500000,
          subtotal: 500000,
        ),
      ],
      especificacionesBackorder: null,
    );

    sampleBackorder = CobroPendienteModel(
      idReferencia: '7c9e6679-7425-40de-944b-e07fc1f90ae7',
      folioDocumento: 'RES-5401',
      tipoOperacion: 'BACKORDER',
      estadoDocumento: 'Pendiente',
      clienteNombre: 'Camila Andrea Soto Lagos',
      clienteRut: '18.432.109-K',
      vendedorNombre: 'Juaquin Leiva',
      fechaEmision: DateTime.now().subtract(const Duration(minutes: 30)),
      fechaEmisionFormateada: '21/08/2026',
      horaEmisionFormateada: '12:20',
      totalOperacion: 1200000,
      abonoPrevio: 900000,
      montoACobrar: 300000,
      articulos: [],
      especificacionesBackorder: BackorderEspecificacionesModel(
        marca: 'Hyundai',
        modelo: 'Tucson 2.0 CRDi Turbo Diesel',
        anio: 2022,
        categoria: 'Conjunto Motor y Turbo',
        cilindrada: '2.0',
        combustible: 'Diesel',
        transito: 'En Tránsito Marítimo',
      ),
    );

    mockService.dummyItems = [sampleVenta, sampleBackorder];
  });

  void setDesktopViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1366, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget createTestWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  testWidgets('ST-F01: Renderiza estado inicial deseleccionado (Empty State)',
      (tester) async {
    setDesktopViewport(tester);
    await tester.pumpWidget(createTestWidget(PanelDetalleCobro(provider: provider)));
    await tester.pumpAndSettle();

    expect(find.text('Seleccione una orden para procesar el cobro'), findsOneWidget);
    expect(find.byIcon(Icons.account_balance_wallet_rounded), findsOneWidget);
  });

  testWidgets('ST-F02 / CA-01: Renderiza detalle de Orden de Venta seleccionada',
      (tester) async {
    setDesktopViewport(tester);
    provider.seleccionarOrden(sampleVenta);

    await tester.pumpWidget(createTestWidget(PanelDetalleCobro(provider: provider)));
    await tester.pumpAndSettle();

    expect(find.text('ORD-9780'), findsOneWidget);
    expect(find.text('Venta en Tienda'), findsOneWidget);
    expect(find.textContaining('Cristobal Alejandro'), findsOneWidget);
    expect(find.text('Motor MG ZS 1.5 VTi-Tech Completo'), findsOneWidget);
    expect(find.text('TOTAL VENTA'), findsOneWidget);
    expect(find.text('SALDO A COBRAR'), findsOneWidget);
  });

  testWidgets('ST-F02 / CA-01: Renderiza detalle de Reserva Backorder seleccionada',
      (tester) async {
    setDesktopViewport(tester);
    provider.seleccionarOrden(sampleBackorder);

    await tester.pumpWidget(createTestWidget(PanelDetalleCobro(provider: provider)));
    await tester.pumpAndSettle();

    expect(find.text('RES-5401'), findsOneWidget);
    expect(find.text('Ventas en Verde'), findsOneWidget);
    expect(find.text('ESPECIFICACIONES DE VENTA EN VERDE'), findsOneWidget);
    expect(find.text('Hyundai'), findsOneWidget);
    expect(find.text('Tucson 2.0 CRDi Turbo Diesel'), findsOneWidget);
  });

  testWidgets('ST-F03 / CA-02: Muestra banner ámbar de advertencia al seleccionar Abono',
      (tester) async {
    setDesktopViewport(tester);
    provider.seleccionarOrden(sampleVenta);

    await tester.pumpWidget(createTestWidget(PanelDetalleCobro(provider: provider)));
    await tester.pumpAndSettle();

    // Cambiar a Abono
    await tester.tap(find.text('Abono Personalizado'));
    await tester.pumpAndSettle();

    expect(
      find.text('Este pago registrará un abono y mantendrá la orden retenida sin emitir código QR de salida.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('ST-F05: Cuadratura exacta habilita botón de confirmación en verde',
      (tester) async {
    setDesktopViewport(tester);
    provider.seleccionarOrden(sampleVenta);

    await tester.pumpWidget(createTestWidget(PanelDetalleCobro(provider: provider)));
    await tester.pumpAndSettle();

    // Por defecto se inicializa con monto exacto en Efectivo ($500.000)
    expect(provider.esCuadraturaValida, isTrue);
    expect(find.text('CONFIRMAR Y PROCESAR COBRO'), findsOneWidget);

    final boton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(boton.onPressed, isNotNull);
  });

  testWidgets('ST-F05: Descuadre bloquea botón de confirmación y muestra alerta roja',
      (tester) async {
    setDesktopViewport(tester);
    provider.seleccionarOrden(sampleVenta);

    await tester.pumpWidget(createTestWidget(PanelDetalleCobro(provider: provider)));
    await tester.pumpAndSettle();

    // Modificar monto para generar descuadre (ingresar 200.000 en vez de 500.000)
    provider.actualizarMontoMetodo(0, 200000);
    await tester.pumpAndSettle();

    expect(provider.esCuadraturaValida, isFalse);
    expect(find.text('PAGO BLOQUEADO (DESCUADRE)'), findsOneWidget);
    expect(find.textContaining('Descuadre Financiero'), findsOneWidget);

    final boton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(boton.onPressed, isNull);
  });

  testWidgets('CA-04: Función Auto-rellenar asigna el saldo faltante correctamente',
      (tester) async {
    setDesktopViewport(tester);
    provider.seleccionarOrden(sampleVenta);

    await tester.pumpWidget(createTestWidget(PanelDetalleCobro(provider: provider)));
    await tester.pumpAndSettle();

    // Agregar segundo canal (Débito)
    provider.agregarMetodoPago(metodo: 'Debito', monto: 0);
    // Cambiar primer canal (Efectivo) a 300.000
    provider.actualizarMontoMetodo(0, 300000);
    await tester.pumpAndSettle();

    expect(provider.diferenciaCuadratura, 200000);

    // Ejecutar auto-rellenar en el segundo canal (index 1)
    provider.autoRellenarRestante(1);
    await tester.pumpAndSettle();

    expect(provider.pagosDivididos[1].monto, 200000);
    expect(provider.esCuadraturaValida, isTrue);
  });

  testWidgets('Procesar cobro invoca al servicio backend y muestra ResultadoCobroDialog',
      (tester) async {
    setDesktopViewport(tester);
    provider.seleccionarOrden(sampleVenta);

    await tester.pumpWidget(createTestWidget(PanelDetalleCobro(provider: provider)));
    await tester.pumpAndSettle();

    // Presionar botón de cobro
    await tester.tap(find.text('CONFIRMAR Y PROCESAR COBRO'));
    await tester.pump();
    await tester.pump(); // Procesa la reanudación del async gap
    await tester.pump(const Duration(milliseconds: 500)); // Renderiza el diálogo modal

    expect(mockService.registrarCobroLlamado, isTrue);
    expect(mockService.ultimoRequest, isNotNull);
    expect(mockService.ultimoRequest!.idDocumento, sampleVenta.idReferencia);
    expect(mockService.ultimoRequest!.montoDeclarado, 500000);
    expect(find.text('Pago Registrado Exitosamente'), findsOneWidget);
    expect(find.text('Siguiente Orden'), findsOneWidget);

    // Pulsar Siguiente Orden
    await tester.tap(find.text('Siguiente Orden'));
    await tester.pumpAndSettle();

    // Diálogo cerrado y panel reiniciado a Empty State
    expect(find.text('Seleccione una orden para procesar el cobro'), findsOneWidget);
  });

  testWidgets('Selector de 5 botones: Alterna método en Pago Único cubriendo 100%',
      (tester) async {
    setDesktopViewport(tester);
    provider.seleccionarOrden(sampleVenta);

    await tester.pumpWidget(createTestWidget(PanelDetalleCobro(provider: provider)));
    await tester.pumpAndSettle();

    // Verificar que los 5 botones existen
    expect(find.text('EFECTIVO'), findsOneWidget);
    expect(find.text('DÉBITO'), findsOneWidget);
    expect(find.text('CRÉDITO'), findsOneWidget);
    expect(find.text('TRANSFERENCIA'), findsOneWidget);
    expect(find.text('CHEQUE'), findsOneWidget);

    // Inicialmente Efectivo cubre el 100%
    expect(provider.esMetodoActivo('Efectivo'), isTrue);
    expect(find.text('Canal Activo: Efectivo'), findsOneWidget);

    // Tocar DÉBITO
    await tester.tap(find.text('DÉBITO'));
    await tester.pumpAndSettle();

    expect(provider.esMetodoActivo('Debito'), isTrue);
    expect(provider.esMetodoActivo('Efectivo'), isFalse);
    expect(find.text('Canal Activo: Debito'), findsOneWidget);
    expect(provider.esCuadraturaValida, isTrue);
  });

  testWidgets('Selector de 5 botones: Permite selección múltiple en Pago Dividido / Mixto',
      (tester) async {
    setDesktopViewport(tester);
    provider.seleccionarOrden(sampleVenta);

    await tester.pumpWidget(createTestWidget(PanelDetalleCobro(provider: provider)));
    await tester.pumpAndSettle();

    // Cambiar a Pago Dividido
    await tester.tap(find.text('Dividir Pago'));
    await tester.pumpAndSettle();

    expect(find.text('DISTRIBUCIÓN DE MONTOS'), findsOneWidget);

    // Tocar DÉBITO para agregarlo a los canales activos
    await tester.tap(find.text('DÉBITO'));
    await tester.pumpAndSettle();

    expect(provider.esMetodoActivo('Efectivo'), isTrue);
    expect(provider.esMetodoActivo('Debito'), isTrue);
    expect(provider.pagosDivididos.length, 2);
  });

  testWidgets('Detalle de orden: Renderiza nombre identificable completo del activo, SKU y misceláneos',
      (tester) async {
    setDesktopViewport(tester);

    final ordenConDetalleRico = CobroPendienteModel(
      idReferencia: 'ord-rico-001',
      folioDocumento: 'ORD-1001',
      tipoOperacion: 'VENTA',
      estadoDocumento: 'Reservada',
      clienteNombre: 'Juan Perez',
      clienteRut: '12.345.678-9',
      vendedorNombre: 'Carlos Vendedor',
      fechaEmision: DateTime.now(),
      fechaEmisionFormateada: '12/09/2026',
      horaEmisionFormateada: '18:30',
      totalOperacion: 950000,
      abonoPrevio: 0,
      montoACobrar: 950000,
      articulos: [
        ArticuloResumenModel(
          cantidad: 1,
          tipo: 'INVENTARIADO',
          descripcion: 'Motor',
          categoria: 'Motor',
          marca: 'Toyota',
          modelo: 'Hilux',
          anio: 2021,
          detalleTecnico: '2.8L • Diésel',
          sku: 'MOT-TOY-HIL-21',
          precio: 900000,
          subtotal: 900000,
        ),
        ArticuloResumenModel(
          cantidad: 2,
          tipo: 'MISCELANEO',
          descripcion: 'Empaquetadura de Culata Reforzada',
          sku: null,
          precio: 25000,
          subtotal: 50000,
        ),
      ],
    );

    provider.seleccionarOrden(ordenConDetalleRico);

    await tester.pumpWidget(createTestWidget(PanelDetalleCobro(provider: provider)));
    await tester.pumpAndSettle();

    // 1. Verificar nombre identificable completo del activo (marca, modelo, año, detalle técnico)
    expect(find.text('Motor - Toyota Hilux 2021 (2.8L • Diésel)'), findsOneWidget);
    expect(find.text('SKU: MOT-TOY-HIL-21'), findsOneWidget);

    // 2. Verificar ítem misceláneo
    expect(find.text('Empaquetadura de Culata Reforzada'), findsOneWidget);
    expect(find.text('Misceláneo'), findsOneWidget);

    // 3. Verificar que NO contenga patente ni ubicación
    expect(find.textContaining('Patente'), findsNothing);
    expect(find.textContaining('Galpón'), findsNothing);
    expect(find.textContaining('Pallet'), findsNothing);
  });

  testWidgets('Flujo Backorder 1er Pago (Abono Inicial): no exige atribución de SKU y habilita procesamiento',
      (tester) async {
    setDesktopViewport(tester);

    final backorderInicial = CobroPendienteModel(
      idReferencia: 'res-inicial-001',
      folioDocumento: 'RES-1001',
      tipoOperacion: 'BACKORDER',
      estadoDocumento: 'Pendiente',
      clienteNombre: 'Rodrigo Perez',
      clienteRut: '15.234.567-8',
      vendedorNombre: 'Juaquin Leiva',
      fechaEmision: DateTime.now(),
      fechaEmisionFormateada: '15/09/2026',
      horaEmisionFormateada: '10:00',
      totalOperacion: 800000,
      abonoPrevio: 0,
      montoACobrar: 200000, // Abono acordado
      articulos: [],
      especificacionesBackorder: BackorderEspecificacionesModel(
        marca: 'Nissan',
        modelo: 'Qashqai',
        anio: 2020,
        categoria: 'Motor',
        cilindrada: '2.0',
        combustible: 'Gasolina',
        transito: 'En Tránsito Marítimo',
      ),
    );

    provider.seleccionarOrden(backorderInicial);

    // 1. Debe inicializarse automáticamente en modalidad ABONO con el monto a cobrar acordado
    expect(provider.modalidad, equals('ABONO'));
    expect(provider.montoDeclarado, equals(200000));

    await tester.pumpWidget(createTestWidget(PanelDetalleCobro(provider: provider)));
    await tester.pumpAndSettle();

    // 2. La sección de atribución de SKU NO debe aparecer (el activo aún no existe)
    expect(find.text('ATRIBUCIÓN DE ACTIVO FÍSICO'), findsNothing);

    // 3. Banner explicativo del abono inicial de reserva
    expect(find.textContaining('Abono Inicial de Reserva: El activo solicitado aún no arriba al inventario'), findsOneWidget);

    // 4. El botón de confirmación de cobro debe estar habilitado sin pedir SKU
    expect(find.text('CONFIRMAR Y PROCESAR COBRO'), findsOneWidget);
    final boton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(boton.onPressed, isNotNull);
  });

  testWidgets('Flujo Backorder 2do Pago (Liquidación Final): sí exige atribución de SKU físico',
      (tester) async {
    setDesktopViewport(tester);

    // sampleBackorder tiene abonoPrevio: 900.000 y montoACobrar: 300.000
    provider.seleccionarOrden(sampleBackorder);

    // 1. Debe inicializarse en LIQUIDACION
    expect(provider.modalidad, equals('LIQUIDACION'));

    await tester.pumpWidget(createTestWidget(PanelDetalleCobro(provider: provider)));
    await tester.pumpAndSettle();

    // 2. La sección de atribución de SKU SÍ debe aparecer
    expect(find.text('ATRIBUCIÓN DE ACTIVO FÍSICO'), findsOneWidget);
    expect(find.textContaining('Ingresa el SKU del repuesto físico'), findsOneWidget);
  });
}
