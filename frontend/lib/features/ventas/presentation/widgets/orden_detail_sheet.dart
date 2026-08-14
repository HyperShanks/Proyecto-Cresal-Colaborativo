import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../services/ordenes_service.dart';

/// Modal inferior para visualizar el detalle técnico completo de una orden de venta (HU-3.5).
/// Ofrece acciones condicionales de edición de notas y anulación transaccional si está en estado 'Reservada'.
class OrdenDetailSheet extends StatefulWidget {
  final OrdenHistorialModel orden;
  final VoidCallback? onOrderUpdated;

  const OrdenDetailSheet({
    super.key,
    required this.orden,
    this.onOrderUpdated,
  });

  @override
  State<OrdenDetailSheet> createState() => _OrdenDetailSheetState();
}

class _OrdenDetailSheetState extends State<OrdenDetailSheet> {
  late OrdenHistorialModel _orden;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _orden = widget.orden;
  }

  Widget _buildStatusBadge() {
    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData icon;
    String label = _orden.estadoOrden;

    if (_orden.esReservada) {
      bgColor = AppPalette.secondary.withValues(alpha: 0.15);
      borderColor = AppPalette.secondary.withValues(alpha: 0.5);
      textColor = AppPalette.secondary;
      icon = Icons.schedule;
      label = 'Reservada';
    } else if (_orden.esPagada) {
      bgColor = AppPalette.success.withValues(alpha: 0.15);
      borderColor = AppPalette.success.withValues(alpha: 0.5);
      textColor = AppPalette.success;
      icon = Icons.check_circle_outline;
      label = 'Pagada';
    } else if (_orden.esAnulada) {
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

  /// Diálogo para editar las instrucciones / notas técnicas para bodega
  Future<void> _dialogEditarInstrucciones() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Tomar la primera nota existente como valor inicial sugerido
    final notaActual = _orden.detalles.isNotEmpty
        ? (_orden.detalles.first.notasPreparacion ?? '')
        : '';
    final controller = TextEditingController(text: notaActual);

    final nuevoTexto = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: const BorderSide(color: Colors.white10),
        ),
        title: Row(
          children: [
            const Icon(Icons.edit_note, color: AppPalette.primary, size: 24.0),
            const SizedBox(width: 8.0),
            Text(
              'Instrucciones a Bodega',
              style: AppTypography.title.copyWith(fontSize: 18.0),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Indica requerimientos especiales de desmontaje o preparación técnica para el bodeguero:',
              style: AppTypography.small.copyWith(color: AppPalette.textSecondary),
            ),
            const SizedBox(height: 12.0),
            TextField(
              controller: controller,
              maxLines: 3,
              style: AppTypography.body,
              decoration: InputDecoration(
                hintText: 'Ej. Entregar con poleas y cables intactos...',
                hintStyle: AppTypography.small.copyWith(color: AppPalette.neutral),
                filled: true,
                fillColor: AppPalette.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: const BorderSide(color: AppPalette.primary, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text(
              'Cancelar',
              style: AppTypography.button.copyWith(color: AppPalette.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.primary,
              foregroundColor: AppPalette.textPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
            ),
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (nuevoTexto == null || !mounted) return;

    setState(() => _isLoading = true);

    try {
      await OrdenesService.actualizarInstruccionesBodega(
        _orden.idOrden,
        nuevoTexto,
      );

      if (!mounted) return;

      setState(() {
        for (final d in _orden.detalles) {
          d.notasPreparacion = nuevoTexto;
        }
        _isLoading = false;
      });

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 20.0),
              SizedBox(width: 8.0),
              Text('Instrucciones a bodega actualizadas exitosamente.'),
            ],
          ),
          backgroundColor: AppPalette.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      widget.onOrderUpdated?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error al actualizar instrucciones: $e'),
          backgroundColor: AppPalette.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Diálogo de confirmación para anular la orden
  Future<void> _dialogAnularOrden() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: const BorderSide(color: Colors.white10),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppPalette.error, size: 24.0),
            const SizedBox(width: 8.0),
            Text(
              '¿Deshacer esta Orden?',
              style: AppTypography.title.copyWith(fontSize: 18.0),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Al anular la orden ${_orden.folioDisplay}:',
              style: AppTypography.body.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8.0),
            Text(
              '• La orden pasará inmediatamente a estado "Anulada".\n'
              '• Todos los repuestos inventariados serán liberados y volverán a estar disponibles en el catálogo.',
              style: AppTypography.small.copyWith(color: AppPalette.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Volver',
              style: AppTypography.button.copyWith(color: AppPalette.textSecondary),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.error,
              foregroundColor: AppPalette.textPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
            ),
            icon: const Icon(Icons.delete_outline, size: 18.0),
            label: const Text('Confirmar Anulación'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() => _isLoading = true);

    try {
      await OrdenesService.anularOrden(_orden.idOrden);

      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 20.0),
              const SizedBox(width: 8.0),
              Expanded(
                child: Text('Orden ${_orden.folioDisplay} anulada. Repuestos devueltos al catálogo.'),
              ),
            ],
          ),
          backgroundColor: AppPalette.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      widget.onOrderUpdated?.call();
      navigator.pop(); // Cerrar el bottom sheet tras anular
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error al anular la orden: $e'),
          backgroundColor: AppPalette.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Tirador visual del modal ──────────────────────────────────
          Container(
            margin: const EdgeInsets.only(top: 8.0, bottom: 4.0),
            width: 40.0,
            height: 4.0,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2.0),
            ),
          ),

          // ── Encabezado del BottomSheet ────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: AppPalette.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: const Icon(
                        Icons.receipt_long_outlined,
                        size: 22.0,
                        color: AppPalette.primary,
                      ),
                    ),
                    const SizedBox(width: 10.0),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _orden.folioDisplay,
                          style: AppTypography.title.copyWith(
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _orden.fechaFormateada,
                          style: AppTypography.small.copyWith(
                            fontSize: 12.0,
                            color: AppPalette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildStatusBadge(),
                    const SizedBox(width: 8.0),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppPalette.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white10, height: 1.0),

          // ── Contenido con Scroll ──────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Sección 1: Datos del Cliente ───────────────────────
                  Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: AppPalette.background,
                      borderRadius: BorderRadius.circular(10.0),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person, size: 16.0, color: AppPalette.primary),
                            const SizedBox(width: 6.0),
                            Text(
                              'Datos del Cliente',
                              style: AppTypography.small.copyWith(
                                color: AppPalette.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          _orden.cliente != null && _orden.cliente!.nombres.isNotEmpty
                              ? '${_orden.cliente!.nombreCompleto} (${_orden.cliente!.rutCliente})'
                              : 'Cliente General',
                          style: AppTypography.body.copyWith(
                            fontSize: 14.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_orden.cliente?.telefono != null && _orden.cliente!.telefono!.isNotEmpty) ...[
                          const SizedBox(height: 4.0),
                          Text(
                            'Teléfono: ${_orden.cliente!.telefono}',
                            style: AppTypography.small.copyWith(color: AppPalette.textSecondary),
                          ),
                        ],
                        if (_orden.cliente?.correo != null && _orden.cliente!.correo!.isNotEmpty) ...[
                          const SizedBox(height: 2.0),
                          Text(
                            'Correo: ${_orden.cliente!.correo}',
                            style: AppTypography.small.copyWith(color: AppPalette.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ── Sección 2: Despacho (si aplica) ────────────────────
                  if (_orden.despacho != null) ...[
                    const SizedBox(height: 12.0),
                    Container(
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: AppPalette.background,
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.local_shipping, size: 16.0, color: AppPalette.secondary),
                              const SizedBox(width: 6.0),
                              Text(
                                'Despacho a Domicilio',
                                style: AppTypography.small.copyWith(
                                  color: AppPalette.secondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8.0),
                          Text(
                            'Dirección: ${_orden.despacho!.direccionEnvio}',
                            style: AppTypography.body.copyWith(fontSize: 13.0),
                          ),
                          const SizedBox(height: 4.0),
                          Text(
                            'Receptor: ${_orden.despacho!.receptorNombres} (${_orden.despacho!.receptorRut})',
                            style: AppTypography.small.copyWith(color: AppPalette.textSecondary),
                          ),
                          const SizedBox(height: 2.0),
                          Text(
                            'Estado Envío: ${_orden.despacho!.estadoDespacho}',
                            style: AppTypography.small.copyWith(color: AppPalette.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16.0),

                  // ── Sección 3: Desglose de Repuestos ───────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Desglose de Repuestos',
                        style: AppTypography.title.copyWith(fontSize: 15.0),
                      ),
                      Text(
                        '${_orden.detalles.length} ${_orden.detalles.length == 1 ? 'ítem' : 'ítems'}',
                        style: AppTypography.small.copyWith(color: AppPalette.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8.0),

                  ..._orden.detalles.map((detalle) => Container(
                        margin: const EdgeInsets.only(bottom: 10.0),
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: AppPalette.background,
                          borderRadius: BorderRadius.circular(10.0),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6.0),
                                  decoration: BoxDecoration(
                                    color: detalle.esInventariado
                                        ? AppPalette.primary.withValues(alpha: 0.15)
                                        : AppPalette.secondary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6.0),
                                  ),
                                  child: Icon(
                                    detalle.esInventariado
                                        ? Icons.precision_manufacturing_outlined
                                        : Icons.handyman_outlined,
                                    size: 16.0,
                                    color: detalle.esInventariado
                                        ? AppPalette.primary
                                        : AppPalette.secondary,
                                  ),
                                ),
                                const SizedBox(width: 8.0),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        detalle.titulo,
                                        style: AppTypography.body.copyWith(
                                          fontSize: 14.0,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (detalle.skuQrFisico != null) ...[
                                        const SizedBox(height: 2.0),
                                        Text(
                                          'SKU: ${detalle.skuQrFisico}',
                                          style: AppTypography.small.copyWith(
                                            fontSize: 12.0,
                                            color: AppPalette.textSecondary,
                                          ),
                                        ),
                                      ],
                                      if (detalle.descripcionManual != null &&
                                          detalle.descripcionManual != detalle.titulo) ...[
                                        const SizedBox(height: 2.0),
                                        Text(
                                          detalle.descripcionManual!,
                                          style: AppTypography.small.copyWith(
                                            fontSize: 12.0,
                                            color: AppPalette.neutral,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      detalle.subtotalFormateado,
                                      style: AppTypography.body.copyWith(
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.bold,
                                        color: AppPalette.secondary,
                                      ),
                                    ),
                                    Text(
                                      '${detalle.cantidad} x ${detalle.precioFinalFormateado}',
                                      style: AppTypography.small.copyWith(
                                        fontSize: 11.0,
                                        color: AppPalette.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            // Notas de preparación técnica de este ítem
                            if (detalle.notasPreparacion != null &&
                                detalle.notasPreparacion!.isNotEmpty) ...[
                              const SizedBox(height: 8.0),
                              Container(
                                padding: const EdgeInsets.all(8.0),
                                decoration: BoxDecoration(
                                  color: AppPalette.surface,
                                  borderRadius: BorderRadius.circular(6.0),
                                  border: Border.all(
                                    color: AppPalette.secondary.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.note_alt_outlined,
                                      size: 14.0,
                                      color: AppPalette.secondary,
                                    ),
                                    const SizedBox(width: 6.0),
                                    Expanded(
                                      child: Text(
                                        'Nota: ${detalle.notasPreparacion}',
                                        style: AppTypography.small.copyWith(
                                          fontSize: 12.0,
                                          color: AppPalette.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      )),

                  const SizedBox(height: 12.0),

                  // ── Resumen de Totales ─────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14.0),
                    decoration: BoxDecoration(
                      color: AppPalette.background,
                      borderRadius: BorderRadius.circular(10.0),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total de la Orden',
                          style: AppTypography.title.copyWith(fontSize: 16.0),
                        ),
                        Text(
                          _orden.totalVentaFormateado,
                          style: AppTypography.headline.copyWith(
                            fontSize: 20.0,
                            color: _orden.esAnulada ? AppPalette.neutral : AppPalette.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Sección 4: Acciones Condicionales (Solo si está Reservada) ─
                  if (_orden.esReservada) ...[
                    const SizedBox(height: 20.0),
                    Text(
                      'Acciones de Gestión',
                      style: AppTypography.title.copyWith(fontSize: 15.0),
                    ),
                    const SizedBox(height: 10.0),

                    // Botón Editar Instrucciones a Bodega
                    SizedBox(
                      width: double.infinity,
                      height: 48.0,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppPalette.primary,
                          side: const BorderSide(color: AppPalette.primary, width: 1.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                        ),
                        icon: const Icon(Icons.edit_note, size: 20.0),
                        label: const Text(
                          'Editar Instrucciones a Bodega',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onPressed: _isLoading ? null : _dialogEditarInstrucciones,
                      ),
                    ),

                    const SizedBox(height: 10.0),

                    // Botón Deshacer / Anular Orden
                    SizedBox(
                      width: double.infinity,
                      height: 48.0,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppPalette.error.withValues(alpha: 0.15),
                          foregroundColor: AppPalette.error,
                          elevation: 0,
                          side: BorderSide(
                            color: AppPalette.error.withValues(alpha: 0.6),
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                        ),
                        icon: const Icon(Icons.delete_outline, size: 20.0),
                        label: const Text(
                          'Deshacer Orden (Liberar Stock)',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onPressed: _isLoading ? null : _dialogAnularOrden,
                      ),
                    ),
                  ],

                  const SizedBox(height: 16.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
