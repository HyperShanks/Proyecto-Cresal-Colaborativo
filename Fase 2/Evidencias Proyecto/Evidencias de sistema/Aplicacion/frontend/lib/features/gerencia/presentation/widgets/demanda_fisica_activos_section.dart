// frontend/lib/features/gerencia/presentation/widgets/demanda_fisica_activos_section.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../models/gerencia_models.dart';
import 'proyeccion_financiera_ia_section.dart';

/// Sección ejecutiva de Pronóstico de Demanda Física (CRES-283).
/// Presenta 3 tarjetas por categoría (Motor, Caja de Cambios, Accesorio / Manual)
/// con unidades físicas proyectadas como enteros positivos, ticket promedio CLP
/// contrastado contra la tasación promedio actual de bodega (Activo_Inventariado),
/// y el desglose comercial del último mes (Stock Físico vs. Compras en Verde / Backorders).
class DemandaFisicaActivosSection extends StatefulWidget {
  final PredictionDashboardModel? prediccion;
  final bool cargando;
  final String? errorMensaje;
  final VoidCallback? onReintentar;

  const DemandaFisicaActivosSection({
    super.key,
    this.prediccion,
    this.cargando = false,
    this.errorMensaje,
    this.onReintentar,
  });

  @override
  State<DemandaFisicaActivosSection> createState() =>
      _DemandaFisicaActivosSectionState();
}

