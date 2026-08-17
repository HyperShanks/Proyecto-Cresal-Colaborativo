import 'package:flutter/material.dart';
import '../../models/tarea_alerta.dart';
import '../../services/logistica_service.dart';

import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../screens/auditoria_salida_screen.dart';

class TaskCard extends StatefulWidget {
  final TareaAlerta tarea;
  final VoidCallback? onActualizar;

  const TaskCard({Key? key, required this.tarea, this.onActualizar}) : super(key: key);

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

  Future<void> _marcarListo(BuildContext context) async {
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
        SnackBar(
          content: Text('❌ Error al completar preparación: $e'),
          backgroundColor: AppPalette.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessingListo = false);
    }
  }

  // Método para desplegar el Modal de Acción
  void _mostrarDetalleModal(
    BuildContext context,
    Color accentColor,
    Color buttonColor,
  ) {
    final tarea = widget.tarea;
    final tituloFormateado = _obtenerTituloFormateado();
    final esLiberada = tarea.tipoAlerta == 'LIBERADA';
    final esImpresion = tarea.tipoAlerta == 'IMPRESION';
    final esPreEntrega = !esLiberada && !esImpresion;

    showModalBottomSheet(
      context: context,
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
                    tarea.ordenRef ?? (esImpresion ? 'PENDIENTE: IMPRESIÓN' : 'TAREA OPERATIVA'),
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
                ],
              ),
              const SizedBox(height: 8),

              Text(tituloFormateado, style: AppTypography.headline),
              const SizedBox(height: 20),

              // Recuadro de Ubicación
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
                      'UBICACIÓN EXACTA',
                      style: AppTypography.small.copyWith(fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tarea.ubicacion,
                      style: AppTypography.title.copyWith(fontSize: 22),
                    ),
                  ],
                ),
              ),

              // RECUADRO DE INSTRUCCIONES DEL VENDEDOR (Destacado)
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
                              'INSTRUCCIONES DE PREPARACIÓN',
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

              // Botón Excluyente 'LISTO' solo para tareas de preparación / pre-entrega (NO en LIBERADA)
              if (esPreEntrega && tarea.idDetalle != null) ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessingListo
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            _marcarListo(context);
                          },
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

              // Botón Excluyente de Salida / Barrera (solo cuando está LIBERADA)
              if (esLiberada) ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AuditoriaSalidaScreen(),
                        ),
                      );
                    },
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
                    onPressed: () async {
                      Navigator.pop(ctx);
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
      default:
        accentColor = AppPalette.neutral;
        buttonColor = AppPalette.neutral;
    }

    final esImpresion = tarea.tipoAlerta == 'IMPRESION';

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
                          tarea.ordenRef ?? (esImpresion ? 'PENDIENTE: IMPRESIÓN' : 'TAREA OPERATIVA'),
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
                    'UBICACIÓN DE RETIRO',
                    style: AppTypography.small.copyWith(fontSize: 10),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tarea.ubicacion,
                    style: AppTypography.title.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
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

    // 1. Estado Pagada / Salida (LIBERADA): Exclusivamente botón BARRERA (oculta LISTO)
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

    // 2. Estado Impresión QR: Botón IMPRIMIR
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

    // 3. Estado Reservada / Pre-entrega Pendiente (PREPARACION / TRASLADO): Botón LISTO + DETALLES (oculta BARRERA)
    return Row(
      children: [
        if (tarea.idDetalle != null) ...[
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 45,
              child: ElevatedButton.icon(
                key: Key('btn_listo_${tarea.idTarea}'),
                onPressed: _isProcessingListo ? null : () => _marcarListo(context),
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
