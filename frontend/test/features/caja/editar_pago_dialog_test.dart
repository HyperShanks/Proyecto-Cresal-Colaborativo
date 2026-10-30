import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/caja/models/cobro_model.dart';
import 'package:frontend/features/caja/models/cobro_pendiente_model.dart';
import 'package:frontend/features/caja/models/historial_caja_model.dart';
import 'package:frontend/features/caja/presentation/widgets/editar_pago_dialog.dart';
import 'package:frontend/features/caja/services/caja_service.dart';

class MockCajaEdicionService implements ICajaService {
  bool editarPagoLlamado = false;
  Map<String, dynamic>? ultimoPayload;
  bool shouldThrow = false;

  @override
  Future<Map<String, dynamic>> editarPago({
    required String idPago,
    int? nuevoMonto,
    String? nuevoMetodo,
    DateTime? nuevaFechaPago,
    required String motivo,
  }) async {
    editarPagoLlamado = true;
    ultimoPayload = {
      'idPago': idPago,
      'nuevoMonto': nuevoMonto,
      'nuevoMetodo': nuevoMetodo,
      'nuevaFechaPago': nuevaFechaPago,
      'motivo': motivo,
    };
    if (shouldThrow) {
      throw Exception('Error simulado en backend');
    }
    return {'success': true};
  }

  @override
  Future<List<CobroPendienteModel>> obtenerCobrosPendientes({required int sucursalId, String? busqueda, String? tipoOperacion}) async => [];
  @override
  Future<RegistrarCobroResponseModel> registrarCobro(RegistrarCobroRequestModel request) async => throw UnimplementedError();
  @override
  Future<ValidarActivoBackorderResponseModel> validarActivoBackorder(ValidarActivoBackorderRequestModel request) async => throw UnimplementedError();
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
  }) async => throw UnimplementedError();
}

HistorialOrdenItemModel _crearOrdenMock({required String estado, int totalVenta = 100000, int montoPendiente = 40000}) {
  return HistorialOrdenItemModel(
    idOrden: 'ord-1234',
    folio: 'ORD-1001',
    tipoOperacion: 'VENTA',
    emiteQr: estado == 'Pagada',
    fechaIso: '2026-10-29',
    hora: '21:00',
    fechaHoraFormateada: '21:00 - 29/10/26',
    clienteNombre: 'Juan Pérez',
    vendedorNombre: 'Carlos Vendedor',
    cajeraNombre: 'Lorena Caja',
    estadoOrden: estado,
    modalidadPago: 'unico',
    metodosResumen: 'Efectivo: \$60.000',
    totalVenta: totalVenta,
    abonoPrevio: 0,
    totalLiquidado: totalVenta - montoPendiente,
    montoPendiente: montoPendiente,
    desglosePagos: [
      HistorialPagoDetalleModel(
        idTransaccion: 'tx-pago-01',
        metodoPago: 'Efectivo',
        monto: totalVenta - montoPendiente,
        fechaPago: DateTime(2026, 10, 29, 20, 0),
      ),
    ],
    articulos: [],
    historialMovimientos: [],
  );
}

