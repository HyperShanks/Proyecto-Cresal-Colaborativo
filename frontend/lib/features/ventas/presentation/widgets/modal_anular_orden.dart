import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../services/ventas_service.dart';

/// Modal dialog interactivo para anulación de órdenes en Mesón de Ventas (SPEC-HU-TAREA-4)
class ModalAnularOrden extends StatefulWidget {
  final String idOrden;
  final String folio;
  final String? clienteNombre;
  final int? totalVenta;
  final VoidCallback? onOrdenAnulada;

  const ModalAnularOrden({
    super.key,
    required this.idOrden,
    required this.folio,
    this.clienteNombre,
    this.totalVenta,
    this.onOrdenAnulada,
  });

  /// Helper estático para abrir el diálogo fácilmente
  static Future<bool?> mostrar(
    BuildContext context, {
    required String idOrden,
    required String folio,
    String? clienteNombre,
    int? totalVenta,
    VoidCallback? onOrdenAnulada,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ModalAnularOrden(
        idOrden: idOrden,
        folio: folio,
        clienteNombre: clienteNombre,
        totalVenta: totalVenta,
        onOrdenAnulada: onOrdenAnulada,
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
      );

      if (!mounted) return;

      widget.onOrdenAnulada?.call();

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 20.0),
              const SizedBox(width: 8.0),
              Expanded(
                child: Text('Orden ${widget.folio} anulada exitosamente. Pagos reversados y tareas de reingreso generadas.'),
              ),
            ],
          ),
          backgroundColor: AppPalette.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      navigator.pop(true);
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
    return AlertDialog(
      backgroundColor: AppPalette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: const BorderSide(color: Colors.white12, width: 1.0),
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppPalette.error.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.warning_amber_rounded, color: AppPalette.error, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('¿Deshacer esta Orden?', style: AppTypography.title.copyWith(fontSize: 18)),
                Text('Folio: ${widget.folio}', style: AppTypography.small.copyWith(color: AppPalette.secondary, fontWeight: FontWeight.w600)),
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
            if (widget.clienteNombre != null) ...[
              Text(
                'Cliente: ${widget.clienteNombre}',
                style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
            ],
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
                  Text(
                    'Impacto de la anulación en el sistema:',
                    style: AppTypography.small.copyWith(fontWeight: FontWeight.bold, color: AppPalette.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '• La orden pasará inmediatamente a estado "Anulada".\n'
                    '• Los pagos asociados serán reversados en caja.\n'
                    '• Se generarán tareas de reingreso para que el bodeguero reubique los repuestos vía PDA.',
                    style: AppTypography.small.copyWith(color: AppPalette.textSecondary, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Motivo de anulación (opcional):', style: AppTypography.small.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _motivoController,
              maxLines: 2,
              enabled: !_isLoading,
              style: AppTypography.body,
              decoration: InputDecoration(
                hintText: 'Ej: Cliente desistió de la compra, cambio de repuesto...',
                hintStyle: AppTypography.small.copyWith(color: AppPalette.textSecondary),
                filled: true,
                fillColor: AppPalette.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppPalette.primary, width: 1.5),
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
                    const Icon(Icons.error_outline, color: AppPalette.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_errorMessage!, style: const TextStyle(color: AppPalette.error, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: Text('Volver', style: AppTypography.button.copyWith(color: AppPalette.textSecondary)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppPalette.error,
            foregroundColor: AppPalette.textPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          ),
          icon: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.delete_outline, size: 18.0),
          label: Text(_isLoading ? 'Anulando...' : 'Confirmar Anulación'),
          onPressed: _isLoading ? null : _ejecutarAnulacion,
        ),
      ],
    );
  }
}
