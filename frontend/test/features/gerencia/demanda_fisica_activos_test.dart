// frontend/test/features/gerencia/demanda_fisica_activos_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/gerencia/models/gerencia_models.dart';
import 'package:frontend/features/gerencia/presentation/screens/dashboard_gerencia_view.dart';
import 'package:frontend/features/gerencia/presentation/widgets/demanda_fisica_activos_section.dart';
import 'package:frontend/routes/app_routes.dart';

Map<String, dynamic> _buildMockPredictionJson({
  int precioPromMotor = 1250000,
  int precioPromCaja = 500000,
}) {
  return {
    'metadata_modelo': {
      'algoritmo': 'XGBoost Multi-Target (CRISP-DM)',
      'exactitud_wape_pct': 90.39,
      'wape_promedio_pct': 9.61,
      'r2_promedio': 0.7247,
      'id_sucursal_filtro': null,
      'semana_proyectada_inicio': '2026-11-16',
      'tiempo_inferencia_ms': 38.4,
    },
    'prediccion_semanal_t1': {
      'semana_inicio': '2026-11-16',
      'dias_habiles': 6,
      'unidades_motor': 4.5,
      'monto_motor_clp': 5000000,
      'unidades_caja': 2.5,
      'monto_caja_clp': 1800000,
      'unidades_accesorio': 160.0,
      'monto_accesorio_clp': 11200000,
      'venta_total_proyectada_clp': 18000000,
      'regimen_motor': 'Alta',
      'regimen_caja': 'Baja',
      'regimen_accesorio': 'Normal',
    },
    'proyeccion_mensual_4_semanas': {
      'unidades_motor': 18.0,
      'monto_motor_clp': 20000000,
      'unidades_caja': 10.0,
      'monto_caja_clp': 7200000,
      'unidades_accesorio': 640.0,
      'monto_accesorio_clp': 44800000,
      'venta_total_proyectada_clp': 72000000,
      'desglose_semanal': [
        {
          'semana_inicio': '2026-11-16',
          'dias_habiles': 6,
          'unidades_motor': 4.5,
          'monto_motor_clp': 5000000,
          'unidades_caja': 2.5,
          'monto_caja_clp': 1800000,
          'unidades_accesorio': 160.0,
          'monto_accesorio_clp': 11200000,
        },
        {
          'semana_inicio': '2026-11-23',
          'dias_habiles': 6,
          'unidades_motor': 4.5,
          'monto_motor_clp': 5000000,
          'unidades_caja': 2.5,
          'monto_caja_clp': 1800000,
          'unidades_accesorio': 160.0,
          'monto_accesorio_clp': 11200000,
        },
        {
          'semana_inicio': '2026-11-30',
          'dias_habiles': 6,
          'unidades_motor': 4.5,
          'monto_motor_clp': 5000000,
          'unidades_caja': 2.5,
          'monto_caja_clp': 1800000,
          'unidades_accesorio': 160.0,
          'monto_accesorio_clp': 11200000,
        },
        {
          'semana_inicio': '2026-12-07',
          'dias_habiles': 6,
          'unidades_motor': 4.5,
          'monto_motor_clp': 5000000,
          'unidades_caja': 2.5,
          'monto_caja_clp': 1800000,
          'unidades_accesorio': 160.0,
          'monto_accesorio_clp': 11200000,
        },
      ],
    },
    'mix_porcentual_ventas': {
      'motor_pct': 27.8,
      'caja_pct': 10.0,
      'accesorio_pct': 62.2,
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
        'precio_referencia_promedio': precioPromMotor,
        'precio_referencia_min': 950000,
        'precio_referencia_max': 1650000,
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
        'precio_referencia_promedio': precioPromCaja,
        'precio_referencia_min': 400000,
        'precio_referencia_max': 650000,
      },
    ],
    'historial_reciente_8_semanas': [
      {
        'semana_inicio': '2026-10-19',
        'unidades_motor': 4.0,
        'monto_motor_clp': 4000000,
        'unidades_caja': 3.0,
        'monto_caja_clp': 1800000,
        'unidades_accesorio': 150.0,
        'monto_accesorio_clp': 10000000,
        'venta_total_clp': 15800000,
      },
    ],
    'desglose_demanda_ultimo_mes': [
      {
        'id_categoria': 1,
        'categoria': 'Motor',
        'unidades_stock_fisico': 12,
        'unidades_backorder': 4,
        'unidades_totales_mes': 16,
      },
      {
        'id_categoria': 2,
        'categoria': 'Caja de Cambios',
        'unidades_stock_fisico': 7,
        'unidades_backorder': 3,
        'unidades_totales_mes': 10,
      },
      {
        'id_categoria': 3,
        'categoria': 'Accesorio / Manual',
        'unidades_stock_fisico': 580,
        'unidades_backorder': 20,
        'unidades_totales_mes': 600,
      },
    ],
  };
}

