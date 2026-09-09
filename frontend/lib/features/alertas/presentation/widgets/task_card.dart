import 'package:flutter/material.dart';
import '../../models/tarea_alerta.dart';
import '../../services/logistica_service.dart';
import '../../services/bodega_service.dart';
import '../../services/bodega_polling_service.dart';

import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../screens/auditoria_salida_screen.dart';

class TaskCard extends StatefulWidget {
  final TareaAlerta tarea;
  final VoidCallback? onActualizar;

  const TaskCard({super.key, required this.tarea, this.onActualizar});

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  bool _isProcessingListo = false;

  String _obtenerTipoPieza() {
    final cat = (widget.tarea.categoria ?? widget.tarea.tipoRepuesto ?? '').toLowerCase();
    final titulo = widget.tarea.tituloPieza.toLowerCase();
    if (cat.contains('motor') || titulo.contains('motor')) {
      return 'MOTOR';
    } else if (cat.contains('caja') || titulo.contains('caja') || cat.contains('transmi') || titulo.contains('transmi')) {
      return 'CAJA DE CAMBIOS';
    }
    return '';
  }

  String _obtenerTituloFormateado() {
    var titulo = widget.tarea.tituloPieza;
    final tipo = _obtenerTipoPieza();
    if (tipo == 'MOTOR') {
      if (titulo.startsWith('Repuesto de ')) {
        return titulo.replaceFirst('Repuesto de ', 'Motor - ');
      } else if (!titulo.toLowerCase().startsWith('motor')) {
        return 'Motor - $titulo';
      }
    } else if (tipo == 'CAJA DE CAMBIOS') {
      if (titulo.startsWith('Repuesto de ')) {
        return titulo.replaceFirst('Repuesto de ', 'Caja de Cambios - ');
      } else if (!titulo.toLowerCase().startsWith('caja')) {
        return 'Caja de Cambios - $titulo';
      }
    }
    return titulo;
  }

