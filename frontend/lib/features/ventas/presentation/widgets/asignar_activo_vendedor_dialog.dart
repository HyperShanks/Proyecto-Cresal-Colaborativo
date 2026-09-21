import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../services/ordenes_service.dart';

/// Diálogo interactivo para que el vendedor asigne un activo físico (Disponible o Paletizado)
/// a una Venta en Verde pagada que ha llegado a bodega.
class AsignarActivoVendedorDialog extends StatefulWidget {
  final OrdenHistorialModel orden;
  final VoidCallback onAsignadoExitoso;

  const AsignarActivoVendedorDialog({
    super.key,
    required this.orden,
    required this.onAsignadoExitoso,
  });

  static Future<void> mostrar(
    BuildContext context, {
    required OrdenHistorialModel orden,
    required VoidCallback onAsignadoExitoso,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AsignarActivoVendedorDialog(
        orden: orden,
        onAsignadoExitoso: onAsignadoExitoso,
      ),
    );
  }

  @override
  State<AsignarActivoVendedorDialog> createState() =>
      _AsignarActivoVendedorDialogState();
}

class _AsignarActivoVendedorDialogState
    extends State<AsignarActivoVendedorDialog> {
  final TextEditingController _skuController = TextEditingController();
  bool _isValidando = false;
  bool _isAsignando = false;
  bool _forzarAtribucion = false;

  Map<String, dynamic>? _resultadoValidacion;
  String? _errorValidacion;

  @override
  void dispose() {
    _skuController.dispose();
    super.dispose();
  }

  Future<void> _validarSku() async {
    final sku = _skuController.text.trim();
    if (sku.isEmpty) return;

    setState(() {
      _isValidando = true;
      _errorValidacion = null;
      _resultadoValidacion = null;
      _forzarAtribucion = false;
    });

    try {
      final res = await OrdenesService.validarActivoBackorder(
        widget.orden.idOrden,
        sku,
      );
      if (!mounted) return;
      setState(() {
        _resultadoValidacion = res;
        _isValidando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorValidacion = e.toString().replaceAll('Exception: ', '');
        _isValidando = false;
      });
    }
  }

  Future<void> _asignarActivo() async {
    final sku = _skuController.text.trim();
    if (sku.isEmpty) return;

    setState(() {
      _isAsignando = true;
    });

    try {
      final res = await OrdenesService.asignarActivoBackorder(
        widget.orden.idOrden,
        sku,
        forzar: _forzarAtribucion,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onAsignadoExitoso();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppPalette.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '¡Activo ${res["sku_asignado"] ?? sku} asignado exitosamente! '
                  'QR de salida generado. La orden ya está lista para entrega en Barrera de Salida.',
                  style: AppTypography.body.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAsignando = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppPalette.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Text(
            'Error al asignar activo: ${e.toString().replaceAll("Exception: ", "")}',
            style: AppTypography.body.copyWith(color: Colors.white),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool coincide = _resultadoValidacion?['coincide'] == true;
    final List<dynamic> discrepancias =
        _resultadoValidacion?['discrepancias'] as List<dynamic>? ?? [];
    final Map<String, dynamic>? detalleActivo =
        _resultadoValidacion?['activo_detalle'] as Map<String, dynamic>?;

    final bool puedeConfirmar = (coincide || _forzarAtribucion) &&
        !_isValidando &&
        !_isAsignando &&
        _skuController.text.trim().isNotEmpty;

    final detalleBo = widget.orden.detalles.firstWhere(
      (d) => !d.esInventariado,
      orElse: () => widget.orden.detalles.first,
    );    return Dialog(
      backgroundColor: AppPalette.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white12),
      ),
      elevation: 16,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Encabezado ──────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppPalette.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.inventory_2_rounded,
                            size: 24,
                            color: AppPalette.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Asignar Activo Físico Paletizado',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.headline.copyWith(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: AppPalette.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Orden ${widget.orden.folioDisplay} • Venta en Verde Pagada',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.small.copyWith(
                                  color: AppPalette.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _isAsignando ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: AppPalette.textSecondary),
                    tooltip: 'Cerrar',
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 16),

              // ── Resumen de lo solicitado por el cliente ────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppPalette.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bookmark_added_rounded, color: AppPalette.secondary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'REPUESTO EN VERDE COMPRADO',
                          style: AppTypography.small.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppPalette.secondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      detalleBo.titulo,
                      style: AppTypography.title.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppPalette.textPrimary,
                      ),
                    ),
                    if (detalleBo.notasPreparacion != null &&
                        detalleBo.notasPreparacion!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        detalleBo.notasPreparacion!,
                        style: AppTypography.small.copyWith(
                          color: AppPalette.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          'Cliente: ',
                          style: AppTypography.small.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppPalette.textSecondary,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${widget.orden.cliente?.nombreCompleto ?? "Cliente General"} (${widget.orden.cliente?.rutCliente ?? "N/A"})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.small.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppPalette.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Campo de Entrada de SKU Físico ──────────────────────
              Text(
                'SKU del Activo Físico Arribado (Bodega)',
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: AppPalette.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _skuController,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppPalette.textPrimary,
                        letterSpacing: 0.5,
                      ),
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: 'Ej: MOT-NIS-1234 o escanear QR',
                        hintStyle: AppTypography.body.copyWith(
                          color: AppPalette.textSecondary.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: AppPalette.background,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        prefixIcon: const Icon(Icons.qr_code_scanner, color: AppPalette.primary, size: 20),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppPalette.primary, width: 1.5),
                        ),
                      ),
                      onSubmitted: (_) => _validarSku(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: _isValidando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.search, size: 18),
                    label: const Text('Validar', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _isValidando ? null : _validarSku,
                  ),
                ],
              ),

              // ── Error de Validación ────────────────────────────────
              if (_errorValidacion != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppPalette.errorBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppPalette.errorBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppPalette.errorText, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorValidacion!,
                          style: AppTypography.small.copyWith(
                            color: AppPalette.errorText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Resultado de Validación ─────────────────────────────
              if (_resultadoValidacion != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: coincide ? AppPalette.successBg : AppPalette.errorBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: coincide ? AppPalette.successBorder : AppPalette.errorBorder,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            coincide ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                            color: coincide ? AppPalette.successText : AppPalette.errorText,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _resultadoValidacion!['mensaje']?.toString() ?? '',
                              style: AppTypography.body.copyWith(
                                color: coincide ? AppPalette.successText : AppPalette.errorText,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!coincide && discrepancias.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ...discrepancias.map(
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

                // Ficha del activo encontrado
                if (detalleActivo != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppPalette.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detalles de la pieza física encontrada:',
                          style: AppTypography.small.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppPalette.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${detalleActivo["categoria"] ?? "Repuesto"} • ${detalleActivo["marca"] ?? ""} ${detalleActivo["modelo"] ?? ""} (${detalleActivo["anio"] ?? "Año N/A"})',
                          style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppPalette.textPrimary,
                          ),
                        ),
                        Text(
                          'Estado: ${detalleActivo["estado_conservacion"] ?? "Disponible"} • Ubicación: ${detalleActivo["ubicacion"] ?? "En paletizado"}',
                          style: AppTypography.small.copyWith(
                            color: AppPalette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Botón inmediato para Forzar Atribución Manual
                if (!coincide && !_forzarAtribucion) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppPalette.error,
                        side: const BorderSide(color: AppPalette.error),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.warning_amber_rounded, size: 18),
                      label: const Text(
                        'Ignorar advertencia y forzar asignación manual',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: () {
                        setState(() {
                          _forzarAtribucion = true;
                        });
                      },
                    ),
                  ),
                ],

                if (_forzarAtribucion) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppPalette.warningBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppPalette.warningBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppPalette.warningText, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Sobreescritura manual activada. Este activo se vinculará a la orden bajo tu responsabilidad comercial.',
                            style: AppTypography.small.copyWith(
                              color: AppPalette.warningText,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 24),

              // ── Botones de Cierre / Confirmación ────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppPalette.textSecondary,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isAsignando ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppPalette.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: _isAsignando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_rounded, size: 18),
                      label: const Text(
                        'Asignar y Generar QR',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: puedeConfirmar ? _asignarActivo : null,
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
}
