import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/caja/models/cobro_pendiente_model.dart';
import 'package:frontend/features/caja/models/cobro_model.dart';
import 'package:frontend/features/caja/models/historial_caja_model.dart';
import 'package:frontend/features/caja/services/caja_service.dart';
import 'package:frontend/features/caja/presentation/providers/caja_provider.dart';
import 'package:frontend/features/caja/presentation/widgets/cobro_pendiente_card.dart';
import 'package:frontend/features/caja/presentation/widgets/bandeja_cobros_panel.dart';
import 'package:frontend/features/caja/presentation/screens/caja_main_screen.dart';

class MockCajaService implements ICajaService {
  List<CobroPendienteModel> dummyItems = [];
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

    var result = List<CobroPendienteModel>.from(dummyItems);

    if (tipoOperacion != null && tipoOperacion != 'TODOS') {
      result = result.where((e) => e.tipoOperacion == tipoOperacion).toList();
    }

    if (busqueda != null && busqueda.isNotEmpty) {
      final q = busqueda.toLowerCase();
      result = result.where((e) {
        return e.folioDocumento.toLowerCase().contains(q) ||
            e.clienteNombre.toLowerCase().contains(q) ||
            e.clienteRut.toLowerCase().contains(q) ||
            e.vendedorNombre.toLowerCase().contains(q);
      }).toList();
    }

