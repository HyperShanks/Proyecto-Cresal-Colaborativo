// frontend/lib/features/gerencia/presentation/widgets/cobertura_stock_prescriptiva_section.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../models/gerencia_models.dart';
import 'proyeccion_financiera_ia_section.dart';

/// Sección prescriptiva de Cobertura de Stock Crítico y Alertas de Compra (CRES-284).
/// Contrastes por categoría crítica (Motores y Cajas de Cambio):
/// - Stock Disponible en Vitrina ('Disponible') vs. Stock en Proceso Interno ('Paletizado' + 'En Desarme')
/// - Desglose físico por sucursal (Viña del Mar vs. Limache)
/// - Balance Neto, Semáforo de 3 Estados y Recomendación Accionable para remates (Vehiculo_Origen).
class CoberturaStockPrescriptivaSection extends StatefulWidget {
  final PredictionDashboardModel? prediccion;
  final bool cargando;
  final String? errorMensaje;
  final VoidCallback? onReintentar;

  const CoberturaStockPrescriptivaSection({
    super.key,
    this.prediccion,
    this.cargando = false,
    this.errorMensaje,
    this.onReintentar,
  });

  @override
  State<CoberturaStockPrescriptivaSection> createState() =>
      _CoberturaStockPrescriptivaSectionState();
}

