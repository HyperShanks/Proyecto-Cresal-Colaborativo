import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/ventas/models/catalogo_model.dart';
import 'package:frontend/features/ventas/presentation/widgets/catalogo_item_card.dart';
import 'package:frontend/features/ventas/presentation/widgets/catalogo_item_detail_sheet.dart';
import 'package:frontend/features/ventas/presentation/widgets/filtros_drawer.dart';
import 'package:frontend/features/ventas/presentation/screens/ventas_main_screen.dart';
import 'package:frontend/features/ventas/presentation/screens/catalogo_screen.dart';

void main() {
  group('CatalogoItem Model Tests', () {
    test('fromJson & getters parse correctly', () {
      final json = {
        'id_activo': '3fa85f64-5717-4562-b3fc-2c963f66afa6',
        'sku_qr_fisico': 'SKU-TEST-001',
        'precio_referencia': 450000,
        'id_categoria': 1,
        'nombre_categoria': 'Motor',
        'id_sucursal_actual': 1,
        'nombre_sucursal': 'Casa Matriz',
        'marca': 'Toyota',
        'modelo': 'Yaris',
        'anio': 2018,
        'traccion': '4x2',
        'cilindrada': '1.5L',
        'combustible': 'Gasolina',
        'transmision_tipo': 'Manual',
        'ubicacion_pasillo': 'P-01',
        'ubicacion_pallet': 'PL-02',
        'estado_activo': 'Disponible',
      };

      final item = CatalogoItem.fromJson(json);

      expect(item.idActivo, '3fa85f64-5717-4562-b3fc-2c963f66afa6');
      expect(item.skuQrFisico, 'SKU-TEST-001');
      expect(item.precioReferencia, 450000);
      expect(item.precioFormateado, '\$450.000');
      expect(item.tituloRepuesto, 'Motor - Toyota Yaris 2018');
      expect(item.ubicacionFormateada, 'P-01 - PL-02');
    });
  });

  group('CatalogoItemCard Widget Tests', () {
    final mockItem = CatalogoItem(
      idActivo: '11111111-1111-1111-1111-111111111111',
      skuQrFisico: 'SKU-TOYOTA-1',
      precioReferencia: 600000,
      idCategoria: 1,
      nombreCategoria: 'Motor',
      idSucursalActual: 1,
      nombreSucursal: 'Casa Matriz - Santiago',
      marca: 'Toyota',
      modelo: 'Corolla',
      anio: 2020,
      cilindrada: '1.8L',
      combustible: 'Gasolina',
      transmisionTipo: 'Automática',
      ubicacionPasillo: 'A-1',
      ubicacionPallet: 'P-10',
    );

    testWidgets('Radar Badge muestra sucursal local cuando coincide id_sucursal', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CatalogoItemCard(
              item: mockItem,
              vendedorSucursalId: 1, // Misma sucursal
            ),
          ),
        ),
      );

      // Debe mostrar el texto del radar local legible con emoji de pin
      expect(find.text('📍 Casa Matriz - Santiago (Tu sucursal)'), findsOneWidget);
      expect(find.byIcon(Icons.my_location), findsOneWidget);
      expect(find.text('Motor - Toyota Corolla 2020'), findsOneWidget);
      expect(find.text('\$600.000'), findsOneWidget);
      // El badge de SKU ya no está en la fila superior
      expect(find.text('SKU: SKU-TOYOTA-1'), findsNothing);
    });

    testWidgets('Radar Badge muestra sucursal remota cuando NO coincide id_sucursal', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CatalogoItemCard(
              item: mockItem,
              vendedorSucursalId: 2, // Otra sucursal
            ),
          ),
        ),
      );

      // Debe mostrar sucursal neutra legible
      expect(find.text('📍 Casa Matriz - Santiago'), findsOneWidget);
      expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
    });

    testWidgets('Botón de carrito tiene tamaño mínimo interactivo de 48x48', (tester) async {
      bool cartPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CatalogoItemCard(
              item: mockItem,
              vendedorSucursalId: 1,
              onAddToCart: () {
                cartPressed = true;
              },
            ),
          ),
        ),
      );

      final cartButtonFinder = find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.width == 48.0 && widget.height == 48.0,
      );

      expect(cartButtonFinder, findsOneWidget);

      await tester.tap(find.byIcon(Icons.add_shopping_cart));
      await tester.pump();

      expect(cartPressed, isTrue);
    });
  });

  group('FiltrosDrawer Widget Tests', () {
    testWidgets('Renderiza correctamente títulos, chips, dropdowns y botón limpiar', (tester) async {
      int? selectedCategoria = 1;
      int? selectedSucursal;
      String? selectedMarca;
      int? selectedAnio;
      String? selectedCilindrada;
      String? selectedTransmision;
      bool limpiarPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            endDrawer: FiltrosDrawer(
              idCategoria: selectedCategoria,
              idSucursal: selectedSucursal,
              marca: selectedMarca,
              anio: selectedAnio,
              cilindrada: selectedCilindrada,
              transmision: selectedTransmision,
              onCategoriaChanged: (val) => selectedCategoria = val,
              onSucursalChanged: (val) => selectedSucursal = val,
              onMarcaChanged: (val) => selectedMarca = val,
              onAnioChanged: (val) => selectedAnio = val,
              onCilindradaChanged: (val) => selectedCilindrada = val,
              onTransmisionChanged: (val) => selectedTransmision = val,
              onLimpiarFiltros: () => limpiarPressed = true,
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

      // Abrir drawer
      await tester.tap(find.text('Abrir Filtros'));
      await tester.pumpAndSettle();

      // Validar presencia de textos
      expect(find.text('Filtros'), findsOneWidget);
      expect(find.text('Ocultar'), findsOneWidget);
      expect(find.text('TIPO'), findsOneWidget);
      expect(find.text('Motores'), findsOneWidget);
      expect(find.text('Cajas'), findsOneWidget);
      expect(find.text('SUCURSAL'), findsOneWidget);
      expect(find.text('Viña del Mar'), findsOneWidget);
      expect(find.text('Limache'), findsOneWidget);
      expect(find.text('MARCA DEL VEHÍCULO'), findsOneWidget);
      expect(find.text('AÑO DEL MOTOR'), findsOneWidget);
      expect(find.text('CILINDRADA'), findsOneWidget);
      expect(find.text('TIPO DE TRANSMISIÓN'), findsOneWidget);
      expect(find.text('Limpiar filtros'), findsOneWidget);

      // Probar tap en "Cajas"
      await tester.tap(find.text('Cajas'));
      await tester.pump();
      expect(selectedCategoria, 2);

      // Probar tap en "Limache"
      await tester.tap(find.text('Limache'));
      await tester.pump();
      expect(selectedSucursal, 2);

      // Probar tap en "Limpiar filtros"
      await tester.tap(find.text('Limpiar filtros'));
      await tester.pump();
      expect(limpiarPressed, isTrue);

      // Probar tap en "Ocultar"
      await tester.tap(find.text('Ocultar'));
      await tester.pumpAndSettle();
      expect(find.text('Filtros'), findsNothing);
    });
  });

  group('VentasMainScreen Widget Tests', () {
    testWidgets('Renderiza BottomNavigationBar con 3 pestañas para Vendedor y navega', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: VentasMainScreen(),
        ),
      );
      await tester.pump();

      // Debe mostrar las 3 pestañas por defecto para vendedor
      expect(find.text('Catálogo'), findsOneWidget);
      expect(find.text('Mis Órdenes'), findsOneWidget);
      expect(find.text('Tasación'), findsNothing);
      expect(find.text('Carrito'), findsOneWidget);

      // Cambiar a pestaña Mis Órdenes
      await tester.tap(find.text('Mis Órdenes'));
      await tester.pump();
      expect(find.text('Mis Órdenes de Venta'), findsOneWidget);

      // Cambiar a pestaña Carrito (Checkout Wizard)
      await tester.tap(find.text('Carrito'));
      await tester.pump();
      expect(find.text('El carrito está actualmente vacío'), findsOneWidget);
    });

    testWidgets('Botón de hamburguesa abre el Drawer con TICKET, CONFIGURACIÓN y CERRAR SESIÓN', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: VentasMainScreen(),
        ),
      );
      await tester.pump();

      // Tap en el botón de hamburguesa del AppBar del catálogo
      await tester.tap(find.byTooltip('Menú principal').first);
      await tester.pump(const Duration(milliseconds: 300));

      // Verificar que el drawer está abierto y contiene las opciones
      expect(find.text('TICKET'), findsOneWidget);
      expect(find.text('CONFIGURACIÓN'), findsOneWidget);
      expect(find.text('CERRAR SESIÓN'), findsOneWidget);
    });
  });

  group('CatalogoItemDetailSheet Widget Tests', () {
    final itemTest = CatalogoItem(
      idActivo: '3fa85f64-5717-4562-b3fc-2c963f66afa6',
      skuQrFisico: 'MOT-TOY-YAR-2019-01',
      precioReferencia: 520000,
      idCategoria: 1,
      nombreCategoria: 'Motor',
      idSucursalActual: 1,
      nombreSucursal: 'Viña del Mar',
      idVehiculo: 'veh-1',
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

    testWidgets('Renderiza título, ficha técnica en 2 columnas y precio formateado', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CatalogoItemDetailSheet(
              item: itemTest,
              vendedorSucursalId: 1,
            ),
          ),
        ),
      );

      // Verificar Título del repuesto y badge de categoría
      expect(find.text('Motor - Toyota Yaris Sport 2019'), findsOneWidget);
      expect(find.text('Motor'), findsOneWidget);

      // Verificar Radar de stock
      expect(find.text('En tu sucursal (Viña del Mar)'), findsOneWidget);

      // Verificar Ficha técnica
      expect(find.text('FICHA TÉCNICA'), findsOneWidget);
      expect(find.text('MOT-TOY-YAR-2019-01'), findsOneWidget);
      expect(find.text('1.5L'), findsOneWidget);
      expect(find.text('Gasolina'), findsOneWidget);
      expect(find.text('Manual'), findsOneWidget);
      expect(find.text('4x2'), findsOneWidget);
      expect(find.text('P-02 - PL-14'), findsOneWidget);
      expect(find.text('Disponible'), findsOneWidget);

      // Verificar Precio y Botón
      expect(find.text('\$520.000'), findsOneWidget);
      expect(find.text('Agregar'), findsOneWidget);
    });

    testWidgets('Botón de cerrar X tiene tamaño interactivo >= 48x48 y botón Agregar ejecuta callback', (tester) async {
      bool cartPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CatalogoItemDetailSheet(
              item: itemTest,
              vendedorSucursalId: 1,
              onAddToCart: () {
                cartPressed = true;
              },
            ),
          ),
        ),
      );

      // Touch Target de botón de cerrar
      final closeButtonFinder = find.byIcon(Icons.close);
      expect(closeButtonFinder, findsOneWidget);
      final closeSize = tester.getSize(closeButtonFinder);
      expect(closeSize.width, greaterThanOrEqualTo(20));

      // Touch Target de botón Agregar (altura compacta >= 40px)
      final cartBtnFinder = find.widgetWithText(ElevatedButton, 'Agregar');
      expect(cartBtnFinder, findsOneWidget);
      final cartBtnSize = tester.getSize(cartBtnFinder);
      expect(cartBtnSize.height, greaterThanOrEqualTo(40.0));

      // Tap en Agregar
      await tester.tap(cartBtnFinder);
      await tester.pump();

      expect(cartPressed, isTrue);
    });

    testWidgets('Tap en CatalogoItemCard navega a DetalleActivoScreen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CatalogoItemCard(
              item: itemTest,
              vendedorSucursalId: 1,
            ),
          ),
        ),
      );

      // Tap en la tarjeta
      await tester.tap(find.text('Motor - Toyota Yaris Sport 2019'));
      await tester.pumpAndSettle();

      // Verificar que DetalleActivoScreen se ha abierto
      expect(find.text('Detalle del Repuesto'), findsOneWidget);
      expect(find.text('ESPECIFICACIONES TÉCNICAS'), findsOneWidget);
      expect(find.text('UBICACIÓN FÍSICA EN BODEGA'), findsOneWidget);
      expect(find.text('Agregar'), findsOneWidget);
    });

    testWidgets('Buscador en tiempo real en CatalogoScreen permite escribir y limpiar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CatalogoScreen(),
          ),
        ),
      );
      await tester.pump();

      final searchFieldFinder = find.byKey(const Key('input_busqueda_catalogo'));
      expect(searchFieldFinder, findsOneWidget);

      // Escribir término de búsqueda
      await tester.enterText(searchFieldFinder, 'Toyota');
      await tester.pump();

      // Debe mostrar el botón de limpiar búsqueda
      expect(find.byTooltip('Limpiar búsqueda'), findsOneWidget);

      // Tap en limpiar búsqueda
      await tester.tap(find.byTooltip('Limpiar búsqueda'));
      await tester.pump();

      // El campo queda vacío y el botón de limpiar desaparece
      final textField = tester.widget<TextField>(searchFieldFinder);
      expect(textField.controller?.text, isEmpty);
      expect(find.byTooltip('Limpiar búsqueda'), findsNothing);
    });
  });
}