  Future<void> _marcarListo() async {
    if (widget.tarea.idDetalle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se encontró el ID de detalle para marcar como listo.'),
          backgroundColor: AppPalette.error,
        ),
      );
      return;
    }

    setState(() => _isProcessingListo = true);

    try {
      final exito = await LogisticaService.completarPreentrega(widget.tarea.idDetalle!);
      if (!mounted) return;

      if (exito) {
        BodegaPollingService.instance.decrementarPendiente(tipoAlerta: widget.tarea.tipoAlerta);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Preparación de ${_obtenerTituloFormateado()} marcada como LISTO.',
            ),
            backgroundColor: AppPalette.success,
            duration: const Duration(seconds: 3),
          ),
        );
        widget.onActualizar?.call();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ocurrió un error al intentar marcar la pieza como lista. Verifique su conexión y vuelva a intentarlo.',
          ),
          backgroundColor: AppPalette.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessingListo = false);
    }
  }

  Future<void> _abrirDialogoConfirmarReingreso(BuildContext context) async {
    final tarea = widget.tarea;
    final idOrden = tarea.idOrden ?? (tarea.ordenRef?.replaceAll('ORDEN #', '').replaceAll('ORDEN ANULADA #', '').trim() ?? '');
    final skuInicial = tarea.skuQrFisico ?? '';

    // Ubicación de origen donde debe devolverse la pieza
    String pasilloInicial = (tarea.ubicacionPasillo != null && tarea.ubicacionPasillo!.isNotEmpty && tarea.ubicacionPasillo != 'S/P')
        ? tarea.ubicacionPasillo!
        : '';
    String palletInicial = (tarea.ubicacionPallet != null && tarea.ubicacionPallet!.isNotEmpty && tarea.ubicacionPallet != 'S/P')
        ? tarea.ubicacionPallet!
        : '';

    if (pasilloInicial.isEmpty || palletInicial.isEmpty) {
      if (tarea.ubicacion.contains('-')) {
        final parts = tarea.ubicacion.split('-');
        if (parts.length >= 2) {
          if (pasilloInicial.isEmpty) pasilloInicial = parts[0].trim().replaceAll('S/P', '');
          if (palletInicial.isEmpty) palletInicial = parts[1].trim().replaceAll('S/P', '');
        }
      }
    }

    final pasilloController = TextEditingController(text: pasilloInicial);
    final palletController = TextEditingController(text: palletInicial);
    final skuController = TextEditingController(text: skuInicial);

    bool isSubmitting = false;
    String? modalError;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (stfContext, setModalState) {
            return AlertDialog(
              backgroundColor: AppPalette.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
                side: const BorderSide(color: Colors.white12),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00A3FF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF00A3FF), size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Confirmar Reingreso', style: AppTypography.title.copyWith(fontSize: 17)),
                        if (skuInicial.isNotEmpty)
                          Text('SKU: $skuInicial', style: AppTypography.small.copyWith(color: AppPalette.secondary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tarjeta informativa de la pieza
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppPalette.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_obtenerTituloFormateado(), style: AppTypography.body.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Orden Anulada: ${tarea.ordenRef ?? idOrden}', style: AppTypography.small.copyWith(color: AppPalette.textSecondary)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.location_on, color: Color(0xFF00A3FF), size: 16),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Devolver a: ${pasilloInicial.isNotEmpty ? pasilloInicial : "S/P"} · ${palletInicial.isNotEmpty ? palletInicial : "S/P"}',
                                  style: AppTypography.small.copyWith(
                                    color: const Color(0xFF00A3FF),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Escaneo de QR Físico
                    Text('Escaneo de QR Físico (Validación):', style: AppTypography.small.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: skuController,
                      enabled: !isSubmitting,
                      style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Escanee o digite el SKU del repuesto',
                        filled: true,
                        fillColor: AppPalette.background,
                        prefixIcon: const Icon(Icons.qr_code, color: Color(0xFF00A3FF), size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF00A3FF), width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Ubicación Pasillo y Pallet (Pre-cargados)
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Pasillo / Rack:', style: AppTypography.small.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              TextField(
                                controller: pasilloController,
                                enabled: !isSubmitting,
                                textCapitalization: TextCapitalization.characters,
                                style: AppTypography.body,
                                decoration: InputDecoration(
                                  hintText: 'Ej: P-02',
                                  filled: true,
                                  fillColor: AppPalette.background,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Pallet:', style: AppTypography.small.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              TextField(
                                controller: palletController,
                                enabled: !isSubmitting,
                                textCapitalization: TextCapitalization.characters,
                                style: AppTypography.body,
                                decoration: InputDecoration(
                                  hintText: 'Ej: PAL-05',
                                  filled: true,
                                  fillColor: AppPalette.background,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (modalError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppPalette.error.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppPalette.error, size: 16),
                            const SizedBox(width: 6),
                            Expanded(child: Text(modalError!, style: const TextStyle(color: AppPalette.error, fontSize: 12))),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(dialogCtx).pop(false),
                  child: Text('Cancelar', style: AppTypography.button.copyWith(color: AppPalette.textSecondary)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check, size: 18),
                  label: Text(isSubmitting ? 'Guardando...' : 'CONFIRMAR REINGRESO'),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final skuEscaneado = skuController.text.trim();
                          if (skuEscaneado.isEmpty) {
                            setModalState(() => modalError = 'Debe ingresar o escanear el SKU físico.');
                            return;
                          }

                          setModalState(() {
                            isSubmitting = true;
                            modalError = null;
                          });

                          try {
                            await BodegaService.confirmarReingreso(
                              skuQrFisico: skuEscaneado,
                              idOrdenAnulada: idOrden,
                              ubicacionPasillo: pasilloController.text.trim(),
                              ubicacionPallet: palletController.text.trim(),
                            );

                            if (!dialogCtx.mounted) return;
                            Navigator.of(dialogCtx).pop(true);
                          } catch (e) {
                            setModalState(() {
                              isSubmitting = false;
                              modalError = e.toString().replaceAll('Exception:', '').trim();
                            });
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );

    pasilloController.dispose();
    palletController.dispose();
    skuController.dispose();

    if (result == true && mounted) {
      BodegaPollingService.instance.decrementarPendiente();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppPalette.success,
          content: Text('✅ Reingreso completado y pieza paletizada en su ubicación.'),
          duration: Duration(seconds: 3),
        ),
      );
      widget.onActualizar?.call();
    }
  }

  // Método para desplegar el Modal de Acción
  Future<void> _mostrarDetalleModal(
    BuildContext context,
    Color accentColor,
    Color buttonColor,
  ) async {
    final tarea = widget.tarea;
    final tituloFormateado = _obtenerTituloFormateado();
    final esLiberada = tarea.tipoAlerta == 'LIBERADA';
    final esImpresion = tarea.tipoAlerta == 'IMPRESION';
    final esReingreso = tarea.tipoAlerta == 'REINGRESO';
    final esPreEntrega = !esLiberada && !esImpresion && !esReingreso;

    final accion = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppPalette.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Indicador de arrastre (pill)
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppPalette.neutral.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    tarea.ordenRef ?? (esImpresion ? 'PENDIENTE: IMPRESIÓN' : (esReingreso ? 'LOGÍSTICA INVERSA' : 'TAREA OPERATIVA')),
                    style: AppTypography.small.copyWith(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (tarea.esTraslado || tarea.tipoAlerta == 'TRASLADO')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppPalette.secondary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppPalette.secondary),
                      ),
                      child: Text(
                        'TRASLADO INTER-SUCURSAL',
                        style: AppTypography.small.copyWith(
                          color: AppPalette.secondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  if (esReingreso)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppPalette.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppPalette.error.withValues(alpha: 0.6)),
                      ),
                      child: Text(
                        'ORDEN ANULADA',
                        style: AppTypography.small.copyWith(
                          color: AppPalette.error,
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              Text(tituloFormateado, style: AppTypography.headline),
              if (tarea.skuQrFisico != null && tarea.skuQrFisico!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('SKU: ${tarea.skuQrFisico}', style: AppTypography.small.copyWith(color: const Color(0xFF00A3FF), fontWeight: FontWeight.bold)),
              ],
              const SizedBox(height: 20),

              // Recuadro de Ubicación (SPEC-HU-TAREA-16)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppPalette.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppPalette.neutral.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      esReingreso ? 'UBICACIÓN ASIGNADA DE RETORNO' : 'UBICACIÓN EXACTA',
                      style: AppTypography.small.copyWith(fontSize: 11),
                    ),
                    const SizedBox(height: 8),
                    if (tarea.ubicacion.isEmpty ||
                        tarea.ubicacion == 'Ubicación Pendiente' ||
                        (tarea.ubicacion == 'S/P - S/P' &&
                            (tarea.ubicacionGalpon == null || tarea.ubicacionGalpon!.isEmpty))) ...[
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 18, color: AppPalette.warning),
                          const SizedBox(width: 8),
                          Text(
                            'Sin Galpón / Sin Ubicación asignada',
                            style: AppTypography.body.copyWith(
                              color: AppPalette.warning,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          if (tarea.ubicacionGalpon != null &&
                              tarea.ubicacionGalpon!.isNotEmpty &&
                              tarea.ubicacionGalpon != 'S/G') ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppPalette.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppPalette.primary, width: 1.5),
                              ),
                              child: Text(
                                'GALPÓN: ${tarea.ubicacionGalpon}',
                                style: AppTypography.small.copyWith(
                                  color: AppPalette.primary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: Text(
                              (tarea.ubicacionPasillo != null &&
                                      tarea.ubicacionPallet != null &&
                                      tarea.ubicacionPasillo!.isNotEmpty)
                                  ? 'Pasillo ${tarea.ubicacionPasillo} - Pallet ${tarea.ubicacionPallet}'
                                  : tarea.ubicacion,
                              style: AppTypography.title.copyWith(fontSize: 18, fontWeight: FontWeight.w900),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tarea.ubicacion,
                        style: AppTypography.small.copyWith(color: AppPalette.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),

              // RECUADRO DE INSTRUCCIONES DEL VENDEDOR / MOTIVO (Destacado)
              if (tarea.notaEspecial != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppPalette.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppPalette.secondary, width: 1.5),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: AppPalette.secondary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DETALLE DE LA TAREA',
                              style: AppTypography.small.copyWith(
                                color: AppPalette.secondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tarea.notaEspecial!,
                              style: AppTypography.body.copyWith(
                                color: AppPalette.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Botón Excluyente 'LISTO' solo para tareas de preparación / pre-entrega
              if (esPreEntrega && tarea.idDetalle != null) ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessingListo ? null : () => Navigator.pop(ctx, 'listo'),
                    icon: _isProcessingListo
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle, color: Colors.white),
                    label: Text(
                      'MARCAR COMO LISTO',
                      style: AppTypography.button.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.success,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Botón de Reingreso / Paletizado
              if (esReingreso) ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(ctx, 'reingreso'),
                    icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
                    label: Text(
                      'REINGRESAR / PALETIZAR',
                      style: AppTypography.button.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A3FF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Botón Excluyente de Salida / Barrera (solo cuando está LIBERADA)
              if (esLiberada) ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(ctx, 'barrera'),
                    icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                    label: Text(
                      'ESCANEAR EN BARRERA',
                      style: AppTypography.button.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.success,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Botón de Impresión (solo cuando es IMPRESION)
              if (esImpresion) ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(ctx, 'imprimir'),
                    icon: const Icon(Icons.print, color: AppPalette.textPrimary),
                    label: Text(
                      'GENERAR ETIQUETA QR',
                      style: AppTypography.button.copyWith(color: AppPalette.textPrimary),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: accentColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );

    if (!mounted || accion == null) return;

    if (accion == 'listo') {
      _marcarListo();
    } else if (accion == 'reingreso') {
      _abrirDialogoConfirmarReingreso(context);
    } else if (accion == 'barrera') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AuditoriaSalidaScreen()),
      );
    } else if (accion == 'imprimir' && tarea.etiquetaData != null) {
      final resultado = await Navigator.pushNamed(
        context,
        '/etiqueta-preview',
        arguments: tarea.etiquetaData,
      );
      if (resultado == true && mounted) {
        widget.onActualizar?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tarea = widget.tarea;
    final tituloFormateado = _obtenerTituloFormateado();
    Color accentColor;
    Color buttonColor;

    switch (tarea.tipoAlerta) {
      case 'IMPRESION':
        accentColor = AppPalette.error;
        buttonColor = AppPalette.error;
        break;
      case 'PREPARACION':
        accentColor = AppPalette.secondary;
        buttonColor = AppPalette.surface;
        break;
      case 'TRASLADO':
        accentColor = AppPalette.secondary;
        buttonColor = AppPalette.secondary;
        break;
      case 'LIBERADA':
        accentColor = AppPalette.success;
        buttonColor = AppPalette.success;
        break;
      case 'REINGRESO':
        accentColor = const Color(0xFFFFB300); // Amber 700
        buttonColor = const Color(0xFF00A3FF); // Cyan
        break;
      default:
        accentColor = AppPalette.neutral;
        buttonColor = AppPalette.neutral;
    }

    final esImpresion = tarea.tipoAlerta == 'IMPRESION';
    final esReingreso = tarea.tipoAlerta == 'REINGRESO';

    return GestureDetector(
      onTap: () => _mostrarDetalleModal(context, accentColor, buttonColor),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: AppPalette.surface,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: accentColor, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          tarea.ordenRef ?? (esImpresion ? 'PENDIENTE: IMPRESIÓN' : (esReingreso ? 'LOGÍSTICA INVERSA' : 'TAREA OPERATIVA')),
                          style: AppTypography.small.copyWith(
                            color: accentColor,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (tarea.esTraslado || tarea.tipoAlerta == 'TRASLADO') ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppPalette.secondary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppPalette.secondary, width: 0.8),
                          ),
                          child: Text(
                            'TRASLADO',
                            style: AppTypography.small.copyWith(
                              color: AppPalette.secondary,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      if (esReingreso) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppPalette.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppPalette.error.withValues(alpha: 0.5), width: 0.8),
                          ),
                          child: Text(
                            'ORDEN ANULADA',
                            style: AppTypography.small.copyWith(
                              color: AppPalette.error,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: buttonColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tarea.accionRequerida,
                    style: AppTypography.small.copyWith(
                      color: buttonColor == AppPalette.surface
                          ? AppPalette.textSecondary
                          : buttonColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(tituloFormateado, style: AppTypography.title),
            if (tarea.skuQrFisico != null && tarea.skuQrFisico!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00A3FF).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF00A3FF).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.qr_code, size: 12, color: Color(0xFF00A3FF)),
                        const SizedBox(width: 4),
                        Text(
                          tarea.skuQrFisico!,
                          style: const TextStyle(
                            color: Color(0xFF00A3FF),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppPalette.background,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    esReingreso ? 'UBICACIÓN DE RETORNO / PALLET' : 'UBICACIÓN DE RETIRO / PALLET',
                    style: AppTypography.small.copyWith(fontSize: 10),
                  ),
                  const SizedBox(height: 6),
                  if (tarea.ubicacion.isEmpty ||
                      tarea.ubicacion == 'Ubicación Pendiente' ||
                      (tarea.ubicacion == 'S/P - S/P' &&
                          (tarea.ubicacionGalpon == null || tarea.ubicacionGalpon!.isEmpty))) ...[
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 16, color: AppPalette.warning),
                        const SizedBox(width: 6),
                        Text(
                          'Sin Galpón / Sin Ubicación asignada',
                          style: AppTypography.small.copyWith(
                            color: AppPalette.warning,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        if (tarea.ubicacionGalpon != null &&
                            tarea.ubicacionGalpon!.isNotEmpty &&
                            tarea.ubicacionGalpon != 'S/G') ...[
                          Container(
                            key: const Key('chip_galpon_tarea'),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppPalette.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppPalette.primary, width: 1.2),
                            ),
                            child: Text(
                              'GALPÓN: ${tarea.ubicacionGalpon}',
                              style: AppTypography.small.copyWith(
                                color: AppPalette.primary,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            (tarea.ubicacionPasillo != null &&
                                    tarea.ubicacionPallet != null &&
                                    tarea.ubicacionPasillo!.isNotEmpty)
                                ? 'Pasillo ${tarea.ubicacionPasillo} - Pallet ${tarea.ubicacionPallet}'
                                : tarea.ubicacion,
                            style: AppTypography.title.copyWith(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (tarea.ubicacionPasillo != null &&
                        tarea.ubicacionPallet != null &&
                        tarea.ubicacionPasillo!.isNotEmpty &&
                        tarea.ubicacion != 'Pasillo ${tarea.ubicacionPasillo} - Pallet ${tarea.ubicacionPallet}') ...[
                      const SizedBox(height: 2),
                      Text(
                        tarea.ubicacion,
                        style: AppTypography.small.copyWith(
                          color: AppPalette.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),

            if (tarea.notaEspecial != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppPalette.secondary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tarea.notaEspecial!,
                      style: AppTypography.small.copyWith(
                        color: AppPalette.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            if (tarea.estadoBloqueo != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      color: AppPalette.textSecondary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tarea.estadoBloqueo!,
                      style: AppTypography.small.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── BOTONES DE ACCIÓN EN TARJETA (LÓGICA EXCLUYENTE) ──
            const SizedBox(height: 16),
            _buildActionButtons(context, accentColor),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, Color accentColor) {
    final tarea = widget.tarea;

    // 1. Estado Reingreso (LOGÍSTICA INVERSA): Botón REINGRESAR / PALETIZAR
    if (tarea.tipoAlerta == 'REINGRESO') {
      return SizedBox(
        width: double.infinity,
        height: 46,
        child: ElevatedButton.icon(
          key: Key('btn_reingresar_${tarea.idTarea}'),
          onPressed: () => _abrirDialogoConfirmarReingreso(context),
          icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 20),
          label: Text(
            'REINGRESAR / PALETIZAR',
            style: AppTypography.button.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00A3FF),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
      );
    }

    // 2. Estado Pagada / Salida (LIBERADA): Exclusivamente botón BARRERA (oculta LISTO)
    if (tarea.tipoAlerta == 'LIBERADA') {
      return SizedBox(
        width: double.infinity,
        height: 45,
        child: ElevatedButton.icon(
          key: Key('btn_barrera_${tarea.idTarea}'),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AuditoriaSalidaScreen(),
              ),
            );
          },
          icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
          label: Text(
            'BARRERA',
            style: AppTypography.button.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppPalette.success,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
      );
    }

    // 3. Estado Impresión QR: Botón IMPRIMIR
    if (tarea.tipoAlerta == 'IMPRESION') {
      return SizedBox(
        width: double.infinity,
        height: 45,
        child: OutlinedButton.icon(
          key: Key('btn_imprimir_${tarea.idTarea}'),
          onPressed: () async {
            if (tarea.etiquetaData != null) {
              final resultado = await Navigator.pushNamed(
                context,
                '/etiqueta-preview',
                arguments: tarea.etiquetaData,
              );
              if (resultado == true) {
                widget.onActualizar?.call();
              }
            }
          },
          icon: const Icon(Icons.print, color: AppPalette.textPrimary, size: 18),
          label: Text(
            'IMPRIMIR',
            style: AppTypography.button.copyWith(fontSize: 12),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: accentColor),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
      );
    }

    // 4. Estado Reservada / Pre-entrega Pendiente (PREPARACION / TRASLADO): Botón LISTO + DETALLES (oculta BARRERA)
    return Row(
      children: [
        if (tarea.idDetalle != null) ...[
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 45,
              child: ElevatedButton.icon(
                key: Key('btn_listo_${tarea.idTarea}'),
                onPressed: _isProcessingListo ? null : _marcarListo,
                icon: _isProcessingListo
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                label: Text(
                  'LISTO',
                  style: AppTypography.button.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.success,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          flex: tarea.idDetalle != null ? 2 : 5,
          child: SizedBox(
            height: 45,
            child: OutlinedButton.icon(
              key: Key('btn_detalles_${tarea.idTarea}'),
              onPressed: () {
                _mostrarDetalleModal(context, accentColor, AppPalette.surface);
              },
              icon: const Icon(Icons.visibility_outlined, color: AppPalette.textPrimary, size: 18),
              label: Text(
                'DETALLES',
                style: AppTypography.button.copyWith(fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: accentColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
