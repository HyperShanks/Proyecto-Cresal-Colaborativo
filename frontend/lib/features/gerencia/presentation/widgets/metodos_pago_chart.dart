// frontend/lib/features/gerencia/presentation/widgets/metodos_pago_chart.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../models/gerencia_models.dart';

/// Gráfico de Dona interactivo de Medios de Pago (HU-5.1) con fl_chart.
/// Implementé este componente para contrastar la recaudación de Efectivo físico
/// frente a canales electrónicos con paleta monocromática tonal.
class MetodosPagoChart extends StatefulWidget {
  final ResumenPagosModel resumen;

  const MetodosPagoChart({
    super.key,
    required this.resumen,
  });

  @override
  State<MetodosPagoChart> createState() => _MetodosPagoChartState();
}

class _MetodosPagoChartState extends State<MetodosPagoChart> {
  int _touchedIndex = -1;

  // Paleta monocromática tonal corporativa de Cresal
  static const List<Color> _tonalPalette = [
    Color(0xFF004C89), // Azul profundo Cresal
    Color(0xFF0284C7), // Azul cielo medio
    Color(0xFF38BDF8), // Cyan celeste
    Color(0xFF94A3B8), // Slate 400
    Color(0xFFCBD5E1), // Slate 300
    Color(0xFFE2E8F0), // Slate 200
  ];

  Color _obtenerColor(int index, String metodo) {
    final m = metodo.toLowerCase();
    if (m.contains('transferencia')) return const Color(0xFF004C89);
    if (m.contains('crédito') || m.contains('credito')) {
      return const Color(0xFF0284C7);
    }
    if (m.contains('efectivo')) return const Color(0xFF38BDF8);
    if (m.contains('débito') || m.contains('debito')) {
      return const Color(0xFF94A3B8);
    }
    if (m.contains('cheque')) return const Color(0xFFCBD5E1);
    return _tonalPalette[index % _tonalPalette.length];
  }

  @override
  Widget build(BuildContext context) {
    final desglose = widget.resumen.desglose;
    final total = widget.resumen.totalRecaudado;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera del Bento
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'RECAUDACIÓN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Medios de Pago',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppPalette.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.verified_user,
                      size: 14,
                      color: AppPalette.primary,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Conciliado',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Distribución de ingresos por canal transaccional liquidado',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 16),

          // Gráfico Donut y Leyenda
          Expanded(
            child: total == 0 || desglose.isEmpty
                ? _buildEmptyState()
                : Row(
                    children: [
                      // Donut PieChart
                      Expanded(
                        flex: 5,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            PieChart(
                              PieChartData(
                                pieTouchData: PieTouchData(
                                  touchCallback:
                                      (FlTouchEvent event, pieTouchResponse) {
                                    setState(() {
                                      if (!event.isInterestedForInteractions ||
                                          pieTouchResponse == null ||
                                          pieTouchResponse.touchedSection ==
                                              null) {
                                        _touchedIndex = -1;
                                        return;
                                      }
                                      _touchedIndex = pieTouchResponse
                                          .touchedSection!
                                          .touchedSectionIndex;
                                    });
                                  },
                                ),
                                borderData: FlBorderData(show: false),
                                sectionsSpace: 2,
                                centerSpaceRadius: 42,
                                sections: List.generate(desglose.length, (i) {
                                  final isTouched = i == _touchedIndex;
                                  final item = desglose[i];
                                  final color = _obtenerColor(i, item.metodoPago);
                                  return PieChartSectionData(
                                    color: color,
                                    value: item.montoTotal.toDouble(),
                                    title: '${item.porcentaje.toStringAsFixed(0)}%',
                                    radius: isTouched ? 28.0 : 22.0,
                                    titleStyle: TextStyle(
                                      fontSize: isTouched ? 12.0 : 10.0,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  );
                                }),
                              ),
                            ),
                            // Centro Reactivo
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _touchedIndex >= 0 &&
                                          _touchedIndex < desglose.length
                                      ? desglose[_touchedIndex]
                                          .metodoPago
                                          .split(' ')[0]
                                          .toUpperCase()
                                      : 'TOTAL',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _touchedIndex >= 0 &&
                                          _touchedIndex < desglose.length
                                      ? CurrencyFormatter.formatCLP(
                                          desglose[_touchedIndex].montoTotal)
                                      : CurrencyFormatter.formatCLP(total),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Leyenda Tonal
                      Expanded(
                        flex: 6,
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const ClampingScrollPhysics(),
                          itemCount: desglose.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, i) {
                            final item = desglose[i];
                            final color = _obtenerColor(i, item.metodoPago);
                            final isHovered = i == _touchedIndex;

                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _touchedIndex =
                                      _touchedIndex == i ? -1 : i;
                                });
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isHovered
                                      ? color.withValues(alpha: 0.1)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: color,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              item.metodoPago,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: isHovered
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                                color: const Color(0xFF334155),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${item.porcentaje.toStringAsFixed(1)}%',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),

          // Pie del Bento con comparativa Efectivo vs Canales
          const Divider(height: 24, thickness: 1, color: Color(0xFFF1F5F9)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: _buildSubtotal(
                  'Efectivo Físico',
                  widget.resumen.efectivoFisico,
                  const Color(0xFF38BDF8),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: _buildSubtotal(
                  'Canales Electrónicos',
                  widget.resumen.canalesElectronicos,
                  const Color(0xFF004C89),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubtotal(String label, int monto, Color dotColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                CurrencyFormatter.formatCLP(monto),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.pie_chart_outline, size: 40, color: Color(0xFFCBD5E1)),
          SizedBox(height: 8),
          Text(
            'Sin pagos registrados hoy',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}
