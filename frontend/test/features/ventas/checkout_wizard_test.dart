// frontend/test/features/ventas/checkout_wizard_test.dart
// Tests automatizados para el Checkout Wizard por Pasos y Backorders (SPEC-HU-05)

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter/services.dart';
import 'package:frontend/features/ventas/models/checkout_wizard_models.dart';
import 'package:frontend/features/ventas/controllers/checkout_wizard_controller.dart';
import 'package:frontend/features/ventas/services/ventas_service.dart';
import 'package:frontend/features/ventas/presentation/screens/checkout_wizard_screen.dart';
import 'package:frontend/features/ventas/presentation/widgets/modal_backorder_form.dart';

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
  group('SPEC-HU-05: CheckoutWizardController - Pruebas Unitarias de Estado', () {
    late CheckoutWizardController controller;

    setUp(() {
      controller = CheckoutWizardController();
    });

    test('Estado inicial está en el Paso 0 con totales en 0', () {
      expect(controller.currentStep, equals(0));
      expect(controller.totalItemsCount, equals(0));
      expect(controller.totalVenta, equals(0));
      expect(controller.montoPendiente, equals(0));
      expect(controller.tipoEntrega, equals('Retiro'));
    });

    test('Agregar repuestos inventariados, manuales y backorders calcula subtotales correctamente', () {
      // 1. Activo inventariado
      controller.addItemInventariado(
        idActivo: 'act-001',
        sku: 'MOT-TOY-001',
        descripcion: 'Motor Toyota Corolla 1.8',
        precio: 650000,
        pasillo: 'P-02',
        pallet: 'PAL-05',
      );
      expect(controller.subtotalInventario, equals(650000));

      // 2. Ítem manual
      controller.addItemManual(
        const ItemManualModel(
          descripcion: 'Aceite 5W30 Sintético',
          cantidad: 2,
          precioUnitario: 25000,
          precioFinal: 50000,
        ),
      );
      expect(controller.subtotalManuales, equals(50000));

      // 3. Reserva Backorder con abono
      controller.addReservaBackorder(
        const ReservaBackorderModel(
          idCategoriaRequerida: 2,
          categoriaNombre: 'Caja de Cambios',
          marcaRequerida: 'Toyota',
          modeloRequerido: 'Corolla',
          anioRequerido: 2021,
          precioAcordado: 400000,
          montoAbonado: 150000,
        ),
      );
      expect(controller.subtotalReservas, equals(400000));

      // Totales: 1 inventariado + 2 unidades manuales + 1 reserva = 4
      expect(controller.totalItemsCount, equals(4));
      expect(controller.totalVenta, equals(1100000)); // 650.000 + 50.000 + 400.000
      expect(controller.abonoReservas, equals(150000));
      expect(controller.montoPendiente, equals(950000)); // 1.100.000 - 150.000
    });

    test('Descuento por Vale a Favor descuenta del totalVenta y recalcula montoPendiente', () {
      controller.addItemInventariado(
        idActivo: 'act-001',
        sku: 'MOT-TOY-001',
        descripcion: 'Motor Toyota Corolla 1.8',
        precio: 100000,
      );
      expect(controller.subtotal, equals(100000));
      expect(controller.totalVenta, equals(100000));

      // Aplicar descuento por vale a favor
      controller.setDescuento(20000);
      expect(controller.descuento, equals(20000));
      expect(controller.totalVenta, equals(80000));
      expect(controller.montoPendiente, equals(80000));

      // Agregar abono adicional
      controller.setAbonoAdicional(30000);
      expect(controller.montoPendiente, equals(50000));

      // Descuento mayor al subtotal se ajusta a 0 (nunca negativo)
      controller.setDescuento(150000);
      expect(controller.totalVenta, equals(0));
      expect(controller.montoPendiente, equals(0));
    });

    test('Validación de paso impide avanzar sin ítems (Paso 0 -> Paso 1)', () {
      expect(controller.nextStep(), isFalse);
      expect(controller.currentStep, equals(0));
      expect(controller.errorMessage, contains('al menos un artículo'));

      controller.addItemInventariado(
        idActivo: 'act-001',
        sku: 'SKU-1',
        descripcion: 'Alternador',
        precio: 80000,
      );

      expect(controller.nextStep(), isTrue);
      expect(controller.currentStep, equals(1));
    });

    test('Validación de paso impide avanzar sin cliente asignado (Paso 1 -> Paso 2)', () {
      controller.addItemInventariado(idActivo: 'act-001', sku: 'SKU-1', descripcion: 'Alternador', precio: 80000);
      controller.nextStep(); // A paso 1

      expect(controller.nextStep(), isFalse);
      expect(controller.currentStep, equals(1));
      expect(controller.errorMessage, contains('cliente'));

      controller.setCliente(
        const ClienteWizardModel(
          idCliente: 'cli-001',
          rut: '19.888.777-6',
          nombres: 'Roberto',
          apellidos: 'López',
          telefono: '+56911223344',
          consentimientoLegal: true,
          estado: 'Activo',
        ),
      );

      expect(controller.nextStep(), isTrue);
      expect(controller.currentStep, equals(2));
    });

    test('Retroceder pasos preserva los datos ingresados', () {
      controller.addItemInventariado(idActivo: 'act-001', sku: 'SKU-1', descripcion: 'Alternador', precio: 80000);
      controller.setCliente(
        const ClienteWizardModel(
          idCliente: 'cli-001',
          rut: '19.888.777-6',
          nombres: 'Roberto',
          apellidos: 'López',
          consentimientoLegal: true,
          estado: 'Activo',
        ),
      );

      controller.nextStep(); // A paso 1
      controller.nextStep(); // A paso 2
      expect(controller.currentStep, equals(2));

      // Retroceder a Paso 0
      controller.previousStep();
      controller.previousStep();
      expect(controller.currentStep, equals(0));

      // Los datos siguen intactos
      expect(controller.itemsInventariados.length, equals(1));
      expect(controller.clienteSeleccionado?.nombres, equals('Roberto'));
    });

    test('Validación de traslado inter-sucursal impide seleccionar misma sucursal origen y destino', () {
      controller.addItemInventariado(idActivo: 'act-001', sku: 'SKU-1', descripcion: 'Alternador', precio: 80000);
      controller.setCliente(
        const ClienteWizardModel(
          idCliente: 'cli-001',
          rut: '19.888.777-6',
          nombres: 'Roberto',
          apellidos: 'López',
          consentimientoLegal: true,
          estado: 'Activo',
        ),
      );
      controller.nextStep(); // Paso 1
      controller.nextStep(); // Paso 2

      controller.setTipoEntrega('Traslado');
      controller.setIdSucursalActual(1); // Viña del Mar
      // Forzar que el destino sea igual al origen
      controller.setIdSucursalDestino(1);
      expect(controller.validateStep3(), isFalse);
      expect(controller.nextStep(), isFalse);
      expect(controller.errorMessage, contains('no puede ser igual'));

      // Asignar destino válido (Limache)
      controller.setIdSucursalDestino(2);
      expect(controller.validateStep3(), isTrue);
      expect(controller.nextStep(), isTrue);
      expect(controller.currentStep, equals(3));
    });
  });

  group('SPEC-HU-05: VentasService.processCheckoutWizard - HTTP Mock', () {
    test('Envía payload consolidado y deserializa respuesta 201 Created', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/checkout-wizard'));
        expect(request.method, equals('POST'));

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['total_venta'], equals(500000));
        expect(body['tipo_entrega'], equals('Retiro'));

        return http.Response(
          jsonEncode({
            'id_orden': 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d',
            'estado': 'Reservada',
            'total_venta': 500000,
            'monto_pendiente': 350000,
            'reservas_generadas': 1,
            'activos_reservados': 0,
            'despacho_generado': false,
            'msg': 'Orden generada exitosamente.',
          }),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      const req = CheckoutWizardRequestModel(
        idCliente: 'cli-001',
        tipoEntrega: 'Retiro',
        totalVenta: 500000,
        montoPendiente: 350000,
        reservas: [
          ReservaBackorderModel(
            idCategoriaRequerida: 1,
            marcaRequerida: 'Nissan',
            modeloRequerido: 'Sentra',
            precioAcordado: 500000,
            montoAbonado: 150000,
          ),
        ],
      );

      final response = await VentasService.processCheckoutWizard(req, client: mockClient);
      expect(response.idOrden, equals('a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d'));
      expect(response.estado, equals('Reservada'));
      expect(response.reservasGeneradas, equals(1));
      expect(response.montoPendiente, equals(350000));
    });
  });

  group('SPEC-HU-05: ModalBackorderForm & CheckoutWizardScreen Widget Tests', () {
    testWidgets('ModalBackorderForm renderiza campos y valida entradas obligatorias', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ModalBackorderForm.mostrar(context),
                child: const Text('Abrir Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Venta en Verde'), findsOneWidget);
      expect(find.text('AÑADIR RESERVA'), findsOneWidget);

      // Intentar guardar con campos vacíos -> Valida campos requeridos
      await tester.tap(find.text('AÑADIR RESERVA'));
      await tester.pumpAndSettle();

      expect(find.text('Requerido'), findsWidgets);
    });

    testWidgets('ModalBackorderForm selector de categorías solo contiene Motor y Caja de Cambios', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ModalBackorderForm.mostrar(context),
                child: const Text('Abrir Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Modal'));
      await tester.pumpAndSettle();

      // Abrir el dropdown de categorías
      await tester.tap(find.text('Motor').first);
      await tester.pumpAndSettle();

      // Verificar que están disponibles únicamente Motor y Caja de Cambios
      expect(find.text('Motor'), findsWidgets);
      expect(find.text('Caja de Cambios'), findsWidgets);

      // Verificar que NO existen opciones adicionales descartadas
      expect(find.text('Culata'), findsNothing);
      expect(find.text('Alternador'), findsNothing);
      expect(find.text('Diferencial'), findsNothing);
      expect(find.text('Motor de Arranque'), findsNothing);
      expect(find.text('Computador ECU'), findsNothing);
    });

    testWidgets('CheckoutWizardScreen renderiza el Stepper de 5 pasos', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CheckoutWizardScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Checkout Transaccional'), findsOneWidget);
      expect(find.text('Ítems'), findsOneWidget);
      expect(find.text('Cliente'), findsOneWidget);
      expect(find.text('Venta en Verde'), findsOneWidget);
      expect(find.text('Venta libre'), findsOneWidget);
      expect(find.text('Siguiente'), findsNothing);
    });

    testWidgets('CheckoutWizardScreen permite activar Consumidor Final y avanzar de paso', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CheckoutWizardScreen(
            initialInventario: [
              {'id_activo': 'act-101', 'sku': 'SKU-101', 'descripcion': 'Alternador', 'precio': 120000}
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Avanzar de Paso 0 a Paso 1 (Cliente CRM)
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();

      expect(find.text('2. Datos del Cliente (Micro-CRM)'), findsOneWidget);
      expect(find.byKey(const Key('switch_cliente_anonimo')), findsOneWidget);

      // Activar Switch Consumidor Final
      await tester.tap(find.byKey(const Key('switch_cliente_anonimo')));
      await tester.pumpAndSettle();

      expect(find.textContaining('RUT 6.666.666-6'), findsOneWidget);

      // Avanzar a Paso 2 (Logística)
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();

      expect(find.text('3. Modalidad de Entrega y Despacho'), findsOneWidget);
      expect(find.text('Traslado Sucursal'), findsOneWidget);
    });

    testWidgets('CheckoutWizardScreen botón Venta libre abre VentaLibreDialog, agrega ítem y oculta botón Siguiente si está vacío', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CheckoutWizardScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Cuando el carrito está vacío, el botón Siguiente NO aparece en pantalla
      expect(find.byKey(const Key('btn_siguiente_wizard')), findsNothing);

      // Abrir modal Venta libre
      await tester.tap(find.text('Venta libre'));
      await tester.pumpAndSettle();

      expect(find.text('Venta Libre'), findsOneWidget);
      expect(find.text('DESCRIPCIÓN DEL ARTÍCULO / SERVICIO *'), findsOneWidget);
      expect(find.text('MONTO UNITARIO (CLP) *'), findsOneWidget);
      expect(find.text('CANTIDAD'), findsOneWidget);
      expect(find.text('Agregar al Carrito'), findsOneWidget);

      // Ingresar ítem de venta libre
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Ej. Perno culata especial, Mano de obra, etc.'),
        'Aceite Motor 1L',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '0'),
        '15000',
      );
      await tester.tap(find.text('Agregar al Carrito'));
      await tester.pumpAndSettle();

      expect(find.text('Aceite Motor 1L'), findsOneWidget);
      expect(find.textContaining('Cantidad: 1'), findsOneWidget);

      // Ahora que hay un artículo, el botón Siguiente aparece
      expect(find.byKey(const Key('btn_siguiente_wizard')), findsOneWidget);
    });

    testWidgets('CheckoutWizardScreen Paso 3 Despacho Domicilio sincroniza datos y avanza a Paso 4 sin error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CheckoutWizardScreen(
            initialInventario: [
              {'id_activo': 'act-101', 'sku': 'SKU-101', 'descripcion': 'Alternador', 'precio': 120000}
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Paso 0 -> Paso 1
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();

      // Consumidor Final
      await tester.tap(find.byKey(const Key('switch_cliente_anonimo')));
      await tester.pumpAndSettle();

      // Paso 1 -> Paso 2 (Logística)
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();

      expect(find.text('3. Modalidad de Entrega y Despacho'), findsOneWidget);

      // Seleccionar Despacho Domicilio
      await tester.tap(find.text('Despacho Domicilio'));
      await tester.pumpAndSettle();

      // Ingresar Dirección
      final dirFinder = find.widgetWithText(TextField, 'Dirección de Entrega *');
      await tester.enterText(dirFinder, 'Av. Libertad 123');
      await tester.pumpAndSettle();

      // Región y Comuna ya vienen precargadas por Consumidor Final (Valparaíso / Viña del Mar)
      expect(find.text('Valparaíso'), findsWidgets);
      expect(find.text('Viña del Mar'), findsWidgets);

      // Avanzar a Paso 3 (Abonos)
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();

      // No debe mostrar el mensaje de error de despacho y debe estar en el Paso 4
      expect(find.text('Complete todos los campos obligatorios para el despacho a domicilio.'), findsNothing);
      expect(find.text('4. Condiciones Comerciales y Abonos'), findsOneWidget);
    });
  });
}

