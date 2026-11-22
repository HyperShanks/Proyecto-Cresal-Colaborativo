import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../models/historial_caja_model.dart';
import '../../services/caja_service.dart';

/// Diálogo modal intuitivo y responsivo para editar registros de pagos y abonos (SPEC-HU-03 / SPEC-HU-4.5).
/// Cumple con las garantías de no-overflow, trazabilidad de auditoría y recálculo dinámico en vivo.
class EditarPagoDialog extends StatefulWidget {
  final HistorialOrdenItemModel orden;
  final HistorialPagoDetalleModel pago;
  final ICajaService? cajaService;

  const EditarPagoDialog({
    super.key,
    required this.orden,
    required this.pago,
    this.cajaService,
  });

  static Future<bool?> show({
    required BuildContext context,
    required HistorialOrdenItemModel orden,
    required HistorialPagoDetalleModel pago,
    ICajaService? cajaService,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EditarPagoDialog(
        orden: orden,
        pago: pago,
        cajaService: cajaService,
      ),
    );
  }

  @override
  State<EditarPagoDialog> createState() => _EditarPagoDialogState();
}

class _EditarPagoDialogState extends State<EditarPagoDialog> {
  late final ICajaService _cajaService;
  late String _metodoSeleccionado;
  late final TextEditingController _montoController;
  late final TextEditingController _motivoController;
  final _formKey = GlobalKey<FormState>();

  bool _isSaving = false;
  String? _errorMessage;

  bool get _esReservada => widget.orden.estadoOrden.toLowerCase() == 'reservada';

  @override
  void initState() {
    super.initState();
    _cajaService = widget.cajaService ?? CajaService();
    _metodoSeleccionado = _normalizarMetodo(widget.pago.metodoPago);
    _montoController = TextEditingController(
      text: CurrencyFormatter.formatNumber(widget.pago.monto),
    );
    _motivoController = TextEditingController();
  }

  @override
  void dispose() {
    _montoController.dispose();
    _motivoController.dispose();
    super.dispose();
  }

  String _normalizarMetodo(String raw) {
    final lower = raw.toLowerCase().trim();
    if (lower.contains('debito') || lower.contains('débito')) return 'Debito';
    if (lower.contains('credito') || lower.contains('crédito')) return 'Credito';
    if (lower.contains('transferencia')) return 'Transferencia';
    if (lower.contains('cheque')) return 'Cheque';
    return 'Efectivo';
  }

  int get _montoIngresado => CurrencyFormatter.parse(_montoController.text);

  bool get _montoInvalido => _esReservada && _montoIngresado <= 0;

  int get _nuevoSaldoPendiente {
    if (!_esReservada) return widget.orden.montoPendiente;
    // Suma de otros abonos
    final otrosPagos = widget.orden.desglosePagos
        .where((p) => p.idTransaccion != widget.pago.idTransaccion)
        .fold<int>(0, (acc, p) => acc + p.monto);
    final nuevoTotalAbonos = otrosPagos + _montoIngresado;
    final saldo = widget.orden.totalVenta - nuevoTotalAbonos;
    return saldo < 0 ? 0 : saldo;
  }

  bool get _superaTotalVenta {
    if (!_esReservada) return false;
    final otrosPagos = widget.orden.desglosePagos
        .where((p) => p.idTransaccion != widget.pago.idTransaccion)
        .fold<int>(0, (acc, p) => acc + p.monto);
    return (otrosPagos + _montoIngresado) >= widget.orden.totalVenta;
  }

  bool get _montoModificado => _esReservada && _montoIngresado != widget.pago.monto;

  bool get _metodoModificado => _metodoSeleccionado != _normalizarMetodo(widget.pago.metodoPago);

  bool get _hayCambios => (_montoModificado && !_montoInvalido) || _metodoModificado;

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;

    if (_montoInvalido) {
      setState(() {
        _errorMessage = 'El monto del abono debe ser estrictamente mayor a \$0.';
      });
      return;
    }

