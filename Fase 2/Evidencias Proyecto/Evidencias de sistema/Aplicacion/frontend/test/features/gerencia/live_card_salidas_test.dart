// frontend/test/features/gerencia/live_card_salidas_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/gerencia/models/gerencia_models.dart';
import 'package:frontend/features/gerencia/presentation/screens/dashboard_gerencia_view.dart';
import 'package:frontend/features/gerencia/presentation/screens/ordenes_gerencia_view.dart';
import 'package:frontend/features/gerencia/presentation/widgets/kpi_card_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'mock-valid-token',
      'user_rol': 'Gerente General',
      'user_id_rol': '4',
      'user_sucursal_id': '1',
      'user_sucursal_nombre': 'Casa Matriz (Viña)',
      'user_nombre_completo': 'Roberto Silva',
    });
  });

  group('1. KpiCardWidget - Live Card e Interactividad (Unit & Widget Tests)', () {
    testWidgets('Renderiza badge EN VIVO, valores e invoca callback onTap',
        (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KpiCardWidget(
              titulo: 'Salidas en Tiempo Real',
              valor: '5 piezas',
              isLive: true,
              subtitulo: '3 MOT • 2 CAJ',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      // Verificamos título, badge EN VIVO y valor
      expect(find.text('SALIDAS EN TIEMPO REAL'), findsOneWidget);
      expect(find.text('EN VIVO'), findsOneWidget);
      expect(find.text('5 piezas'), findsOneWidget);
      expect(find.text('3 MOT • 2 CAJ'), findsOneWidget);

      // Verificamos clic
      await tester.tap(find.text('SALIDAS EN TIEMPO REAL'));
      expect(tapped, isTrue);
    });

    test('KpiFinancieroModel serializa y deserializa campos de salidas en vivo', () {
      final jsonMap = {
        'ventas_del_dia': 2500000,
        'transacciones_hoy': 8,
        'acumulado_mensual_mtd': 35000000,
        'ticket_promedio': 312500.0,
        'salidas_motores_hoy': 3,
        'salidas_cajas_hoy': 2,
        'total_salidas_hoy': 5,
      };

      final model = KpiFinancieroModel.fromJson(jsonMap);
      expect(model.salidasMotoresHoy, 3);
      expect(model.salidasCajasHoy, 2);
      expect(model.totalSalidasHoy, 5);

      final encoded = model.toJson();
      expect(encoded['salidas_motores_hoy'], 3);
      expect(encoded['salidas_cajas_hoy'], 2);
      expect(encoded['total_salidas_hoy'], 5);
    });
  });

  group('2. OrdenesGerenciaView - Feedback de Filtro Activo y Restablecimiento', () {
    testWidgets('Muestra banner informativo cuando tipoActivoInicial es MOTORES_CAJAS',
        (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OrdenesGerenciaView(
              tipoActivoInicial: 'MOTORES_CAJAS',
              periodoInicial: 'hoy',
            ),
          ),
        ),
      );

      // Verificamos que el banner superior de feedback está visible
      expect(find.byKey(const Key('banner_filtro_motores_cajas')), findsOneWidget);
      expect(
        find.textContaining('Filtro Activo: Salidas de Motores y Cajas Inventariadas'),
        findsOneWidget,
      );
      expect(find.textContaining('(MOT-XXXX y CAJ-XXXX)'), findsOneWidget);
      expect(find.textContaining('Mostrando exclusivamente órdenes'), findsOneWidget);
      expect(find.byKey(const Key('btn_limpiar_filtro_banner')), findsOneWidget);

      // Al presionar el botón de restablecer en el banner, se restablece el historial
      await tester.tap(find.byKey(const Key('btn_limpiar_filtro_banner')));
      await tester.pump();

      // El banner debe desaparecer tras limpiar el filtro
      expect(find.byKey(const Key('banner_filtro_motores_cajas')), findsNothing);
    });

    testWidgets('Método aplicarFiltroTipoActivo activa el banner reactivamente',
        (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final ordenesKey = GlobalKey<OrdenesGerenciaViewState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrdenesGerenciaView(
              key: ordenesKey,
            ),
          ),
        ),
      );

      // Inicialmente no está activo el banner
      expect(find.byKey(const Key('banner_filtro_motores_cajas')), findsNothing);

      // Invocamos el método de aplicación de filtro
      await ordenesKey.currentState?.aplicarFiltroTipoActivo('MOTORES_CAJAS', periodo: 'hoy');
      await tester.pump();

      // Ahora el banner debe renderizarse
      expect(find.byKey(const Key('banner_filtro_motores_cajas')), findsOneWidget);
    });
  });

  group('3. DashboardGerenciaView - Integración de Live Card y Navegación al Clic', () {
    testWidgets('Dashboard incluye Live Card y navega a órdenes con filtro al hacer clic',
        (tester) async {
      tester.view.physicalSize = const Size(1366, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const mockKpis = KpiFinancieroModel(
        ventasDelDia: 2500000,
        transaccionesHoy: 8,
        acumuladoMensualMtd: 35000000,
        ticketPromedio: 312500.0,
        salidasMotoresHoy: 3,
        salidasCajasHoy: 2,
        totalSalidasHoy: 5,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DashboardGerenciaView(
              kpisIniciales: mockKpis,
            ),
          ),
        ),
      );

      await tester.pump();

      // Verificamos que la tarjeta de salidas en tiempo real está en el dashboard
      expect(find.byKey(const Key('kpi_card_salidas_motores_cajas')), findsOneWidget);
      expect(find.text('SALIDAS EN TIEMPO REAL'), findsOneWidget);
      expect(find.text('EN VIVO'), findsOneWidget);
      expect(find.text('5 piezas'), findsOneWidget);
      expect(find.text('3 MOT • 2 CAJ'), findsOneWidget);
      expect(find.text('Auditar'), findsOneWidget);

      // Al presionar la tarjeta interactiva:
      await tester.tap(find.byKey(const Key('kpi_card_salidas_motores_cajas')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // La aplicación navega automáticamente a la pestaña de órdenes y activa el banner
      expect(find.byKey(const Key('banner_filtro_motores_cajas')), findsOneWidget);
      expect(
        find.textContaining('Filtro Activo: Salidas de Motores y Cajas Inventariadas'),
        findsOneWidget,
      );
    });
  });
}
