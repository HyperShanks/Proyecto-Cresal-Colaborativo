// frontend/test/features/gerencia/cobertura_stock_prescriptiva_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/gerencia/models/gerencia_models.dart';
import 'package:frontend/features/gerencia/presentation/screens/dashboard_gerencia_view.dart';
import 'package:frontend/features/gerencia/presentation/widgets/cobertura_stock_prescriptiva_section.dart';

Map<String, dynamic> _buildPredictionWithCobertura({
  required Map<String, dynamic> motorCob,
  required Map<String, dynamic> cajaCob,
}) {
  return {
    'metadata_modelo': {
      'algoritmo': 'XGBoost Multi-Target (CRISP-DM)',
      'exactitud_wape_pct': 90.39,
      'wape_promedio_pct': 9.61,
      'r2_promedio': 0.7247,
      'id_sucursal_filtro': null,
      'semana_proyectada_inicio': '2026-11-16',
      'tiempo_inferencia_ms': 41.0,
    },
    'prediccion_semanal_t1': {
      'semana_inicio': '2026-11-16',
      'dias_habiles': 6,
      'unidades_motor': motorCob['demanda_predicha_semanal'],
      'monto_motor_clp': 5000000,
      'unidades_caja': cajaCob['demanda_predicha_semanal'],
      'monto_caja_clp': 1800000,
      'unidades_accesorio': 160.0,
      'monto_accesorio_clp': 11200000,
      'venta_total_proyectada_clp': 18000000,
      'regimen_motor': 'Alta',
      'regimen_caja': 'Normal',
      'regimen_accesorio': 'Normal',
    },
    'proyeccion_mensual_4_semanas': {
      'unidades_motor': motorCob['demanda_predicha_mensual_4sem'],
      'monto_motor_clp': 20000000,
      'unidades_caja': cajaCob['demanda_predicha_mensual_4sem'],
      'monto_caja_clp': 7200000,
      'unidades_accesorio': 640.0,
      'monto_accesorio_clp': 44800000,
      'venta_total_proyectada_clp': 72000000,
      'desglose_semanal': const [],
    },
    'mix_porcentual_ventas': {
      'motor_pct': 27.8,
      'caja_pct': 10.0,
      'accesorio_pct': 62.2,
    },
    'cobertura_stock_critico': [motorCob, cajaCob],
    'historial_reciente_8_semanas': const [],
    'desglose_demanda_ultimo_mes': const [],
  };
}

