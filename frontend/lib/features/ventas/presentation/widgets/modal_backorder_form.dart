import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../models/checkout_wizard_models.dart';

/// Modal dialog interactivo para configurar una Reserva por Encargo (Compra en Verde / Backorder) (SPEC-HU-05)
class ModalBackorderForm extends StatefulWidget {
  const ModalBackorderForm({super.key});

  /// Abre el diálogo y retorna la `ReservaBackorderModel` configurada o `null` si se cancela.
  static Future<ReservaBackorderModel?> mostrar(BuildContext context) {
    return showDialog<ReservaBackorderModel>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const ModalBackorderForm(),
    );
  }

  @override
  State<ModalBackorderForm> createState() => _ModalBackorderFormState();
}

class _ModalBackorderFormState extends State<ModalBackorderForm> {
  final _formKey = GlobalKey<FormState>();

  int _selectedCategoriaId = 1;
  String _selectedCategoriaNombre = 'Motor';

  final _marcaController = TextEditingController();
  final _modeloController = TextEditingController();
  final _anioController = TextEditingController();
  final _cilindradaController = TextEditingController();
  final _precioController = TextEditingController();
  final _abonoController = TextEditingController();
  final _notasController = TextEditingController();

  String _combustible = 'Bencina';
  String _transmision = 'Manual';

  final List<Map<String, dynamic>> _categoriasDisponibles = [
    {'id': 1, 'nombre': 'Motor'},
    {'id': 2, 'nombre': 'Caja de Cambios'},
    {'id': 3, 'nombre': 'Diferencial'},
    {'id': 4, 'nombre': 'Alternador'},
    {'id': 5, 'nombre': 'Motor de Arranque'},
    {'id': 6, 'nombre': 'Culata'},
    {'id': 7, 'nombre': 'Computador ECU'},
    {'id': 8, 'nombre': 'Suspensión / Dirección'},
    {'id': 9, 'nombre': 'Otros Repuestos Mecánicos'},
  ];