void main() {
  group('EditarPagoDialog Widget Tests', () {
    testWidgets('Renderiza correctamente cabecera, resumen de orden y campos del formulario', (tester) async {
      final mockService = MockCajaEdicionService();
      final orden = _crearOrdenMock(estado: 'Reservada', totalVenta: 100000, montoPendiente: 40000);
      final pago = orden.desglosePagos.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditarPagoDialog(
              orden: orden,
              pago: pago,
              cajaService: mockService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Corregir Registro de Pago'), findsOneWidget);
      expect(find.textContaining('ORD-1001'), findsOneWidget);
      expect(find.text('TOTAL VENTA'), findsOneWidget);
      expect(find.text('MÉTODO DE PAGO'), findsOneWidget);
      expect(find.text('MONTO DEL ABONO'), findsOneWidget);
      expect(find.text('FECHA Y HORA DE IMPUTACIÓN'), findsOneWidget);
      expect(find.text('MOTIVO DE LA CORRECCIÓN'), findsOneWidget);
      expect(find.text('Guardar'), findsOneWidget);

      // Verifica que el botón Guardar inicia deshabilitado al no haber cambios
      final botonInicial = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Guardar'));
      expect(botonInicial.onPressed, isNull);
    });

    testWidgets('En orden Reservada, permite editar monto y muestra recálculo dinámico del saldo', (tester) async {
      final mockService = MockCajaEdicionService();
      final orden = _crearOrdenMock(estado: 'Reservada', totalVenta: 100000, montoPendiente: 40000);
      final pago = orden.desglosePagos.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditarPagoDialog(
              orden: orden,
              pago: pago,
              cajaService: mockService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Buscar el campo de monto y cambiar de 60.000 a 50.000
      final montoFinder = find.byType(TextFormField).first;
      await tester.enterText(montoFinder, '50000');
      await tester.pumpAndSettle();

      // Debe mostrar el nuevo saldo pendiente recalculado: $50.000
      expect(find.textContaining('Nuevo saldo pendiente resultante: \$ 50.000'), findsOneWidget);
    });

    testWidgets('En orden Pagada, bloquea la edición del monto del pago', (tester) async {
      final mockService = MockCajaEdicionService();
      final orden = _crearOrdenMock(estado: 'Pagada', totalVenta: 200000, montoPendiente: 0);
      final pago = orden.desglosePagos.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditarPagoDialog(
              orden: orden,
              pago: pago,
              cajaService: mockService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bloqueado en Pagada'), findsOneWidget);
      expect(find.textContaining('Para órdenes pagadas o entregadas, anule la orden'), findsOneWidget);
    });

    testWidgets('Valida que el motivo tenga al menos 10 caracteres', (tester) async {
      final mockService = MockCajaEdicionService();
      final orden = _crearOrdenMock(estado: 'Reservada');
      final pago = orden.desglosePagos.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditarPagoDialog(
              orden: orden,
              pago: pago,
              cajaService: mockService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Modificar monto para activar _hayCambios
      final montoFinder = find.byType(TextFormField).first;
      await tester.enterText(montoFinder, '50000');
      await tester.pumpAndSettle();

      // Escribir motivo corto
      final motivoFinder = find.byType(TextFormField).last;
      await tester.enterText(motivoFinder, 'error');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Ingrese un motivo claro de al menos 10 caracteres.'), findsOneWidget);
      expect(mockService.editarPagoLlamado, isFalse);
    });

    testWidgets('Envía petición al servicio con datos válidos y cierra modal', (tester) async {
      final mockService = MockCajaEdicionService();
      final orden = _crearOrdenMock(estado: 'Reservada', totalVenta: 100000, montoPendiente: 40000);
      final pago = orden.desglosePagos.first;

      bool? modalResultado;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                modalResultado = await EditarPagoDialog.show(
                  context: ctx,
                  orden: orden,
                  pago: pago,
                  cajaService: mockService,
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      // Cambiar método a Transferencia
      await tester.tap(find.text('Efectivo').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Transferencia Bancaria').last);
      await tester.pumpAndSettle();

      // Escribir motivo válido
      final motivoFinder = find.byType(TextFormField).last;
      await tester.enterText(motivoFinder, 'Cliente pagó con Transferencia BancoEstado comprobante 4892');
      await tester.pumpAndSettle();

      // Presionar Guardar
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(mockService.editarPagoLlamado, isTrue);
      expect(mockService.ultimoPayload?['nuevoMetodo'], 'Transferencia');
      expect(modalResultado, isTrue);
    });

    testWidgets('Garantía Anti-Overflow en resolución estrecha (320px)', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockService = MockCajaEdicionService();
      final orden = _crearOrdenMock(estado: 'Reservada');
      final pago = orden.desglosePagos.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditarPagoDialog(
              orden: orden,
              pago: pago,
              cajaService: mockService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
