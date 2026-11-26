// frontend/lib/features/gerencia/presentation/widgets/proyeccion_financiera_ia_section.dart
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../models/gerencia_models.dart';

/// Horizonte temporal seleccionable para la proyección financiera IA (CRES-282).
enum HorizontePrediccion { semanal, mensual }

/// Sección ejecutiva de Proyección Financiera IA & Mix de Ingresos (CRES-282).
/// Presenta 4 tarjetas KPI en CLP con variación porcentual vs últimas 4 semanas cerradas,
/// gráfico de tendencia temporal (8 semanas sólidas + horizonte futuro punteado) y
/// gráfico de distribución porcentual del mix de ingresos por categoría.
class ProyeccionFinancieraIaSection extends StatefulWidget {
  final PredictionDashboardModel? prediccion;
  final bool cargando;
  final String? errorMensaje;
  final VoidCallback? onReintentar;

  const ProyeccionFinancieraIaSection({
    super.key,
    this.prediccion,
    this.cargando = false,
    this.errorMensaje,
    this.onReintentar,
  });

  @override
  State<ProyeccionFinancieraIaSection> createState() =>
      _ProyeccionFinancieraIaSectionState();
}

class _ProyeccionFinancieraIaSectionState
    extends State<ProyeccionFinancieraIaSection> {
  HorizontePrediccion _horizonte = HorizontePrediccion.semanal;
  int _touchedMixIndex = -1;

  static const Color _colorMotor = Color(0xFF004C89);
  static const Color _colorCaja = Color(0xFF0284C7);
  static const Color _colorAccesorio = Color(0xFFF59E0B);

  String _formatClp(int valor) {
    final prefix = valor < 0 ? '-\$' : '\$';
    return '$prefix${CurrencyFormatter.formatNumber(valor.abs())}';
  }

  String _formatAxisClp(double valor) {
    final absVal = valor.abs();
    if (absVal >= 1000000) {
      final millones = valor / 1000000.0;
      final dec = millones.abs() >= 10 ? 0 : 1;
      return '\$${millones.toStringAsFixed(dec)}M';
    }
    if (absVal >= 1000) {
      return '\$${(valor / 1000.0).toStringAsFixed(0)}K';
    }
    return '\$${valor.toStringAsFixed(0)}';
  }

  String _formatShortDate(String isoDate) {
    final parts = isoDate.split('-');
    if (parts.length == 3) {
      return '${parts[2]}/${parts[1]}';
    }
    return isoDate;
  }

  List<HistorialSemanalItemModel> _ultimas4Semanas(
    List<HistorialSemanalItemModel> historial,
  ) {
    if (historial.length <= 4) return historial;
    return historial.sublist(historial.length - 4);
  }

  double _calcularPromedioBase(
    List<HistorialSemanalItemModel> baseSemanas,
    int Function(HistorialSemanalItemModel item) selector,
    HorizontePrediccion horizonte,
  ) {
    if (baseSemanas.isEmpty) return 0.0;
    final suma = baseSemanas.fold<int>(0, (acc, item) => acc + selector(item));
    final promSemanal = suma / baseSemanas.length;
    return horizonte == HorizontePrediccion.mensual
        ? promSemanal * 4.0
        : promSemanal;
  }

  double _calcularVariacionPct(int proyectado, double baseComparativa) {
    if (baseComparativa <= 0) {
      return 0.0;
    }
    return ((proyectado - baseComparativa) / baseComparativa) * 100.0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('section_proyeccion_financiera_ia'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          if (widget.cargando && widget.prediccion == null)
            _buildLoadingState()
          else if (widget.errorMensaje != null && widget.prediccion == null)
            _buildErrorState()
          else if (widget.prediccion == null)
            _buildLoadingState()
          else
            _buildLoadedContent(widget.prediccion!),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final pred = widget.prediccion;
    final esSemanal = _horizonte == HorizontePrediccion.semanal;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 780;

        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppPalette.tertiary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.auto_graph_rounded,
                    color: AppPalette.tertiary,
                    size: 18,
                  ),
                ),
                const Text(
                  'Proyección Financiera y Mix de Ingresos',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (pred != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                    ),
                    child: Text(
                      'Precisión ${pred.metadataModelo.exactitudWapePct.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0369A1),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              pred != null
                  ? (esSemanal
                        ? 'Estimación para la semana del ${_formatShortDate(pred.prediccionSemanalT1.semanaInicio)} comparada con el promedio de las últimas 4 semanas'
                        : 'Estimación acumulada de 4 semanas (desde el ${_formatShortDate(pred.metadataModelo.semanaProyectadaInicio)}) comparada con el mes anterior')
                  : 'Proyección de ingresos y participación por categoría de producto',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        );

        final selector = _buildHorizonteSelector(esSemanal);

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [titleBlock, const SizedBox(height: 12), selector],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 16),
            selector,
          ],
        );
      },
    );
  }

  Widget _buildHorizonteSelector(bool esSemanal) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: _buildHorizonteButton(
              key: const Key('btn_horizonte_semanal'),
              label: 'Vista Semanal',
              selected: esSemanal,
              onTap: () {
                if (!esSemanal) {
                  setState(() => _horizonte = HorizontePrediccion.semanal);
                }
              },
            ),
          ),
          Flexible(
            child: _buildHorizonteButton(
              key: const Key('btn_horizonte_mensual'),
              label: 'Vista Mensual',
              selected: !esSemanal,
              onTap: () {
                if (esSemanal) {
                  setState(() => _horizonte = HorizontePrediccion.mensual);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizonteButton({
    required Key key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? AppPalette.tertiary : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadedContent(PredictionDashboardModel pred) {
    final esSemanal = _horizonte == HorizontePrediccion.semanal;
    final t1 = pred.prediccionSemanalT1;
    final m4 = pred.proyeccionMensual4Semanas;

    final int ventaTotal = esSemanal
        ? t1.ventaTotalProyectadaClp
        : m4.ventaTotalProyectadaClp;
    final int montoMotor = esSemanal ? t1.montoMotorClp : m4.montoMotorClp;
    final int montoCaja = esSemanal ? t1.montoCajaClp : m4.montoCajaClp;
    final int montoAccesorio = esSemanal
        ? t1.montoAccesorioClp
        : m4.montoAccesorioClp;

    final base4 = _ultimas4Semanas(pred.historialReciente8Semanas);
    final baseTotal = _calcularPromedioBase(
      base4,
      (e) => e.ventaTotalClp,
      _horizonte,
    );
    final baseMotor = _calcularPromedioBase(
      base4,
      (e) => e.montoMotorClp,
      _horizonte,
    );
    final baseCaja = _calcularPromedioBase(
      base4,
      (e) => e.montoCajaClp,
      _horizonte,
    );
    final baseAccesorio = _calcularPromedioBase(
      base4,
      (e) => e.montoAccesorioClp,
      _horizonte,
    );

    final varTotal = _calcularVariacionPct(ventaTotal, baseTotal);
    final varMotor = _calcularVariacionPct(montoMotor, baseMotor);
    final varCaja = _calcularVariacionPct(montoCaja, baseCaja);
    final varAccesorio = _calcularVariacionPct(montoAccesorio, baseAccesorio);

    final double motorPct;
    final double cajaPct;
    final double accesorioPct;
    if (esSemanal) {
      motorPct = pred.mixPorcentualVentas.motorPct;
      cajaPct = pred.mixPorcentualVentas.cajaPct;
      accesorioPct = pred.mixPorcentualVentas.accesorioPct;
    } else {
      final denom = math.max(montoMotor + montoCaja + montoAccesorio, 1);
      motorPct = (montoMotor / denom) * 100.0;
      cajaPct = (montoCaja / denom) * 100.0;
      accesorioPct = (montoAccesorio / denom) * 100.0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.errorMensaje != null) ...[
          _buildInlineWarningBanner(widget.errorMensaje!),
          const SizedBox(height: 12),
        ],
        _buildKpiCardsGrid(
          ventaTotal: ventaTotal,
          varTotal: varTotal,
          montoMotor: montoMotor,
          varMotor: varMotor,
          montoCaja: montoCaja,
          varCaja: varCaja,
          montoAccesorio: montoAccesorio,
          varAccesorio: varAccesorio,
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 980;
            final trendChart = _buildTrendChartCard(pred);
            final mixChart = _buildMixChartCard(
              motorMonto: montoMotor,
              cajaMonto: montoCaja,
              accesorioMonto: montoAccesorio,
              motorPct: motorPct,
              cajaPct: cajaPct,
              accesorioPct: accesorioPct,
              totalMonto: montoMotor + montoCaja + montoAccesorio,
              esSemanal: esSemanal,
            );

            if (!isDesktop) {
              return Column(
                children: [
                  SizedBox(height: 350, child: trendChart),
                  const SizedBox(height: 16),
                  mixChart,
                ],
              );
            }

            return SizedBox(
              height: 365,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 6, child: trendChart),
                  const SizedBox(width: 16),
                  Expanded(flex: 4, child: mixChart),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildKpiCardsGrid({
    required int ventaTotal,
    required double varTotal,
    required int montoMotor,
    required double varMotor,
    required int montoCaja,
    required double varCaja,
    required int montoAccesorio,
    required double varAccesorio,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 4;
        if (constraints.maxWidth < 640) {
          crossAxisCount = 1;
        } else if (constraints.maxWidth < 1100) {
          crossAxisCount = 2;
        }

        return GridView(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: 108,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _FinancialForecastKpiCard(
              key: const Key('kpi_ia_venta_total'),
              titulo: 'Venta Total Proyectada',
              valor: _formatClp(ventaTotal),
              variacionPct: varTotal,
              accentColor: AppPalette.tertiary,
              icono: Icons.account_balance_wallet_rounded,
            ),
            _FinancialForecastKpiCard(
              key: const Key('kpi_ia_monto_motor'),
              titulo: 'Ingresos Estimados por Motores',
              valor: _formatClp(montoMotor),
              variacionPct: varMotor,
              accentColor: _colorMotor,
              icono: Icons.precision_manufacturing_rounded,
            ),
            _FinancialForecastKpiCard(
              key: const Key('kpi_ia_monto_caja'),
              titulo: 'Ingresos Estimados por Cajas de Cambio',
              valor: _formatClp(montoCaja),
              variacionPct: varCaja,
              accentColor: _colorCaja,
              icono: Icons.settings_input_component_rounded,
            ),
            _FinancialForecastKpiCard(
              key: const Key('kpi_ia_monto_accesorio'),
              titulo: 'Ingresos por Venta Menor / Accesorios',
              valor: _formatClp(montoAccesorio),
              variacionPct: varAccesorio,
              accentColor: const Color(0xFFB45309),
              icono: Icons.build_circle_rounded,
            ),
          ],
        );
      },
    );
  }

  Widget _buildTrendChartCard(PredictionDashboardModel pred) {
    final esSemanal = _horizonte == HorizontePrediccion.semanal;
    final hist = pred.historialReciente8Semanas;
    final List<ProyeccionSemanalItemModel> futuro = esSemanal
        ? [
            ProyeccionSemanalItemModel(
              semanaInicio: pred.prediccionSemanalT1.semanaInicio,
              diasHabiles: pred.prediccionSemanalT1.diasHabiles,
              unidadesMotor: pred.prediccionSemanalT1.unidadesMotor,
              montoMotorClp: pred.prediccionSemanalT1.montoMotorClp,
              unidadesCaja: pred.prediccionSemanalT1.unidadesCaja,
              montoCajaClp: pred.prediccionSemanalT1.montoCajaClp,
              unidadesAccesorio: pred.prediccionSemanalT1.unidadesAccesorio,
              montoAccesorioClp: pred.prediccionSemanalT1.montoAccesorioClp,
            ),
          ]
        : pred.proyeccionMensual4Semanas.desgloseSemanal;

    final allLabels = <String>[
      ...hist.map((e) => _formatShortDate(e.semanaInicio)),
      ...futuro.map((e) => _formatShortDate(e.semanaInicio)),
    ];

    final solidSpots = <FlSpot>[
      for (int i = 0; i < hist.length; i++)
        FlSpot(i.toDouble(), hist[i].ventaTotalClp.toDouble()),
    ];

    final dashedSpots = <FlSpot>[
      if (hist.isNotEmpty)
        FlSpot(
          (hist.length - 1).toDouble(),
          hist.last.ventaTotalClp.toDouble(),
        ),
      for (int j = 0; j < futuro.length; j++)
        FlSpot(
          (hist.length + j).toDouble(),
          futuro[j].ventaTotalClp.toDouble(),
        ),
    ];

    final allY = <double>[
      ...solidSpots.map((s) => s.y),
      ...dashedSpots.map((s) => s.y),
    ];
    final maxRawY = allY.isEmpty ? 1000000.0 : allY.reduce(math.max);
    final safeMaxY = maxRawY <= 0 ? 1000000.0 : maxRawY * 1.18;
    final yInterval = math.max(safeMaxY / 4.0, 1.0);
    final maxX = math.max(allLabels.length - 1, 1).toDouble();

    return Container(
      key: const Key('chart_tendencia_temporal_ia'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'TENDENCIA TEMPORAL DE INGRESOS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Historial Real (8 Semanas) vs. Proyección',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _buildLineLegendItem(
                      label: 'Real (8 sem)',
                      color: AppPalette.tertiary,
                      dashed: false,
                    ),
                    _buildLineLegendItem(
                      label: 'Proyección',
                      color: AppPalette.primary,
                      dashed: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: allLabels.isEmpty
                ? const Center(
                    child: Text(
                      'Sin datos históricos suficientes para graficar.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: maxX,
                      minY: 0,
                      maxY: safeMaxY,
                      clipData: const FlClipData.all(),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: yInterval,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: const Color(0xFFE2E8F0),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: const Border(
                          bottom: BorderSide(color: Color(0xFFCBD5E1)),
                          left: BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 54,
                            interval: yInterval,
                            getTitlesWidget: (value, meta) {
                              return SideTitleWidget(
                                meta: meta,
                                space: 6,
                                child: Text(
                                  _formatAxisClp(value),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              if ((value - value.roundToDouble()).abs() >
                                  0.01) {
                                return const SizedBox.shrink();
                              }
                              final idx = value.round();
                              if (idx < 0 || idx >= allLabels.length) {
                                return const SizedBox.shrink();
                              }
                              final esFuturo = idx >= hist.length;
                              return SideTitleWidget(
                                meta: meta,
                                space: 6,
                                child: Text(
                                  esFuturo
                                      ? '${allLabels[idx]}*'
                                      : allLabels[idx],
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: esFuturo
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: esFuturo
                                        ? AppPalette.primary
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          fitInsideHorizontally: true,
                          fitInsideVertically: true,
                          getTooltipColor: (_) => const Color(0xFF0F172A),
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              final idx = spot.x.round();
                              final fecha = (idx >= 0 && idx < allLabels.length)
                                  ? allLabels[idx]
                                  : '';
                              final esSerieProyectada =
                                  spot.bar.dashArray != null;
                              // Evita duplicar tooltip en el punto puente de empalme
                              if (esSerieProyectada &&
                                  hist.isNotEmpty &&
                                  idx == hist.length - 1) {
                                return null;
                              }
                              final prefijo = esSerieProyectada
                                  ? 'Proyección'
                                  : 'Real';
                              return LineTooltipItem(
                                '$prefijo ($fecha)\n${_formatClp(spot.y.round())}',
                                TextStyle(
                                  color: esSerieProyectada
                                      ? const Color(0xFF7DD3FC)
                                      : Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                      lineBarsData: [
                        if (solidSpots.isNotEmpty)
                          LineChartBarData(
                            spots: solidSpots,
                            isCurved: true,
                            preventCurveOverShooting: true,
                            color: AppPalette.tertiary,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, bar, index) =>
                                  FlDotCirclePainter(
                                    radius: 3.5,
                                    color: AppPalette.tertiary,
                                    strokeWidth: 1.5,
                                    strokeColor: Colors.white,
                                  ),
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppPalette.tertiary.withValues(
                                alpha: 0.08,
                              ),
                            ),
                          ),
                        if (dashedSpots.length >= 2)
                          LineChartBarData(
                            spots: dashedSpots,
                            isCurved: true,
                            preventCurveOverShooting: true,
                            color: AppPalette.primary,
                            barWidth: 3,
                            dashArray: const [6, 4],
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              checkToShowDot: (spot, barData) {
                                // Destaca únicamente los puntos futuros proyectados
                                return hist.isEmpty ||
                                    spot.x.round() >= hist.length;
                              },
                              getDotPainter: (spot, percent, bar, index) =>
                                  FlDotCirclePainter(
                                    radius: 4.5,
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                    strokeColor: AppPalette.primary,
                                  ),
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppPalette.primary.withValues(alpha: 0.12),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineLegendItem({
    required String label,
    required Color color,
    required bool dashed,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 22,
          height: 10,
          child: CustomPaint(
            painter: _LegendLinePainter(color: color, dashed: dashed),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
      ],
    );
  }

  Widget _buildMixChartCard({
    required int motorMonto,
    required int cajaMonto,
    required int accesorioMonto,
    required double motorPct,
    required double cajaPct,
    required double accesorioPct,
    required int totalMonto,
    required bool esSemanal,
  }) {
    final items = [
      (label: 'Motor', pct: motorPct, monto: motorMonto, color: _colorMotor),
      (
        label: 'Caja de Cambios',
        pct: cajaPct,
        monto: cajaMonto,
        color: _colorCaja,
      ),
      (
        label: 'Accesorio / Manual',
        pct: accesorioPct,
        monto: accesorioMonto,
        color: _colorAccesorio,
      ),
    ];

    return Container(
      key: const Key('chart_mix_porcentual_ia'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isStacked = constraints.maxWidth < 380;

          final donutWidget = Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      final newIdx =
                          (!event.isInterestedForInteractions ||
                              response == null ||
                              response.touchedSection == null)
                          ? -1
                          : response.touchedSection!.touchedSectionIndex;
                      if (newIdx != _touchedMixIndex) {
                        setState(() => _touchedMixIndex = newIdx);
                      }
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 2.5,
                  centerSpaceRadius: isStacked ? 30 : 34,
                  sections: List.generate(items.length, (i) {
                    final isTouched = i == _touchedMixIndex;
                    final item = items[i];
                    return PieChartSectionData(
                      color: item.color,
                      value: item.monto > 0 ? item.monto.toDouble() : 0.01,
                      showTitle: false,
                      radius: isTouched
                          ? (isStacked ? 30.0 : 34.0)
                          : (isStacked ? 24.0 : 28.0),
                    );
                  }),
                ),
                duration: const Duration(milliseconds: 120),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _touchedMixIndex >= 0 && _touchedMixIndex < items.length
                          ? items[_touchedMixIndex].label
                                .split(' ')[0]
                                .toUpperCase()
                          : 'TOTAL',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _touchedMixIndex >= 0 && _touchedMixIndex < items.length
                            ? '${items[_touchedMixIndex].pct.toStringAsFixed(1)}%'
                            : _formatAxisClp(totalMonto.toDouble()),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final legendColumn = Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: List.generate(items.length, (i) {
              final item = items[i];
              final isHovered = i == _touchedMixIndex;
              return MouseRegion(
                onEnter: (_) {
                  if (_touchedMixIndex != i) {
                    setState(() => _touchedMixIndex = i);
                  }
                },
                onExit: (_) {
                  if (_touchedMixIndex == i) {
                    setState(() => _touchedMixIndex = -1);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isHovered
                        ? item.color.withValues(alpha: 0.1)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isHovered
                          ? item.color.withValues(alpha: 0.4)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: item.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.label,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _formatClp(item.monto),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${item.pct.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          );

          final bodyContent = totalMonto <= 0
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Text(
                      'Sin ingresos proyectados para calcular mix.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                  ),
                )
              : isStacked
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 165, child: donutWidget),
                    const SizedBox(height: 12),
                    legendColumn,
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: SizedBox(height: 185, child: donutWidget),
                    ),
                    const SizedBox(width: 12),
                    Expanded(flex: 6, child: legendColumn),
                  ],
                );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'PARTICIPACIÓN POR CATEGORÍA',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.7,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Mix de Ingresos Proyectado',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        esSemanal ? 'Próxima semana' : 'Próximas 4 semanas',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppPalette.tertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 10,
                  child: totalMonto <= 0
                      ? Container(color: const Color(0xFFE2E8F0))
                      : Row(
                          children: items.map((it) {
                            final flexVal = math.max((it.pct * 10).round(), 1);
                            return Expanded(
                              flex: flexVal,
                              child: Container(color: it.color),
                            );
                          }).toList(),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              if (constraints.hasBoundedHeight)
                Expanded(child: bodyContent)
              else
                bodyContent,
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      key: const Key('prediccion_ia_loading'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppPalette.primary),
          SizedBox(height: 14),
          Text(
            'Calculando proyección de ingresos...',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      key: const Key('prediccion_ia_error'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: AppPalette.errorBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.errorBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.analytics_outlined,
            size: 36,
            color: AppPalette.error,
          ),
          const SizedBox(height: 10),
          const Text(
            'No fue posible cargar la proyección de ingresos',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppPalette.errorText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            widget.errorMensaje ??
                'El servicio predictivo no respondió en este momento.',
            style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D)),
            textAlign: TextAlign.center,
          ),
          if (widget.onReintentar != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              key: const Key('btn_reintentar_prediccion_ia'),
              onPressed: widget.onReintentar,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reintentar proyección'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppPalette.errorText,
                side: const BorderSide(color: AppPalette.errorBorder),
                backgroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInlineWarningBanner(String msg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppPalette.warningBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppPalette.warningBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppPalette.warningText,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Mostrando última proyección disponible. Error al refrescar: $msg',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppPalette.warningText,
              ),
            ),
          ),
          if (widget.onReintentar != null)
            TextButton(
              onPressed: widget.onReintentar,
              child: const Text(
                'Reintentar',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }
}

class _FinancialForecastKpiCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final double variacionPct;
  final Color accentColor;
  final IconData icono;

  const _FinancialForecastKpiCard({
    super.key,
    required this.titulo,
    required this.valor,
    required this.variacionPct,
    required this.accentColor,
    required this.icono,
  });

  @override
  Widget build(BuildContext context) {
    final esPositivo = variacionPct >= 0;
    final badgeColor = esPositivo ? AppPalette.success : AppPalette.error;
    final badgeBg = esPositivo ? AppPalette.successBg : AppPalette.errorBg;
    final badgeBorder = esPositivo
        ? AppPalette.successBorder
        : AppPalette.errorBorder;
    final signo = esPositivo ? '+' : '-';
    final textoBadge = '$signo${variacionPct.abs().toStringAsFixed(1)}%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icono, size: 15, color: accentColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  titulo.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: badgeBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      esPositivo
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 12,
                      color: badgeColor,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      textoBadge,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valor,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: accentColor == AppPalette.tertiary
                    ? AppPalette.tertiary
                    : const Color(0xFF0F172A),
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendLinePainter extends CustomPainter {
  final Color color;
  final bool dashed;

  const _LegendLinePainter({required this.color, required this.dashed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final y = size.height / 2;
    if (!dashed) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }

    double x = 0;
    const dashWidth = 4.0;
    const dashSpace = 3.0;
    while (x < size.width) {
      final endX = math.min(x + dashWidth, size.width);
      canvas.drawLine(Offset(x, y), Offset(endX, y), paint);
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _LegendLinePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.dashed != dashed;
  }
}
