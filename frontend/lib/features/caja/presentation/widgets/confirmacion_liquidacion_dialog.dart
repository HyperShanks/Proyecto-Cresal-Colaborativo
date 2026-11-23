import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../models/cobro_model.dart';
import '../../models/cobro_pendiente_model.dart';
import 'cobro_pendiente_card.dart';

/// Diálogo modal de confirmación preventiva (Poka-Yoke) para todos los cobros en ventanilla:
/// ventas nuevas, abonos iniciales o adicionales, liquidaciones totales y ventas en verde (backorders).
/// Exige validación consciente mediante casilla de verificación antes de impactar la base de datos.
class ConfirmacionLiquidacionDialog extends StatefulWidget {
  final CobroPendienteModel orden;
  final int montoALiquidar;
  final List<TransaccionPagoItemModel> pagos;
  final bool? esLiquidacion;
  final int? saldoPendienteActual;

  const ConfirmacionLiquidacionDialog({
    super.key,
    required this.orden,
    required this.montoALiquidar,
    this.pagos = const [],
    this.esLiquidacion,
    this.saldoPendienteActual,
  });

  static Future<bool> show({
    required BuildContext context,
    required CobroPendienteModel orden,
    required int montoALiquidar,
    List<TransaccionPagoItemModel> pagos = const [],
    bool? esLiquidacion,
    int? saldoPendienteActual,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ConfirmacionLiquidacionDialog(
        orden: orden,
        montoALiquidar: montoALiquidar,
        pagos: pagos,
        esLiquidacion: esLiquidacion,
        saldoPendienteActual: saldoPendienteActual,
      ),
    );
    return result ?? false;
  }

  @override
  State<ConfirmacionLiquidacionDialog> createState() =>
      _ConfirmacionLiquidacionDialogState();
}

