import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../models/historial_caja_model.dart';
import 'cobro_pendiente_card.dart';

/// Panel superior de 4 tarjetas con métricas de arqueo y cuadre de caja (SPEC-HU-4.5).
/// Consume AppPalette y AppTypography.
class HistorialMetricasPanel extends StatelessWidget {
  final ResumenCuadreCajaModel resumen;

  const HistorialMetricasPanel({
    super.key,
    required this.resumen,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            // 1. Total Recaudado
            _buildMetricCard(
              icon: Icons.account_balance_wallet_rounded,
              title: 'Total Recaudado',
              value: CobroPendienteCard.formatClp(resumen.totalRecaudado),
              subtitle: '${resumen.totalOrdenesPagadas} órdenes pagadas',
              color: AppPalette.primary,
            ),
            const SizedBox(width: 14),

            // 2. Efectivo en Gaveta
            _buildMetricCard(
              icon: Icons.payments_rounded,
              title: 'Efectivo en Gaveta',
              value: CobroPendienteCard.formatClp(resumen.totalEfectivo),
              subtitle: 'Arqueo físico disponible',
              color: AppPalette.success,
            ),
            const SizedBox(width: 14),

            // 3. Total POS / Tarjetas
            _buildMetricCard(
              icon: Icons.credit_card_rounded,
              title: 'Total Tarjetas POS',
              value: CobroPendienteCard.formatClp(resumen.totalPos),
              subtitle:
                  'Déb: ${CobroPendienteCard.formatClp(resumen.totalDebito)} • Créd: ${CobroPendienteCard.formatClp(resumen.totalCredito)}',
              color: const Color(0xFF4F46E5),
            ),
            const SizedBox(width: 14),

            // 4. Transferencias y Cheques
            _buildMetricCard(
              icon: Icons.swap_horiz_rounded,
              title: 'Transferencias / Cheques',
              value: CobroPendienteCard.formatClp(
                resumen.totalTransferencia + resumen.totalCheque,
              ),
              subtitle:
                  'Transf: ${CobroPendienteCard.formatClp(resumen.totalTransferencia)} • Chq: ${CobroPendienteCard.formatClp(resumen.totalCheque)}',
              color: AppPalette.secondary,
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppPalette.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppPalette.neutral.withValues(alpha: 0.18),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTypography.cardTitle.copyWith(
                      color: AppPalette.textSecondaryLight,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: AppTypography.title.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppPalette.textPrimaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.small.copyWith(
                      color: AppPalette.textSecondaryLight,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
