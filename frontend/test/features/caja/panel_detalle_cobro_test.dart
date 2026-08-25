import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/caja/models/cobro_pendiente_model.dart';
import 'package:frontend/features/caja/models/cobro_model.dart';
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
    expect(find.text('Reserva Backorder'), findsOneWidget);
    expect(find.text('ESPECIFICACIONES DE LA RESERVA BACKORDER'), findsOneWidget);
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
}
