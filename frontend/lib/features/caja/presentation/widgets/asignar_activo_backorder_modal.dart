import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../models/cobro_model.dart';
import '../../models/cobro_pendiente_model.dart';
import '../providers/caja_provider.dart';
import 'cobro_pendiente_card.dart';

/// Modal interactivo de asignación de activo físico para Ventas en Verde.
/// Se dispara de forma atómica antes de procesar el pago cuando el cliente
/// liquida el 100% del saldo de una reserva backorder.
class AsignarActivoBackorderModal extends StatefulWidget {
  final CobroPendienteModel orden;
  final CajaProvider provider;
  final int montoALiquidar;
  final Future<void> Function(String sku, bool forzar) onConfirmar;

  const AsignarActivoBackorderModal({
    super.key,
    required this.orden,
    required this.provider,
    required this.montoALiquidar,
    required this.onConfirmar,
  });

  @override
  State<AsignarActivoBackorderModal> createState() =>
      _AsignarActivoBackorderModalState();
}

class _AsignarActivoBackorderModalState
    extends State<AsignarActivoBackorderModal> {
  late final TextEditingController _skuController;
  int _intentosFallidosSku = 0;
  bool _isConfirmando = false;

  @override
  void initState() {
    super.initState();
    _skuController = TextEditingController(
      text: widget.provider.skuActivoAtribuido ?? '',
    );
  }

  @override
  void dispose() {
    _skuController.dispose();
    super.dispose();
  }

  Future<void> _ejecutarValidacionSku() async {
    final sku = _skuController.text.trim();
    if (sku.isEmpty) return;
    await widget.provider.validarActivoBackorder(sku);
    final res = widget.provider.validacionActivo;
    if (res != null && !res.coincide) {
      setState(() {
        _intentosFallidosSku++;
      });
    }
  }

  Future<void> _confirmarAtribucion() async {
    final sku = _skuController.text.trim();
    if (sku.isEmpty) return;

    setState(() {
      _isConfirmando = true;
    });

    try {
      await widget.onConfirmar(sku, widget.provider.forzarAtribucion);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConfirmando = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppPalette.error,
            content: Text(
              'Error al confirmar atribución: ${e.toString().replaceAll("Exception: ", "")}',
              style: AppTypography.body.copyWith(color: Colors.white),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.provider,
      builder: (context, _) {
        final validacion = widget.provider.validacionActivo;
        final isRevisando = widget.provider.isRevisandoActivo;
        final atribuido = widget.provider.skuActivoAtribuido != null;
        final forzar = widget.provider.forzarAtribucion;
        final coincide = validacion?.coincide == true;
        final puedeConfirmar = (coincide || forzar) &&
            !isRevisando &&
            !_isConfirmando &&
            _skuController.text.trim().isNotEmpty;

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
            constraints: const BoxConstraints(maxWidth: 680),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Encabezado Modal ──────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppPalette.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.inventory_2_rounded,
                              size: 24,
                              color: AppPalette.primary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Venta en Verde al 100%',
                                style: AppTypography.headline.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: AppPalette.primary,
                                ),
                              ),
                              Text(
                                'Asignación obligatoria de repuesto físico en bodega',
                                style: AppTypography.small.copyWith(
                                  color: AppPalette.textSecondaryLight,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        color: AppPalette.textSecondaryLight,
                        onPressed: _isConfirmando ? null : () => Navigator.of(context).pop(false),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Banner Resumen de la Orden ───────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppPalette.backgroundLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppPalette.borderLight),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.receipt_long_rounded,
                              size: 18,
                              color: AppPalette.tertiary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${widget.orden.folioDocumento} • ${widget.orden.clienteNombre}',
                              style: AppTypography.body.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppPalette.textPrimaryLight,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppPalette.successBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppPalette.successBorder),
                          ),
                          child: Text(
                            'Saldando: ${CobroPendienteCard.formatClp(widget.montoALiquidar)}',
                            style: AppTypography.small.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppPalette.successText,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'Ingresa el código SKU del repuesto físico que se entregará al cliente. El sistema validará su compatibilidad con las especificaciones de la reserva:',
                    style: AppTypography.small.copyWith(
                      color: AppPalette.textSecondaryLight,
                      fontSize: 12,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Input de SKU + Botón Validar ────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _skuController,
                          enabled: !atribuido || (validacion?.coincide == false && !forzar),
                          style: AppTypography.body.copyWith(
                            color: AppPalette.textPrimaryLight,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          textInputAction: TextInputAction.search,
                          onSubmitted: (isRevisando || (atribuido && coincide) || forzar)
                              ? null
                              : (_) => _ejecutarValidacionSku(),
                          decoration: InputDecoration(
                            hintText: 'Ej: MOT-1020',
                            prefixIcon: const Icon(
                              Icons.tag_rounded,
                              size: 20,
                              color: AppPalette.primary,
                            ),
                            filled: true,
                            fillColor: AppPalette.backgroundLight,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AppPalette.borderLight),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppPalette.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: isRevisando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.search_rounded, size: 18),
                        label: Text(
                          'Validar',
                          style: AppTypography.button.copyWith(fontSize: 13),
                        ),
                        onPressed: isRevisando || (atribuido && coincide) || forzar
                            ? null
                            : _ejecutarValidacionSku,
                      ),
                    ],
                  ),

                  // ── Resultado de Validación ─────────────────────────
                  if (validacion != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: validacion.coincide ? AppPalette.successBg : AppPalette.errorBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: validacion.coincide
                              ? AppPalette.successBorder
                              : AppPalette.errorBorder,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                validacion.coincide
                                    ? Icons.check_circle_rounded
                                    : Icons.error_outline_rounded,
                                color: validacion.coincide
                                    ? AppPalette.successText
                                    : AppPalette.errorText,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  validacion.mensaje,
                                  style: AppTypography.body.copyWith(
                                    color: validacion.coincide
                                        ? AppPalette.successText
                                        : AppPalette.errorText,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (!validacion.coincide &&
                              validacion.discrepancias.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ...validacion.discrepancias.map(
                              (d) => Padding(
                                padding: const EdgeInsets.only(left: 26, top: 2),
                                child: Text(
                                  '• $d',
                                  style: AppTypography.small.copyWith(
                                    color: AppPalette.errorText,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    if (validacion.activoDetalle != null) ...[
                      _buildDetalleActivoIngresado(
                        validacion.activoDetalle!,
                        widget.orden.especificacionesBackorder,
                      ),
                    ],
                  ],

                  // ── Forzar Atribución Manual ───────────────────────
                  if (validacion != null &&
                      !validacion.coincide &&
                      _intentosFallidosSku >= 2 &&
                      !forzar) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppPalette.error,
                          side: const BorderSide(color: AppPalette.error),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.warning_amber_rounded, size: 18),
                        label: const Text(
                          'Ignorar advertencia y forzar atribución',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          widget.provider.setForzarAtribucion(true);
                        },
                      ),
                    ),
                  ],

                  if (forzar) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppPalette.warningBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppPalette.warningBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: AppPalette.warningText,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Validación técnica ignorada manualmente. El repuesto será vinculado bajo responsabilidad operativa de caja.',
                              style: AppTypography.small.copyWith(
                                color: AppPalette.warningText,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── Botones de Acción ──────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppPalette.textSecondaryLight,
                            side: const BorderSide(color: AppPalette.borderLight),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _isConfirmando
                              ? null
                              : () => Navigator.of(context).pop(false),
                          child: Text(
                            'Cancelar (Volver a Caja)',
                            style: AppTypography.button.copyWith(
                              fontSize: 13,
                              color: AppPalette.textSecondaryLight,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppPalette.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: _isConfirmando
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_circle_rounded, size: 18),
                          label: Text(
                            'Confirmar y Finalizar Cobro',
                            style: AppTypography.button.copyWith(fontSize: 13),
                          ),
                          onPressed: puedeConfirmar ? _confirmarAtribucion : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetalleActivoIngresado(
    ActivoDetalleBackorderModel detalle,
    BackorderEspecificacionesModel? bo,
  ) {
    final bool marcaCoincide = bo?.marca == null ||
        (detalle.marca != null &&
            detalle.marca!.trim().toLowerCase() == bo!.marca.trim().toLowerCase());
    final bool modeloCoincide = bo?.modelo == null ||
        (detalle.modelo != null &&
            detalle.modelo!.trim().toLowerCase() == bo!.modelo.trim().toLowerCase());

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppPalette.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.inventory_2_rounded,
                  size: 20,
                  color: AppPalette.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'REPUESTO EN BODEGA',
                          style: AppTypography.title.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: AppPalette.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppPalette.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            detalle.sku,
                            style: AppTypography.small.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppPalette.primary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ficha técnica del repuesto físico cotejado con la reserva.',
                      style: AppTypography.small.copyWith(
                        color: AppPalette.textSecondaryLight,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (detalle.estadoConservacion != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppPalette.successBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppPalette.successBorder),
                  ),
                  child: Text(
                    detalle.estadoConservacion!,
                    style: AppTypography.small.copyWith(
                      color: AppPalette.successText,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppPalette.borderLight),
          const SizedBox(height: 14),

          // Grilla de detalles técnicos del activo
          Row(
            children: [
              Expanded(
                child: _buildActivoInfoItem(
                  icon: Icons.directions_car_rounded,
                  label: 'Vehículo Origen',
                  value: '${detalle.marca ?? "-"} ${detalle.modelo ?? "-"}',
                  badgeText: (marcaCoincide && modeloCoincide) ? 'Coincide' : 'Difiere',
                  isMatch: marcaCoincide && modeloCoincide,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActivoInfoItem(
                  icon: Icons.calendar_today_rounded,
                  label: 'Año / Categoría',
                  value:
                      '${detalle.anio != null ? detalle.anio.toString() : "S/A"} • ${detalle.categoria ?? "Repuesto"}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildActivoInfoItem(
                  icon: Icons.speed_rounded,
                  label: 'Motor / Combustible',
                  value: '${detalle.cilindrada ?? "-"} • ${detalle.combustible ?? "-"}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActivoInfoItem(
                  icon: Icons.settings_input_component_rounded,
                  label: 'Transmisión',
                  value: detalle.transmision ?? 'No especificada',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildActivoInfoItem(
                  icon: Icons.warehouse_rounded,
                  label: 'Ubicación Física',
                  value: detalle.ubicacion ?? 'Sin ubicación registrada',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActivoInfoItem(
                  icon: Icons.tag_rounded,
                  label: 'Patente / VIN',
                  value: '${detalle.patente ?? "S/P"} • ${detalle.vin ?? "S/V"}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivoInfoItem({
    required IconData icon,
    required String label,
    required String value,
    String? badgeText,
    bool isMatch = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppPalette.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppPalette.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppPalette.textSecondaryLight),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.small.copyWith(
                    color: AppPalette.textSecondaryLight,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isMatch ? AppPalette.successBg : AppPalette.errorBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: isMatch ? AppPalette.successText : AppPalette.errorText,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: AppPalette.textPrimaryLight,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