void main() {
  group('CRES-284 - DTO CoberturaStockCriticoItemModel', () {
    test('Mapea todos los campos prescriptivos y soporta JSON legacy', () {
      final fullItem = CoberturaStockCriticoItemModel.fromJson({
        'id_categoria': 1,
        'categoria': 'Motor',
        'stock_disponible_tasado': 2,
        'stock_paletizado_sin_tasar': 1,
        'stock_en_desarme': 2,
        'stock_en_proceso_interno': 3,
        'stock_total_disponible': 3,
        'stock_vina_del_mar': 2,
        'stock_limache': 1,
        'stock_disponible_vina': 2,
        'stock_disponible_limache': 0,
        'stock_proceso_vina': 2,
        'stock_proceso_limache': 1,
        'paletizado_vina': 1,
        'paletizado_limache': 0,
        'desarme_vina': 1,
        'desarme_limache': 1,
        'backorders_pendientes': 2,
        'demanda_predicha_semanal': 4.5,
        'demanda_predicha_mensual_4sem': 18.0,
        'requerimiento_total': 7,
        'balance_unidades': -5,
        'deficit_neto_compra': 2,
        'semanas_cobertura': 0.44,
        'estado_alerta': 'Déficit Crítico',
        'recomendacion_accionable':
            'Déficit crítico proyectado de 5 unidades. Adquirir 2 en remates.',
        'requerimiento_total_mensual_4sem': 20,
        'balance_unidades_mensual_4sem': -18,
        'deficit_neto_compra_mensual_4sem': 15,
        'estado_alerta_mensual_4sem': 'Déficit Crítico',
        'recomendacion_accionable_mensual_4sem':
            'Plan mensual: adquirir 15 motores adicionales en remates.',
      });

      expect(fullItem.stockEnDesarme, 2);
      expect(fullItem.stockEnProcesoInterno, 3);
      expect(fullItem.stockProcesoVina, 2);
      expect(fullItem.stockProcesoLimache, 1);
      expect(fullItem.deficitNetoCompra, 2);
      expect(fullItem.estadoAlerta, 'Déficit Crítico');

      // Fallback desde payload anterior sin campos CRES-284
      final legacyItem = CoberturaStockCriticoItemModel.fromJson({
        'id_categoria': 2,
        'categoria': 'Caja de Cambios',
        'stock_disponible_tasado': 5,
        'stock_paletizado_sin_tasar': 1,
        'stock_total_disponible': 6,
        'stock_vina_del_mar': 4,
        'stock_limache': 2,
        'backorders_pendientes': 1,
        'demanda_predicha_semanal': 2.5,
        'demanda_predicha_mensual_4sem': 10.0,
        'balance_unidades': 1,
        'semanas_cobertura': 2.0,
        'estado_alerta': 'Cobertura Óptima',
      });

      expect(legacyItem.stockEnProcesoInterno, 1);
      expect(legacyItem.requerimientoTotal, 4);
      expect(legacyItem.deficitNetoCompra, 0);
    });
  });

  group('CRES-284 - Widget CoberturaStockPrescriptivaSection', () {
    testWidgets(
      'Escenario 1 (Déficit Crítico) y Escenario 3 (Cobertura Óptima) con desglose Viña/Limache y alternancia mensual',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final pred = PredictionDashboardModel.fromJson(
          _buildPredictionWithCobertura(
            motorCob: {
              'id_categoria': 1,
              'categoria': 'Motor',
              'stock_disponible_tasado': 2,
              'stock_paletizado_sin_tasar': 1,
              'stock_en_desarme': 1,
              'stock_en_proceso_interno': 2,
              'stock_total_disponible': 3,
              'stock_vina_del_mar': 2,
              'stock_limache': 1,
              'stock_disponible_vina': 1,
              'stock_disponible_limache': 1,
              'stock_proceso_vina': 1,
              'stock_proceso_limache': 1,
              'backorders_pendientes': 2,
              'demanda_predicha_semanal': 4.5,
              'demanda_predicha_mensual_4sem': 18.0,
              'requerimiento_total': 7,
              'balance_unidades': -5,
              'deficit_neto_compra': 3,
              'semanas_cobertura': 0.44,
              'estado_alerta': 'Déficit Crítico',
              'recomendacion_accionable':
                  'Déficit crítico proyectado de 5 unidades. Existen 2 activos en Paletizado/En Desarme (1 en Viña del Mar, 1 en Limache); se sugiere priorizar su liberación y adquirir/desarmar 3 unidades adicionales en remates.',
              'requerimiento_total_mensual_4sem': 20,
              'balance_unidades_mensual_4sem': -18,
              'deficit_neto_compra_mensual_4sem': 16,
              'estado_alerta_mensual_4sem': 'Déficit Crítico',
              'recomendacion_accionable_mensual_4sem':
                  'Déficit crítico proyectado de 18 unidades en 4 semanas; adquirir/desarmar 16 unidades adicionales en remates.',
            },
            cajaCob: {
              'id_categoria': 2,
              'categoria': 'Caja de Cambios',
              'stock_disponible_tasado': 6,
              'stock_paletizado_sin_tasar': 1,
              'stock_en_desarme': 0,
              'stock_en_proceso_interno': 1,
              'stock_total_disponible': 7,
              'stock_vina_del_mar': 5,
              'stock_limache': 2,
              'stock_disponible_vina': 4,
              'stock_disponible_limache': 2,
              'stock_proceso_vina': 1,
              'stock_proceso_limache': 0,
              'backorders_pendientes': 1,
              'demanda_predicha_semanal': 2.5,
              'demanda_predicha_mensual_4sem': 10.0,
              'requerimiento_total': 4,
              'balance_unidades': 2,
              'deficit_neto_compra': 0,
              'semanas_cobertura': 2.4,
              'estado_alerta': 'Cobertura Óptima',
              'recomendacion_accionable':
                  'Cobertura óptima: superávit de +2 unidades disponibles en vitrina para cubrir la demanda proyectada y reservas activas.',
              'requerimiento_total_mensual_4sem': 11,
              'balance_unidades_mensual_4sem': -5,
              'deficit_neto_compra_mensual_4sem': 4,
              'estado_alerta_mensual_4sem': 'Déficit Crítico',
              'recomendacion_accionable_mensual_4sem':
                  'Déficit crítico proyectado de 5 unidades mensuales; adquirir 4 cajas adicionales en remates.',
            },
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CoberturaStockPrescriptivaSection(prediccion: pred),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const Key('section_cobertura_stock_prescriptiva')),
          findsOneWidget,
        );
        expect(find.text('Déficit Crítico'), findsOneWidget);
        expect(find.text('Cobertura Óptima'), findsOneWidget);
        expect(find.text('-5 unid'), findsOneWidget);
        expect(find.text('+2 unid'), findsOneWidget);
        expect(find.text('Adquirir en remates: 3 unid'), findsOneWidget);
        expect(
          find.textContaining('Paletizado: 1 · En Desarme: 1'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Viña del Mar: 1 · Limache: 1'),
          findsWidgets,
        );

        // Cambiar a Vista Mensual
        await tester.tap(
          find.byKey(const Key('btn_cobertura_horizonte_mensual')),
        );
        await tester.pump();

        expect(find.text('-18 unid'), findsOneWidget);
        expect(find.text('Adquirir en remates: 16 unid'), findsOneWidget);
        expect(find.text('Déficit Crítico'), findsNWidgets(2));
      },
    );

    testWidgets(
      'Escenario 2 (Atención / En Proceso): stock interno cubre déficit sin compra externa',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final pred = PredictionDashboardModel.fromJson(
          _buildPredictionWithCobertura(
            motorCob: {
              'id_categoria': 1,
              'categoria': 'Motor',
              'stock_disponible_tasado': 3,
              'stock_paletizado_sin_tasar': 2,
              'stock_en_desarme': 2,
              'stock_en_proceso_interno': 4,
              'stock_total_disponible': 5,
              'stock_vina_del_mar': 3,
              'stock_limache': 2,
              'stock_disponible_vina': 2,
              'stock_disponible_limache': 1,
              'stock_proceso_vina': 3,
              'stock_proceso_limache': 1,
              'backorders_pendientes': 1,
              'demanda_predicha_semanal': 4.2,
              'demanda_predicha_mensual_4sem': 16.8,
              'requerimiento_total': 6,
              'balance_unidades': -3,
              'deficit_neto_compra': 0,
              'semanas_cobertura': 0.71,
              'estado_alerta': 'Atención / En Proceso',
              'recomendacion_accionable':
                  'Atención: faltan 3 unidades disponibles en vitrina, pero existen 4 activos en estado Paletizado/En Desarme (3 en Viña del Mar, 1 en Limache). Se sugiere priorizar su tasación y preparación.',
            },
            cajaCob: {
              'id_categoria': 2,
              'categoria': 'Caja de Cambios',
              'stock_disponible_tasado': 5,
              'stock_paletizado_sin_tasar': 0,
              'stock_en_desarme': 0,
              'stock_en_proceso_interno': 0,
              'stock_total_disponible': 5,
              'stock_vina_del_mar': 3,
              'stock_limache': 2,
              'stock_disponible_vina': 3,
              'stock_disponible_limache': 2,
              'stock_proceso_vina': 0,
              'stock_proceso_limache': 0,
              'backorders_pendientes': 1,
              'demanda_predicha_semanal': 2.1,
              'demanda_predicha_mensual_4sem': 8.4,
              'requerimiento_total': 4,
              'balance_unidades': 1,
              'deficit_neto_compra': 0,
              'semanas_cobertura': 2.38,
              'estado_alerta': 'Cobertura Óptima',
              'recomendacion_accionable':
                  'Cobertura óptima: superávit de +1 unidades disponibles en vitrina para cubrir la demanda proyectada y reservas activas.',
            },
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CoberturaStockPrescriptivaSection(prediccion: pred),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Atención / En Proceso'), findsOneWidget);
        expect(find.text('-3 unid'), findsOneWidget);
        expect(
          find.textContaining('priorizar su tasación y preparación'),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('badge_compra_remate_cat_1')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'DashboardGerenciaView integra CoberturaStockPrescriptivaSection al final del flujo analítico',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 1600);
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
          _buildPredictionWithCobertura(
            motorCob: {
              'id_categoria': 1,
              'categoria': 'Motor',
              'stock_disponible_tasado': 2,
              'stock_paletizado_sin_tasar': 1,
              'stock_en_desarme': 1,
              'stock_en_proceso_interno': 2,
              'stock_total_disponible': 3,
              'stock_vina_del_mar': 2,
              'stock_limache': 1,
              'backorders_pendientes': 1,
              'demanda_predicha_semanal': 4.5,
              'demanda_predicha_mensual_4sem': 18.0,
              'balance_unidades': -4,
              'semanas_cobertura': 0.44,
              'estado_alerta': 'Déficit Crítico',
            },
            cajaCob: {
              'id_categoria': 2,
              'categoria': 'Caja de Cambios',
              'stock_disponible_tasado': 5,
              'stock_paletizado_sin_tasar': 0,
              'stock_en_desarme': 0,
              'stock_en_proceso_interno': 0,
              'stock_total_disponible': 5,
              'stock_vina_del_mar': 3,
              'stock_limache': 2,
              'backorders_pendientes': 0,
              'demanda_predicha_semanal': 2.5,
              'demanda_predicha_mensual_4sem': 10.0,
              'balance_unidades': 2,
              'semanas_cobertura': 2.0,
              'estado_alerta': 'Cobertura Óptima',
            },
          ),
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
        expect(
          find.byKey(const Key('section_cobertura_stock_prescriptiva')),
          findsOneWidget,
        );
      },
    );
  });
}
