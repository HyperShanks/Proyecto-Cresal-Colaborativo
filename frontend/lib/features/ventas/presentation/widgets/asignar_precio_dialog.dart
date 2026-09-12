// lib/features/ventas/presentation/widgets/asignar_precio_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../models/pendiente_precio_model.dart';
import '../../services/inventario_service.dart';
import '../screens/catalogo_screen.dart';
import 'galeria_activo_widget.dart';

/// Diálogo modal interactivo para fijar el precio de referencia de un repuesto (HU-3.8).
class AsignarPrecioDialog extends StatefulWidget {
  final ActivoPendientePrecioModel activo;
  final VoidCallback onPrecioAsignado;

  const AsignarPrecioDialog({
    super.key,
    required this.activo,
    required this.onPrecioAsignado,
  });

  static Future<void> show(
    BuildContext context, {
    required ActivoPendientePrecioModel activo,
    required VoidCallback onPrecioAsignado,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AsignarPrecioDialog(
        activo: activo,
        onPrecioAsignado: onPrecioAsignado,
      ),
    );
  }

  @override
  State<AsignarPrecioDialog> createState() => _AsignarPrecioDialogState();
}

class _AsignarPrecioDialogState extends State<AsignarPrecioDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _precioController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _precioController.dispose();
    super.dispose();
  }

  int _obtenerMontoLimpio(String text) {
    final clean = text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(clean) ?? 0;
  }

  Future<void> _guardarPrecio() async {
    if (!_formKey.currentState!.validate()) return;

    final precio = _obtenerMontoLimpio(_precioController.text);
    if (precio <= 0) {
      setState(() {
        _errorMessage = 'El precio debe ser un monto mayor a \$0.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await InventarioService.asignarPrecio(
        widget.activo.idActivo,
        precio,
      );

      if (!mounted) return;

      Navigator.of(context).pop(); // Cierra el diálogo
      CatalogoScreen.refreshNotifier.value++;
      widget.onPrecioAsignado();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppPalette.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${response.mensaje} (${response.precioFormateado})',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppPalette.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: const BorderSide(color: Colors.white12, width: 1.0),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: AppPalette.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: const Icon(
              Icons.price_change_outlined,
              color: AppPalette.primary,
              size: 22.0,
            ),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Text(
              'Fijar Precio de Referencia',
              style: AppTypography.title.copyWith(fontSize: 17.0),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480.0,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Resumen del repuesto
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: AppPalette.background,
                    borderRadius: BorderRadius.circular(10.0),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.activo.tituloRepuesto,
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.0,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        'SKU: ${widget.activo.skuQrFisico} • ${widget.activo.fichaVehiculoDisplay}',
                        style: AppTypography.small.copyWith(
                          color: AppPalette.secondary,
                          fontSize: 12.0,
                        ),
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        widget.activo.especificacionesDisplay,
                        style: AppTypography.small.copyWith(
                          color: AppPalette.textSecondary,
                          fontSize: 11.0,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14.0),

                // Galería de Fotografías del Activo (SPEC-HU-TAREA-15)
                GaleriaActivoWidget(
                  fotografias: widget.activo.fotografias,
                  height: 190.0,
                ),

                const SizedBox(height: 16.0),

                // Campo de entrada de precio
                Text(
                  'PRECIO DE REFERENCIA (CLP)',
                  style: AppTypography.small.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 11.0,
                    letterSpacing: 0.8,
                    color: AppPalette.textSecondary,
                  ),
                ),
                const SizedBox(height: 8.0),

              TextFormField(
                controller: _precioController,
                keyboardType: TextInputType.number,
                autofocus: true,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _MilesTextInputFormatter(),
                ],
                style: AppTypography.title.copyWith(
                  fontSize: 20.0,
                  color: AppPalette.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  prefixStyle: AppTypography.title.copyWith(
                    fontSize: 20.0,
                    color: AppPalette.primary,
                    fontWeight: FontWeight.bold,
                  ),
                  hintText: 'Ej. 450.000',
                  hintStyle: AppTypography.body.copyWith(color: AppPalette.textSecondary),
                  filled: true,
                  fillColor: AppPalette.background,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppPalette.primary, width: 1.5),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Ingresa un precio de referencia';
                  }
                  final numVal = _obtenerMontoLimpio(val);
                  if (numVal <= 0) {
                    return 'El precio debe ser mayor a \$0';
                  }
                  return null;
                },
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12.0),
                Container(
                  padding: const EdgeInsets.all(10.0),
                  decoration: BoxDecoration(
                    color: AppPalette.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: AppPalette.error.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 18.0, color: AppPalette.error),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: AppTypography.small.copyWith(
                            color: AppPalette.error,
                            fontSize: 12.0,
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
      ),
    ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 48.0,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppPalette.textSecondary,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Cancelar', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12.0),
            Expanded(
              flex: 3,
              child: SizedBox(
                height: 48.0,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.primary,
                    foregroundColor: AppPalette.textPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: _isLoading ? null : _guardarPrecio,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppPalette.textPrimary,
                          ),
                        )
                      : const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Confirmar Precio',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Formateador de miles automático para CLP (ej. 100000 -> 100.000)
class _MilesTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return const TextEditingValue();

    final buffer = StringBuffer();
    int count = 0;
    for (int i = digitsOnly.length - 1; i >= 0; i--) {
      buffer.write(digitsOnly[i]);
      count++;
      if (count % 3 == 0 && i > 0) {
        buffer.write('.');
      }
    }
    final formatted = buffer.toString().split('').reversed.join('');

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
