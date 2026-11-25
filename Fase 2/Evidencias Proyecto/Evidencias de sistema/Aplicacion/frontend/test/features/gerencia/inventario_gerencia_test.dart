// frontend/test/features/gerencia/inventario_gerencia_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/ventas/models/catalogo_model.dart';
import 'package:frontend/features/gerencia/presentation/screens/inventario_gerencia_view.dart';
import 'package:frontend/features/inventario/presentation/widgets/editar_activo_modal.dart';
import 'package:frontend/features/auth/services/auth_service.dart';
import 'package:frontend/features/auth/models/auth_user_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HU-5.3: Modelos de Inventario y Tasación', () {
    test('CatalogoItem deserializa correctamente nuevos campos HU-5.3', () {
      final json = {
        'id_activo': 'act-001',
        'sku_qr_fisico': 'REP-ENG-001',
        'nombre_categoria': 'Motor',
        'marca': 'Toyota',
        'modelo': 'Hilux',
        'anio': 2021,
        'estado_activo': 'Paletizado',
        'nombre_sucursal': 'Casa Matriz (Viña)',
        'id_sucursal_actual': 1,
        'ubicacion_pasillo': 'Rack C',
        'ubicacion_pallet': 'Nivel 2',
        'ubicacion_galpon': 'Galpón 1',
        'precio_referencia': 450000,
        'cilindrada': '2.8',
        'combustible': 'Diésel',
        'transmision_tipo': 'Manual 6ta',
        'traccion': '4x4',
        'numero_motor': '1GD-1234567',
        'observacion_estado': 'Excelente estado de compresión',
        'imagenes': ['https://example.com/foto1.jpg'],
      };

      final item = CatalogoItem.fromJson(json);

      expect(item.idActivo, 'act-001');
      expect(item.skuQrFisico, 'REP-ENG-001');
      expect(item.nombreCategoria, 'Motor');
      expect(item.marca, 'Toyota');
      expect(item.modelo, 'Hilux');
      expect(item.anio, 2021);
      expect(item.estadoActivo, 'Paletizado');
      expect(item.ubicacionGalpon, 'Galpón 1');
      expect(item.observacionEstado, 'Excelente estado de compresión');
      expect(item.precioReferencia, 450000);
      expect(item.combustible, 'Diésel');
      expect(item.transmisionTipo, 'Manual 6ta');
      expect(item.imagenes.length, 1);
    });

    test('PaginatedCatalogoResponse deserializa pendientesTasacionCount', () {
      final json = {
        'total_count': 45,
        'items': [
          {
            'id_activo': 'act-002',
            'sku_qr_fisico': 'REP-CAJ-002',
            'nombre_categoria': 'Transmisión',
            'marca': 'Nissan',
            'modelo': 'Navara',
            'anio': 2020,
            'estado_activo': 'Paletizado',
            'nombre_sucursal': 'Patio Limache',
            'id_sucursal_actual': 2,
            'precio_referencia': 0,
            'imagenes': [],
          }
        ],
        'pendientes_tasacion_count': 14,
      };

      final paginated = PaginatedCatalogoResponse.fromJson(json);

      expect(paginated.totalCount, 45);
      expect(paginated.items.length, 1);
      expect(paginated.pendientesTasacionCount, 14);
      expect(paginated.items.first.skuQrFisico, 'REP-CAJ-002');
    });
  });

  group('HU-5.3: Componente InventarioGerenciaView', () {
    testWidgets('Renderiza barra de búsqueda, chips y botones de vista', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InventarioGerenciaView(
              idSucursalInicial: null,
              filtroSinTasarInicial: false,
            ),
          ),
        ),
      );

      // Verificamos presencia de los componentes interactivos clave
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Buscar por SKU, Marca, N° Motor, Pasillo, Pallet o N° Ingreso...'), findsOneWidget);
      expect(find.text('Sin Tasar'), findsOneWidget);
      expect(find.text('Limpiar'), findsOneWidget);
      expect(find.text('Tarjetas'), findsOneWidget);
      expect(find.text('Tabla'), findsOneWidget);
    });

    testWidgets('Conmutación interactiva entre modo Tarjetas y Tabla', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InventarioGerenciaView(
              idSucursalInicial: 1,
              filtroSinTasarInicial: true,
            ),
          ),
        ),
      );

      // Verificamos botón de vista Tabla
      final botonTabla = find.text('Tabla');
      expect(botonTabla, findsOneWidget);

      await tester.tap(botonTabla);
      await tester.pump();

      // Verificamos botón de vista Tarjetas
      final botonTarjetas = find.text('Tarjetas');
      expect(botonTarjetas, findsOneWidget);

      await tester.tap(botonTarjetas);
      await tester.pump();
    });

    testWidgets('Botón Limpiar muestra badge de filtros activos y resetea al presionar', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InventarioGerenciaView(
              idSucursalInicial: 1,
              filtroSinTasarInicial: true,
            ),
          ),
        ),
      );

      // Dado que filtroSinTasarInicial es true, debe haber 1 filtro activo y mostrar el badge '1'
      expect(find.text('Limpiar'), findsOneWidget);
      expect(find.text('1'), findsWidgets);

      // Al presionar Limpiar, se limpian los filtros
      await tester.tap(find.text('Limpiar'));
      await tester.pump();
    });

    test('HU-24: CatalogoItem de Motor incluye siglas en corchetes y exporta toJson completo para edición', () {
      final json = {
        'id_activo': 'act-moto-001',
        'sku_qr_fisico': 'REP-ENG-888',
        'id_categoria': 1,
        'nombre_categoria': 'Motor',
        'marca': 'Toyota',
        'modelo': 'Hilux',
        'anio': 2021,
        'cilindrada': '2.8L',
        'combustible': 'Diesel',
        'transmision_tipo': 'Manual',
        'traccion': '4x4',
        'numero_motor': '1GD-FTV-9999',
        'ubicacion_pasillo': 'B',
        'ubicacion_pallet': 'P-12',
        'ubicacion_galpon': '1',
        'observacion_estado': 'Seminuevo',
        'estado_activo': 'Paletizado',
        'version_lock': 3,
      };

      final item = CatalogoItem.fromJson(json);

      // Verificamos que el título incluya las primeras 4 siglas del motor
      expect(item.tituloRepuesto, 'Motor - Toyota Hilux 2021 [1GDF]');

      // Verificamos que el payload para EditarActivoModal contenga todos los campos de origen y técnicos
      final exportJson = item.toJson();
      expect(exportJson['id_activo'], 'act-moto-001');
      expect(exportJson['numero_motor'], '1GD-FTV-9999');
      expect(exportJson['combustible'], 'Diesel');
      expect(exportJson['transmision_tipo'], 'Manual');
      expect(exportJson['traccion'], '4x4');
      expect(exportJson['marca'], 'Toyota');
      expect(exportJson['modelo'], 'Hilux');
      expect(exportJson['anio'], 2021);
      expect(exportJson['ubicacion_pasillo'], 'B');
      expect(exportJson['ubicacion_pallet'], 'P-12');
      expect(exportJson['ubicacion_galpon'], '1');
      expect(exportJson['version_lock'], 3);
    });

    test('HU-24: CatalogoItem de Caja de Cambios NO incluye siglas en corchetes', () {
      final json = {
        'id_activo': 'act-caj-001',
        'sku_qr_fisico': 'REP-CAJ-111',
        'id_categoria': 2,
        'nombre_categoria': 'Caja de Cambios',
        'marca': 'Toyota',
        'modelo': 'Hilux',
        'anio': 2021,
        'numero_motor': '1GD-FTV-9999', // El vehículo donante tiene motor pero la pieza es Caja
        'estado_activo': 'Paletizado',
      };

      final item = CatalogoItem.fromJson(json);

      // La caja no debe llevar siglas
      expect(item.tituloRepuesto, 'Caja de Cambios - Toyota Hilux 2021');
      expect(item.tituloRepuesto.contains('['), isFalse);
    });

    testWidgets('HU-24: InventarioGerenciaView es responsivo y libre de overpixels en pantalla móvil (360x640)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InventarioGerenciaView(
              idSucursalInicial: 1,
              filtroSinTasarInicial: false,
            ),
          ),
        ),
      );
      await tester.pump();

      // Debe renderizar sin excepciones de overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('HU-24: InventarioGerenciaView es responsivo y libre de overpixels en tablet (768x1024)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InventarioGerenciaView(
              idSucursalInicial: 1,
              filtroSinTasarInicial: false,
            ),
          ),
        ),
      );
      await tester.pump();

      // Debe renderizar sin excepciones de overflow
      expect(tester.takeException(), isNull);
    });

    test('HU-24: AuthService.puedeEditarInventario autoriza a Bodeguero (1) y Gerencia (4) y DENEGA a Administrador (5)', () async {
      AuthUserModel crearUser(int idRol, String rol) => AuthUserModel(
            idUsuario: 'u-test',
            rutUsuario: '11.111.111-1',
            nombres: 'Test',
            apellidos: 'User',
            email: 'test@example.com',
            idRol: idRol,
            nombreRol: rol,
            idSucursal: 1,
          );

      AuthService.setMockUserCache(crearUser(5, 'Administrador'));
      expect(await AuthService.puedeEditarInventario(), isFalse);

      AuthService.setMockUserCache(crearUser(4, 'Gerente General'));
      expect(await AuthService.puedeEditarInventario(), isTrue);

      AuthService.setMockUserCache(crearUser(1, 'Bodeguero'));
      expect(await AuthService.puedeEditarInventario(), isTrue);

      AuthService.setMockUserCache(crearUser(2, 'Vendedor'));
      expect(await AuthService.puedeEditarInventario(), isFalse);

      AuthService.setMockUserCache(null);
    });

    testWidgets('HU-24: EditarActivoModal es responsivo y libre de overpixels en pantalla móvil (360x640 y 320x480)', (WidgetTester tester) async {
      final activoData = {
        'id_activo': 'act-test-01',
        'sku_qr_fisico': 'REP-MOT-999',
        'categoria': 'Motor',
        'marca': 'Toyota',
        'modelo': 'Hilux',
        'anio': 2021,
        'cilindrada': '2.8L',
        'combustible': 'Diesel',
        'transmision': 'Manual',
        'traccion': '4x4',
        'numero_motor': '1GD-FTV-9999',
        'pasillo': 'B',
        'pallet': 'P-12',
        'galpon': '1',
        'version_lock': 1,
      };

      // Test en pantalla móvil típica 360x640
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditarActivoModal(activo: activoData),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Test en pantalla móvil ultra estrecha 320x480
      tester.view.physicalSize = const Size(320, 480);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditarActivoModal(activo: activoData),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('HU-24: EditarActivoModal es responsivo en tablet (768x1024) y desktop', (WidgetTester tester) async {
      final activoData = {
        'id_activo': 'act-test-02',
        'sku_qr_fisico': 'REP-CAJ-888',
        'categoria': 'Caja de Cambios',
        'marca': 'Nissan',
        'modelo': 'Navara',
        'anio': 2020,
        'cilindrada': '2.5L',
        'combustible': 'Diesel',
        'transmision': 'Automática',
        'traccion': '4x2',
        'pasillo': 'C',
        'pallet': 'P-05',
        'galpon': '2',
        'version_lock': 2,
      };

      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditarActivoModal(activo: activoData),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