class _ConfirmacionLiquidacionDialogState
    extends State<ConfirmacionLiquidacionDialog> {
  bool _confirmado = false;

  _DialogVisualConfig _resolverConfiguracion(
    CobroPendienteModel orden,
    bool esLiquidacionTotal,
    bool tieneAbonosPrevios,
  ) {
    if (orden.esBackorder) {
      if (esLiquidacionTotal) {
        return _DialogVisualConfig(
          badgeLabel: 'VENTA EN VERDE • LIQUIDACIÓN TOTAL',
          titulo: 'Confirmar Liquidación Venta en Verde',
          subtitulo: tieneAbonosPrevios
              ? 'Estás a punto de saldar el total restante de esta Venta en Verde.\nLa asignación del repuesto quedará a cargo de ventas y bodega.'
              : 'Vas a cobrar el 100% de esta Venta en Verde (Backorder).\nLa asignación física del repuesto quedará pendiente hasta su arribo.',
          textoCheckbox:
              'Confirmo que el cliente liquida el 100% de esta Venta en Verde.',
          icono: Icons.directions_boat_filled_outlined,
          accentColor: const Color(0xFF4338CA),
          accentBg: const Color(0xFFEEF2FF),
          accentBorder: const Color(0xFFC7D2FE),
        );
      }
      return _DialogVisualConfig(
        badgeLabel: tieneAbonosPrevios
            ? 'VENTA EN VERDE • ABONO ADICIONAL'
            : 'VENTA EN VERDE • SEÑA INICIAL',
        titulo: tieneAbonosPrevios
            ? 'Confirmar Abono a Venta en Verde'
            : 'Confirmar Seña de Venta en Verde',
        subtitulo: tieneAbonosPrevios
            ? 'Registrarás un abono adicional para esta Venta en Verde.\nLa reserva continuará activa con el saldo actualizado.'
            : 'Registrarás la seña inicial de esta Venta en Verde (Backorder).\nEl saldo restante se cobrará en una operación posterior.',
        textoCheckbox:
            'Confirmo que recibí este abono parcial para la Venta en Verde.',
        icono: Icons.savings_rounded,
        accentColor: const Color(0xFF4338CA),
        accentBg: const Color(0xFFEEF2FF),
        accentBorder: const Color(0xFFC7D2FE),
      );
    }

    if (esLiquidacionTotal) {
      if (tieneAbonosPrevios) {
        return _DialogVisualConfig(
          badgeLabel: 'VENTA EN TIENDA • LIQUIDACIÓN FINAL',
          titulo: 'Confirmar Liquidación Total',
          subtitulo:
              'Estás a punto de liquidar el total de la orden.\n¿Estás seguro que no es un abono?',
          textoCheckbox:
              'Confirmo que el cliente cancela la totalidad de la orden y no un abono.',
          icono: Icons.warning_amber_rounded,
          accentColor: AppPalette.warningText,
          accentBg: AppPalette.warningBg,
          accentBorder: AppPalette.warningBorder,
        );
      }
      return _DialogVisualConfig(
        badgeLabel: 'VENTA NUEVA • COBRO TOTAL (100%)',
        titulo: 'Confirmar Cobro Total',
        subtitulo:
            'Vas a cobrar el 100% de esta venta nueva en ventanilla.\nVerifica los montos y medios de pago antes de emitir el comprobante.',
        textoCheckbox:
            'Confirmo que recibí el pago completo por los métodos indicados.',
        icono: Icons.fact_check_rounded,
        accentColor: AppPalette.warningText,
        accentBg: AppPalette.warningBg,
        accentBorder: AppPalette.warningBorder,
      );
    }

    return _DialogVisualConfig(
      badgeLabel: tieneAbonosPrevios
          ? 'VENTA EN TIENDA • ABONO ADICIONAL'
          : 'VENTA NUEVA • PRIMER ABONO',
      titulo: tieneAbonosPrevios
          ? 'Confirmar Abono Adicional'
          : 'Confirmar Primer Abono',
      subtitulo: tieneAbonosPrevios
          ? 'Registrarás un abono parcial adicional sobre esta orden.\nLa orden seguirá en estado Reservada con saldo pendiente.'
          : 'Registrarás un abono parcial sobre esta orden nueva.\nLa orden quedará en estado Reservada hasta completar el saldo.',
      textoCheckbox:
          'Confirmo que recibí este abono parcial y el saldo pendiente es correcto.',
      icono: Icons.savings_rounded,
      accentColor: const Color(0xFF7E22CE),
      accentBg: const Color(0xFFF3E8FF),
      accentBorder: const Color(0xFFD8B4FE),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orden = widget.orden;
    final monto = widget.montoALiquidar;
    final saldoBase = widget.saldoPendienteActual ??
        (orden.saldoPendiente > 0
            ? orden.saldoPendiente
            : (orden.montoACobrar > 0 ? orden.montoACobrar : orden.totalOperacion));
    final esLiquidacionTotal =
        widget.esLiquidacion ?? (monto >= saldoBase && saldoBase > 0);
    final saldoRestante = (saldoBase - monto).clamp(0, saldoBase);
    final tieneAbonosPrevios =
        orden.abonoPrevio > 0 || orden.historialAbonos.isNotEmpty;
    final pagosActivos =
        widget.pagos.where((p) => p.monto > 0).toList(growable: false);

    final config = _resolverConfiguracion(
      orden,
      esLiquidacionTotal,
      tieneAbonosPrevios,
    );

    return Dialog(
      backgroundColor: AppPalette.surfaceLight,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppPalette.borderLight),
      ),
      elevation: 8,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 1. ÍCONO DE CONTEXTO Y PÍLDORA DE OPERACIÓN ──
              Center(
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: config.accentBg,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: config.accentBorder,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    config.icono,
                    size: 32,
                    color: config.accentColor,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: config.accentBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: config.accentBorder),
                  ),
                  child: Text(
                    config.badgeLabel,
                    style: AppTypography.small.copyWith(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: config.accentColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // ── 2. TÍTULO Y PREGUNTA EXPLÍCITA ──
              Text(
                config.titulo,
                style: AppTypography.title.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppPalette.textPrimaryLight,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                config.subtitulo,
                style: AppTypography.body.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppPalette.textSecondaryLight,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),

              // ── 3. RESUMEN FINANCIERO VISUAL ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppPalette.backgroundLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppPalette.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildFilaResumen(
                      'Orden / Folio:',
                      orden.folioDocumento,
                      isBold: true,
                    ),
                    const SizedBox(height: 8),
                    _buildFilaResumen(
                      'Tipo de Operación:',
                      orden.esBackorder
                          ? 'Venta en Verde (Backorder)'
                          : 'Venta en Tienda',
                    ),
                    const SizedBox(height: 8),
                    _buildFilaResumen('Cliente:', orden.clienteNombre),
                    const SizedBox(height: 8),
                    if (orden.descuento > 0) ...[
                      _buildFilaResumen(
                        'Total Bruto:',
                        CobroPendienteCard.formatClp(orden.totalOperacion),
                      ),
                      const SizedBox(height: 8),
                      _buildFilaResumen(
                        'Descuento Aplicado:',
                        '- ${CobroPendienteCard.formatClp(orden.descuento)}',
                        colorValor: AppPalette.errorText,
                      ),
                    ] else
                      _buildFilaResumen(
                        'Total de la Orden:',
                        CobroPendienteCard.formatClp(orden.totalOperacion),
                      ),
                    if (orden.abonoPrevio > 0) ...[
                      const SizedBox(height: 8),
                      _buildFilaResumen(
                        'Abonos Previos Realizados:',
                        '- ${CobroPendienteCard.formatClp(orden.abonoPrevio)}',
                        colorValor: AppPalette.warningText,
                      ),
                    ],
                    if (pagosActivos.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: AppPalette.borderLight),
                      const SizedBox(height: 10),
                      Text(
                        pagosActivos.length > 1
                            ? 'MEDIOS DE PAGO DIVIDIDOS (${pagosActivos.length})'
                            : 'MEDIO DE PAGO SELECCIONADO',
                        style: AppTypography.small.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppPalette.textSecondaryLight,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...pagosActivos.map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: _buildFilaResumen(
                            '• ${p.metodo}',
                            CobroPendienteCard.formatClp(p.monto),
                            isBold: true,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: AppPalette.borderLight),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            esLiquidacionTotal
                                ? 'Monto a Liquidar Ahora:'
                                : 'Monto del Abono Ahora:',
                            style: AppTypography.small.copyWith(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: AppPalette.textPrimaryLight,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          CobroPendienteCard.formatClp(monto),
                          style: AppTypography.title.copyWith(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: AppPalette.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Badge de saldo restante
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: esLiquidacionTotal
                            ? AppPalette.successBg
                            : AppPalette.warningBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: esLiquidacionTotal
                              ? AppPalette.successBorder
                              : AppPalette.warningBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            esLiquidacionTotal
                                ? Icons.check_circle_outline_rounded
                                : Icons.pending_actions_rounded,
                            size: 18,
                            color: esLiquidacionTotal
                                ? AppPalette.success
                                : AppPalette.warningText,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              esLiquidacionTotal
                                  ? (orden.esBackorder
                                      ? 'Saldo restante tras este pago: \$0 CLP (Venta en Verde Saldada)'
                                      : 'Saldo restante tras este pago: \$0 CLP (Orden Saldada)')
                                  : 'Saldo restante tras este abono: ${CobroPendienteCard.formatClp(saldoRestante)} CLP (Queda en Reservada)',
                              style: AppTypography.small.copyWith(
                                color: esLiquidacionTotal
                                    ? AppPalette.successText
                                    : AppPalette.warningText,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                height: 1.25,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ── 4. CASILLA DE VERIFICACIÓN (CHECKBOX) ──
              InkWell(
                onTap: () {
                  setState(() {
                    _confirmado = !_confirmado;
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _confirmado
                        ? AppPalette.successBg
                        : AppPalette.backgroundLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _confirmado
                          ? AppPalette.successBorder
                          : AppPalette.borderLight,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Checkbox(
                        value: _confirmado,
                        activeColor: AppPalette.success,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _confirmado = val ?? false;
                          });
                        },
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          config.textoCheckbox,
                          style: AppTypography.body.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppPalette.textPrimaryLight,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // ── 5. BOTONES DE ACCIÓN (TAMAÑO IDÉNTICO Y ANTI-OVERFLOW) ──
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          foregroundColor: AppPalette.textPrimaryLight,
                          side: const BorderSide(color: AppPalette.borderLight),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(false),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Cancelar / Volver',
                            style: AppTypography.button.copyWith(
                              color: AppPalette.textPrimaryLight,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          backgroundColor: _confirmado
                              ? AppPalette.success
                              : AppPalette.disabled,
                          foregroundColor: _confirmado
                              ? Colors.white
                              : AppPalette.disabledText,
                          disabledBackgroundColor: AppPalette.disabled,
                          disabledForegroundColor: AppPalette.disabledText,
                          elevation: _confirmado ? 2 : 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _confirmado
                            ? () => Navigator.of(context).pop(true)
                            : null,
                        icon: const Icon(Icons.check_circle_rounded, size: 18),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Confirmar',
                            style: AppTypography.button.copyWith(
                              color: _confirmado
                                  ? Colors.white
                                  : AppPalette.disabledText,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilaResumen(
    String label,
    String valor, {
    bool isBold = false,
    Color? colorValor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.small.copyWith(
              fontSize: 13.5,
              color: AppPalette.textSecondaryLight,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            valor,
            textAlign: TextAlign.right,
            style: AppTypography.small.copyWith(
              fontSize: 13.5,
              color: colorValor ?? AppPalette.textPrimaryLight,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}

class _DialogVisualConfig {
  final String badgeLabel;
  final String titulo;
  final String subtitulo;
  final String textoCheckbox;
  final IconData icono;
  final Color accentColor;
  final Color accentBg;
  final Color accentBorder;

  const _DialogVisualConfig({
    required this.badgeLabel,
    required this.titulo,
    required this.subtitulo,
    required this.textoCheckbox,
    required this.icono,
    required this.accentColor,
    required this.accentBg,
    required this.accentBorder,
  });
}
