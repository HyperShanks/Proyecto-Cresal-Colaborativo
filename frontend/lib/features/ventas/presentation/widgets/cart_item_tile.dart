// lib/features/ventas/presentation/widgets/cart_item_tile.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../controllers/cart_controller.dart';
import '../../models/cart_item_model.dart';

/// Tarjeta de ítem individual dentro del Carrito Híbrido (HU-3.3).
/// Diseñada en Flat Design estricto (sin sombras).
/// Permite edición in-line del precio acordado, ajuste de cantidad y eliminación.
class CartItemTile extends StatefulWidget {
  final CartItem item;

  const CartItemTile({
    super.key,
    required this.item,
  });

  @override
  State<CartItemTile> createState() => _CartItemTileState();
}

class _CartItemTileState extends State<CartItemTile> {
  late TextEditingController _precioController;
  final FocusNode _precioFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _precioController = TextEditingController(
      text: widget.item.precioUnitario.toString(),
    );
    _precioFocusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant CartItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.precioUnitario != widget.item.precioUnitario &&
        !_precioFocusNode.hasFocus) {
      _precioController.text = widget.item.precioUnitario.toString();
    }
  }

  @override
  void dispose() {
    _precioFocusNode.removeListener(_onFocusChange);
    _precioFocusNode.dispose();
    _precioController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_precioFocusNode.hasFocus) {
      _guardarPrecio();
    }
  }

  void _guardarPrecio() {
    final limpio = _precioController.text.replaceAll(RegExp(r'[^\d]'), '');
    final nuevoPrecio = int.tryParse(limpio) ?? 0;

    if (nuevoPrecio >= 0 && nuevoPrecio != widget.item.precioUnitario) {
      CartController.instance.actualizarPrecio(widget.item.id, nuevoPrecio);
    } else {
      _precioController.text = widget.item.precioUnitario.toString();
    }
  }

  void _editarNotas(BuildContext context) async {
    final currentNotas = widget.item is InventariadoCartItem
        ? (widget.item as InventariadoCartItem).notasPreparacion ?? ''
        : (widget.item as VentaLibreCartItem).observacion ?? '';

    final controller = TextEditingController(text: currentNotas);

    final resultado = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          widget.item.esInventariado
              ? 'Notas de Preparación'
              : 'Observaciones del Ítem',
          style: AppTypography.title.copyWith(fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: AppTypography.body,
          decoration: InputDecoration(
            hintText: 'Ej. Entregar con soporte, detalle especial...',
            hintStyle: AppTypography.small.copyWith(color: AppPalette.neutral),
            filled: true,
            fillColor: AppPalette.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancelar', style: TextStyle(color: AppPalette.neutral)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.primary,
              foregroundColor: AppPalette.textPrimary,
              elevation: 0,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (resultado != null) {
      CartController.instance.actualizarNotas(
        widget.item.id,
        resultado.isNotEmpty ? resultado : null,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isInventario = widget.item.esInventariado;

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: isInventario
              ? AppPalette.primary.withValues(alpha: 0.2)
              : AppPalette.secondary.withValues(alpha: 0.25),
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Fila Superior: Badge Tipo + Botón Eliminar (Touch 48x48) ────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Badge Tipo de Ítem
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                  decoration: BoxDecoration(
                    color: isInventario
                        ? AppPalette.primary.withValues(alpha: 0.15)
                        : AppPalette.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6.0),
                    border: Border.all(
                      color: isInventario ? AppPalette.primary : AppPalette.secondary,
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isInventario ? Icons.inventory_2_outlined : Icons.edit_note,
                        size: 13,
                        color: isInventario ? AppPalette.primary : AppPalette.secondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isInventario ? 'Inventario' : 'Venta Libre',
                        style: AppTypography.small.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isInventario ? AppPalette.primary : AppPalette.secondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Botón de Eliminación (Touch Target >= 48x48)
                SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppPalette.error,
                      size: 22,
                    ),
                    onPressed: () {
                      CartController.instance.eliminarItem(widget.item.id);
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppPalette.surface,
                          duration: const Duration(seconds: 2),
                          content: Text(
                            '${widget.item.titulo} eliminado del carrito',
                            style: AppTypography.small.copyWith(color: AppPalette.textPrimary),
                          ),
                        ),
                      );
                    },
                    tooltip: 'Eliminar del carrito',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // ── Título del Ítem ─────────────────────────────────────────────
            Text(
              widget.item.titulo,
              style: AppTypography.cardTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            // ── Subtítulo / Detalles ────────────────────────────────────────
            Text(
              widget.item.subtitulo,
              style: AppTypography.small.copyWith(
                color: AppPalette.textSecondary,
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // ── Fila de Notas de Preparación / Observación ───────────────────
            _buildNotasRow(context),

            const SizedBox(height: 12),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 12),

            // ── Fila Inferior: Edición de Precio / Cantidad y Subtotal ──────
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Columna 1: Precio Acordado / Unitario Editable
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PRECIO ACORDADO (CLP):',
                        style: AppTypography.small.copyWith(
                          fontSize: 10,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.bold,
                          color: AppPalette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppPalette.background,
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: TextField(
                          controller: _precioController,
                          focusNode: _precioFocusNode,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          textAlignVertical: TextAlignVertical.center,
                          style: AppTypography.body.copyWith(
                            color: AppPalette.secondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            prefixText: '\$ ',
                            prefixStyle: AppTypography.body.copyWith(
                              color: AppPalette.secondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            suffixIcon: const Icon(
                              Icons.edit_outlined,
                              size: 16,
                              color: AppPalette.neutral,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (_) => _guardarPrecio(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Columna 2 (si es Venta Libre): Selector de Cantidad
                if (!isInventario) ...[
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'CANTIDAD:',
                          style: AppTypography.small.copyWith(
                            fontSize: 10,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.bold,
                            color: AppPalette.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppPalette.background,
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(
                                width: 28,
                                height: 42,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.remove, size: 16),
                                  color: widget.item.cantidad > 1
                                      ? AppPalette.textPrimary
                                      : AppPalette.neutral,
                                  onPressed: () {
                                    CartController.instance.actualizarCantidad(
                                      widget.item.id,
                                      widget.item.cantidad - 1,
                                    );
                                  },
                                ),
                              ),
                              Text(
                                '${widget.item.cantidad}',
                                style: AppTypography.title.copyWith(fontSize: 14),
                              ),
                              SizedBox(
                                width: 28,
                                height: 42,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.add, size: 16),
                                  color: AppPalette.textPrimary,
                                  onPressed: () {
                                    CartController.instance.actualizarCantidad(
                                      widget.item.id,
                                      widget.item.cantidad + 1,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                ],

                // Columna 3: Subtotal
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'SUBTOTAL:',
                        style: AppTypography.small.copyWith(
                          fontSize: 10,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.bold,
                          color: AppPalette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 42,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            widget.item.subtotalFormateado,
                            style: AppTypography.headline.copyWith(
                              color: AppPalette.secondary,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotasRow(BuildContext context) {
    String? notas;
    if (widget.item is InventariadoCartItem) {
      notas = (widget.item as InventariadoCartItem).notasPreparacion;
    } else if (widget.item is VentaLibreCartItem) {
      notas = (widget.item as VentaLibreCartItem).observacion;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _editarNotas(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: AppPalette.background,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.sticky_note_2_outlined, size: 14, color: AppPalette.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  notas != null && notas.isNotEmpty
                      ? 'Nota: $notas'
                      : 'Agregar nota de preparación...',
                  style: AppTypography.small.copyWith(
                    fontSize: 11,
                    color: notas != null && notas.isNotEmpty
                        ? AppPalette.textPrimary
                        : AppPalette.neutral,
                    fontStyle: notas != null && notas.isNotEmpty
                        ? FontStyle.normal
                        : FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.edit_outlined, size: 13, color: AppPalette.neutral),
            ],
          ),
        ),
      ),
    );
  }
}