    if (_esReservada && _superaTotalVenta) {
      setState(() {
        _errorMessage = 'El nuevo monto liquidaría el total de la orden. Para liquidar, use el módulo de cobro en ventanilla.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final idPagoStr = widget.pago.idTransaccion;
      if (idPagoStr == null || idPagoStr.isEmpty) {
        throw Exception('No se encontró el ID de transacción para editar.');
      }

      int? nuevoMontoPayload;
      if (_montoModificado) {
        nuevoMontoPayload = _montoIngresado;
      }

      String? nuevoMetodoPayload;
      if (_metodoModificado) {
        nuevoMetodoPayload = _metodoSeleccionado;
      }

      if (!_hayCambios) {
        throw Exception('No se han modificado valores en el pago.');
      }

      await _cajaService.editarPago(
        idPago: idPagoStr,
        nuevoMonto: nuevoMontoPayload,
        nuevoMetodo: nuevoMetodoPayload,
        motivo: _motivoController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppPalette.surfaceLight,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppPalette.neutral.withValues(alpha: 0.2),
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 560,
        constraints: const BoxConstraints(maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Cabecera ──
            _buildHeader(),
            Divider(height: 1, color: AppPalette.neutral.withValues(alpha: 0.15)),

            // ── Formulario Scrollable ──
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Banner de Contexto de la Orden
                      _buildResumenOrdenCard(),
                      const SizedBox(height: 16),

                      // Campo 1: Método de Pago
                      _buildSelectorMetodoPago(),
                      const SizedBox(height: 16),

                      // Campo 2: Monto del Abono
                      _buildInputMonto(),
                      const SizedBox(height: 16),

                      // Dato informativo de solo lectura: Fecha de Imputación Contable
                      _buildFechaSoloLectura(),
                      const SizedBox(height: 16),

                      // Campo 4: Motivo de la Corrección (Obligatorio)
                      _buildInputMotivo(),

                      // Error Banner si aplica
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 14),
                        _buildErrorBanner(_errorMessage!),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            Divider(height: 1, color: AppPalette.neutral.withValues(alpha: 0.15)),

            // ── Barra de Acciones Inferior ──
            _buildFooterActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppPalette.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.edit_note_rounded,
              color: AppPalette.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Corregir Registro de Pago',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.title.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.textPrimaryLight,
                  ),
                ),
                Text(
                  'Folio: ${widget.orden.folio} • Estado: ${widget.orden.estadoOrden}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.small.copyWith(
                    fontSize: 12,
                    color: AppPalette.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            color: AppPalette.textSecondaryLight,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenOrdenCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.backgroundLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppPalette.neutral.withValues(alpha: 0.15)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 360;
          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildResumenItem('TOTAL VENTA', CurrencyFormatter.formatCLP(widget.orden.totalVenta), AppPalette.textPrimaryLight),
                const SizedBox(height: 8),
                _buildResumenItem('MONTO PAGO ACTUAL', CurrencyFormatter.formatCLP(widget.pago.monto), AppPalette.primary),
                const SizedBox(height: 8),
                _buildResumenItem(
                  'SALDO RESTANTE',
                  CurrencyFormatter.formatCLP(widget.orden.montoPendiente),
                  widget.orden.montoPendiente > 0 ? AppPalette.warning : AppPalette.success,
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(
                child: _buildResumenItem('TOTAL VENTA', CurrencyFormatter.formatCLP(widget.orden.totalVenta), AppPalette.textPrimaryLight),
              ),
              Container(height: 28, width: 1, color: AppPalette.neutral.withValues(alpha: 0.2)),
              const SizedBox(width: 12),
              Expanded(
                child: _buildResumenItem('MONTO PAGO ACTUAL', CurrencyFormatter.formatCLP(widget.pago.monto), AppPalette.primary),
              ),
              Container(height: 28, width: 1, color: AppPalette.neutral.withValues(alpha: 0.2)),
              const SizedBox(width: 12),
              Expanded(
                child: _buildResumenItem(
                  'SALDO RESTANTE',
                  CurrencyFormatter.formatCLP(widget.orden.montoPendiente),
                  widget.orden.montoPendiente > 0 ? AppPalette.warning : AppPalette.success,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildResumenItem(String title, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.small.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: AppPalette.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.body.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectorMetodoPago() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MÉTODO DE PAGO',
          style: AppTypography.small.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 0.5,
            color: AppPalette.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _metodoSeleccionado,
          isExpanded: true,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: AppPalette.backgroundLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppPalette.neutral.withValues(alpha: 0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppPalette.neutral.withValues(alpha: 0.2)),
            ),
          ),
          items: const [
            DropdownMenuItem(value: 'Efectivo', child: Text('Efectivo')),
            DropdownMenuItem(value: 'Debito', child: Text('Tarjeta de Débito')),
            DropdownMenuItem(value: 'Credito', child: Text('Tarjeta de Crédito')),
            DropdownMenuItem(value: 'Transferencia', child: Text('Transferencia Bancaria')),
            DropdownMenuItem(value: 'Cheque', child: Text('Cheque')),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() => _metodoSeleccionado = val);
            }
          },
        ),
      ],
    );
  }

  Widget _buildInputMonto() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'MONTO DEL ABONO',
                style: AppTypography.small.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 0.5,
                  color: AppPalette.textSecondaryLight,
                ),
              ),
              if (!_esReservada)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppPalette.neutral.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Bloqueado en ${widget.orden.estadoOrden}',
                    style: AppTypography.small.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.textSecondaryLight,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _montoController,
          enabled: _esReservada,
          keyboardType: TextInputType.number,
          inputFormatters: [MilesTextInputFormatter()],
          style: AppTypography.body.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: _esReservada ? AppPalette.textPrimaryLight : AppPalette.disabledText,
          ),
          decoration: InputDecoration(
            prefixText: '\$ ',
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: _esReservada ? AppPalette.backgroundLight : AppPalette.neutral.withValues(alpha: 0.08),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppPalette.neutral.withValues(alpha: 0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppPalette.neutral.withValues(alpha: 0.2)),
            ),
            helperText: _esReservada
                ? 'Nuevo saldo pendiente resultante: ${CurrencyFormatter.formatCLP(_nuevoSaldoPendiente)}'
                : 'Para órdenes pagadas o entregadas, anule la orden para liberar el stock.',
            helperStyle: TextStyle(
              fontSize: 12,
              color: _superaTotalVenta ? AppPalette.error : const Color(0xFF0F766E),
              fontWeight: FontWeight.w700,
            ),
          ),
          onChanged: (_) => setState(() {}),
          validator: (val) {
            if (!_esReservada) return null;
            final m = CurrencyFormatter.parse(val);
            if (m <= 0) return 'El monto debe ser mayor a \$0';
            if (_superaTotalVenta) return 'El abono no puede liquidar el 100% de la venta';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildFechaSoloLectura() {
    final fechaRef = widget.pago.fechaPago;
    final String fechaStr;
    if (fechaRef != null) {
      final dia = fechaRef.day.toString().padLeft(2, '0');
      final mes = fechaRef.month.toString().padLeft(2, '0');
      final anio = fechaRef.year;
      final hora = fechaRef.hour.toString().padLeft(2, '0');
      final min = fechaRef.minute.toString().padLeft(2, '0');
      fechaStr = '$dia/$mes/$anio a las $hora:$min hrs';
    } else {
      fechaStr = 'Fecha original del comprobante';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FECHA Y HORA DE IMPUTACIÓN (INMUTABLE)',
          style: AppTypography.small.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 0.5,
            color: AppPalette.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: AppPalette.neutral.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppPalette.neutral.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_clock_rounded, size: 16, color: AppPalette.textSecondaryLight),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fechaStr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.textSecondaryLight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputMotivo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 2,
          children: [
            Text(
              'MOTIVO DE LA CORRECCIÓN',
              style: AppTypography.small.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 0.5,
                color: AppPalette.textSecondaryLight,
              ),
            ),
            Text(
              '*(Obligatorio para auditoría)',
              style: AppTypography.small.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppPalette.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _motivoController,
          maxLines: 2,
          maxLength: 150,
          style: AppTypography.body.copyWith(
            fontSize: 13,
            color: AppPalette.textPrimaryLight,
          ),
          decoration: InputDecoration(
            hintText: 'Ej: Cajero seleccionó Efectivo por error; cliente pagó con Transferencia BancoEstado.',
            hintStyle: AppTypography.small.copyWith(
              fontSize: 12,
              color: AppPalette.textSecondaryLight.withValues(alpha: 0.65),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: AppPalette.backgroundLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppPalette.neutral.withValues(alpha: 0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppPalette.neutral.withValues(alpha: 0.2)),
            ),
          ),
          validator: (val) {
            if (val == null || val.trim().length < 10) {
              return 'Ingrese un motivo claro de al menos 10 caracteres.';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String error) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppPalette.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppPalette.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 16, color: AppPalette.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: AppTypography.small.copyWith(
                color: AppPalette.error,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            TextButton(
              onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
              child: Text(
                'Cancelar',
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppPalette.textSecondaryLight,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppPalette.neutral.withValues(alpha: 0.22),
                disabledForegroundColor: AppPalette.textSecondaryLight.withValues(alpha: 0.45),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: (_isSaving || !_hayCambios || _montoInvalido) ? null : _guardarCambios,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Guardar',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
