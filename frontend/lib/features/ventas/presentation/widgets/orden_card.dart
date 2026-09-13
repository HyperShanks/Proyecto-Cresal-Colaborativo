import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../services/ordenes_service.dart';
import 'qr_ticket_dialog.dart';

/// Tarjeta de orden de venta en Flat Design estricto (HU-3.5).
/// Muestra el folio, badge de estado con colores semánticos, cliente, fecha y total.
class OrdenCard extends StatelessWidget {
  final OrdenHistorialModel orden;
  final VoidCallback? onTap;

  const OrdenCard({
    super.key,
    required this.orden,
    this.onTap,
  });

  Widget _buildStatusBadge() {
    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData icon;
    String label = orden.estadoOrden;

    if (orden.esReservada) {
      bgColor = AppPalette.secondary.withValues(alpha: 0.15);
      borderColor = AppPalette.secondary.withValues(alpha: 0.5);
      textColor = AppPalette.secondary;
      icon = Icons.schedule;
      label = 'Reservada';
    } else if (orden.esPagada) {
      bgColor = AppPalette.success.withValues(alpha: 0.15);
      borderColor = AppPalette.success.withValues(alpha: 0.5);
      textColor = AppPalette.success;
      icon = Icons.check_circle_outline;
      label = 'Pagada';
    } else if (orden.esCompletada) {
      bgColor = AppPalette.primary.withValues(alpha: 0.15);
      borderColor = AppPalette.primary.withValues(alpha: 0.5);
      textColor = AppPalette.primary;
      icon = Icons.verified_outlined;
      label = 'Completada';
    } else if (orden.esAnulada) {
      bgColor = AppPalette.error.withValues(alpha: 0.15);
      borderColor = AppPalette.error.withValues(alpha: 0.5);
      textColor = AppPalette.error;
      icon = Icons.cancel_outlined;
      label = 'Anulada';
    } else {
      bgColor = AppPalette.neutral.withValues(alpha: 0.15);
      borderColor = AppPalette.neutral.withValues(alpha: 0.5);
      textColor = AppPalette.textSecondary;
      icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.0, color: textColor),
          const SizedBox(width: 4.0),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.0,
              fontWeight: FontWeight.w600,
              color: textColor,
              fontFamily: AppTypography.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: orden.esReservada
              ? AppPalette.secondary.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.06),
          width: 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(12.0),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Cabecera: Folio y Badge de Estado ─────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6.0),
                            decoration: BoxDecoration(
                              color: AppPalette.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: const Icon(
                              Icons.receipt_long_outlined,
                              size: 18.0,
                              color: AppPalette.primary,
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          Expanded(
                            child: Text(
                              orden.folioDisplay,
                              style: AppTypography.title.copyWith(
                                fontSize: 16.0,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    _buildStatusBadge(),
                  ],
                ),

                const SizedBox(height: 12.0),
                const Divider(color: Colors.white10, height: 1.0),
                const SizedBox(height: 12.0),

                // ── Datos del Cliente ─────────────────────────────────────
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 16.0,
                      color: AppPalette.textSecondary,
                    ),
                    const SizedBox(width: 6.0),
                    Expanded(
                      child: Text(
                        orden.cliente != null && orden.cliente!.nombres.isNotEmpty
                            ? '${orden.cliente!.nombreCompleto} (${orden.cliente!.rutCliente})'
                            : 'Cliente General',
                        style: AppTypography.body.copyWith(
                          fontSize: 14.0,
                          color: AppPalette.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6.0),

                // ── Fecha / Hora y Cantidad de Ítems ───────────────────────
                Wrap(
                  spacing: 16.0,
                  runSpacing: 4.0,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 15.0,
                          color: AppPalette.textSecondary,
                        ),
                        const SizedBox(width: 6.0),
                        Text(
                          orden.fechaFormateada,
                          style: AppTypography.small.copyWith(
                            fontSize: 13.0,
                            color: AppPalette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.inventory_2_outlined,
                          size: 15.0,
                          color: AppPalette.textSecondary,
                        ),
                        const SizedBox(width: 6.0),
                        Text(
                          '${orden.totalItems} ${orden.totalItems == 1 ? 'ítem' : 'ítems'}',
                          style: AppTypography.small.copyWith(
                            fontSize: 13.0,
                            color: AppPalette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    if (orden.esMixta) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                        decoration: BoxDecoration(
                          color: AppPalette.secondary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4.0),
                          border: Border.all(color: AppPalette.secondary.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          'Mixta: Mesón + Bodega',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: AppPalette.secondary,
                            fontFamily: AppTypography.fontFamily,
                          ),
                        ),
                      ),
                    ] else if (!orden.contieneMotorOCaja) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                        decoration: BoxDecoration(
                          color: AppPalette.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4.0),
                          border: Border.all(color: AppPalette.success.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          'Mesón',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: AppPalette.success,
                            fontFamily: AppTypography.fontFamily,
                          ),
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                        decoration: BoxDecoration(
                          color: AppPalette.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4.0),
                          border: Border.all(color: AppPalette.primary.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          'Bodega',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: AppPalette.primary,
                            fontFamily: AppTypography.fontFamily,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                // ── Indicador de Despacho (si aplica) ─────────────────────
                if (orden.despacho != null) ...[
                  const SizedBox(height: 6.0),
                  Row(
                    children: [
                      const Icon(
                        Icons.local_shipping_outlined,
                        size: 15.0,
                        color: AppPalette.primary,
                      ),
                      const SizedBox(width: 6.0),
                      Expanded(
                        child: Text(
                          'Despacho: ${orden.despacho!.direccionEnvio}',
                          style: AppTypography.small.copyWith(
                            fontSize: 13.0,
                            color: AppPalette.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12.0),
                const Divider(color: Colors.white10, height: 1.0),
                const SizedBox(height: 12.0),

                // ── Pie: Total y Botón Ver Detalle ────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            orden.esAnulada ? 'Total Anulado' : 'Total Orden',
                            style: AppTypography.small.copyWith(
                              fontSize: 12.0,
                              color: AppPalette.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2.0),
                          Text(
                            orden.totalVentaFormateado,
                            style: AppTypography.title.copyWith(
                              fontSize: 18.0,
                              fontWeight: FontWeight.bold,
                              color: orden.esAnulada
                                  ? AppPalette.neutral
                                  : AppPalette.secondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (orden.contieneMotorOCaja) ...[
                          if (orden.tieneQrDisponible) ...[
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppPalette.success,
                                side: BorderSide(
                                  color: AppPalette.success.withValues(alpha: 0.6),
                                  width: 1.0,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                              ),
                              icon: const Icon(Icons.qr_code, size: 15.0),
                              label: const Text(
                                'Ver QR',
                                style: TextStyle(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () => QrTicketDialog.mostrar(context, orden),
                            ),
                            const SizedBox(width: 8.0),
                          ],
                        ] else if (orden.esPagada && !orden.esCompletada) ...[
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppPalette.success,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                            icon: const Icon(Icons.check_circle_outline, size: 15.0),
                            label: const Text(
                              'Entregado',
                              style: TextStyle(
                                fontSize: 12.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () => _confirmarEntregaMeson(context),
                          ),
                          const SizedBox(width: 8.0),
                        ],
                        Text(
                          'Ver detalle',
                          style: AppTypography.small.copyWith(
                            color: AppPalette.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4.0),
                        const Icon(
                          Icons.chevron_right,
                          size: 20.0,
                          color: AppPalette.primary,
                        ),
                      ],
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

  Future<void> _confirmarEntregaMeson(BuildContext context) async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: AppPalette.success, size: 24),
            const SizedBox(width: 8),
            const Text('Confirmar Entrega', style: TextStyle(color: AppPalette.textPrimary)),
          ],
        ),
        content: Text(
          '¿Confirmar la entrega de la orden #${orden.folioDisplay} al cliente?\n\nEsta acción marcará la orden como Completada.',
          style: const TextStyle(color: AppPalette.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCELAR', style: TextStyle(color: AppPalette.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('CONFIRMAR ENTREGA', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await OrdenesService.confirmarEntregaTienda(orden.idOrden);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppPalette.surface,
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: AppPalette.success),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '¡Orden #${orden.folioDisplay} entregada exitosamente!',
                    style: const TextStyle(color: AppPalette.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppPalette.surface,
            content: Text(
              'Error al confirmar entrega: ${e.toString().replaceAll("Exception: ", "")}',
              style: const TextStyle(color: AppPalette.error),
            ),
          ),
        );
      }
    }
  }
}
