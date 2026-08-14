// test/carrito_screen_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/ventas/controllers/cart_controller.dart';
import 'package:frontend/features/ventas/models/catalogo_model.dart';
import 'package:frontend/features/ventas/presentation/screens/carrito_screen.dart';
import 'package:frontend/features/ventas/presentation/widgets/cart_item_tile.dart';

void main() {
  final itemTest1 = CatalogoItem(
    idActivo: '3fa85f64-5717-4562-b3fc-2c963f66afa6',
    skuQrFisico: 'MOT-TOY-YAR-2019-01',
    precioReferencia: 520000,
    idCategoria: 1,
    nombreCategoria: 'Motor',
    idSucursalActual: 1,
    nombreSucursal: 'Viña del Mar',
    marca: 'Toyota',
    modelo: 'Yaris Sport',
    anio: 2019,
    traccion: '4x2',
    cilindrada: '1.5L',
    combustible: 'Gasolina',
    transmisionTipo: 'Manual',
    ubicacionPasillo: 'P-02',
    ubicacionPallet: 'PL-14',
    estadoActivo: 'Disponible',
  );

  setUp(() {
    CartController.instance.vaciarCarrito();
  });

  group('CarritoScreen UI Tests', () {
    testWidgets('Muestra estado vacío interactivo cuando no hay productos', (tester) async {
      bool catalogoPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: CarritoScreen(
            onNavigateToCatalogo: () {
              catalogoPressed = true;
            },
          ),
        ),
      );

      expect(find.text('Carrito de Ventas'), findsOneWidget);
      expect(find.text('Tu carrito está vacío'), findsOneWidget);
      expect(find.byIcon(Icons.remove_shopping_cart_outlined), findsOneWidget);
      expect(find.text('Explorar Catálogo'), findsOneWidget);
      expect(find.text('Venta Libre / Misceláneo'), findsOneWidget);

      // Botón Explorar Catálogo ejecuta callback
      await tester.tap(find.text('Explorar Catálogo'));
      await tester.pump();

      expect(catalogoPressed, isTrue);
    });

    testWidgets('Renderiza vista unificada (Carrito + Micro-CRM) con barra fija', (tester) async {
      CartController.instance.agregarInventariado(itemTest1);
      CartController.instance.agregarVentaLibre(
        descripcion: 'Pernos Culata Especiales',
        monto: 15000,
        cantidad: 2,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: CarritoScreen(),
        ),
      );

      // Encabezado del carrito
      expect(find.text('Carrito de Compras'), findsOneWidget);
      expect(find.text('Revisa tus activos y finaliza la venta'), findsOneWidget);
      expect(find.text('3 Ítems'), findsOneWidget);

      // Badges distintivos
      expect(find.text('Inventario'), findsOneWidget);
      expect(find.text('Venta Libre'), findsOneWidget);

      // Títulos de productos
      expect(find.text('Motor - Toyota Yaris Sport 2019'), findsOneWidget);
      expect(find.text('Pernos Culata Especiales'), findsOneWidget);

      // Botón ancho completo '+ Añadir Ítem No Inventariado / Misceláneo'
      expect(find.text('+ Añadir Ítem No Inventariado / Misceláneo'), findsOneWidget);

      // Tarjetas Micro-CRM
      expect(find.text('DATOS POST-VENTA CLIENTE'), findsOneWidget);
      expect(find.text('REQUIERE DESPACHO'), findsOneWidget);

      // Barra inferior de Checkout
      expect(find.text('TOTAL CARRITO:'), findsOneWidget);
      expect(find.text('\$550.000'), findsOneWidget); // 520.000 + 30.000
      expect(find.text('Derivar a Caja'), findsOneWidget);

      // Botones en AppBar
      expect(find.byTooltip('Agregar ítem manual'), findsOneWidget);
      expect(find.byTooltip('Vaciar carrito'), findsOneWidget);
    });

    testWidgets('Checkbox Requiere Despacho despliega campos adicionales', (tester) async {
      CartController.instance.agregarInventariado(itemTest1);

      await tester.pumpWidget(
        const MaterialApp(
          home: CarritoScreen(),
        ),
      );

      // Al inicio no se muestran campos de despacho
      expect(find.text('Dirección de Envío *'), findsNothing);

      // Scroll hasta REQUIERE DESPACHO y marcar checkbox
      await tester.scrollUntilVisible(
        find.text('REQUIERE DESPACHO'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('REQUIERE DESPACHO'), findsOneWidget);

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      // Ahora se despliegan los campos de despacho
      await tester.scrollUntilVisible(
        find.text('Dirección de Envío *'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Dirección de Envío *'), findsOneWidget);
      expect(find.text('Comuna Destino'), findsOneWidget);
      expect(find.text('RUT Receptor *'), findsOneWidget);
      expect(find.text('Nombres Receptor *'), findsOneWidget);
      expect(find.text('Teléfono Receptor *'), findsOneWidget);
    });

    testWidgets('Edición in-line de precio recalcula subtotal y total en tiempo real', (tester) async {
      CartController.instance.agregarInventariado(itemTest1);

      await tester.pumpWidget(
        const MaterialApp(
          home: CarritoScreen(),
        ),
      );

      expect(find.text('\$520.000'), findsNWidgets(2)); // Subtotal + Total

      // Modificar el precio en el TextField in-line
      final precioField = find.widgetWithText(TextField, '520000');
      expect(precioField, findsOneWidget);

      await tester.enterText(precioField, '450000');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // Verificar que el total y subtotal se actualizaron a $450.000
      expect(find.text('\$450.000'), findsNWidgets(2));
      expect(CartController.instance.totalMonto, 450000);
    });

    testWidgets('Selector de cantidad en CartItemTile incrementa/decrementa total', (tester) async {
      CartController.instance.agregarVentaLibre(
        descripcion: 'Aceite 10W40',
        monto: 20000,
        cantidad: 1,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CarritoScreen(),
          ),
        ),
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.text('\$20.000'), findsNWidgets(2)); // Subtotal + Total

      // Presionar botón '+' para subir a 2 en el stepper de CartItemTile
      await tester.tap(find.widgetWithIcon(IconButton, Icons.add));
      await tester.pump();

      expect(find.text('2'), findsOneWidget);
      expect(find.text('\$40.000'), findsNWidgets(2)); // 20.000 * 2
      expect(CartController.instance.totalMonto, 40000);
    });

    testWidgets('Eliminar ítem mediante botón de basurero actualiza UI y controller', (tester) async {
      CartController.instance.agregarInventariado(itemTest1);

      await tester.pumpWidget(
        const MaterialApp(
          home: CarritoScreen(),
        ),
      );

      expect(find.text('Motor - Toyota Yaris Sport 2019'), findsOneWidget);

      // Tap en icono de basurero
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // Carrito queda vacío y muestra pantalla de estado vacío
      expect(find.text('Tu carrito está vacío'), findsOneWidget);
      expect(CartController.instance.estaVacio, isTrue);
    });

    testWidgets('Validación al presionar Derivar a Caja y flujo de derivación exitoso', (tester) async {
      CartController.instance.agregarInventariado(
        itemTest1,
        notas: 'Entregar con soporte especial',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: CarritoScreen(),
        ),
      );

      // 1. Presionar Derivar a Caja sin llenar datos debe mostrar error
      final btnDerivar = find.widgetWithText(ElevatedButton, 'Derivar a Caja');
      expect(btnDerivar, findsOneWidget);

      await tester.tap(btnDerivar);
      await tester.pump();

      expect(find.text('Campo requerido'), findsWidgets);
      expect(find.text('Debes aceptar el consentimiento para continuar'), findsOneWidget);

      // 2. Llenar campos requeridos
      await tester.enterText(
        find.widgetWithText(TextFormField, '12.345.678-9').first,
        '18.765.432-1',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Juan'),
        'Carlos',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Pérez'),
        'González',
      );

      // 3. Marcar checkbox de consentimiento legal
      await tester.scrollUntilVisible(
        find.text('Consentimiento Ley N° 21.719 *'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byType(Checkbox).last);
      await tester.pump();

      // 4. Presionar Derivar a Caja de nuevo -> Éxito
      await tester.tap(btnDerivar);
      await tester.pumpAndSettle();

      expect(find.text('Orden Derivada a Caja'), findsOneWidget);
      expect(find.text('Cliente: Carlos González'), findsOneWidget);
      expect(find.text('Total a Cobrar: \$520.000'), findsOneWidget);
      expect(find.text('⚠️ Alertas de preparación a bodega:'), findsOneWidget);
      expect(find.text('• ${itemTest1.tituloRepuesto}: "Entregar con soporte especial"'), findsOneWidget);
    });

    testWidgets('Botón Derivar a Caja está deshabilitado si el monto es 0', (tester) async {
      CartController.instance.agregarVentaLibre(
        descripcion: 'Item Gratuito / Promoción',
        monto: 0,
        cantidad: 1,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: CarritoScreen(),
        ),
      );

      // El botón debe existir pero estar deshabilitado (onPressed == null)
      final btnDerivar = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Derivar a Caja'),
      );
      expect(btnDerivar.onPressed, isNull);
    });
  });
}
