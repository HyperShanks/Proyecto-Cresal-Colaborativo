import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../models/historial_caja_model.dart';
import 'cobro_pendiente_card.dart';

/// Tabla estructurada para la visualización del historial y auditoría de órdenes de caja (SPEC-HU-4.5).
class HistorialTablaView extends StatelessWidget {
  final List<HistorialOrdenItemModel> items;
  final int paginaActual;
  final int totalPaginas;
  final ValueChanged<int> onCambiarPagina;
  final ValueChanged<HistorialOrdenItemModel> onVerDetalle;

  const HistorialTablaView({
    super.key,
    required this.items,
    required this.paginaActual,
    required this.totalPaginas,
    required this.onCambiarPagina,
    required this.onVerDetalle,
  });

  Color _getEstadoColor(String estado) {
    switch (estado.toLowerCase()) {
      case 'pagada':
        return AppPalette.success;
      case 'despachada':
        return const Color(0xFF0284C7);
      case 'reservada':
      case 'pendiente':
        return AppPalette.secondary;
      case 'anulada':
        return AppPalette.error;
      default:
        return AppPalette.textSecondaryLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppPalette.neutral.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // ── CABECERA DE LA TABLA ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppPalette.backgroundLight,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
              border: Border(
                bottom: BorderSide(
                  color: AppPalette.neutral.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                _buildHeaderCell('FOLIO', flex: 2),
                _buildHeaderCell('FECHA / HORA', flex: 2),
                _buildHeaderCell('CLIENTE / RUT', flex: 3),
                _buildHeaderCell('VENDEDOR / CAJERA', flex: 3),
                _buildHeaderCell('ESTADO', flex: 2),
                _buildHeaderCell('MÉTODOS DE PAGO', flex: 3),
                _buildHeaderCell('TOTAL', flex: 2, alignment: Alignment.centerRight),
                _buildHeaderCell('AUDITORÍA', flex: 2, alignment: Alignment.center),
              ],
            ),
          ),

          // ── FILAS DE DATOS ──
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: AppPalette.neutral.withValues(alpha: 0.1),
              ),
              itemBuilder: (context, index) {
                final item = items[index];
                final estadoColor = _getEstadoColor(item.estadoOrden);

                return InkWell(
                  onTap: () => onVerDetalle(item),
                  hoverColor: AppPalette.primary.withValues(alpha: 0.03),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        // Folio + QR indicator
                        Expanded(
                          flex: 2,
                          child: Row(
                            children: [
                              Text(
                                item.folio,
                                style: AppTypography.body.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppPalette.textPrimaryLight,
                                  fontSize: 13,
                                ),
                              ),
                              if (item.emiteQr) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.qr_code_2_rounded,
                                  size: 14,
                                  color: AppPalette.primary,
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Fecha / Hora
                        Expanded(
                          flex: 2,
                          child: Text(
                            item.fechaHoraFormateada,
                            style: AppTypography.small.copyWith(
                              color: AppPalette.textSecondaryLight,
                              fontSize: 12,
                            ),
                          ),
                        ),

                        // Cliente / RUT
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.clienteNombre,
                                style: AppTypography.small.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppPalette.textPrimaryLight,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (item.clienteRut != null)
                                Text(
                                  item.clienteRut!,
                                  style: AppTypography.small.copyWith(
                                    color: AppPalette.textSecondaryLight,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Vendedor / Cajera
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Vend: ${item.vendedorNombre}',
                                style: AppTypography.small.copyWith(
                                  color: AppPalette.textPrimaryLight,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Caja: ${item.cajeraNombre}',
                                style: AppTypography.small.copyWith(
                                  color: AppPalette.textSecondaryLight,
                                  fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // Estado Badge
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: estadoColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: estadoColor.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                item.estadoOrden,
                                style: AppTypography.small.copyWith(
                                  color: estadoColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Métodos de Pago
                        Expanded(
                          flex: 3,
                          child: Text(
                            item.metodosResumen,
                            style: AppTypography.small.copyWith(
                              color: AppPalette.textSecondaryLight,
                              fontSize: 11,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Total
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              CobroPendienteCard.formatClp(item.totalLiquidado),
                              style: AppTypography.body.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: item.esAnulada
                                    ? AppPalette.textSecondaryLight
                                    : AppPalette.textPrimaryLight,
                              ),
                            ),
                          ),
                        ),

                        // Acciones: Botón "Ver Detalle"
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.center,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                side: BorderSide(
                                  color: AppPalette.primary.withValues(alpha: 0.5),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              icon: const Icon(
                                Icons.visibility_rounded,
                                size: 13,
                                color: AppPalette.primary,
                              ),
                              label: Text(
                                'Ver Detalle',
                                style: AppTypography.small.copyWith(
                                  color: AppPalette.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                              onPressed: () => onVerDetalle(item),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ── BARRA DE PAGINACIÓN INFERIOR ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppPalette.backgroundLight,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(11),
                bottomRight: Radius.circular(11),
              ),
              border: Border(
                top: BorderSide(
                  color: AppPalette.neutral.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mostrando página $paginaActual de $totalPaginas (${items.length} registros en esta página)',
                  style: AppTypography.small.copyWith(
                    color: AppPalette.textSecondaryLight,
                    fontSize: 12,
                  ),
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        side: BorderSide(
                          color: AppPalette.neutral.withValues(alpha: 0.3),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      icon: const Icon(Icons.chevron_left_rounded, size: 18),
                      label: const Text('Anterior'),
                      onPressed: paginaActual > 1
                          ? () => onCambiarPagina(paginaActual - 1)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        side: BorderSide(
                          color: AppPalette.neutral.withValues(alpha: 0.3),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      icon: const Icon(Icons.chevron_right_rounded, size: 18),
                      label: const Text('Siguiente'),
                      onPressed: paginaActual < totalPaginas
                          ? () => onCambiarPagina(paginaActual + 1)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String label, {required int flex, Alignment alignment = Alignment.centerLeft}) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment: alignment,
        child: Text(
          label,
          style: AppTypography.small.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 11,
            color: AppPalette.textSecondaryLight,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}
