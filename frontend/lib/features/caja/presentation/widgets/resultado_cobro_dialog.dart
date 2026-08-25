import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../models/cobro_model.dart';
import '../../models/cobro_pendiente_model.dart';
import 'cobro_pendiente_card.dart';

/// Diálogo modal de confirmación financiera tras registrar un cobro (SPEC-HU-04 / CRES-215).
/// Adaptado 1:1 de prototipo_caja_sprint4.html con Material Icons nativos y AppPalette.
/// Cumple la restricción estricta de NO renderizar imágenes gráficas de código QR en pantalla.
class ResultadoCobroDialog extends StatelessWidget {
  final CobroPendienteModel orden;
  final RegistrarCobroResponseModel resultado;
  final String metodosResumen;
  final VoidCallback onSiguienteOrden;

  const ResultadoCobroDialog({
    super.key,
    required this.orden,
    required this.resultado,
    required this.metodosResumen,
    required this.onSiguienteOrden,
  });

  @override
  Widget build(BuildContext context) {
    final emiteQr = resultado.qrGenerado != null;
    final esAbono = !emiteQr;

    return Dialog(
      backgroundColor: AppPalette.surfaceLight,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppPalette.borderLight),
      ),
      elevation: 12,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── 1. Círculo de Estado ─────────────────────────────────────────
              _buildStatusCircle(emiteQr),

              const SizedBox(height: 16),

              // ── 2. Título y Subtítulo Adaptativo ───────────────────────────
              _buildTitleAndSubtitle(emiteQr),

              const SizedBox(height: 20),

              // ── 3. Tarjeta Resumen Financiero ──────────────────────────────
              _buildFinancialSummaryCard(emiteQr, esAbono),

              const SizedBox(height: 16),

              // ── 4. Recuadro de Instrucción Operativa ───────────────────────
              _buildOperationalInstructionBox(emiteQr),

              const SizedBox(height: 24),

              // ── 5. Botón de Acción Principal (Siguiente Orden) ─────────────
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.primary,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: onSiguienteOrden,
                  child: Text(
                    'Siguiente Orden',
                    style: AppTypography.button.copyWith(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCircle(bool emiteQr) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: emiteQr ? AppPalette.successBg : AppPalette.primary.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(
          color: emiteQr ? AppPalette.successBorder : AppPalette.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Icon(
        emiteQr ? Icons.check_circle_rounded : Icons.receipt_long_rounded,
        size: 36,
        color: emiteQr ? AppPalette.success : AppPalette.primary,
      ),
    );
  }

  Widget _buildTitleAndSubtitle(bool emiteQr) {
    return Column(
      children: [
        Text(
          emiteQr ? 'Pago Registrado Exitosamente' : 'Comprobante de Abono Registrado',
          style: AppTypography.title.copyWith(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            color: AppPalette.textPrimaryLight,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          emiteQr
              ? 'QR Transaccional generado para barrera de salida'
              : 'Abono procesado correctamente • Sin emisión de QR',
          style: AppTypography.body.copyWith(
            color: emiteQr ? AppPalette.success : AppPalette.primary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFinancialSummaryCard(bool emiteQr, bool esAbono) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.borderLight),
      ),
      child: Column(
        children: [
          // Fila 1: Folio y Cliente
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    orden.esBackorder ? 'FOLIO RESERVA' : 'FOLIO ORDEN',
                    style: AppTypography.small.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.textSecondaryLight,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    resultado.folio,
                    style: AppTypography.title.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppPalette.primary,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'CLIENTE',
                      style: AppTypography.small.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.textSecondaryLight,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      orden.clienteNombre,
                      style: AppTypography.body.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.textPrimaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                    Text(
                      'RUT: ${orden.clienteRut}',
                      style: AppTypography.small.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppPalette.textSecondaryLight,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: AppPalette.borderLight, height: 1),
          ),

          // Fila 2: Monto Liquidado y Métodos
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    emiteQr ? 'MONTO TOTAL PAGADO' : 'ABONO INGRESADO',
                    style: AppTypography.small.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.textSecondaryLight,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    CobroPendienteCard.formatClp(resultado.montoCobrado),
                    style: AppTypography.title.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppPalette.textPrimaryLight,
                    ),
                  ),
                ],
              ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppPalette.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppPalette.borderLight),
                  ),
                  child: Text(
                    metodosResumen.isNotEmpty ? metodosResumen : 'Efectivo',
                    style: AppTypography.small.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.textPrimaryLight,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
              ),
            ],
          ),

          // Fila 3: Si es Abono, mostrar Nuevo Saldo Pendiente
          if (esAbono || resultado.nuevoSaldoPendiente > 0) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(color: AppPalette.borderLight, height: 1),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'NUEVO SALDO PENDIENTE:',
                    style: AppTypography.small.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.textSecondaryLight,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Text(
                  CobroPendienteCard.formatClp(resultado.nuevoSaldoPendiente),
                  style: AppTypography.title.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppPalette.primary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOperationalInstructionBox(bool emiteQr) {
    final bgColor = emiteQr ? AppPalette.surfaceLight : AppPalette.warningBg;
    final borderColor = emiteQr ? AppPalette.borderLight : AppPalette.warningBorder;
    final headerTextColor = emiteQr ? AppPalette.textPrimaryLight : AppPalette.warningText;
    final iconColor = emiteQr ? AppPalette.primary : AppPalette.warningText;
    final bodyTextColor = emiteQr ? AppPalette.textSecondaryLight : AppPalette.warningText;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                emiteQr ? Icons.info_outline_rounded : Icons.warning_amber_rounded,
                size: 16,
                color: iconColor,
              ),
              const SizedBox(width: 6),
              Text(
                'Instrucción Operativa:',
                style: AppTypography.body.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: headerTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            emiteQr
                ? 'Derive al cliente al Mesón de Venta para la entrega física de sus piezas y repuestos.'
                : 'Entregue comprobante de abono al cliente. La orden queda retenida en estado \'Reservada\' / Confirmada sin código QR de salida hasta la liquidación final o arribo a bodega.',
            style: AppTypography.small.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: bodyTextColor,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
