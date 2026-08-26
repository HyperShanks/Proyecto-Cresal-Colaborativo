import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../models/cobro_pendiente_model.dart';

/// Tarjeta individual para una orden de venta o reserva backorder en la Bandeja de Cobros.
/// Rediseñada para coincidir 1:1 con el prototipo visual de Caja.
class CobroPendienteCard extends StatelessWidget {
  final CobroPendienteModel orden;
  final bool isSelected;
  final VoidCallback onTap;

  const CobroPendienteCard({
    super.key,
    required this.orden,
    required this.isSelected,
    required this.onTap,
  });

  static String formatClp(int valor) {
    return '\$${valor.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        )}';
  }

  String _calcTiempoRelativo(DateTime fecha) {
    final now = DateTime.now();
    final diff = now.difference(fecha);

    if (diff.inDays > 0) {
      return 'Hace ${diff.inDays} ${diff.inDays == 1 ? "día" : "días"}';
    } else if (diff.inHours > 0) {
      return 'Hace ${diff.inHours} ${diff.inHours == 1 ? "hora" : "horas"}';
    } else if (diff.inMinutes > 0) {
      return 'Hace ${diff.inMinutes} min';
    } else {
      return 'Hace unos instantes';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVenta = orden.esVenta;
    final badgeBg = isVenta
        ? AppPalette.secondary.withValues(alpha: 0.15)
        : const Color(0xFF4F46E5).withValues(alpha: 0.12);
    final badgeBorder = isVenta
        ? AppPalette.secondary.withValues(alpha: 0.5)
        : const Color(0xFF4F46E5).withValues(alpha: 0.4);
    final badgeColor = isVenta
        ? const Color(0xFFB78103)
        : const Color(0xFF4F46E5);
    final badgeText = isVenta ? 'Venta en Tienda' : 'Reserva Backorder';
    final badgeIcon = isVenta
        ? Icons.storefront_rounded
        : Icons.directions_boat_filled_outlined;

    final borderColor = isSelected
        ? AppPalette.primary
        : AppPalette.neutral.withValues(alpha: 0.2);
    final bgColor = isSelected
        ? AppPalette.primary.withValues(alpha: 0.04)
        : AppPalette.surfaceLight;

    final relativeTime = _calcTiempoRelativo(orden.fechaEmision);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? AppPalette.primary.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: isSelected ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          hoverColor: AppPalette.primary.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── FILA 1: Folio + Badge de Tipo ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        orden.folioDocumento,
                        style: AppTypography.title.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppPalette.textPrimaryLight,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: badgeBorder, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(badgeIcon, size: 12, color: badgeColor),
                          const SizedBox(width: 4),
                          Text(
                            badgeText,
                            style: AppTypography.small.copyWith(
                              color: badgeColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // ── FILA 2: Cliente destacado, RUT y Vendedor ──
                Text(
                  orden.clienteNombre,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppPalette.textPrimaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (orden.clienteRut.isNotEmpty) ...[
                      Text(
                        'RUT: ${orden.clienteRut}',
                        style: AppTypography.small.copyWith(
                          color: AppPalette.textSecondaryLight,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        ' • ',
                        style: AppTypography.small.copyWith(
                          color: AppPalette.textSecondaryLight,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    Expanded(
                      child: Text(
                        'Vendedor: ${orden.vendedorNombre}',
                        style: AppTypography.small.copyWith(
                          color: AppPalette.textSecondaryLight,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                // ── FILA 3: Divisor sutil + Fecha/Hora y Tiempo Relativo ──
                Divider(
                  height: 18,
                  color: AppPalette.neutral.withValues(alpha: 0.15),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 13,
                            color: AppPalette.textSecondaryLight,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${orden.fechaEmisionFormateada} • ${orden.horaEmisionFormateada}',
                              style: AppTypography.small.copyWith(
                                color: AppPalette.textSecondaryLight,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppPalette.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: AppPalette.primary.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 13,
                            color: AppPalette.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            relativeTime,
                            style: AppTypography.small.copyWith(
                              color: AppPalette.textPrimaryLight,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ── FILA 4: Saldo a Pagar / Abono Inicial a la izquierda y monto a la derecha ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isVenta
                                ? (orden.abonoPrevio > 0 ? 'Saldo a Pagar:' : 'Total a Pagar:')
                                : 'Abono Inicial:',
                            style: AppTypography.small.copyWith(
                              color: AppPalette.textSecondaryLight,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (orden.abonoPrevio > 0 && isVenta) ...[
                            Text(
                              'Total: ${formatClp(orden.totalOperacion)} (Abono: ${formatClp(orden.abonoPrevio)})',
                              style: AppTypography.small.copyWith(
                                color: AppPalette.textSecondaryLight,
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatClp(orden.montoACobrar),
                      style: AppTypography.title.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isVenta
                            ? AppPalette.success
                            : const Color(0xFF4F46E5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
