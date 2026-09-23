import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../services/ventas_service.dart';
import 'dialogo_devolucion_dinero.dart';

/// Modal dialog interactivo para anulación de órdenes en Mesón de Ventas (SPEC-HU-TAREA-4)
class ModalAnularOrden extends StatefulWidget {
  final String idOrden;
  final String folio;
  final String? clienteNombre;
  final int? totalVenta;
  final int montoPagado;
  final VoidCallback? onOrdenAnulada;
  final http.Client? client;

  const ModalAnularOrden({
    super.key,
    required this.idOrden,
    required this.folio,
    this.clienteNombre,
    this.totalVenta,
    this.montoPagado = 0,
    this.onOrdenAnulada,
    this.client,
  });

  /// Helper estático para abrir el diálogo fácilmente
  static Future<bool?> mostrar(
    BuildContext context, {
    required String idOrden,
    required String folio,
    String? clienteNombre,
    int? totalVenta,
    int montoPagado = 0,
    VoidCallback? onOrdenAnulada,
    http.Client? client,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ModalAnularOrden(
        idOrden: idOrden,
        folio: folio,
        clienteNombre: clienteNombre,
        totalVenta: totalVenta,
        montoPagado: montoPagado,
        onOrdenAnulada: onOrdenAnulada,
        client: client,
      ),
    );
  }

  @override
  State<ModalAnularOrden> createState() => _ModalAnularOrdenState();
}

class _ModalAnularOrdenState extends State<ModalAnularOrden> {
  final TextEditingController _motivoController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  Future<void> _ejecutarAnulacion() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final motivo = _motivoController.text.trim();

    try {
      await VentasService.anularOrden(
        widget.idOrden,
        motivoAnulacion: motivo.isNotEmpty ? motivo : null,
        client: widget.client,
      );

      if (!mounted) return;

      widget.onOrdenAnulada?.call();

      // Cerrar modal de confirmación
      navigator.pop(true);

      // Si el cliente ya había pagado o abonado dinero, lanzar el modal de devolución persistente con 5s de timeout
      if (widget.montoPagado > 0) {
        await DialogoDevolucionDinero.mostrar(
          context,
          folio: widget.folio,
          montoADevolver: widget.montoPagado,
          clienteNombre: widget.clienteNombre,
        );
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 20.0),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text('Orden ${widget.folio} anulada exitosamente. Stock liberado a bodega.'),
                ),
              ],
            ),
            backgroundColor: AppPalette.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool tieneDineroPagado = widget.montoPagado > 0;
    final montoFormateado = CurrencyFormatter.formatCLP(widget.montoPagado);

    return AlertDialog(
      backgroundColor: AppPalette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(
          color: tieneDineroPagado
              ? AppPalette.error.withValues(alpha: 0.6)
              : Colors.white12,
          width: 1.2,
        ),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppPalette.error.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppPalette.error,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tieneDineroPagado
                      ? '⚠️ PELIGRO: CLIENTE YA PAGÓ'
                      : '¿Deshacer esta Orden?',
                  style: AppTypography.title.copyWith(
                    fontSize: 16,
                    color: tieneDineroPagado
                        ? AppPalette.error
                        : AppPalette.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Folio: ${widget.folio}',
                  style: AppTypography.small.copyWith(
                    color: AppPalette.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Alerta de Peligro si ya se registró pago o abono
            if (tieneDineroPagado) ...[
              Container(
                key: const Key('alerta_peligro_cliente_pago'),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppPalette.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppPalette.error.withValues(alpha: 0.5),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.report_problem_rounded,
                          color: AppPalette.error,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'EL CLIENTE YA TIENE DINERO PAGADO',
                            style: AppTypography.small.copyWith(
                              color: AppPalette.error,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text.rich(
                      TextSpan(
                        style: AppTypography.small.copyWith(
                          color: AppPalette.textPrimary,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                        children: [
                          const TextSpan(text: 'El cliente registra un pago/abono de '),
                          TextSpan(
                            text: montoFormateado,
                            style: const TextStyle(
                              color: AppPalette.error,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                          ),
                          const TextSpan(
                            text: '. Si confirmas la anulación, será ',
                          ),
                          const TextSpan(
                            text: 'OBLIGATORIO DEVOLVERLE ESTE DINERO ',
                            style: TextStyle(
                              color: AppPalette.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const TextSpan(
                            text: 'en Caja o Mesón de inmediato. ¿Estás seguro que quieres anular?',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (widget.clienteNombre != null &&
                widget.clienteNombre!.trim().isNotEmpty) ...[
              Text(
                'Cliente: ${widget.clienteNombre}',
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppPalette.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Impacto de la anulación en el sistema:',
                    style: AppTypography.small.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppPalette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '• La orden pasará inmediatamente a estado "Anulada".\n'
                    '• Los pagos asociados serán reversados en caja.\n'
                    '• Se generarán tareas de reingreso para que bodega reubique los repuestos vía PDA.',
                    style: AppTypography.small.copyWith(
                      color: AppPalette.textSecondary,
                      height: 1.3,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Motivo de anulación (opcional):',
              style: AppTypography.small.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _motivoController,
              maxLines: 2,
              enabled: !_isLoading,
              style: AppTypography.body.copyWith(fontSize: 13),
              decoration: InputDecoration(
                hintText:
                    'Ej: Cliente desistió de la compra, cambio de repuesto...',
                hintStyle: AppTypography.small.copyWith(
                  color: AppPalette.textSecondary,
                  fontSize: 12,
                ),
                filled: true,
                fillColor: AppPalette.background,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: AppPalette.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppPalette.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppPalette.error,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppPalette.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        // Botones en columna con ancho completo (Extend) para evitar overflow de píxeles
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                key: const Key('btn_confirmar_anulacion_orden'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.error,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.delete_forever, size: 18),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _isLoading ? 'Anulando...' : 'Confirmar Anulación',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                onPressed: _isLoading ? null : _ejecutarAnulacion,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppPalette.textSecondary,
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                onPressed: _isLoading
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Volver'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