void main() {
  group('CRES-283 - DTOs y RBAC Jefe de Ventas', () {
    test('Mapea precio_referencia_promedio y desglose_demanda_ultimo_mes', () {
      final model = PredictionDashboardModel.fromJson(
        _buildMockPredictionJson(),
      );

      expect(model.coberturaStockCritico.length, 2);
      expect(model.coberturaStockCritico[0].precioReferenciaPromedio, 1250000);
      expect(model.coberturaStockCritico[0].precioReferenciaMin, 950000);
      expect(model.coberturaStockCritico[0].precioReferenciaMax, 1650000);
      expect(model.coberturaStockCritico[1].precioReferenciaPromedio, 500000);

      expect(model.desgloseDemandaUltimoMes.length, 3);
      final mot = model.desgloseDemandaUltimoMes[0];
      expect(mot.idCategoria, 1);
      expect(mot.unidadesStockFisico, 12);
      expect(mot.unidadesBackorder, 4);
      expect(mot.unidadesTotalesMes, 16);
      expect(mot.porcentajeStockFisico, closeTo(75.0, 0.01));
      expect(mot.porcentajeBackorder, closeTo(25.0, 0.01));
    });

    test('Mantiene compatibilidad si JSON omite campos nuevos de CRES-283', () {
      final jsonLegacy = _buildMockPredictionJson()
        ..remove('desglose_demanda_ultimo_mes');
      for (final item
          in jsonLegacy['cobertura_stock_critico'] as List<dynamic>) {
        final m = item as Map<String, dynamic>;
        m.remove('precio_referencia_promedio');
        m.remove('precio_referencia_min');
        m.remove('precio_referencia_max');
      }

      final model = PredictionDashboardModel.fromJson(jsonLegacy);
      expect(model.desgloseDemandaUltimoMes, isEmpty);
      expect(model.coberturaStockCritico[0].precioReferenciaPromedio, 0);
    });

    test('AppRoutes permite acceso a /gerencia al Jefe de Ventas (idRol == 6)',
        () {
      expect(AppRoutes.isRouteAllowedForRole(6, AppRoutes.gerencia), isTrue);
      expect(AppRoutes.isRouteAllowedForRole(6, AppRoutes.ventasMain), isTrue);
      expect(AppRoutes.isRouteAllowedForRole(2, AppRoutes.gerencia), isFalse);
    });
  });

  group('CRES-283 - Widget DemandaFisicaActivosSection', () {
    testWidgets(
      'Muestra unidades enteras redondeadas y cambia entre Vista Semanal y Mensual',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
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
                child: DemandaFisicaActivosSection(prediccion: model),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const Key('section_demanda_fisica_activos')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('card_demanda_categoria_1')), findsOneWidget);
        expect(find.byKey(const Key('card_demanda_categoria_2')), findsOneWidget);
        expect(find.byKey(const Key('card_demanda_categoria_3')), findsOneWidget);

        // Semanal: 4.5 -> 5 unid, 2.5 -> 3 unid, 160.0 -> 160 unid (enteros sin decimales)
        expect(find.text('5 unid'), findsOneWidget);
        expect(find.text('3 unid'), findsOneWidget);
        expect(find.text('160 unid'), findsOneWidget);
        expect(find.text('Demanda Alta'), findsOneWidget);
        expect(find.text('Demanda Baja'), findsOneWidget);
        expect(find.text('Demanda Normal'), findsOneWidget);

        // Cambiar a Vista Mensual (4 semanas)
        await tester.tap(
          find.byKey(const Key('btn_demanda_horizonte_mensual')),
        );
        await tester.pump();

        expect(find.text('18 unid'), findsOneWidget);
        expect(find.text('10 unid'), findsOneWidget);
        expect(find.text('640 unid'), findsOneWidget);
      },
    );

    testWidgets(
      'Calcula Ticket Promedio CLP, compara contra tasación en bodega y muestra Stock Físico vs Backorders',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
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
                child: DemandaFisicaActivosSection(prediccion: model),
              ),
            ),
          ),
        );
        await tester.pump();

        // Ticket promedio Motor: 5.000.000 / 5 = $ 1.000.000 vs tasación $ 1.250.000 (-20.0%)
        expect(find.text('\$ 1.000.000'), findsOneWidget);
        expect(find.text('\$ 1.250.000'), findsOneWidget);
        expect(find.text('Bajo tasación actual (-20.0%)'), findsOneWidget);

        // Ticket promedio Caja: 1.800.000 / 3 = $ 600.000 vs tasación $ 500.000 (+20.0%)
        expect(find.text('\$ 600.000'), findsOneWidget);
        expect(find.text('\$ 500.000'), findsOneWidget);
        expect(find.text('Sobre tasación actual (+20.0%)'), findsOneWidget);

        // Desglose Stock Físico vs Compras en Verde (Backorders)
        expect(find.text('Stock Físico: 12 unid'), findsOneWidget);
        expect(
          find.text('Compras en Verde (Backorder): 4 unid'),
          findsOneWidget,
        );
        expect(find.text('Total: 16 unid'), findsOneWidget);

        // Excluir alertas de quiebre de stock (reservadas para CRES-284)
        expect(find.text('Déficit Crítico'), findsNothing);
        expect(find.text('Riesgo de Quiebre'), findsNothing);
      },
    );

    testWidgets('Muestra "Sin tasación de bodega" cuando precioPromedio es 0',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final model = PredictionDashboardModel.fromJson(
        _buildMockPredictionJson(precioPromMotor: 0, precioPromCaja: 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DemandaFisicaActivosSection(prediccion: model),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Sin tasación de bodega'), findsNWidgets(2));
    });

    testWidgets(
      'DashboardGerenciaView integra DemandaFisicaActivosSection debajo de ProyeccionFinancieraIaSection',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 1400);
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

        expect(
          find.byKey(const Key('section_proyeccion_financiera_ia')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('section_demanda_fisica_activos')),
          findsOneWidget,
        );
      },
    );
  });
}