  @override
  void dispose() {
    _marcaController.dispose();
    _modeloController.dispose();
    _anioController.dispose();
    _cilindradaController.dispose();
    _precioController.dispose();
    _abonoController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  void _guardarReserva() {
    if (!_formKey.currentState!.validate()) return;

    final precio = int.tryParse(_precioController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final abono = int.tryParse(_abonoController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final anio = int.tryParse(_anioController.text.trim());

    if (abono > precio) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El abono inicial no puede ser superior al precio acordado.'),
          backgroundColor: AppPalette.error,
        ),
      );
      return;
    }

    final reserva = ReservaBackorderModel(
      idCategoriaRequerida: _selectedCategoriaId,
      categoriaNombre: _selectedCategoriaNombre,
      marcaRequerida: _marcaController.text.trim(),
      modeloRequerido: _modeloController.text.trim(),
      anioRequerido: anio,
      cilindradaRequerida: _cilindradaController.text.trim().isNotEmpty ? _cilindradaController.text.trim() : null,
      combustibleRequerido: _combustible,
      transmisionRequerida: _transmision,
      precioAcordado: precio,
      montoAbonado: abono,
      notasPreparacion: _notasController.text.trim().isNotEmpty ? _notasController.text.trim() : null,
    );

    Navigator.of(context).pop(reserva);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppPalette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: const BorderSide(color: Colors.white12),
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppPalette.secondary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.bookmark_add_rounded, color: AppPalette.secondary, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Venta en Verde', style: AppTypography.title.copyWith(fontSize: 18)),
                Text('Pedido por encargo (Sin stock inmediato)', style: AppTypography.small.copyWith(color: AppPalette.secondary, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppPalette.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppPalette.primary, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Esta pieza se registrará como Venta en Verde. Generará un abono en caja y una orden de búsqueda para adquisiciones/bodega.',
                          style: AppTypography.small.copyWith(color: AppPalette.textSecondary, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Categoría
                Text('Categoría Requerida *', style: AppTypography.small.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                DropdownButtonFormField<int>(
                  initialValue: _selectedCategoriaId,
                  dropdownColor: AppPalette.surface,
                  style: AppTypography.body,
                  decoration: _inputDecoration('Seleccione categoría'),
                  items: _categoriasDisponibles.map((cat) {
                    return DropdownMenuItem<int>(
                      value: cat['id'] as int,
                      child: Text(cat['nombre'] as String),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedCategoriaId = val;
                        _selectedCategoriaNombre = _categoriasDisponibles.firstWhere((c) => c['id'] == val)['nombre'] as String;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),

                // Marca y Modelo
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Marca *', style: AppTypography.small.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _marcaController,
                            style: AppTypography.body,
                            textCapitalization: TextCapitalization.words,
                            decoration: _inputDecoration('Ej: Toyota, Nissan...'),
                            validator: (val) => (val == null || val.trim().isEmpty) ? 'Requerido' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Modelo *', style: AppTypography.small.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _modeloController,
                            style: AppTypography.body,
                            textCapitalization: TextCapitalization.words,
                            decoration: _inputDecoration('Ej: Corolla, Sentra...'),
                            validator: (val) => (val == null || val.trim().isEmpty) ? 'Requerido' : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Año y Cilindrada
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Año', style: AppTypography.small.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _anioController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: AppTypography.body,
                            decoration: _inputDecoration('Ej: 2021'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cilindrada / Motor', style: AppTypography.small.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _cilindradaController,
                            style: AppTypography.body,
                            decoration: _inputDecoration('Ej: 1.8L, 2.0 Turbo'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Combustible y Transmisión
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Combustible', style: AppTypography.small.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            initialValue: _combustible,
                            dropdownColor: AppPalette.surface,
                            style: AppTypography.body,
                            decoration: _inputDecoration(''),
                            items: const [
                              DropdownMenuItem(value: 'Bencina', child: Text('Bencina')),
                              DropdownMenuItem(value: 'Diésel', child: Text('Diésel')),
                              DropdownMenuItem(value: 'Híbrido', child: Text('Híbrido')),
                              DropdownMenuItem(value: 'Eléctrico', child: Text('Eléctrico')),
                            ],
                            onChanged: (val) => setState(() => _combustible = val ?? 'Bencina'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Transmisión', style: AppTypography.small.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            initialValue: _transmision,
                            dropdownColor: AppPalette.surface,
                            style: AppTypography.body,
                            decoration: _inputDecoration(''),
                            items: const [
                              DropdownMenuItem(value: 'Manual', child: Text('Manual')),
                              DropdownMenuItem(value: 'Automática', child: Text('Automática')),
                              DropdownMenuItem(value: 'CVT', child: Text('CVT')),
                              DropdownMenuItem(value: 'Tiptronic', child: Text('Tiptronic')),
                            ],
                            onChanged: (val) => setState(() => _transmision = val ?? 'Manual'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Precios y Abonos
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Precio Acordado (\$) *', style: AppTypography.small.copyWith(fontWeight: FontWeight.bold, color: AppPalette.secondary)),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _precioController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: AppTypography.body.copyWith(fontWeight: FontWeight.bold),
                            decoration: _inputDecoration('Ej: 450000'),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Requerido';
                              final n = int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                              if (n <= 0) return 'Mayor a 0';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Monto a Abonar (\$) *', style: AppTypography.small.copyWith(fontWeight: FontWeight.bold, color: AppPalette.success)),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _abonoController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: AppTypography.body.copyWith(fontWeight: FontWeight.bold),
                            decoration: _inputDecoration('Ej: 100000 (0 si no abona hoy)'),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return null;
                              final n = int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                              if (n < 0) return 'Inválido';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Notas técnicas
                Text('Notas Técnicas / Especificaciones:', style: AppTypography.small.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _notasController,
                  maxLines: 2,
                  style: AppTypography.body,
                  decoration: _inputDecoration('Detalles específicos para desarme o compras...'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text('Cancelar', style: AppTypography.button.copyWith(color: AppPalette.textSecondary)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppPalette.secondary,
            foregroundColor: AppPalette.background,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: const Icon(Icons.check, size: 18),
          label: const Text('AÑADIR RESERVA', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: _guardarReserva,
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.small.copyWith(color: AppPalette.textSecondary),
      filled: true,
      fillColor: AppPalette.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppPalette.primary, width: 1.5)),
    );
  }
}
