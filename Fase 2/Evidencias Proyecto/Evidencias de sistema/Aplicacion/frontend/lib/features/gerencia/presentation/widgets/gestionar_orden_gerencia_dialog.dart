// frontend/lib/features/gerencia/presentation/widgets/gestionar_orden_gerencia_dialog.dart
import 'package:flutter/material.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../../caja/models/historial_caja_model.dart';
import '../../../caja/presentation/widgets/cobro_pendiente_card.dart';
import '../../services/gerencia_service.dart';

/// Modal administrativo para que Gerencia/Administrador edite el estado de una orden,
/// liquide automáticamente saldos pendientes al pasar a Pagada/Completada, reasigne vendedor,
/// anule o elimine definitivamente una orden del historial (SPEC-HU-TAREA-25).
class GestionarOrdenGerenciaDialog extends StatefulWidget {
  final HistorialOrdenItemModel orden;

  const GestionarOrdenGerenciaDialog({
    super.key,
    required this.orden,
  });

  static Future<bool?> show(
    BuildContext context,
    HistorialOrdenItemModel orden,
  ) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.48),
      builder: (ctx) => GestionarOrdenGerenciaDialog(orden: orden),
    );
  }

  @override
  State<GestionarOrdenGerenciaDialog> createState() =>
      _GestionarOrdenGerenciaDialogState();
}

