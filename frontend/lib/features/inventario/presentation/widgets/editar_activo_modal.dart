import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../services/inventario_service.dart';

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
  late final TextEditingController _observacionController;
  late final TextEditingController _numeroMotorController;
  late final TextEditingController _cilindradaController;

  late final String _initialPasillo;
  late final String _initialPallet;
  late final String _initialGalpon;
  late final String _initialObservacion;
  late final String _initialNumeroMotor;
  late final String _initialCilindrada;

  bool _isSaving = false;
  late final bool _esMotor;

  @override
  void initState() {
    super.initState();

    final cat = widget.activo['categoria']?.toString().toUpperCase() ?? '';
    _esMotor = cat.contains('MOTOR');

    _initialPasillo = (widget.activo['pasillo'] ?? widget.activo['ubicacion_pasillo'] ?? '').toString().trim();
    _initialPallet = (widget.activo['pallet'] ?? widget.activo['ubicacion_pallet'] ?? '').toString().trim();
    _initialGalpon = (widget.activo['galpon'] ?? widget.activo['ubicacion_galpon'] ?? '').toString().trim();

    final rawObs = (widget.activo['observacion'] ?? widget.activo['observacion_estado'] ?? '').toString().trim();
    _initialObservacion = rawObs == 'Sin observaciones registradas.' ? '' : rawObs;

    _initialNumeroMotor = (widget.activo['numero_motor'] ?? '').toString().trim();
    _initialCilindrada = (widget.activo['cilindrada'] ?? '').toString().trim();
    final cleanCilindrada = _initialCilindrada == 'N/A' ? '' : _initialCilindrada;

    _pasilloController = TextEditingController(text: _initialPasillo);
    _palletController = TextEditingController(text: _initialPallet);
    _galponController = TextEditingController(text: _initialGalpon);
    _observacionController = TextEditingController(text: _initialObservacion);
    _numeroMotorController = TextEditingController(text: _initialNumeroMotor);
    _cilindradaController = TextEditingController(text: cleanCilindrada);
  }

  @override
  void dispose() {
    _pasilloController.dispose();
    _palletController.dispose();
    _galponController.dispose();
    _observacionController.dispose();
    _numeroMotorController.dispose();
    _cilindradaController.dispose();
    super.dispose();
  }

  bool _isFormDirty() {
    final cilindradaEsperada = _initialCilindrada == 'N/A' ? '' : _initialCilindrada;
    return _pasilloController.text.trim() != _initialPasillo ||
        _palletController.text.trim() != _initialPallet ||
        _galponController.text.trim() != _initialGalpon ||
        _observacionController.text.trim() != _initialObservacion ||
        _numeroMotorController.text.trim() != _initialNumeroMotor ||
        _cilindradaController.text.trim() != cilindradaEsperada;
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
          'Tienes cambios sin guardar. ¿Estás seguro de que quieres salir y descartar las modificaciones?',
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
        'observacion_estado': _observacionController.text.trim(),
      };

      if (_esMotor) {
        payload['numero_motor'] = _numeroMotorController.text.trim();
        payload['cilindrada'] = _cilindradaController.text.trim();
      }

      final resultado = await InventarioService.editarActivo(idActivo, payload);

      if (!mounted) return;
      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Activo actualizado exitosamente.',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppPalette.success,
          duration: const Duration(seconds: 3),
        ),
      );

      Navigator.of(context).pop(resultado);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);

      final errorMsg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMsg,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppPalette.error,
          duration: const Duration(seconds: 4),
        ),
      );

      // En caso de conflicto de concurrencia (409), cerramos notificando para recargar datos
      if (errorMsg.contains('modificada por otro usuario recientemente')) {
        Navigator.of(context).pop({'conflict': true});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sku = widget.activo['sku'] ?? widget.activo['sku_qr_fisico'] ?? 'S/N';
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

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
          maxHeight: MediaQuery.of(context).size.height * 0.88,
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
                      Icons.edit_note_rounded,
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
                          'Editar Información del Activo',
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

            // Formulario Scrollable
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
                    const SizedBox(height: 12),

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
                    const SizedBox(height: 14),

                    // Galpón
                    _buildTextField(
                      controller: _galponController,
                      label: 'Galpón',
                      hintText: 'Ej. Galpón Central / G-A',
                      icon: Icons.warehouse_outlined,
                    ),
                    const SizedBox(height: 22),

                    // Específico para Motores
                    if (_esMotor) ...[
                      Text(
                        'DETALLES DE MOTOR',
                        style: AppTypography.small.copyWith(
                          color: AppPalette.primary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _numeroMotorController,
                        label: 'Número de Motor',
                        hintText: 'Ej. 1NZ-FE-789012',
                        icon: Icons.numbers_outlined,
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _cilindradaController,
                        label: 'Cilindrada',
                        hintText: 'Ej. 1.5L / 1500cc',
                        icon: Icons.speed_outlined,
                      ),
                      const SizedBox(height: 22),
                    ],

                    Text(
                      'OBSERVACIÓN TÉCNICA / ESTADO FÍSICO',
                      style: AppTypography.small.copyWith(
                        color: AppPalette.primary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _observacionController,
                      label: 'Notas de Estado',
                      hintText: 'Describe el estado físico o notas de control...',
                      icon: Icons.notes_outlined,
                      maxLines: 3,
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
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: _isSaving ? null : _handleCancelOrClose,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: AppPalette.neutral.withValues(alpha: 0.3),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'CANCELAR',
                          style: AppTypography.button.copyWith(
                            color: AppPalette.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _guardarCambios,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.save_rounded, color: Colors.white),
                        label: Text(
                          _isSaving ? 'GUARDANDO...' : 'GUARDAR CAMBIOS',
                          style: AppTypography.button.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppPalette.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
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
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.small.copyWith(
            color: AppPalette.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: AppTypography.body.copyWith(color: AppPalette.textPrimary),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AppTypography.body.copyWith(
              color: AppPalette.textSecondary.withValues(alpha: 0.5),
            ),
            prefixIcon: Icon(icon, color: AppPalette.primary, size: 20),
            filled: true,
            fillColor: AppPalette.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: AppPalette.neutral.withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AppPalette.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