class _CoberturaStockPrescriptivaSectionState
    extends State<CoberturaStockPrescriptivaSection> {
  HorizontePrediccion _horizonte = HorizontePrediccion.semanal;

  static const Color _colorMotor = Color(0xFF004C89);
  static const Color _colorCaja = Color(0xFF0284C7);

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('section_cobertura_stock_prescriptiva'),
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
                    color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.inventory_2_rounded,
                    color: Color(0xFFB91C1C),
                    size: 18,
                  ),
                ),
                const Text(
                  'Alertas Prescriptivas de Cobertura y Adquisición',
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
                  ? 'Balance neto semanal (T+1) entre stock en vitrina, reservas activas y piezas en Paletizado/En Desarme por sucursal para compra en remates'
                  : 'Balance neto acumulado (4 semanas) entre stock en vitrina, reservas activas y piezas en Paletizado/En Desarme para planificación de flota',
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
            key: const Key('btn_cobertura_horizonte_semanal'),
            label: 'Vista Semanal',
            selected: esSemanal,
            onTap: () {
              if (!esSemanal) {
                setState(() => _horizonte = HorizontePrediccion.semanal);
              }
            },
          ),
          _buildHorizonteButton(
            key: const Key('btn_cobertura_horizonte_mensual'),
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
    final itemsCriticos = pred.coberturaStockCritico
        .where((e) => e.idCategoria == 1 || e.idCategoria == 2)
        .toList()
      ..sort((a, b) => a.idCategoria.compareTo(b.idCategoria));

    if (itemsCriticos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Sin datos de cobertura para categorías críticas.',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 820;
        const spacing = 16.0;
        final columns = isWide && itemsCriticos.length >= 2 ? 2 : 1;
        final cardWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: itemsCriticos
              .map(
                (item) => SizedBox(
                  width: cardWidth,
                  child: _buildCategoriaCard(item, esSemanal),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildCategoriaCard(
    CoberturaStockCriticoItemModel item,
    bool esSemanal,
  ) {
    final esMotor = item.idCategoria == 1;
    final accentColor = esMotor ? _colorMotor : _colorCaja;
    final iconData = esMotor
        ? Icons.settings_suggest_rounded
        : Icons.tune_rounded;

    final demandaEntera = esSemanal
        ? item.demandaPredichaSemanal.ceil()
        : item.demandaPredichaMensual4Sem.ceil();
    final requerimientoTotal = esSemanal
        ? item.requerimientoTotal
        : item.requerimientoTotalMensual4Sem;
    final balanceNeto = esSemanal
        ? item.balanceUnidades
        : item.balanceUnidadesMensual4Sem;
    final deficitCompra = esSemanal
        ? item.deficitNetoCompra
        : item.deficitNetoCompraMensual4Sem;
    final estadoRaw = esSemanal
        ? item.estadoAlerta
        : item.estadoAlertaMensual4Sem;
    final recomendacionRaw = esSemanal
        ? item.recomendacionAccionable
        : item.recomendacionAccionableMensual4Sem;

    final estilo = _resolveSemaforoStyle(estadoRaw, balanceNeto);
    final recomendacionTexto = recomendacionRaw.trim().isNotEmpty
        ? recomendacionRaw
        : _buildFallbackRecomendacion(
            item: item,
            estado: estilo.label,
            balanceNeto: balanceNeto,
            deficitCompra: deficitCompra,
          );

    final balanceTexto = balanceNeto > 0 ? '+$balanceNeto unid' : '$balanceNeto unid';

    return Container(
      key: Key('card_cobertura_prescriptiva_${item.idCategoria}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado categoría + Semáforo
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(iconData, size: 17, color: accentColor),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      item.categoria.isNotEmpty
                          ? item.categoria
                          : (esMotor ? 'Motor' : 'Caja de Cambios'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                _buildSemaforoBadge(
                  key: Key('badge_semaforo_cat_${item.idCategoria}'),
                  estilo: estilo,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Tabla / Desglose de Balance Neto
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMetricRow(
                  label: "Stock Disponible ('Disponible')",
                  value: '${item.stockDisponibleTasado} unid',
                  subtext:
                      'Viña del Mar: ${item.stockDisponibleVina} · Limache: ${item.stockDisponibleLimache}',
                  valueColor: const Color(0xFF0F172A),
                ),
                const Divider(height: 16, color: Color(0xFFF1F5F9)),
                _buildMetricRow(
                  label: "Stock en Proceso ('Paletizado' + 'En Desarme')",
                  value: '${item.stockEnProcesoInterno} unid',
                  subtext:
                      'Paletizado: ${item.stockPaletizadoSinTasar} · En Desarme: ${item.stockEnDesarme} | '
                      'Viña del Mar: ${item.stockProcesoVina} · Limache: ${item.stockProcesoLimache}',
                  valueColor: const Color(0xFF334155),
                ),
                const Divider(height: 16, color: Color(0xFFF1F5F9)),
                _buildMetricRow(
                  label: 'Backorders Pendientes',
                  value: '${item.backordersPendientes} unid',
                  valueColor: const Color(0xFF475569),
                ),
                const SizedBox(height: 8),
                _buildMetricRow(
                  label: esSemanal
                      ? 'Demanda Proyectada IA (T+1)'
                      : 'Demanda Proyectada IA (4 sem.)',
                  value: '$demandaEntera unid',
                  subtext: 'Requerimiento total c/ backorders: $requerimientoTotal unid',
                  valueColor: accentColor,
                ),
                const Divider(height: 18, color: Color(0xFFE2E8F0)),
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      const Text(
                        'Balance Neto en Vitrina',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            key: Key('txt_balance_neto_cat_${item.idCategoria}'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: estilo.bgColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: estilo.borderColor),
                            ),
                            child: Text(
                              balanceTexto,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: estilo.textColor,
                              ),
                            ),
                          ),
                          if (esSemanal) ...[
                            const SizedBox(width: 8),
                            Text(
                              '(${item.semanasCobertura.toStringAsFixed(1)} sem.)',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Banner de Recomendación Prescriptiva Accionable
          Container(
            key: Key('banner_recomendacion_cat_${item.idCategoria}'),
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: estilo.bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: estilo.borderColor),
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
                    runSpacing: 6,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            estilo.actionIcon,
                            size: 16,
                            color: estilo.textColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Recomendación Prescriptiva',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: estilo.textColor,
                            ),
                          ),
                        ],
                      ),
                      if (deficitCompra > 0)
                        Container(
                          key: Key('badge_compra_remate_cat_${item.idCategoria}'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: estilo.borderColor),
                          ),
                          child: Text(
                            'Adquirir en remates: $deficitCompra unid',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: estilo.textColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  recomendacionTexto,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.38,
                    fontWeight: FontWeight.w600,
                    color: estilo.textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow({
    required String label,
    required String value,
    String? subtext,
    required Color valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 2,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
        if (subtext != null && subtext.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            subtext,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSemaforoBadge({
    required Key key,
    required _SemaforoStyle estilo,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: estilo.bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: estilo.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: estilo.dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            estilo.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: estilo.textColor,
            ),
          ),
        ],
      ),
    );
  }

  _SemaforoStyle _resolveSemaforoStyle(String estadoRaw, int balanceNeto) {
    final norm = estadoRaw.trim().toLowerCase();
    if (norm.contains('déficit') ||
        norm.contains('deficit') ||
        norm.contains('crítico') ||
        norm.contains('critico')) {
      return const _SemaforoStyle(
        label: 'Déficit Crítico',
        dotColor: Color(0xFFDC2626),
        textColor: Color(0xFF991B1B),
        bgColor: Color(0xFFFEF2F2),
        borderColor: Color(0xFFFECACA),
        actionIcon: Icons.gavel_rounded,
      );
    }
    if (norm.contains('atención') ||
        norm.contains('atencion') ||
        norm.contains('proceso') ||
        norm.contains('quiebre')) {
      return const _SemaforoStyle(
        label: 'Atención / En Proceso',
        dotColor: Color(0xFFD97706),
        textColor: Color(0xFF92400E),
        bgColor: Color(0xFFFFFBEB),
        borderColor: Color(0xFFFDE68A),
        actionIcon: Icons.handyman_rounded,
      );
    }
    if (balanceNeto < 0) {
      return const _SemaforoStyle(
        label: 'Atención / En Proceso',
        dotColor: Color(0xFFD97706),
        textColor: Color(0xFF92400E),
        bgColor: Color(0xFFFFFBEB),
        borderColor: Color(0xFFFDE68A),
        actionIcon: Icons.handyman_rounded,
      );
    }
    return const _SemaforoStyle(
      label: 'Cobertura Óptima',
      dotColor: Color(0xFF059669),
      textColor: Color(0xFF065F46),
      bgColor: Color(0xFFECFDF5),
      borderColor: Color(0xFFA7F3D0),
      actionIcon: Icons.verified_rounded,
    );
  }

  String _buildFallbackRecomendacion({
    required CoberturaStockCriticoItemModel item,
    required String estado,
    required int balanceNeto,
    required int deficitCompra,
  }) {
    if (estado == 'Cobertura Óptima') {
      return 'Cobertura óptima: superávit de +$balanceNeto unidades disponibles en vitrina para cubrir la demanda proyectada y reservas activas.';
    }
    if (estado == 'Atención / En Proceso') {
      return 'Atención: faltan ${balanceNeto.abs()} unidades disponibles en vitrina, pero existen ${item.stockEnProcesoInterno} activos en estado Paletizado/En Desarme (${item.stockProcesoVina} en Viña del Mar, ${item.stockProcesoLimache} en Limache). Se sugiere priorizar su tasación y preparación.';
    }
    return 'Déficit crítico proyectado de ${balanceNeto.abs()} unidades. Existen ${item.stockEnProcesoInterno} activos en Paletizado/En Desarme (${item.stockProcesoVina} en Viña del Mar, ${item.stockProcesoLimache} en Limache); se sugiere priorizar su liberación y adquirir/desarmar $deficitCompra unidades adicionales en remates.';
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
          Flexible(
            child: Text(
              'Evaluando cobertura y alertas prescriptivas...',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
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
                  'No fue posible cargar las alertas de cobertura prescriptiva.',
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

class _SemaforoStyle {
  final String label;
  final Color dotColor;
  final Color textColor;
  final Color bgColor;
  final Color borderColor;
  final IconData actionIcon;

  const _SemaforoStyle({
    required this.label,
    required this.dotColor,
    required this.textColor,
    required this.bgColor,
    required this.borderColor,
    required this.actionIcon,
  });
}