class _GestionarOrdenGerenciaDialogState
    extends State<GestionarOrdenGerenciaDialog> {
  static const List<({String valor, String titulo, String subtitulo, Color color})>
      _estadosDisponibles = [
    (
      valor: 'Reservada',
      titulo: 'Reservada',
      subtitulo: 'Pendiente de pago o con abono parcial',
      color: Color(0xFFD97706),
    ),
    (
      valor: 'Pagada',
      titulo: 'Pagada',
      subtitulo: 'Pago liquidado, lista para entrega o barrera',
      color: Color(0xFF0284C7),
    ),
    (
      valor: 'Despachada',
      titulo: 'Despachada',
      subtitulo: 'Enviada por courier o traslado',
      color: Color(0xFF7C3AED),
    ),
    (
      valor: 'Completada',
      titulo: 'Completada (Entregada)',
      subtitulo: 'Ciclo cerrado y piezas entregadas al cliente',
      color: Color(0xFF059669),
    ),
    (
      valor: 'Anulada',
      titulo: 'Anulada',
      subtitulo: 'Reversa pagos y devuelve piezas a stock',
      color: Color(0xFFDC2626),
    ),
  ];

  static const List<String> _metodosPago = [
    'Efectivo',
    'Transferencia',
    'Débito',
    'Crédito',
    'Cheque',
  ];

  late String _estadoSeleccionado;
  bool _liquidarAutomaticamente = true;
  String _metodoPagoSeleccionado = 'Efectivo';
  String? _idNuevoVendedor;
  late final TextEditingController _motivoController;

  List<Map<String, dynamic>> _vendedores = [];
  bool _cargandoVendedores = true;

  bool _procesando = false;
  String? _errorMensaje;

  @override
  void initState() {
    super.initState();
    _estadoSeleccionado = _normalizarEstadoInicial(widget.orden.estadoOrden);
    _motivoController = TextEditingController();
    _cargarVendedores();
  }

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  String _normalizarEstadoInicial(String raw) {
    final lower = raw.trim().toLowerCase();
    for (final est in _estadosDisponibles) {
      if (est.valor.toLowerCase() == lower) {
        return est.valor;
      }
    }
    return 'Reservada';
  }

  Future<void> _cargarVendedores() async {
    try {
      final list = await GerenciaService.obtenerVendedoresActivos();
      if (!mounted) return;
      setState(() {
        _vendedores = list;
        _cargandoVendedores = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargandoVendedores = false);
    }
  }

  int get _saldoPorPagar {
    if (widget.orden.esAnulada) {
      return widget.orden.totalVenta;
    }
    if (widget.orden.montoPendiente > 0) {
      return widget.orden.montoPendiente;
    }
    final diff = widget.orden.totalVenta - widget.orden.totalLiquidado;
    return diff > 0 ? diff : 0;
  }

  bool get _requierePagoAlCompletar =>
      (_estadoSeleccionado == 'Pagada' ||
          _estadoSeleccionado == 'Despachada' ||
          _estadoSeleccionado == 'Completada') &&
      _saldoPorPagar > 0;

  bool get _hayCambios {
    final cambioEstado =
        _estadoSeleccionado.toLowerCase() != widget.orden.estadoOrden.toLowerCase();
    final cambioVendedor = _idNuevoVendedor != null;
    final liquidaPendiente = _requierePagoAlCompletar && _liquidarAutomaticamente;
    return cambioEstado || cambioVendedor || liquidaPendiente;
  }

  Future<void> _guardarCambios() async {
    if (!_hayCambios) {
      setState(() {
        _errorMensaje =
            'Selecciona un nuevo estado, vendedor o activa la liquidación automática para aplicar cambios.';
      });
      return;
    }

    if (_estadoSeleccionado == 'Anulada' &&
        widget.orden.estadoOrden != 'Anulada' &&
        _motivoController.text.trim().length < 5) {
      setState(() {
        _errorMensaje =
            'Ingresa un motivo administrativo breve (mínimo 5 caracteres) para anular la orden.';
      });
      return;
    }

    setState(() {
      _procesando = true;
      _errorMensaje = null;
    });

    try {
      final res = await GerenciaService.editarOrdenGerencia(
        idOrden: widget.orden.idOrden,
        nuevoEstado: _estadoSeleccionado,
        liquidarSaldoPendiente: _liquidarAutomaticamente,
        metodoPagoLiquidacion: _metodoPagoSeleccionado,
        idNuevoVendedor: _idNuevoVendedor,
        motivo: _motivoController.text.trim(),
      );

      if (!mounted) return;
      final mensaje = (res['mensaje'] as String?) ??
          'Orden ${widget.orden.folioDisplay} actualizada correctamente.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mensaje,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.of(context).pop(true);
    } on CustomApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMensaje = e.messageUser;
        _procesando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMensaje = ApiService.limpiarMensajeExcepcion(e);
        _procesando = false;
      });
    }
  }

  Future<void> _confirmarYEliminarOrden() async {
    final confirmado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.delete_forever_rounded,
                color: Color(0xFFDC2626),
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Eliminar ${widget.orden.folioDisplay} del historial',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Esta acción eliminará definitivamente la orden, sus registros de pago y su trazabilidad de barrera.\n\n'
          'Los activos inventariados asociados (si existen) serán devueltos automáticamente a estado disponible en bodega. '
          'Si deseas conservar el registro histórico para auditoría contable, es recomendable usar el estado "Anulada".',
          style: AppTypography.small.copyWith(
            color: const Color(0xFF334155),
            fontSize: 13,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.delete_outline_rounded, size: 17),
            label: const Text(
              'Sí, eliminar definitivamente',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmado != true || !mounted) return;

    setState(() {
      _procesando = true;
      _errorMensaje = null;
    });

    try {
      final res = await GerenciaService.eliminarOrdenGerencia(
        idOrden: widget.orden.idOrden,
      );
      if (!mounted) return;

      final mensaje = (res['mensaje'] as String?) ??
          'Orden ${widget.orden.folioDisplay} eliminada del historial.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mensaje,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.of(context).pop(true);
    } on CustomApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMensaje = e.messageUser;
        _procesando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMensaje = ApiService.limpiarMensajeExcepcion(e);
        _procesando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 12,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 740),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 22, 26, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabecera
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.edit_note_rounded,
                      color: Color(0xFF0284C7),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GESTIÓN ADMINISTRATIVA DE ORDEN',
                          style: AppTypography.small.copyWith(
                            color: const Color(0xFF94A3B8),
                            fontWeight: FontWeight.w800,
                            fontSize: 10.5,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.orden.folioDisplay,
                          style: AppTypography.headline.copyWith(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                    onPressed: _procesando ? null : () => Navigator.of(context).pop(false),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Resumen financiero rápido
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    _buildMiniStat(
                      'Total Orden',
                      CobroPendienteCard.formatClp(widget.orden.totalVenta),
                      const Color(0xFF0F172A),
                    ),
                    _buildVerticalDivider(),
                    _buildMiniStat(
                      'Pagado / Abonado',
                      CobroPendienteCard.formatClp(widget.orden.totalLiquidado),
                      const Color(0xFF059669),
                    ),
                    _buildVerticalDivider(),
                    _buildMiniStat(
                      'Saldo Pendiente',
                      _saldoPorPagar > 0
                          ? CobroPendienteCard.formatClp(_saldoPorPagar)
                          : '—',
                      _saldoPorPagar > 0
                          ? const Color(0xFFC2410C)
                          : const Color(0xFF64748B),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Cuerpo scrollable
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_errorMensaje != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(11),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 18,
                                color: Color(0xFFDC2626),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMensaje!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFB91C1C),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // 1. Selector de Estado
                      Text(
                        'ESTADO OFICIAL DE LA ORDEN',
                        style: AppTypography.small.copyWith(
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _estadoSeleccionado,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: _estadosDisponibles.map((est) {
                          return DropdownMenuItem<String>(
                            value: est.valor,
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: est.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  est.titulo,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: _procesando
                            ? null
                            : (val) {
                                if (val != null) {
                                  setState(() {
                                    _estadoSeleccionado = val;
                                    _errorMensaje = null;
                                  });
                                }
                              },
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _estadosDisponibles
                            .firstWhere((e) => e.valor == _estadoSeleccionado)
                            .subtitulo,
                        style: AppTypography.small.copyWith(
                          color: const Color(0xFF64748B),
                          fontSize: 11.5,
                        ),
                      ),

                      // 2. Auto-liquidación de saldo pendiente
                      if (_requierePagoAlCompletar) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap: _procesando
                                    ? null
                                    : () {
                                        setState(() {
                                          _liquidarAutomaticamente =
                                              !_liquidarAutomaticamente;
                                        });
                                      },
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: Checkbox(
                                        value: _liquidarAutomaticamente,
                                        activeColor: const Color(0xFF059669),
                                        onChanged: _procesando
                                            ? null
                                            : (val) {
                                                setState(() {
                                                  _liquidarAutomaticamente =
                                                      val ?? true;
                                                });
                                              },
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Auto-liquidar saldo pendiente (${CobroPendienteCard.formatClp(_saldoPorPagar)})',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF065F46),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Se calculará y registrará automáticamente como pagado lo que faltaba por cobrar al pasar a "$_estadoSeleccionado".',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              color: Color(0xFF047857),
                                              height: 1.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_liquidarAutomaticamente) ...[
                                const SizedBox(height: 12),
                                const Text(
                                  'MÉTODO DE PAGO DEL SALDO FALTANTE:',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF065F46),
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: _metodosPago.map((metodo) {
                                    final seleccionado =
                                        _metodoPagoSeleccionado == metodo;
                                    return ChoiceChip(
                                      label: Text(
                                        metodo,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: seleccionado
                                              ? Colors.white
                                              : const Color(0xFF065F46),
                                        ),
                                      ),
                                      selected: seleccionado,
                                      selectedColor: const Color(0xFF059669),
                                      backgroundColor: Colors.white,
                                      side: BorderSide(
                                        color: seleccionado
                                            ? const Color(0xFF059669)
                                            : const Color(0xFFA7F3D0),
                                      ),
                                      onSelected: _procesando
                                          ? null
                                          : (_) {
                                              setState(() {
                                                _metodoPagoSeleccionado = metodo;
                                              });
                                            },
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // 3. Reasignación de Vendedor Titular
                      Text(
                        'REASIGNAR VENDEDOR TITULAR (OPCIONAL)',
                        style: AppTypography.small.copyWith(
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_cargandoVendedores)
                        const LinearProgressIndicator(minHeight: 2)
                      else
                        DropdownButtonFormField<String?>(
                          initialValue: _idNuevoVendedor,
                          isExpanded: true,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                'Mantener actual: ${widget.orden.vendedorNombre}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF475569),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            ..._vendedores.map((v) {
                              final idUsr = v['id_usuario']?.toString() ?? '';
                              final nom = v['nombre_completo']?.toString() ?? '';
                              final rolNom = v['rol_nombre']?.toString() ?? '';
                              return DropdownMenuItem<String?>(
                                value: idUsr,
                                child: Text(
                                  rolNom.isNotEmpty ? '$nom ($rolNom)' : nom,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF0F172A),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }),
                          ],
                          onChanged: _procesando
                              ? null
                              : (val) => setState(() => _idNuevoVendedor = val),
                        ),

                      const SizedBox(height: 16),

                      // 4. Motivo / Observación
                      Text(
                        _estadoSeleccionado == 'Anulada'
                            ? 'MOTIVO DE ANULACIÓN (REQUERIDO)'
                            : 'OBSERVACIÓN ADMINISTRATIVA (OPCIONAL)',
                        style: AppTypography.small.copyWith(
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _motivoController,
                        maxLines: 2,
                        enabled: !_procesando,
                        decoration: InputDecoration(
                          hintText: _estadoSeleccionado == 'Anulada'
                              ? 'Ej: Devolución autorizada por gerencia o error de emisión...'
                              : 'Ej: Ajuste de estado autorizado por gerencia...',
                          hintStyle: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF94A3B8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // 5. Eliminación definitiva
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              size: 20,
                              color: Color(0xFFDC2626),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Eliminar del historial',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF991B1B),
                                    ),
                                  ),
                                  Text(
                                    'Borra la orden y devuelve sus piezas inventariadas a stock.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFFB91C1C),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFDC2626),
                                side: const BorderSide(color: Color(0xFFFCA5A5)),
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: _procesando ? null : _confirmarYEliminarOrden,
                              icon: const Icon(Icons.delete_outline_rounded, size: 16),
                              label: const Text(
                                'Eliminar',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Botones inferiores
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF475569),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _procesando
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 42,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppPalette.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _procesando ? null : _guardarCambios,
                        icon: _procesando
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline_rounded, size: 18),
                        label: Text(
                          _procesando ? 'Aplicando...' : 'Guardar Cambios',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
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

  Widget _buildMiniStat(String label, String value, Color valueColor) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: const Color(0xFFE2E8F0),
    );
  }
}