    return result;
  }

  @override
  Future<RegistrarCobroResponseModel> registrarCobro(
    RegistrarCobroRequestModel request,
  ) async {
    if (shouldFail) {
      throw Exception('Fallo de conexión simulado');
    }
    return RegistrarCobroResponseModel(
      success: true,
      mensaje: 'Cobro registrado exitosamente',
      folio: 'ORD-9780',
      montoCobrado: request.montoDeclarado,
      nuevoSaldoPendiente: 0,
      estadoActualizado: 'Pagada',
      transaccionesIds: ['tx-001'],
    );
  }

  @override
  Future<ValidarActivoBackorderResponseModel> validarActivoBackorder(
    ValidarActivoBackorderRequestModel request,
  ) async {
    return ValidarActivoBackorderResponseModel(
      coincide: true,
      discrepancias: [],
      mensaje: 'Activo validado exitosamente',
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
  late CobroPendienteModel sampleVenta;
  late CobroPendienteModel sampleBackorder;

  setUp(() {
    mockService = MockCajaService();

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
          precio: 550000,
          subtotal: 550000,
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
        cilindrada: '2.0L Turbo Diesel (D4HA)',
        combustible: 'Diésel',
        transito: 'En Tránsito Marítimo (Arribo est.: 10 días)',
      ),
    );

    mockService.dummyItems = [sampleVenta, sampleBackorder];
  });

  group('SPEC-HU-4.2: DTOs & Model Tests', () {
    test('CobroPendienteModel y DTOs serializan y deserializan correctamente', () {
      final json = sampleVenta.toJson();
      expect(json['folio_documento'], 'ORD-9780');
      expect(json['tipo_operacion'], 'VENTA');
      expect(json['monto_a_cobrar'], 500000);
      expect(sampleVenta.esVenta, isTrue);
      expect(sampleVenta.esBackorder, isFalse);

      final fromJson = CobroPendienteModel.fromJson(json);
      expect(fromJson.folioDocumento, 'ORD-9780');
      expect(fromJson.articulos.length, 1);
      expect(fromJson.articulos.first.sku, 'MOT-MG-ZS-15-089');

      expect(sampleBackorder.esBackorder, isTrue);
      expect(sampleBackorder.especificacionesBackorder?.marca, 'Hyundai');
    });
  });

  group('SPEC-HU-4.2: CajaProvider State Tests', () {
    test('CajaProvider carga cobros, calcula totales y selecciona orden', () async {
      final provider = CajaProvider(cajaService: mockService);
      expect(provider.cobros, isEmpty);

      await provider.cargarCobrosPendientes(sucursalId: 1);

      expect(provider.cobros.length, 2);
      expect(provider.totalCobros, 2);
      expect(provider.totalVentasCount, 1);
      expect(provider.totalBackordersCount, 1);
      expect(provider.montoTotalPendiente, 800000);

      // Selección de orden
      provider.seleccionarOrden(sampleVenta);
      expect(provider.ordenSeleccionada?.idReferencia, sampleVenta.idReferencia);
    });

    test('CajaProvider filtra por píldoras VENTA y BACKORDER', () async {
      final provider = CajaProvider(cajaService: mockService);
      await provider.cargarCobrosPendientes(sucursalId: 1);

      provider.setFiltroTipo('VENTA');
      await Future.delayed(Duration.zero);
      expect(provider.filtroTipo, 'VENTA');
      expect(provider.cobros.length, 1);
      expect(provider.cobros.first.folioDocumento, 'ORD-9780');

      provider.setFiltroTipo('BACKORDER');
      await Future.delayed(Duration.zero);
      expect(provider.filtroTipo, 'BACKORDER');
      expect(provider.cobros.length, 1);
      expect(provider.cobros.first.folioDocumento, 'RES-5401');
    });

    test('CajaProvider maneja errores de red adecuadamente', () async {
      mockService.shouldFail = true;
      final provider = CajaProvider(cajaService: mockService);

      await provider.cargarCobrosPendientes(sucursalId: 1);
      expect(provider.errorMessage, isNotNull);
      expect(provider.cobros, isEmpty);
    });
  });

  group('SPEC-HU-4.2: CobroPendienteCard Widget Tests', () {
    testWidgets('CobroPendienteCard renderiza datos de Venta y badge Ámbar', (tester) async {
      tester.view.physicalSize = const Size(500, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CobroPendienteCard(
              orden: sampleVenta,
              isSelected: false,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('ORD-9780'), findsOneWidget);
      expect(find.text('Venta en Tienda'), findsOneWidget);
      expect(find.text('Cristobal Alejandro Espinoza Perez'), findsOneWidget);
      expect(find.text('RUT: 14.892.401-2'), findsOneWidget);
      expect(find.text('Vendedor: Juaquin Leiva'), findsOneWidget);
      expect(find.text('Saldo a Pagar:'), findsOneWidget);
      expect(find.text('\$500.000'), findsOneWidget);

      await tester.tap(find.byType(CobroPendienteCard));
      expect(tapped, isTrue);
    });

    testWidgets('CobroPendienteCard renderiza datos de Backorder y badge Índigo', (tester) async {
      tester.view.physicalSize = const Size(500, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CobroPendienteCard(
              orden: sampleBackorder,
              isSelected: true,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('RES-5401'), findsOneWidget);
      expect(find.text('Ventas en Verde'), findsOneWidget);
      expect(find.text('Camila Andrea Soto Lagos'), findsOneWidget);
      expect(find.text('Abono Inicial:'), findsOneWidget);
      expect(find.text('\$300.000'), findsOneWidget);
    });
  });

  group('SPEC-HU-4.2: BandejaCobrosPanel & Zero State Widget Tests', () {
    testWidgets('BandejaCobrosPanel renderiza cabecera, buscador, píldoras y lista de tarjetas', (tester) async {
      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final provider = CajaProvider(cajaService: mockService);
      await provider.cargarCobrosPendientes(sucursalId: 1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 420,
              child: ListenableBuilder(
                listenable: provider,
                builder: (context, _) => BandejaCobrosPanel(provider: provider),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CAJA'), findsOneWidget);
      expect(find.text('Pagos Pendientes'), findsOneWidget);
      expect(find.text('2 órdenes esperando cobro'), findsOneWidget);
      expect(find.text('Todos (2)'), findsOneWidget);
      expect(find.text('Saldos Venta (1)'), findsOneWidget);
      expect(find.text('Ventas en Verde (1)'), findsOneWidget);
      expect(find.text('ORD-9780'), findsOneWidget);
      expect(find.text('RES-5401'), findsOneWidget);

      // Tap en píldora Saldos Venta
      await tester.tap(find.text('Saldos Venta (1)'));
      await tester.pumpAndSettle();
      expect(find.text('ORD-9780'), findsOneWidget);
      expect(find.text('RES-5401'), findsNothing);

      // Búsqueda en caja de texto
      final searchInput = find.byType(TextField);
      await tester.enterText(searchInput, 'Cristobal');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('ORD-9780'), findsOneWidget);
    });

    testWidgets('BandejaCobrosPanel renderiza Zero State cuando no hay órdenes', (tester) async {
      mockService.dummyItems = [];
      final provider = CajaProvider(cajaService: mockService);
      await provider.cargarCobrosPendientes(sucursalId: 1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 420,
              child: ListenableBuilder(
                listenable: provider,
                builder: (context, _) => BandejaCobrosPanel(provider: provider),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No se encontraron órdenes pendientes'), findsOneWidget);
      expect(find.byIcon(Icons.inbox_rounded), findsOneWidget);
    });
  });

  group('SPEC-HU-4.2: Master-Detail en CajaMainScreen Tests', () {
    testWidgets('CajaMainScreen sincroniza selección Master-Detail en panel derecho', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final provider = CajaProvider(cajaService: mockService);
      await provider.cargarCobrosPendientes(sucursalId: 1);

      await tester.pumpWidget(
        MaterialApp(
          home: CajaMainScreen(provider: provider),
        ),
      );
      await tester.pumpAndSettle();

      // Estado inicial: mensaje para seleccionar orden
      expect(find.text('Seleccione una orden para procesar el cobro'), findsOneWidget);

      // Toggle menú hamburguesa para colapsar y expandir sidebar
      final toggleMenuBtn = find.byIcon(Icons.menu_open_rounded);
      expect(toggleMenuBtn, findsOneWidget);
      await tester.tap(toggleMenuBtn);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.menu_rounded), findsOneWidget);

      // Expandir de nuevo
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();

      // Seleccionar orden de Venta (ORD-9780)
      await tester.tap(find.text('ORD-9780'));
      await tester.pumpAndSettle();

      // Panel derecho muestra detalle de la orden seleccionada
      expect(find.text('DETALLE DE REPUESTOS Y ARTÍCULOS'), findsOneWidget);
      expect(find.text('Motor MG ZS 1.5 VTi-Tech Completo'), findsWidgets);
      expect(find.text('TOTAL VENTA'), findsOneWidget);

      // Seleccionar orden de Backorder (RES-5401)
      await tester.tap(find.text('RES-5401').first);
      await tester.pumpAndSettle();

      expect(find.text('ESPECIFICACIONES DE VENTA EN VERDE'), findsOneWidget);
      expect(find.text('Tucson 2.0 CRDi Turbo Diesel'), findsOneWidget);
      expect(find.text('PRECIO ACORDADO'), findsOneWidget);
    });
  });
}