class _DemandaFisicaActivosSectionState
    extends State<DemandaFisicaActivosSection> {
  HorizontePrediccion _horizonte = HorizontePrediccion.semanal;

  static const Color _colorMotor = Color(0xFF004C89);
  static const Color _colorCaja = Color(0xFF0284C7);
  static const Color _colorAccesorio = Color(0xFFF59E0B);
  static const Color _colorBackorder = Color(0xFF0D9488);

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('section_demanda_fisica_activos'),
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
                    color: _colorMotor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.precision_manufacturing_rounded,
                    color: _colorMotor,
                    size: 18,
                  ),
                ),
                const Text(
                  'Pronóstico de Demanda Física y Ticket Promedio',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              esSemanal
                  ? 'Unidades físicas estimadas para la próxima semana (T+1), ticket promedio vs. tasación en bodega y origen de demanda (Stock Físico vs. Compras en Verde)'
                  : 'Unidades físicas acumuladas para las próximas 4 semanas, ticket promedio vs. tasación en bodega y origen de demanda del último mes',
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
            children: [
              titleBlock,
              const SizedBox(height: 12),
              selector,
            ],
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
          _buildHorizonteButton(
            key: const Key('btn_demanda_horizonte_semanal'),
            label: 'Vista Semanal',
            selected: esSemanal,
            onTap: () {
              if (!esSemanal) {
                setState(() => _horizonte = HorizontePrediccion.semanal);
              }
            },
          ),
          _buildHorizonteButton(
            key: const Key('btn_demanda_horizonte_mensual'),
            label: 'Vista Mensual',
            selected: !esSemanal,
            onTap: () {
              if (esSemanal) {
                setState(() => _horizonte = HorizontePrediccion.mensual);
              }
            },
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
    final mensual = pred.proyeccionMensual4Semanas;

    final cobMotor = _buscarCoberturaCategoria(pred.coberturaStockCritico, 1);
    final cobCaja = _buscarCoberturaCategoria(pred.coberturaStockCritico, 2);

    final cardsData = [
      _CategoriaDemandaConfig(
        idCategoria: 1,
        titulo: 'Motores',
        subtituloEtiqueta: 'Motor',
        icon: Icons.settings_suggest_rounded,
        accentColor: _colorMotor,
        unidadesRaw: esSemanal ? t1.unidadesMotor : mensual.unidadesMotor,
        montoProyectadoClp: esSemanal ? t1.montoMotorClp : mensual.montoMotorClp,
        regimen: t1.regimenMotor,
        cobertura: cobMotor,
        desglose: _buscarDesgloseCategoria(
          pred.desgloseDemandaUltimoMes,
          1,
          'Motor',
        ),
        esCategoriaInventariada: true,
      ),
      _CategoriaDemandaConfig(
        idCategoria: 2,
        titulo: 'Cajas de Cambio',
        subtituloEtiqueta: 'Caja de Cambios',
        icon: Icons.tune_rounded,
        accentColor: _colorCaja,
        unidadesRaw: esSemanal ? t1.unidadesCaja : mensual.unidadesCaja,
        montoProyectadoClp: esSemanal ? t1.montoCajaClp : mensual.montoCajaClp,
        regimen: t1.regimenCaja,
        cobertura: cobCaja,
        desglose: _buscarDesgloseCategoria(
          pred.desgloseDemandaUltimoMes,
          2,
          'Caja de Cambios',
        ),
        esCategoriaInventariada: true,
      ),
      _CategoriaDemandaConfig(
        idCategoria: 3,
        titulo: 'Accesorios y Manuales',
        subtituloEtiqueta: 'Accesorio / Manual',
        icon: Icons.build_circle_outlined,
        accentColor: _colorAccesorio,
        unidadesRaw: esSemanal
            ? t1.unidadesAccesorio
            : mensual.unidadesAccesorio,
        montoProyectadoClp: esSemanal
            ? t1.montoAccesorioClp
            : mensual.montoAccesorioClp,
        regimen: t1.regimenAccesorio,
        cobertura: null,
        desglose: _buscarDesgloseCategoria(
          pred.desgloseDemandaUltimoMes,
          3,
          'Accesorio / Manual',
        ),
        esCategoriaInventariada: false,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final isMedium = constraints.maxWidth >= 600;
        const spacing = 14.0;
        final columns = isWide ? 3 : (isMedium ? 2 : 1);
        final cardWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cardsData
              .map(
                (cfg) => SizedBox(
                  width: cardWidth,
                  child: _buildCategoriaCard(cfg, esSemanal),
                ),
              )
              .toList(),
        );
      },
    );
  }

  CoberturaStockCriticoItemModel? _buscarCoberturaCategoria(
    List<CoberturaStockCriticoItemModel> lista,
    int idCategoria,
  ) {
    for (final item in lista) {
      if (item.idCategoria == idCategoria) return item;
    }
    return null;
  }

  DesgloseDemandaCategoriaModel _buscarDesgloseCategoria(
    List<DesgloseDemandaCategoriaModel> lista,
    int idCategoria,
    String fallbackNombre,
  ) {
    for (final item in lista) {
      if (item.idCategoria == idCategoria) return item;
    }
    return DesgloseDemandaCategoriaModel(
      idCategoria: idCategoria,
      categoria: fallbackNombre,
      unidadesStockFisico: 0,
      unidadesBackorder: 0,
      unidadesTotalesMes: 0,
    );
  }

  Widget _buildCategoriaCard(_CategoriaDemandaConfig cfg, bool esSemanal) {
    final unidadesEnteras = cfg.unidadesRaw.round().clamp(0, 999999);
    final ticketPromedio = unidadesEnteras > 0
        ? (cfg.montoProyectadoClp / unidadesEnteras).round()
        : 0;

    return Container(
      key: Key('card_demanda_categoria_${cfg.idCategoria}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: cfg.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(cfg.icon, size: 17, color: cfg.accentColor),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  cfg.titulo,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              _buildRegimenBadge(cfg.regimen),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$unidadesEnteras unid',
                key: Key('txt_unidades_cat_${cfg.idCategoria}'),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                  color: cfg.accentColor,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  esSemanal ? 'próx. semana' : 'próx. 4 semanas',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTicketYTasacionBox(cfg, ticketPromedio),
          const SizedBox(height: 12),
          _buildDesgloseDemandaMes(cfg),
        ],
      ),
    );
  }

  Widget _buildRegimenBadge(String regimen) {
    final norm = regimen.trim().toLowerCase();
    Color bg = const Color(0xFFE0F2FE);
    Color border = const Color(0xFFBAE6FD);
    Color text = const Color(0xFF0369A1);

    if (norm == 'alta') {
      bg = const Color(0xFFECFDF5);
      border = const Color(0xFFA7F3D0);
      text = const Color(0xFF047857);
    } else if (norm == 'baja') {
      bg = const Color(0xFFFEF3C7);
      border = const Color(0xFFFDE68A);
      text = const Color(0xFFB45309);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(
        'Demanda $regimen',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: text,
        ),
      ),
    );
  }

  Widget _buildTicketYTasacionBox(
    _CategoriaDemandaConfig cfg,
    int ticketPromedio,
  ) {
    final precioPromBodega = cfg.cobertura?.precioReferenciaPromedio ?? 0;
    final precioMin = cfg.cobertura?.precioReferenciaMin ?? 0;
    final precioMax = cfg.cobertura?.precioReferenciaMax ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
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
              spacing: 8,
              runSpacing: 4,
              children: [
                const Text(
                  'Ticket Promedio Proyectado',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                Text(
                  CurrencyFormatter.formatCLP(ticketPromedio),
                  key: Key('txt_ticket_promedio_cat_${cfg.idCategoria}'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          if (!cfg.esCategoriaInventariada)
            const Text(
              'Mix variado de repuestos menores y manuales',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            )
          else if (precioPromBodega <= 0)
            const Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: Color(0xFF64748B),
                ),
                SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'Sin tasación de bodega',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            )
          else ...[
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  const Text(
                    'Tasación promedio bodega',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    CurrencyFormatter.formatCLP(precioPromBodega),
                    key: Key('txt_tasacion_bodega_cat_${cfg.idCategoria}'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            _buildComparativoTasacionChip(
              ticketPromedio: ticketPromedio,
              precioPromBodega: precioPromBodega,
            ),
            if (precioMin > 0 && precioMax > precioMin) ...[
              const SizedBox(height: 4),
              Text(
                'Rango activo: ${CurrencyFormatter.formatCLP(precioMin)} – ${CurrencyFormatter.formatCLP(precioMax)}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildComparativoTasacionChip({
    required int ticketPromedio,
    required int precioPromBodega,
  }) {
    final diffPct =
        ((ticketPromedio - precioPromBodega) / precioPromBodega) * 100.0;
    final absPct = diffPct.abs().toStringAsFixed(1);

    late final IconData icon;
    late final Color fg;
    late final Color bg;
    late final String label;

    if (diffPct >= 5.0) {
      icon = Icons.trending_up_rounded;
      fg = const Color(0xFF047857);
      bg = const Color(0xFFECFDF5);
      label = 'Sobre tasación actual (+$absPct%)';
    } else if (diffPct <= -5.0) {
      icon = Icons.trending_down_rounded;
      fg = const Color(0xFFB45309);
      bg = const Color(0xFFFEF3C7);
      label = 'Bajo tasación actual (-$absPct%)';
    } else {
      icon = Icons.balance_rounded;
      fg = const Color(0xFF0369A1);
      bg = const Color(0xFFE0F2FE);
      label = 'Alineado a tasación actual';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesgloseDemandaMes(_CategoriaDemandaConfig cfg) {
    final desglose = cfg.desglose;
    final total = desglose.unidadesTotalesMes;
    final fisico = desglose.unidadesStockFisico;
    final backorder = desglose.unidadesBackorder;

    final fisicoFlex = total > 0 ? math.max(fisico, 0) : 0;
    final backorderFlex = total > 0 ? math.max(backorder, 0) : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
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
              spacing: 8,
              runSpacing: 4,
              children: [
                const Text(
                  'Demanda último mes (28 días)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
                Text(
                  'Total: $total unid',
                  key: Key('txt_total_mes_cat_${cfg.idCategoria}'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: total == 0
                  ? Container(color: const Color(0xFFE2E8F0))
                  : Row(
                      children: [
                        if (fisicoFlex > 0)
                          Expanded(
                            flex: fisicoFlex,
                            child: Container(color: cfg.accentColor),
                          ),
                        if (backorderFlex > 0)
                          Expanded(
                            flex: backorderFlex,
                            child: Container(color: _colorBackorder),
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildOrigenChip(
                dotColor: cfg.accentColor,
                label: 'Stock Físico: $fisico unid',
              ),
              _buildOrigenChip(
                dotColor: _colorBackorder,
                label: 'Compras en Verde (Backorder): $backorder unid',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrigenChip({
    required Color dotColor,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: 150,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: AppPalette.tertiary,
            ),
          ),
          SizedBox(width: 12),
          Text(
            'Calculando pronóstico de demanda física...',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFDC2626),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.errorMensaje ??
                  'No fue posible cargar el pronóstico de demanda física.',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF991B1B),
              ),
            ),
          ),
          if (widget.onReintentar != null)
            TextButton(
              onPressed: widget.onReintentar,
              child: const Text('Reintentar'),
            ),
        ],
      ),
    );
  }
}

class _CategoriaDemandaConfig {
  final int idCategoria;
  final String titulo;
  final String subtituloEtiqueta;
  final IconData icon;
  final Color accentColor;
  final double unidadesRaw;
  final int montoProyectadoClp;
  final String regimen;
  final CoberturaStockCriticoItemModel? cobertura;
  final DesgloseDemandaCategoriaModel desglose;
  final bool esCategoriaInventariada;

  const _CategoriaDemandaConfig({
    required this.idCategoria,
    required this.titulo,
    required this.subtituloEtiqueta,
    required this.icon,
    required this.accentColor,
    required this.unidadesRaw,
    required this.montoProyectadoClp,
    required this.regimen,
    required this.cobertura,
    required this.desglose,
    required this.esCategoriaInventariada,
  });
}
