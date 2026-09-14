import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../services/inventario_service.dart';

/// Modal para editar exclusivamente la ubicación logística de un activo en bodega (Pasillo, Pallet, Galpón).
/// Solo disponible para repuestos en estado 'Disponible' o 'Paletizado'.
class EditarActivoModal extends StatefulWidget {
  final Map<String, dynamic> activo;

  const EditarActivoModal({
    super.key,
    required this.activo,
  });

  @override
  State<EditarActivoModal> createState() => _EditarActivoModalState();
}

class _EditarActivoModalState extends State<EditarActivoModal> {
  late final TextEditingController _pasilloController;
  late final TextEditingController _palletController;
  late final TextEditingController _galponController;

  late final String _initialPasillo;
  late final String _initialPallet;
  late final String _initialGalpon;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _initialPasillo = (widget.activo['pasillo'] ?? widget.activo['ubicacion_pasillo'] ?? '').toString().trim();
    _initialPallet = (widget.activo['pallet'] ?? widget.activo['ubicacion_pallet'] ?? '').toString().trim();
    _initialGalpon = (widget.activo['galpon'] ?? widget.activo['ubicacion_galpon'] ?? '').toString().trim();

    _pasilloController = TextEditingController(text: _initialPasillo == 'S/P' ? '' : _initialPasillo);
    _palletController = TextEditingController(text: _initialPallet == 'S/P' ? '' : _initialPallet);
    _galponController = TextEditingController(text: _initialGalpon == 'S/G' ? '' : _initialGalpon);
  }

  @override
  void dispose() {
    _pasilloController.dispose();
    _palletController.dispose();
    _galponController.dispose();
    super.dispose();
  }

  bool _isFormDirty() {
    final curPasillo = _pasilloController.text.trim();
    final curPallet = _palletController.text.trim();
    final curGalpon = _galponController.text.trim();

    final initP = _initialPasillo == 'S/P' ? '' : _initialPasillo;
    final initPl = _initialPallet == 'S/P' ? '' : _initialPallet;
    final initG = _initialGalpon == 'S/G' ? '' : _initialGalpon;

    return curPasillo != initP || curPallet != initPl || curGalpon != initG;
  }

  Future<bool> _mostrarDialogoConfirmacionDescarte() async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.surface,
        title: Text(
          'Descartar cambios',
          style: AppTypography.title.copyWith(color: AppPalette.textPrimary),
        ),
        content: Text(
          'Tienes cambios sin guardar en la ubicación. ¿Estás seguro de que quieres salir y descartar las modificaciones?',
          style: AppTypography.body.copyWith(color: AppPalette.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Seguir editando',
              style: AppTypography.button.copyWith(color: AppPalette.neutral),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.error,
            ),
            child: Text(
              'Descartar',
              style: AppTypography.button.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  Future<void> _handleCancelOrClose() async {
    if (_isFormDirty()) {
      final shouldPop = await _mostrarDialogoConfirmacionDescarte();
      if (shouldPop && mounted) {
        Navigator.of(context).pop();
      }
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _guardarCambios() async {
    setState(() => _isSaving = true);
    try {
      final idActivo = widget.activo['id_activo']?.toString() ?? '';
      final versionLock = (widget.activo['version_lock'] as num?)?.toInt() ?? 1;

      final Map<String, dynamic> payload = {
        'version_lock_esperado': versionLock,
        'ubicacion_pasillo': _pasilloController.text.trim(),
        'ubicacion_pallet': _palletController.text.trim(),
        'ubicacion_galpon': _galponController.text.trim(),
      };

      final resultado = await InventarioService.editarActivo(idActivo, payload);

      if (!mounted) return;
      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ubicación actualizada exitosamente.',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppPalette.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pop({
        'ubicacion_pasillo': _pasilloController.text.trim(),
        'ubicacion_pallet': _palletController.text.trim(),
        'ubicacion_galpon': _galponController.text.trim(),
        'version_lock': resultado['version_lock'] ?? (versionLock + 1),
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);

      final errorMsg = e.toString().replaceFirst('Exception: ', '').replaceAll('"', '');

      if (errorMsg.contains('modificada por otro usuario recientemente')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMsg,
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: AppPalette.warning,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.of(context).pop({'conflict': true});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMsg,
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: AppPalette.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final sku = widget.activo['sku']?.toString() ?? widget.activo['sku_qr_fisico']?.toString() ?? 'S/N';
    final categoria = widget.activo['categoria']?.toString() ?? 'Repuesto';

    return PopScope(
      canPop: !_isFormDirty(),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _mostrarDialogoConfirmacionDescarte();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.70,
        ),
        padding: EdgeInsets.only(bottom: bottomInset),
        decoration: const BoxDecoration(
          color: AppPalette.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cabecera Modal
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppPalette.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(
                  bottom: BorderSide(
                    color: AppPalette.neutral.withValues(alpha: 0.15),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppPalette.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.edit_location_alt_rounded,
                      color: AppPalette.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Editar Ubicación de $categoria',
                          style: AppTypography.title.copyWith(
                            fontSize: 16,
                            color: AppPalette.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'SKU: $sku',
                          style: AppTypography.small.copyWith(
                            color: AppPalette.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppPalette.textSecondary),
                    onPressed: _handleCancelOrClose,
                    tooltip: 'Cerrar',
                  ),
                ],
              ),
            ),

            // Formulario Scrollable enfocado exclusivamente en ubicación
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'UBICACIÓN TÉCNICA Y LOGÍSTICA',
                      style: AppTypography.small.copyWith(
                        color: AppPalette.primary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Indica la posición física de almacenamiento del activo en bodega.',
                      style: AppTypography.small.copyWith(
                        color: AppPalette.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Fila Pasillo y Pallet
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _pasilloController,
                            label: 'Pasillo',
                            hintText: 'Ej. P-04',
                            icon: Icons.view_column_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _palletController,
                            label: 'Pallet',
                            hintText: 'Ej. PL-12',
                            icon: Icons.layers_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Galpón
                    _buildTextField(
                      controller: _galponController,
                      label: 'Galpón',
                      hintText: 'Ej. Galpón Central / G-A',
                      icon: Icons.warehouse_outlined,
                    ),
                  ],
                ),
              ),
            ),

            // Barra Inferior de Acciones
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppPalette.surface,
                border: Border(
                  top: BorderSide(
                    color: AppPalette.neutral.withValues(alpha: 0.15),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : _handleCancelOrClose,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: AppPalette.neutral.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'CANCELAR',
                        style: AppTypography.button.copyWith(color: AppPalette.textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _guardarCambios,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded, color: Colors.white),
                      label: Text(
                        _isSaving ? 'GUARDANDO...' : 'GUARDAR UBICACIÓN',
                        style: AppTypography.button.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppPalette.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.small.copyWith(
            fontWeight: FontWeight.bold,
            color: AppPalette.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: AppTypography.body.copyWith(color: AppPalette.textPrimary),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AppTypography.body.copyWith(color: AppPalette.textSecondary.withValues(alpha: 0.5)),
            prefixIcon: Icon(icon, color: AppPalette.primary, size: 20),
            filled: true,
            fillColor: AppPalette.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppPalette.neutral.withValues(alpha: 0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppPalette.neutral.withValues(alpha: 0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppPalette.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
