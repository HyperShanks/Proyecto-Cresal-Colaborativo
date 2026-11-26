// frontend/test/features/gerencia/proyeccion_financiera_ia_test.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/tokens/app_palette.dart';
import 'package:frontend/features/gerencia/models/gerencia_models.dart';
import 'package:frontend/features/gerencia/presentation/screens/dashboard_gerencia_view.dart';
import 'package:frontend/features/gerencia/presentation/widgets/proyeccion_financiera_ia_section.dart';

Map<String, dynamic> _buildMockPredictionJson() {
  return {
    'metadata_modelo': {
      'algoritmo': 'XGBoost Multi-Target (CRISP-DM)',
      'exactitud_wape_pct': 90.39,
      'wape_promedio_pct': 9.61,
      'r2_promedio': 0.7247,
      'id_sucursal_filtro': null,
      'semana_proyectada_inicio': '2026-11-16',
      'tiempo_inferencia_ms': 42.5,
    },
    'prediccion_semanal_t1': {
      'semana_inicio': '2026-11-16',
      'dias_habiles': 6,
      'unidades_motor': 4.5,
      'monto_motor_clp': 4800000,
      'unidades_caja': 2.5,
      'monto_caja_clp': 1600000,
      'unidades_accesorio': 160.0,
      'monto_accesorio_clp': 11578712,
      'venta_total_proyectada_clp': 17978712,
      'regimen_motor': 'Alta',
      'regimen_caja': 'Baja',
      'regimen_accesorio': 'Normal',
    },
    'proyeccion_mensual_4_semanas': {
      'unidades_motor': 18.0,
      'monto_motor_clp': 19200000,
      'unidades_caja': 10.0,
      'monto_caja_clp': 6400000,
      'unidades_accesorio': 640.0,
      'monto_accesorio_clp': 46314848,
      'venta_total_proyectada_clp': 71914848,
      'desglose_semanal': [
        {
          'semana_inicio': '2026-11-16',
          'dias_habiles': 6,
          'unidades_motor': 4.5,
          'monto_motor_clp': 4800000,
          'unidades_caja': 2.5,
          'monto_caja_clp': 1600000,
          'unidades_accesorio': 160.0,
          'monto_accesorio_clp': 11578712,
        },
        {
          'semana_inicio': '2026-11-23',
          'dias_habiles': 6,
          'unidades_motor': 4.5,
          'monto_motor_clp': 4800000,
          'unidades_caja': 2.5,
          'monto_caja_clp': 1600000,
          'unidades_accesorio': 160.0,
          'monto_accesorio_clp': 11578712,
        },
        {
          'semana_inicio': '2026-11-30',
          'dias_habiles': 6,
          'unidades_motor': 4.5,
          'monto_motor_clp': 4800000,
          'unidades_caja': 2.5,
          'monto_caja_clp': 1600000,
          'unidades_accesorio': 160.0,
          'monto_accesorio_clp': 11578712,
        },
        {
          'semana_inicio': '2026-12-07',
          'dias_habiles': 6,
          'unidades_motor': 4.5,
          'monto_motor_clp': 4800000,
          'unidades_caja': 2.5,
          'monto_caja_clp': 1600000,
          'unidades_accesorio': 160.0,
          'monto_accesorio_clp': 11578712,
        },
      ],
    },
    'mix_porcentual_ventas': {
      'motor_pct': 26.7,
      'caja_pct': 8.9,
      'accesorio_pct': 64.4,
    },
    'cobertura_stock_critico': [
      {
        'id_categoria': 1,
        'categoria': 'Motor',
        'stock_disponible_tasado': 8,
        'stock_paletizado_sin_tasar': 2,
        'stock_total_disponible': 10,
        'stock_vina_del_mar': 7,
        'stock_limache': 3,
        'backorders_pendientes': 1,
        'demanda_predicha_semanal': 4.5,
        'demanda_predicha_mensual_4sem': 18.0,
        'balance_unidades': 4,
        'semanas_cobertura': 2.22,
        'estado_alerta': 'Óptimo',
      },
      {
        'id_categoria': 2,
        'categoria': 'Caja de Cambios',
        'stock_disponible_tasado': 3,
        'stock_paletizado_sin_tasar': 1,
        'stock_total_disponible': 4,
        'stock_vina_del_mar': 3,
        'stock_limache': 1,
        'backorders_pendientes': 2,
        'demanda_predicha_semanal': 2.5,
        'demanda_predicha_mensual_4sem': 10.0,
        'balance_unidades': -1,
        'semanas_cobertura': 1.6,
        'estado_alerta': 'Déficit Crítico',
      },
    ],
    // Promedio últimas 4 semanas:
    // - motor: 4.000.000 -> vs 4.800.000 (+20.0%)
    // - caja:  2.000.000 -> vs 1.600.000 (-20.0%)
    // - acc:  10.000.000 -> vs 11.578.712 (+15.8%)
    // - total: 16.000.000 -> vs 17.978.712 (+12.4%)
    'historial_reciente_8_semanas': [
      {
        'semana_inicio': '2026-09-21',
        'unidades_motor': 3.0,
        'monto_motor_clp': 3200000,
        'unidades_caja': 2.0,
        'monto_caja_clp': 1500000,
        'unidades_accesorio': 140.0,
        'monto_accesorio_clp': 9300000,
        'venta_total_clp': 14000000,
      },
      {
        'semana_inicio': '2026-09-28',
        'unidades_motor': 4.0,
        'monto_motor_clp': 3800000,
        'unidades_caja': 3.0,
        'monto_caja_clp': 1800000,
        'unidades_accesorio': 150.0,
        'monto_accesorio_clp': 9400000,
        'venta_total_clp': 15000000,
      },
      {
        'semana_inicio': '2026-10-05',
        'unidades_motor': 3.0,
        'monto_motor_clp': 3500000,
        'unidades_caja': 3.0,
        'monto_caja_clp': 1900000,
        'unidades_accesorio': 145.0,
        'monto_accesorio_clp': 9600000,
        'venta_total_clp': 15000000,
      },
      {
        'semana_inicio': '2026-10-12',
        'unidades_motor': 4.0,
        'monto_motor_clp': 3900000,
        'unidades_caja': 2.0,
        'monto_caja_clp': 1700000,
        'unidades_accesorio': 155.0,
        'monto_accesorio_clp': 9900000,
        'venta_total_clp': 15500000,
      },
      {
        'semana_inicio': '2026-10-19',
        'unidades_motor': 4.0,
        'monto_motor_clp': 4000000,
        'unidades_caja': 3.0,
        'monto_caja_clp': 2000000,
        'unidades_accesorio': 150.0,
        'monto_accesorio_clp': 10000000,
        'venta_total_clp': 16000000,
      },
      {
        'semana_inicio': '2026-10-26',
        'unidades_motor': 4.0,
        'monto_motor_clp': 4000000,
        'unidades_caja': 3.0,
        'monto_caja_clp': 2000000,
        'unidades_accesorio': 150.0,
        'monto_accesorio_clp': 10000000,
        'venta_total_clp': 16000000,
      },
      {
        'semana_inicio': '2026-11-02',
        'unidades_motor': 4.0,
        'monto_motor_clp': 4000000,
        'unidades_caja': 3.0,
        'monto_caja_clp': 2000000,
        'unidades_accesorio': 150.0,
        'monto_accesorio_clp': 10000000,
        'venta_total_clp': 16000000,
      },
      {
        'semana_inicio': '2026-11-09',
        'unidades_motor': 4.0,
        'monto_motor_clp': 4000000,
        'unidades_caja': 3.0,
        'monto_caja_clp': 2000000,
        'unidades_accesorio': 150.0,
        'monto_accesorio_clp': 10000000,
        'venta_total_clp': 16000000,
      },
    ],
  };
}

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

  group('CRES-282 - Modelos DTO PredictionDashboardModel', () {
    test('Deserializa y serializa correctamente la respuesta completa', () {
      final jsonMap = _buildMockPredictionJson();
      final model = PredictionDashboardModel.fromJson(jsonMap);

      expect(model.metadataModelo.exactitudWapePct, 90.39);
      expect(model.prediccionSemanalT1.ventaTotalProyectadaClp, 17978712);
      expect(model.proyeccionMensual4Semanas.desgloseSemanal.length, 4);
      expect(model.mixPorcentualVentas.motorPct, 26.7);
      expect(model.coberturaStockCritico.length, 2);
      expect(model.coberturaStockCritico[1].estadoAlerta, 'Déficit Crítico');
      expect(model.historialReciente8Semanas.length, 8);

      final encoded = model.toJson();
      expect(encoded['prediccion_semanal_t1']['monto_motor_clp'], 4800000);
      expect(encoded['historial_reciente_8_semanas'].length, 8);
    });
  });

  group('CRES-282 - ProyeccionFinancieraIaSection UI & Gráficos', () {
    testWidgets(
      'Renderiza 4 tarjetas KPI CLP sin decimales, badges +%/-% y gráficos semanal/mensual',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 950);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final model = PredictionDashboardModel.fromJson(
          _buildMockPredictionJson(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ProyeccionFinancieraIaSection(prediccion: model),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Proyección Financiera y Mix de Ingresos'),
          findsOneWidget,
        );
        expect(find.textContaining('XGBoost'), findsNothing);
        expect(find.textContaining('WAPE'), findsNothing);
        expect(find.textContaining('t+1'), findsNothing);
        expect(find.textContaining('Prom. 4 sem'), findsNothing);

        // Valores CLP sin decimales y con puntos de miles en Vista Semanal
        expect(find.text('\$17.978.712'), findsOneWidget);
        expect(find.text('\$4.800.000'), findsWidgets);
        expect(find.text('\$1.600.000'), findsWidgets);
        expect(find.text('\$11.578.712'), findsWidgets);

        // Variación porcentual (+% verde y -% rojo)
        expect(find.text('+12.4%'), findsOneWidget);
        expect(find.text('+20.0%'), findsOneWidget);
        expect(find.text('-20.0%'), findsOneWidget);
        expect(find.text('+15.8%'), findsOneWidget);

        final posText = tester.widget<Text>(find.text('+20.0%'));
        final negText = tester.widget<Text>(find.text('-20.0%'));
        expect(posText.style?.color, AppPalette.success);
        expect(negText.style?.color, AppPalette.error);

        // Gráfico de Mix y Gráfico de Tendencia (8 reales + puente + 1 futuro t+1 = 2 puntos punteados)
        expect(find.byType(PieChart), findsOneWidget);
        expect(find.byType(LineChart), findsOneWidget);
        final lineSemanal = tester.widget<LineChart>(find.byType(LineChart));
        expect(lineSemanal.data.lineBarsData.length, 2);
        expect(lineSemanal.data.lineBarsData[0].dashArray, isNull);
        expect(lineSemanal.data.lineBarsData[0].spots.length, 8);
        expect(lineSemanal.data.lineBarsData[1].dashArray, isNotNull);
        expect(lineSemanal.data.lineBarsData[1].spots.length, 2);

        // Alternar a Vista Mensual
        await tester.tap(find.byKey(const Key('btn_horizonte_mensual')));
        await tester.pumpAndSettle();

        expect(find.text('\$71.914.848'), findsOneWidget);
        expect(find.text('\$19.200.000'), findsWidgets);
        expect(find.text('\$6.400.000'), findsWidgets);
        expect(find.text('\$46.314.848'), findsWidgets);

        // En Vista Mensual, la serie punteada empalma las 4 semanas proyectadas (puente + 4 = 5 spots)
        final lineMensual = tester.widget<LineChart>(find.byType(LineChart));
        expect(lineMensual.data.lineBarsData[1].spots.length, 5);
      },
    );

    testWidgets(
      'Maneja estado de carga y error controlado con botón Reintentar',
      (tester) async {
        bool retried = false;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ProyeccionFinancieraIaSection(cargando: true),
            ),
          ),
        );
        expect(find.byKey(const Key('prediccion_ia_loading')), findsOneWidget);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ProyeccionFinancieraIaSection(
                cargando: false,
                errorMensaje: 'Servicio ML temporalmente inactivo (503)',
                onReintentar: () => retried = true,
              ),
            ),
          ),
        );

        expect(find.byKey(const Key('prediccion_ia_error')), findsOneWidget);
        expect(
          find.text('Servicio ML temporalmente inactivo (503)'),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('btn_reintentar_prediccion_ia')));
        expect(retried, isTrue);
      },
    );
  });

  group('CRES-282 - Integración en DashboardGerenciaView', () {
    testWidgets(
      'Dashboard renderiza sección de Proyección Financiera IA debajo de Bento',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 1200);
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
        final mockPred = PredictionDashboardModel.fromJson(
          _buildMockPredictionJson(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DashboardGerenciaView(
                kpisIniciales: mockKpis,
                prediccionesIniciales: mockPred,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('FACTURACIÓN HOY'), findsOneWidget);
        expect(
          find.byKey(const Key('section_proyeccion_financiera_ia')),
          findsOneWidget,
        );
        expect(find.text('\$17.978.712'), findsOneWidget);
      },
    );

    testWidgets(
      'DashboardGerenciaView y secciones predictivas no generan RenderFlex overflow en ventanas estrechas (390px y 760px)',
      (tester) async {
        for (final size in [const Size(390, 900), const Size(760, 900)]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

          const mockKpis = KpiFinancieroModel(
            ventasDelDia: 2500000,
            transaccionesHoy: 8,
            acumuladoMensualMtd: 35000000,
            ticketPromedio: 312500.0,
            salidasMotoresHoy: 3,
            salidasCajasHoy: 2,
            totalSalidasHoy: 5,
          );
          final mockPred = PredictionDashboardModel.fromJson(
            _buildMockPredictionJson(),
          );

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: DashboardGerenciaView(
                  kpisIniciales: mockKpis,
                  prediccionesIniciales: mockPred,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        }
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );
  });
}
