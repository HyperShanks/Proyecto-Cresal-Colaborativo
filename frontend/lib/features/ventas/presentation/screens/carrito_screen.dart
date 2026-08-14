// lib/features/ventas/presentation/screens/carrito_screen.dart

import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../controllers/cart_controller.dart';
import '../../models/cart_item_model.dart';
import '../widgets/cart_item_tile.dart';
import '../widgets/venta_libre_dialog.dart';

/// Pantalla Unificada de Carrito de Ventas y Micro-CRM (HU-3.3 + HU-3.4).
/// Integra el listado reactivo del Carrito Híbrido, formulario de datos de cliente,
/// opción de despacho a domicilio, consentimiento legal (Ley 21.719), notas a bodega
/// y barra fija de derivación a caja.
class CarritoScreen extends StatefulWidget {
  final VoidCallback? onOpenMenuDrawer;
  final VoidCallback? onNavigateToCatalogo;

  const CarritoScreen({
    super.key,
    this.onOpenMenuDrawer,
    this.onNavigateToCatalogo,
  });

  @override
  State<CarritoScreen> createState() => _CarritoScreenState();
}

class _CarritoScreenState extends State<CarritoScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controladores de Datos de Cliente
  final TextEditingController _rutController = TextEditingController();
  final TextEditingController _nombresController = TextEditingController();
  final TextEditingController _apellidosController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();

  // Controladores de Despacho
  final TextEditingController _direccionDespachoController = TextEditingController();
  final TextEditingController _rutReceptorController = TextEditingController();
  final TextEditingController _nombresReceptorController = TextEditingController();
  final TextEditingController _telefonoReceptorController = TextEditingController();

  // Variables de Selección y Switches
  String _comunaCliente = 'Viña del Mar';
  String _comunaDespacho = 'Viña del Mar';
  bool _requiereDespacho = false;
  bool _consentimientoLey = false;
  bool _mostrarErrorConsentimiento = false;

  static const List<String> _comunasDisponibles = [
    'Viña del Mar',
    'Valparaíso',
    'Limache',
    'Quilpué',
    'Villa Alemana',
    'Concón',
    'Quillota',
    'San Antonio',
    'Santiago',
  ];

  @override
  void dispose() {
    _rutController.dispose();
    _nombresController.dispose();
    _apellidosController.dispose();
    _telefonoController.dispose();
    _direccionDespachoController.dispose();
    _rutReceptorController.dispose();
    _nombresReceptorController.dispose();
    _telefonoReceptorController.dispose();
    super.dispose();
  }

  void _confirmarVaciarCarrito(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Vaciar Carrito', style: AppTypography.title),
        content: const Text(
          '¿Estás seguro de que deseas eliminar todos los productos del carrito?',
          style: AppTypography.small,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancelar',
              style: AppTypography.button.copyWith(color: AppPalette.neutral),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'VACIAR',
              style: AppTypography.button.copyWith(color: AppPalette.error),
            ),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      CartController.instance.vaciarCarrito();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppPalette.surface,
          content: Text('Carrito vaciado exitosamente'),
        ),
      );
    }
  }

  void _onDerivarACaja(BuildContext context) {
    final cart = CartController.instance;

    // 1. Validar que el carrito no esté vacío
    if (cart.estaVacio || cart.totalMonto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppPalette.surface,
          content: Text(
            'El carrito debe contener al menos un producto con monto mayor a \$0',
            style: TextStyle(color: AppPalette.error),
          ),
        ),
      );
      return;
    }

    // 2. Validar Formulario
    final formValido = _formKey.currentState?.validate() ?? false;

    // 3. Validar Consentimiento Ley 21.719
    if (!_consentimientoLey) {
      setState(() {
        _mostrarErrorConsentimiento = true;
      });
    } else {
      setState(() {
        _mostrarErrorConsentimiento = false;
      });
    }

    if (!formValido || !_consentimientoLey) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppPalette.surface,
          content: Text(
            'Por favor completa todos los campos requeridos (*)',
            style: TextStyle(color: AppPalette.error),
          ),
        ),
      );
      return;
    }

    // 4. Procesar Derivación con éxito
    _mostrarModalConfirmacion(context);
  }

  void _mostrarModalConfirmacion(BuildContext context) {
    final cart = CartController.instance;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: AppPalette.success, size: 24),
            const SizedBox(width: 10),
            Text('Orden Derivada a Caja', style: AppTypography.title.copyWith(fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Cliente: ${_nombresController.text} ${_apellidosController.text}',
                style: AppTypography.body.copyWith(fontWeight: FontWeight.bold),
              ),
              Text('RUT: ${_rutController.text}', style: AppTypography.small),
              Text('Comuna: $_comunaCliente', style: AppTypography.small),
              if (_requiereDespacho) ...[
                const SizedBox(height: 8),
                Text(
                  '🚚 Despacho a: ${_direccionDespachoController.text}, $_comunaDespacho',
                  style: AppTypography.small.copyWith(color: AppPalette.secondary),
                ),
              ],
              // Notas de preparación de los activos añadidos (para alerta de bodega)
              ...() {
                final itemsConNotas = cart.items.where((i) {
                  if (i is InventariadoCartItem) {
                    return i.notasPreparacion != null && i.notasPreparacion!.isNotEmpty;
                  } else if (i is VentaLibreCartItem) {
                    return i.observacion != null && i.observacion!.isNotEmpty;
                  }
                  return false;
                }).toList();

                if (itemsConNotas.isEmpty) return <Widget>[];

                return [
                  const SizedBox(height: 10),
                  Text(
                    '⚠️ Alertas de preparación a bodega:',
                    style: AppTypography.small.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppPalette.primary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...itemsConNotas.map((i) {
                    final nota = i is InventariadoCartItem
                        ? i.notasPreparacion
                        : (i as VentaLibreCartItem).observacion;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2.0),
                      child: Text(
                        '• ${i.titulo}: "$nota"',
                        style: AppTypography.small.copyWith(
                          fontSize: 11,
                          color: AppPalette.textPrimary,
                        ),
                      ),
                    );
                  }),
                ];
              }(),
              const Divider(color: Colors.white10, height: 20),
              Text(
                'Total a Cobrar: ${cart.totalMontoFormateado}',
                style: AppTypography.headline.copyWith(
                  color: AppPalette.secondary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'La orden ha sido registrada para pago en mesón de caja y alerta de tarea a bodega.',
                style: AppTypography.small.copyWith(color: AppPalette.textSecondary),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppPalette.surface,
                  duration: const Duration(seconds: 2),
                  content: Text(
                    'Orden derivada exitosamente por ${cart.totalMontoFormateado}',
                    style: AppTypography.small.copyWith(color: AppPalette.textPrimary),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.success,
              foregroundColor: AppPalette.textPrimary,
              elevation: 0,
            ),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CartController.instance,
      builder: (context, _) {
        final cart = CartController.instance;

        return Scaffold(
          backgroundColor: AppPalette.background,
          appBar: AppBar(
            backgroundColor: AppPalette.background,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.menu, color: AppPalette.textPrimary),
              onPressed: widget.onOpenMenuDrawer,
              tooltip: 'Menú principal',
            ),
            title: Text('Carrito de Ventas', style: AppTypography.title),
            actions: [
              if (!cart.estaVacio) ...[
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: AppPalette.secondary),
                  onPressed: () => VentaLibreDialog.show(context),
                  tooltip: 'Agregar ítem manual',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined, color: AppPalette.error),
                  onPressed: () => _confirmarVaciarCarrito(context),
                  tooltip: 'Vaciar carrito',
                ),
              ],
            ],
          ),
          body: cart.estaVacio
              ? _buildEmptyState(context)
              : _buildUnifiedBody(context, cart),
          bottomNavigationBar: cart.estaVacio
              ? null
              : _buildCheckoutBar(context, cart),
        );
      },
    );
  }

  /// Vista de Estado Vacío
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppPalette.surface,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: const Icon(
                Icons.remove_shopping_cart_outlined,
                size: 42,
                color: AppPalette.neutral,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Tu carrito está vacío',
              style: AppTypography.headline.copyWith(fontSize: 22),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Agrega repuestos desde el catálogo o genera una venta libre de artículos misceláneos.',
              style: AppTypography.small.copyWith(color: AppPalette.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // Botón 1: Ir al Catálogo
            SizedBox(
              width: 220,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: widget.onNavigateToCatalogo,
                icon: const Icon(Icons.storefront, size: 20),
                label: const Text('Explorar Catálogo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.primary,
                  foregroundColor: AppPalette.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Botón 2: Venta Libre
            SizedBox(
              width: 220,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => VentaLibreDialog.show(context),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Venta Libre / Misceláneo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppPalette.secondary,
                  side: const BorderSide(color: AppPalette.secondary, width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Cuerpo Continuo: Lista de Carrito + Formulario Micro-CRM
  Widget _buildUnifiedBody(BuildContext context, CartController cart) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 40.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Encabezado del Carrito ───────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Carrito de Compras',
                        style: AppTypography.headline.copyWith(fontSize: 20),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Revisa tus activos y finaliza la venta',
                        style: AppTypography.small.copyWith(color: AppPalette.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: AppPalette.surface,
                    borderRadius: BorderRadius.circular(20.0),
                    border: Border.all(
                      color: AppPalette.primary.withValues(alpha: 0.4),
                      width: 1.0,
                    ),
                  ),
                  child: Text(
                    '${cart.totalItems} ${cart.totalItems == 1 ? 'Ítem' : 'Ítems'}',
                    style: AppTypography.small.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppPalette.primary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── 2. Lista de Productos (shrinkWrap: true) ────────────────────
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cart.items.length,
              itemBuilder: (ctx, index) {
                final item = cart.items[index];
                return CartItemTile(
                  key: ValueKey(item.id),
                  item: item,
                );
              },
            ),
            const SizedBox(height: 8),

            // ── 3. Botón de Ancho Completo: Añadir Ítem No Inventariado ─────
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => VentaLibreDialog.show(context),
                icon: const Icon(Icons.add, color: AppPalette.secondary, size: 20),
                label: Text(
                  '+ Añadir Ítem No Inventariado / Misceláneo',
                  style: AppTypography.button.copyWith(
                    color: AppPalette.secondary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: AppPalette.secondary.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  backgroundColor: AppPalette.surface.withValues(alpha: 0.4),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── 4. Tarjeta 1: DATOS POST-VENTA CLIENTE ──────────────────────
            _buildCardContainer(
              icon: Icons.person_outline,
              title: 'DATOS POST-VENTA CLIENTE',
              children: [
                _buildTextField(
                  controller: _rutController,
                  label: 'RUT Cliente *',
                  hint: '12.345.678-9',
                  isRequired: true,
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _nombresController,
                        label: 'Nombres *',
                        hint: 'Juan',
                        isRequired: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _apellidosController,
                        label: 'Apellidos *',
                        hint: 'Pérez',
                        isRequired: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _telefonoController,
                        label: 'Teléfono',
                        hint: '+56 9 1234 5678',
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDropdown(
                        label: 'Comuna',
                        value: _comunaCliente,
                        items: _comunasDisponibles,
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _comunaCliente = val);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── 5. Tarjeta 2: REQUIERE DESPACHO ─────────────────────────────
            _buildCardContainer(
              icon: Icons.local_shipping_outlined,
              title: 'REQUIERE DESPACHO',
              trailing: Checkbox(
                value: _requiereDespacho,
                activeColor: AppPalette.primary,
                side: const BorderSide(color: AppPalette.neutral),
                onChanged: (val) {
                  setState(() {
                    _requiereDespacho = val ?? false;
                  });
                },
              ),
              children: [
                if (_requiereDespacho) ...[
                  const Divider(color: Colors.white10, height: 16),
                  _buildTextField(
                    controller: _direccionDespachoController,
                    label: 'Dirección de Envío *',
                    hint: 'Av. Libertad 1234, Depto 402',
                    isRequired: _requiereDespacho,
                  ),
                  const SizedBox(height: 12),
                  _buildDropdown(
                    label: 'Comuna Destino',
                    value: _comunaDespacho,
                    items: _comunasDisponibles,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _comunaDespacho = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _rutReceptorController,
                          label: 'RUT Receptor *',
                          hint: '12.345.678-9',
                          isRequired: _requiereDespacho,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _nombresReceptorController,
                          label: 'Nombres Receptor *',
                          hint: 'Pedro González',
                          isRequired: _requiereDespacho,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _telefonoReceptorController,
                    label: 'Teléfono Receptor *',
                    hint: '+56 9 8765 4321',
                    isRequired: _requiereDespacho,
                    keyboardType: TextInputType.phone,
                  ),
                ] else
                  Text(
                    'Marca la casilla si el cliente solicita despacho a domicilio de los repuestos.',
                    style: AppTypography.small.copyWith(
                      color: AppPalette.textSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // ── 6. Tarjeta 3: CONSENTIMIENTO LEGAL ──────────────────────────
            Container(
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                color: AppPalette.surface,
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(
                  color: _mostrarErrorConsentimiento
                      ? AppPalette.error
                      : Colors.white.withValues(alpha: 0.06),
                  width: _mostrarErrorConsentimiento ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _consentimientoLey,
                    activeColor: AppPalette.primary,
                    side: BorderSide(
                      color: _mostrarErrorConsentimiento
                          ? AppPalette.error
                          : AppPalette.neutral,
                    ),
                    onChanged: (val) {
                      setState(() {
                        _consentimientoLey = val ?? false;
                        if (_consentimientoLey) {
                          _mostrarErrorConsentimiento = false;
                        }
                      });
                    },
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Consentimiento Ley N° 21.719 *',
                            style: AppTypography.cardTitle.copyWith(
                              color: _mostrarErrorConsentimiento
                                  ? AppPalette.error
                                  : AppPalette.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Autorizo el tratamiento de mis datos de contacto para fines de garantía técnica, post-venta y trazabilidad conforme a la política de privacidad de Cresal Repuestos.',
                            style: AppTypography.small.copyWith(
                              color: AppPalette.textSecondary,
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                          if (_mostrarErrorConsentimiento) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Debes aceptar el consentimiento para continuar',
                              style: AppTypography.small.copyWith(
                                color: AppPalette.error,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
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

  /// Contenedor Modular Flat Design para Tarjetas
  Widget _buildCardContainer({
    required IconData icon,
    required String title,
    Widget? trailing,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppPalette.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.cardTitle.copyWith(
                    fontSize: 12,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  /// Campo de Texto Minimalista
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.small.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppPalette.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: AppTypography.body.copyWith(fontSize: 13),
          validator: isRequired
              ? (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Campo requerido';
                  }
                  return null;
                }
              : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTypography.small.copyWith(
              color: AppPalette.neutral,
              fontSize: 12,
            ),
            filled: true,
            fillColor: AppPalette.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: const BorderSide(
                color: AppPalette.primary,
              ),
            ),
            errorStyle: const TextStyle(color: AppPalette.error, fontSize: 10),
          ),
        ),
      ],
    );
  }

  /// Dropdown Minimalista
  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.small.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppPalette.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          initialValue: items.contains(value) ? value : items.first,
          dropdownColor: AppPalette.surface,
          style: AppTypography.body.copyWith(fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppPalette.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          items: items.map((comuna) {
            return DropdownMenuItem(
              value: comuna,
              child: Text(comuna, style: AppTypography.body.copyWith(fontSize: 13)),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  /// Barra Inferior Fija (Derivar a Caja)
  Widget _buildCheckoutBar(BuildContext context, CartController cart) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 16.0),
      decoration: const BoxDecoration(
        color: AppPalette.surface,
        border: Border(
          top: BorderSide(
            color: Colors.white10,
            width: 1.0,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Total Carrito
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'TOTAL CARRITO:',
                    style: AppTypography.small.copyWith(
                      fontSize: 10,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.bold,
                      color: AppPalette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cart.totalMontoFormateado,
                    style: AppTypography.headline.copyWith(
                      color: AppPalette.secondary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Botón Derivar a Caja (>= 48px, Verde corporativo)
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: cart.totalMonto > 0
                    ? () => _onDerivarACaja(context)
                    : null,
                icon: const Icon(
                  Icons.send,
                  size: 18,
                  color: AppPalette.textPrimary,
                ),
                label: Text(
                  'Derivar a Caja',
                  style: AppTypography.button.copyWith(
                    color: AppPalette.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.success,
                  foregroundColor: AppPalette.textPrimary,
                  disabledBackgroundColor: AppPalette.surface,
                  disabledForegroundColor: AppPalette.neutral,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18.0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
