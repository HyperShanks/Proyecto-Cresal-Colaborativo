import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../services/inventario_service.dart';

/// Diálogo de seguridad anti-equivocación para despaletizar un activo y devolverlo
/// al estado "En Desarme".
///
/// Implementa un temporizador regresivo de 5 segundos durante el cual el botón de
/// confirmación permanece deshabilitado para evitar pulsaciones impulsivas o accidentales.
class DialogoDespaletizar extends StatefulWidget {
  final String idActivo;
  final String sku;
  final String categoria;
  final String? numeroIngreso;

  const DialogoDespaletizar({
    super.key,
    required this.idActivo,
    required this.sku,
    required this.categoria,
    this.numeroIngreso,
  });

  /// Método de utilidad para mostrar el diálogo.
  /// Retorna `true` si el activo fue despaletizado exitosamente.
  static Future<bool?> mostrar(
    BuildContext context, {
    required String idActivo,
    required String sku,
    required String categoria,
    String? numeroIngreso,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DialogoDespaletizar(
        idActivo: idActivo,
        sku: sku,
        categoria: categoria,
        numeroIngreso: numeroIngreso,
      ),
    );
  }

  @override
  State<DialogoDespaletizar> createState() => _DialogoDespaletizarState();
}

class _DialogoDespaletizarState extends State<DialogoDespaletizar> {
  int _segundosRestantes = 5;
  Timer? _timer;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _iniciarCuentaRegresiva();
  }

  void _iniciarCuentaRegresiva() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_segundosRestantes > 1) {
        setState(() {
          _segundosRestantes--;
        });
      } else {
        setState(() {
          _segundosRestantes = 0;
        });
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _ejecutarDespaletizado() async {
    setState(() => _isLoading = true);
    try {
      await InventarioService.despaletizarActivo(widget.idActivo);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceAll('Exception: ', ''),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppPalette.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final folioStr = widget.numeroIngreso != null && widget.numeroIngreso!.isNotEmpty
        ? 'Folio Ingreso: ${widget.numeroIngreso}'
        : 'SKU: ${widget.sku}';

    return AlertDialog(
      backgroundColor: AppPalette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppPalette.error.withValues(alpha: 0.3)),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppPalette.error.withValues(alpha: 0.15),
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
              children: [
                Text(
                  'Despaletizar Repuesto',
                  style: AppTypography.title.copyWith(
                    color: AppPalette.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  folioStr,
                  style: AppTypography.small.copyWith(
                    color: AppPalette.textSecondary,
                    fontSize: 12,
                  ),
                ),
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppPalette.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppPalette.error.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: AppPalette.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Esta acción devolverá este repuesto (${widget.categoria}) al estado "En Desarme".',
                      style: AppTypography.body.copyWith(
                        color: AppPalette.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Consecuencias de esta acción:',
              style: AppTypography.small.copyWith(
                color: AppPalette.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 11.5,
              ),
            ),
            const SizedBox(height: 8),
            _buildCheckItem('Se liberará la ubicación física (Galpón, Pasillo y Pallet).'),
            _buildCheckItem('El estado del QR físico se restablecerá a pendiente.'),
            _buildCheckItem('Se desvincularán las fotos comerciales registradas.'),
            _buildCheckItem('El repuesto volverá a aparecer en "Pendientes de Paletizado".'),
            const SizedBox(height: 14),

            // Banner del contador de seguridad
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppPalette.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _segundosRestantes > 0
                      ? AppPalette.neutral.withValues(alpha: 0.3)
                      : AppPalette.success.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_segundosRestantes > 0) ...[
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: (5 - _segundosRestantes) / 5.0,
                        color: AppPalette.warning,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Por seguridad, espera $_segundosRestantes s para confirmar...',
                      style: AppTypography.small.copyWith(
                        color: AppPalette.warning,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ] else ...[
                    const Icon(Icons.check_circle_outline, color: AppPalette.success, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Verificación completa. Ya puedes confirmar.',
                      style: AppTypography.small.copyWith(
                        color: AppPalette.success,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('btn_cancelar_despaletizado'),
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: Text(
            'CANCELAR',
            style: AppTypography.button.copyWith(color: AppPalette.textSecondary),
          ),
        ),
        ElevatedButton.icon(
          key: const Key('btn_confirmar_despaletizado'),
          onPressed: (_segundosRestantes == 0 && !_isLoading) ? _ejecutarDespaletizado : null,
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  Icons.undo_rounded,
                  size: 18,
                  color: _segundosRestantes == 0 ? Colors.white : Colors.white38,
                ),
          label: Text(
            _isLoading
                ? 'REVIRTIENDO...'
                : (_segundosRestantes > 0 ? 'CONFIRMAR (${_segundosRestantes}s)' : 'CONFIRMAR DESPALETIZADO'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: _segundosRestantes == 0 ? Colors.white : Colors.white38,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppPalette.error,
            disabledBackgroundColor: AppPalette.error.withValues(alpha: 0.25),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.arrow_right_rounded, color: AppPalette.error, size: 18),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: AppTypography.small.copyWith(
                color: AppPalette.textSecondary,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
