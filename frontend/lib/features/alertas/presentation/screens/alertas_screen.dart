// lib/features/alertas/presentation/screens/alertas_screen.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/tarea_alerta.dart';
import '../../services/logistica_service.dart';
import '../../services/bodega_polling_service.dart';
import '../widgets/alerta_preentrega_tab.dart';
import '../widgets/alerta_reimpresion_tab.dart';
import '../widgets/alerta_reintegracion_tab.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';

/// Centro de Alertas y Tareas de Bodega PDA con navegación por pestañas (SPEC-HU-TAREA-13).
/// Segmenta el flujo de trabajo en:
/// 1. Pre-entrega (Preparación, Liberada, Traslado)
/// 2. Re-impresión (Etiquetas QR por imprimir)
/// 3. Re-integración (Logística Inversa por órdenes anuladas)
class AlertasScreen extends StatefulWidget {
  final Future<List<TareaAlerta>>? futureAlertas;

  const AlertasScreen({super.key, this.futureAlertas});

  @override
  State<AlertasScreen> createState() => _AlertasScreenState();
}

class _AlertasScreenState extends State<AlertasScreen> {
  late Future<List<TareaAlerta>> futureAlertas;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    futureAlertas = widget.futureAlertas ?? LogisticaService.obtenerAlertas();
    futureAlertas.then((tareas) {
      if (mounted && !_isDisposed) {
        _sincronizarNotifiers(tareas);
      }
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _sincronizarNotifiers(List<TareaAlerta> tareas) {
    if (!mounted || _isDisposed) return;

    final preentrega = tareas
        .where((t) =>
            t.tipoAlerta == 'PREPARACION' ||
            t.tipoAlerta == 'LIBERADA' ||
            t.tipoAlerta == 'TRASLADO')
        .toList();
    final reimpresion = tareas.where((t) => t.tipoAlerta == 'IMPRESION').toList();
    final reintegracion = tareas.where((t) => t.tipoAlerta == 'REINGRESO').toList();

    final s = BodegaPollingService.instance;
    s.tareasNotifier.value = tareas;
    s.preentregaNotifier.value = preentrega;
    s.reimpresionNotifier.value = reimpresion;
    s.reintegracionNotifier.value = reintegracion;
    s.conteoPreentregaNotifier.value = preentrega.length;
    s.conteoReimpresionNotifier.value = reimpresion.length;
    s.conteoReintegracionNotifier.value = reintegracion.length;
    s.totalPendientesNotifier.value = tareas.length;
  }

  Future<void> _refreshAlertas() async {
    final fut = widget.futureAlertas ?? LogisticaService.obtenerAlertas();
    if (mounted && !_isDisposed) {
      setState(() {
        futureAlertas = fut;
      });
    }
    try {
      final tareas = await fut;
      if (mounted && !_isDisposed) {
        _sincronizarNotifiers(tareas);
      }
    } catch (_) {}
  }

  Widget _buildTabItem({
    required String label,
    required ValueListenable<int> countNotifier,
  }) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
          ValueListenableBuilder<int>(
            valueListenable: countNotifier,
            builder: (context, count, _) {
              if (count <= 0) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: AppPalette.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final polling = BodegaPollingService.instance;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppPalette.background,
        appBar: AppBar(
          backgroundColor: AppPalette.surface,
          foregroundColor: AppPalette.textPrimary,
          elevation: 0.5,
          centerTitle: false,
          title: Text(
            'Alertas Tareas',
            style: AppTypography.title.copyWith(fontSize: 18),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppPalette.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Volver',
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: AppPalette.primary),
              onPressed: _refreshAlertas,
              tooltip: 'Actualizar tareas',
            ),
          ],
          bottom: TabBar(
            indicatorColor: AppPalette.primary,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.tab,
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            labelColor: AppPalette.primary,
            unselectedLabelColor: AppPalette.textSecondary,
            tabs: [
              _buildTabItem(
                label: 'Entrega',
                countNotifier: polling.conteoPreentregaNotifier,
              ),
              _buildTabItem(
                label: 'Imprimir',
                countNotifier: polling.conteoReimpresionNotifier,
              ),
              _buildTabItem(
                label: 'Re-integración',
                countNotifier: polling.conteoReintegracionNotifier,
              ),
            ],
          ),
        ),
        body: FutureBuilder<List<TareaAlerta>>(
          future: futureAlertas,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppPalette.primary),
              );
            } else if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off_rounded, color: AppPalette.error, size: 52),
                      const SizedBox(height: 16),
                      const Text(
                        'No se pudieron cargar las tareas. Reintentando conexión con la bodega...',
                        style: TextStyle(
                          color: AppPalette.error,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _refreshAlertas,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppPalette.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final tareas = snapshot.data ?? [];

            final preentrega = tareas
                .where((t) =>
                    t.tipoAlerta == 'PREPARACION' ||
                    t.tipoAlerta == 'LIBERADA' ||
                    t.tipoAlerta == 'TRASLADO')
                .toList();
            final reimpresion = tareas.where((t) => t.tipoAlerta == 'IMPRESION').toList();
            final reintegracion = tareas.where((t) => t.tipoAlerta == 'REINGRESO').toList();

            return TabBarView(
              children: [
                AlertaPreentregaTab(
                  tareas: preentrega,
                  onRefresh: _refreshAlertas,
                ),
                AlertaReimpresionTab(
                  tareas: reimpresion,
                  onRefresh: _refreshAlertas,
                ),
                AlertaReintegracionTab(
                  tareas: reintegracion,
                  onRefresh: _refreshAlertas,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
