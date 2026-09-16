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

      // Totales
      expect(controller.totalItemsCount, equals(3));
      expect(controller.totalVenta, equals(1100000)); // 650.000 + 50.000 + 400.000
      expect(controller.abonoReservas, equals(150000));
      expect(controller.montoPendiente, equals(950000)); // 1.100.000 - 150.000
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

    testWidgets('CheckoutWizardScreen renderiza el Stepper de 5 pasos', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CheckoutWizardScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Checkout Transaccional'), findsOneWidget);
      expect(find.text('Ítems & Reservas'), findsOneWidget);
      expect(find.text('Cliente CRM'), findsOneWidget);
      expect(find.text('Siguiente'), findsOneWidget);
      expect(find.text('Venta en Verde'), findsOneWidget);
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

    testWidgets('CheckoutWizardScreen diálogo ítem manual no precarga el número 1 y muestra placeholder Cantidad', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CheckoutWizardScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Abrir diálogo Ítem Manual
      await tester.tap(find.text('+ Ítem Manual'));
      await tester.pumpAndSettle();

      expect(find.text('Añadir Ítem Manual'), findsOneWidget);
      expect(find.text('Descripción del ítem'), findsOneWidget);
      expect(find.text('Cantidad'), findsOneWidget);
      expect(find.text('Precio Unitario (\$)'), findsOneWidget);

      // Verificar que el campo de cantidad no tiene '1' precargado como texto
      final textFields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(textFields.length, equals(3));
      expect(textFields[1].controller?.text, isEmpty);

      // Ingresar ítem manual sin escribir cantidad (toma 1 por defecto)
      await tester.enterText(find.byWidget(textFields[0]), 'Aceite Motor 1L');
      await tester.enterText(find.byWidget(textFields[2]), '15000');
      await tester.tap(find.text('Añadir'));
      await tester.pumpAndSettle();

      expect(find.text('Aceite Motor 1L'), findsOneWidget);
      expect(find.textContaining('Cantidad: 1'), findsOneWidget);
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
      final dirFinder = find.widgetWithText(TextField, 'Dirección de entrega (Calle, Número, Depto) *');
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

