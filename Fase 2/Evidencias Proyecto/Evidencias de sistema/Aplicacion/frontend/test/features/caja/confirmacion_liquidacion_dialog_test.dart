import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/caja/models/cobro_model.dart';
import 'package:frontend/features/caja/models/cobro_pendiente_model.dart';
import 'package:frontend/features/caja/presentation/widgets/confirmacion_liquidacion_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CobroPendienteModel ordenPrueba;

  setUp(() {
    ordenPrueba = CobroPendienteModel(
      idReferencia: 'ref-test-liquidar',
      folioDocumento: 'ORD-8821',
      tipoOperacion: 'VENTA',
      estadoDocumento: 'Reservada',
      clienteNombre: 'Valentina Silva Castro',
      clienteRut: '19.876.543-2',
      vendedorNombre: 'Marcos Rivas',
      fechaEmision: DateTime.now(),
      fechaEmisionFormateada: '08/10/2026',
      horaEmisionFormateada: '14:30',
      totalOperacion: 850000,
      abonoPrevio: 350000,
      saldoPendiente: 500000,
      montoACobrar: 500000,
      articulos: [],
    );
  });

  void setViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget createDialogHost({required Widget child, Size? size}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: size?.width ?? 600,
            height: size?.height ?? 700,
            child: child,
          ),
        ),
      ),
    );
  }

  testWidgets(
      'ConfirmacionLiquidacionDialog: Renderiza advertencia, resumen financiero y estado inicial desmarcado',
      (tester) async {
    await tester.pumpWidget(
      createDialogHost(
        child: ConfirmacionLiquidacionDialog(
          orden: ordenPrueba,
          montoALiquidar: 500000,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Título y mensaje claro (sin terminología técnica ajena a la cajera)
    expect(find.text('Confirmar Liquidación Total'), findsOneWidget);
    expect(
      find.text('Estás a punto de liquidar el total de la orden.\n¿Estás seguro que no es un abono?'),
      findsOneWidget,
    );
    expect(find.textContaining('Poka'), findsNothing);

    // 2. Resumen financiero visual
    expect(find.text('ORD-8821'), findsOneWidget);
    expect(find.text('Valentina Silva Castro'), findsOneWidget);
    expect(find.text('\$850.000'), findsOneWidget); // Total
    expect(find.text('- \$350.000'), findsOneWidget); // Abonos previos
    expect(find.text('\$500.000'), findsOneWidget); // Monto a liquidar
    expect(find.textContaining('Saldo restante tras este pago: \$0 CLP'), findsOneWidget);

    // 3. Casilla desmarcada por defecto y botón deshabilitado
    final checkboxFinder = find.byType(Checkbox);
    expect(checkboxFinder, findsOneWidget);
    final checkbox = tester.widget<Checkbox>(checkboxFinder);
    expect(checkbox.value, isFalse);

    final btnConfirmarFinder = find.widgetWithText(ElevatedButton, 'Confirmar');
    expect(btnConfirmarFinder, findsOneWidget);
    final btnConfirmar = tester.widget<ElevatedButton>(btnConfirmarFinder);
    expect(btnConfirmar.onPressed, isNull);
  });

  testWidgets(
      'ConfirmacionLiquidacionDialog: Al marcar casilla se activa botón y confirmar retorna true',
      (tester) async {
    setViewport(tester);
    bool? resultadoRetornado;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                resultadoRetornado = await ConfirmacionLiquidacionDialog.show(
                  context: ctx,
                  orden: ordenPrueba,
                  montoALiquidar: 500000,
                );
              },
              child: const Text('Abrir Modal'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Abrir modal
    await tester.tap(find.text('Abrir Modal'));
    await tester.pumpAndSettle();

    // Marcar checkbox
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    // Presionar Confirmar
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(resultadoRetornado, isTrue);
  });

  testWidgets(
      'ConfirmacionLiquidacionDialog: Presionar Cancelar / Volver cierra el modal retornando false',
      (tester) async {
    setViewport(tester);
    bool? resultadoRetornado;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                resultadoRetornado = await ConfirmacionLiquidacionDialog.show(
                  context: ctx,
                  orden: ordenPrueba,
                  montoALiquidar: 500000,
                );
              },
              child: const Text('Abrir Modal'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Abrir modal
    await tester.tap(find.text('Abrir Modal'));
    await tester.pumpAndSettle();

    // Presionar Cancelar / Volver
    await tester.tap(find.text('Cancelar / Volver'));
    await tester.pumpAndSettle();

    expect(resultadoRetornado, isFalse);
  });

  testWidgets(
      'ConfirmacionLiquidacionDialog: Anti-overflow en viewport POS compacto (420 x 600)',
      (tester) async {
    tester.view.physicalSize = const Size(420, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      createDialogHost(
        size: const Size(420, 600),
        child: ConfirmacionLiquidacionDialog(
          orden: ordenPrueba,
          montoALiquidar: 500000,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Comprobar que no hay RenderFlex overflow y todos los elementos críticos están presentes
    expect(find.text('Confirmar Liquidación Total'), findsOneWidget);
    expect(find.text('Cancelar / Volver'), findsOneWidget);
    expect(find.text('Confirmar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'ConfirmacionLiquidacionDialog: Venta nueva al 100% con pago dividido y descuento muestra métodos y tamaño idéntico de botones',
      (tester) async {
    setViewport(tester);

    final ventaNueva = CobroPendienteModel(
      idReferencia: 'ref-venta-nueva',
      folioDocumento: 'ORD-9001',
      tipoOperacion: 'VENTA',
      estadoDocumento: 'Reservada',
      clienteNombre: 'Pedro Muñoz',
      clienteRut: '12.345.678-9',
      vendedorNombre: 'Carlos Mesón',
      fechaEmision: DateTime.now(),
      fechaEmisionFormateada: '23/11/2026',
      horaEmisionFormateada: '10:15',
      totalOperacion: 600000,
      descuento: 50000,
      abonoPrevio: 0,
      saldoPendiente: 550000,
      montoACobrar: 550000,
      articulos: [],
    );

    await tester.pumpWidget(
      createDialogHost(
        child: ConfirmacionLiquidacionDialog(
          orden: ventaNueva,
          montoALiquidar: 550000,
          esLiquidacion: true,
          saldoPendienteActual: 550000,
          pagos: [
            TransaccionPagoItemModel(metodo: 'Efectivo', monto: 250000),
            TransaccionPagoItemModel(metodo: 'Debito', monto: 300000),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('VENTA NUEVA • COBRO TOTAL (100%)'), findsOneWidget);
    expect(find.text('Confirmar Cobro Total'), findsOneWidget);
    expect(find.text('Total Bruto:'), findsOneWidget);
    expect(find.text('- \$50.000'), findsOneWidget);
    expect(find.text('MEDIOS DE PAGO DIVIDIDOS (2)'), findsOneWidget);
    expect(find.text('• Efectivo'), findsOneWidget);
    expect(find.text('\$250.000'), findsOneWidget);
    expect(find.text('• Debito'), findsOneWidget);
    expect(find.text('\$300.000'), findsOneWidget);
    expect(find.textContaining('Saldo restante tras este pago: \$0 CLP'), findsOneWidget);

    // Verificar tamaño idéntico entre botón Cancelar y Confirmar
    final cancelSize = tester.getSize(find.byType(OutlinedButton));
    final confirmSize = tester.getSize(find.byType(ElevatedButton));
    expect(cancelSize.height, equals(48.0));
    expect(confirmSize.height, equals(48.0));
    expect(cancelSize.width, closeTo(confirmSize.width, 1.0));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'ConfirmacionLiquidacionDialog: Abono parcial muestra saldo pendiente en Reservada sin decir \$0',
      (tester) async {
    setViewport(tester);

    final ventaParaAbono = CobroPendienteModel(
      idReferencia: 'ref-abono-parcial',
      folioDocumento: 'ORD-9002',
      tipoOperacion: 'VENTA',
      estadoDocumento: 'Reservada',
      clienteNombre: 'María López',
      clienteRut: '15.111.222-3',
      vendedorNombre: 'Carlos Mesón',
      fechaEmision: DateTime.now(),
      fechaEmisionFormateada: '23/11/2026',
      horaEmisionFormateada: '11:00',
      totalOperacion: 800000,
      abonoPrevio: 0,
      abonoRequerido: 200000,
      saldoPendiente: 800000,
      montoACobrar: 200000,
      articulos: [],
    );

    await tester.pumpWidget(
      createDialogHost(
        child: ConfirmacionLiquidacionDialog(
          orden: ventaParaAbono,
          montoALiquidar: 200000,
          esLiquidacion: false,
          saldoPendienteActual: 800000,
          pagos: [
            TransaccionPagoItemModel(metodo: 'Transferencia', monto: 200000),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('VENTA NUEVA • PRIMER ABONO'), findsOneWidget);
    expect(find.text('Confirmar Primer Abono'), findsOneWidget);
    expect(find.text('Monto del Abono Ahora:'), findsOneWidget);
    expect(
      find.text('Saldo restante tras este abono: \$600.000 CLP (Queda en Reservada)'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'ConfirmacionLiquidacionDialog: Venta en Verde (Backorder) cubre seña inicial, abono adicional y liquidación total',
      (tester) async {
    setViewport(tester);

    // 1. Seña inicial en Backorder nueva
    final boNueva = CobroPendienteModel(
      idReferencia: 'ref-bo-nueva',
      folioDocumento: 'RES-1010',
      tipoOperacion: 'BACKORDER',
      estadoDocumento: 'Pendiente',
      clienteNombre: 'Andrés Vega',
      clienteRut: '17.222.333-4',
      vendedorNombre: 'Marcos Rivas',
      fechaEmision: DateTime.now(),
      fechaEmisionFormateada: '23/11/2026',
      horaEmisionFormateada: '12:00',
      totalOperacion: 1500000,
      abonoPrevio: 0,
      abonoRequerido: 500000,
      saldoPendiente: 1500000,
      montoACobrar: 500000,
      articulos: [],
    );

    await tester.pumpWidget(
      createDialogHost(
        child: ConfirmacionLiquidacionDialog(
          orden: boNueva,
          montoALiquidar: 500000,
          esLiquidacion: false,
          saldoPendienteActual: 1500000,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('VENTA EN VERDE • SEÑA INICIAL'), findsOneWidget);
    expect(find.text('Confirmar Seña de Venta en Verde'), findsOneWidget);
    expect(
      find.text('Saldo restante tras este abono: \$1.000.000 CLP (Queda en Reservada)'),
      findsOneWidget,
    );

    // 2. Liquidación total de Backorder con abono previo
    final boConAbono = CobroPendienteModel(
      idReferencia: 'ref-bo-liq',
      folioDocumento: 'RES-1011',
      tipoOperacion: 'BACKORDER',
      estadoDocumento: 'Confirmada',
      clienteNombre: 'Andrés Vega',
      clienteRut: '17.222.333-4',
      vendedorNombre: 'Marcos Rivas',
      fechaEmision: DateTime.now(),
      fechaEmisionFormateada: '23/11/2026',
      horaEmisionFormateada: '12:00',
      totalOperacion: 1500000,
      abonoPrevio: 500000,
      saldoPendiente: 1000000,
      montoACobrar: 1000000,
      articulos: [],
    );

    await tester.pumpWidget(
      createDialogHost(
        child: ConfirmacionLiquidacionDialog(
          orden: boConAbono,
          montoALiquidar: 1000000,
          esLiquidacion: true,
          saldoPendienteActual: 1000000,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('VENTA EN VERDE • LIQUIDACIÓN TOTAL'), findsOneWidget);
    expect(find.text('Confirmar Liquidación Venta en Verde'), findsOneWidget);
    expect(
      find.text('Saldo restante tras este pago: \$0 CLP (Venta en Verde Saldada)'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'ConfirmacionLiquidacionDialog: Anti-overflow extremo en viewport 320x600 con múltiples medios de pago y botones parejos',
      (tester) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      createDialogHost(
        size: const Size(320, 600),
        child: ConfirmacionLiquidacionDialog(
          orden: ordenPrueba,
          montoALiquidar: 500000,
          esLiquidacion: true,
          saldoPendienteActual: 500000,
          pagos: [
            TransaccionPagoItemModel(metodo: 'Efectivo', monto: 200000),
            TransaccionPagoItemModel(metodo: 'Transferencia', monto: 300000),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cancelSize = tester.getSize(find.byType(OutlinedButton));
    final confirmSize = tester.getSize(find.byType(ElevatedButton));
    expect(cancelSize.height, equals(48.0));
    expect(confirmSize.height, equals(48.0));
    expect(cancelSize.width, closeTo(confirmSize.width, 1.0));
    expect(tester.takeException(), isNull);
  });
}
