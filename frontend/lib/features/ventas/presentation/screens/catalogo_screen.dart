// lib/features/ventas/presentation/screens/catalogo_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../../auth/services/auth_service.dart';
import '../../controllers/cart_controller.dart';
import '../../models/catalogo_model.dart';
import '../../services/catalogo_service.dart';
import '../widgets/catalogo_item_card.dart';
import '../widgets/catalogo_item_detail_sheet.dart';
import '../widgets/filtros_drawer.dart';
import '../widgets/venta_libre_dialog.dart';

/// Pantalla Principal del Catálogo de Ventas con Radar de Stock (HU-3.2).
/// Incluye buscador con debounce de 500ms, panel lateral de filtros interactivo,
/// scroll infinito y FAB de Venta Rápida.
class CatalogoScreen extends StatefulWidget {
  final VoidCallback? onOpenMenuDrawer;

  const CatalogoScreen({
    super.key,
    this.onOpenMenuDrawer,
  });

  @override
  State<CatalogoScreen> createState() => CatalogoScreenState();
}

class CatalogoScreenState extends State<CatalogoScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Timer? _debounceTimer;

  /// Método público para forzar la recarga del catálogo desde el backend
  /// (usado tras derivar órdenes a caja para sincronizar stock en tiempo real).
  Future<void> refrescarCatalogo() async {
    await _fetchCatalogo(resetPagination: true);
  }

  // Estado del catálogo
  List<CatalogoItem> _items = [];
  int _totalCount = 0;
  int _offset = 0;
  static const int _limit = 15;

  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  String? _errorMessage;

  // ID de la sucursal del vendedor logueado (para radar)
  int? _vendedorSucursalId;

  // Filtros activos
  int? _idCategoria;
  int? _idSucursalFiltro;
  int? _anio;
  String? _marca;

  bool get _tieneFiltrosActivos =>
      _idCategoria != null ||
      _idSucursalFiltro != null ||
      _anio != null ||
      _marca != null;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _cargarSucursalYCatalogo();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _cargarSucursalYCatalogo() async {
    final sucursalId = await AuthService.getSucursalId();
    if (mounted) {
      setState(() {
        _vendedorSucursalId = sucursalId;
      });
    }
    await _fetchCatalogo(resetPagination: true);
  }

  // ── Debounce de Búsqueda (500 ms) ──────────────────────────────────────────

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _fetchCatalogo(resetPagination: true);
    });
  }

  void _onClearSearch() {
    _searchController.clear();
    _fetchCatalogo(resetPagination: true);
  }

  // ── Gestión de Filtros ───────────────────────────────────────────────────

  void _aplicarFiltros() {
    _fetchCatalogo(resetPagination: true);
  }

  void _limpiarFiltros() {
    setState(() {
      _idCategoria = null;
      _idSucursalFiltro = null;
      _anio = null;
      _marca = null;
    });
    _aplicarFiltros();
  }

  // ── Infinite Scrolling (80% del scroll) ───────────────────────────────────

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (maxScroll > 0 && currentScroll >= maxScroll * 0.8) {
      if (!_isLoadingMore && !_isLoadingInitial && _items.length < _totalCount) {
        _fetchCatalogo(resetPagination: false);
      }
    }
  }

  // ── Consulta al Servicio HTTP ─────────────────────────────────────────────

  Future<void> _fetchCatalogo({required bool resetPagination}) async {
    if (resetPagination) {
      setState(() {
        _isLoadingInitial = true;
        _errorMessage = null;
        _offset = 0;
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final currentQuery = _searchController.text.trim();
      final targetOffset = resetPagination ? 0 : _offset + _limit;

      final response = await CatalogoService.obtenerCatalogo(
        q: currentQuery.isNotEmpty ? currentQuery : null,
        idCategoria: _idCategoria,
        idSucursal: _idSucursalFiltro,
        marca: _marca,
        anio: _anio,
        limit: _limit,
        offset: targetOffset,
      );

      if (!mounted) return;

      final itemsDisponibles = response.items
          .where((i) => i.estadoActivo?.toLowerCase() == 'disponible')
          .toList();

      setState(() {
        if (resetPagination) {
          _items = itemsDisponibles;
          _offset = 0;
        } else {
          _items.addAll(itemsDisponibles);
          _offset = targetOffset;
        }
        _totalCount = response.totalCount;
        _isLoadingInitial = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoadingInitial = false;
        _isLoadingMore = false;
      });
    }
  }

  // ── Interacciones de Usuario ──────────────────────────────────────────────

  void _showDetalleRepuesto(CatalogoItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (ctx) => CatalogoItemDetailSheet(
        item: item,
        vendedorSucursalId: _vendedorSucursalId,
        onAddToCart: () => _onAddToCart(item),
      ),
    );
  }

  void _onAddToCart(CatalogoItem item) {
    final agregado = CartController.instance.agregarInventariado(item);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppPalette.surface,
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            Icon(
              agregado ? Icons.check_circle : Icons.info_outline,
              color: agregado ? AppPalette.primary : AppPalette.secondary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                agregado
                    ? '${item.tituloRepuesto} agregado al carrito'
                    : 'Este activo ya está en el carrito',
                style: AppTypography.small.copyWith(color: AppPalette.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onVentaRapida() {
    VentaLibreDialog.show(context);
  }

  // ── Construcción de la Vista ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      endDrawer: FiltrosDrawer(
        idCategoria: _idCategoria,
        idSucursal: _idSucursalFiltro,
        marca: _marca,
        anio: _anio,
        onCategoriaChanged: (val) {
          setState(() => _idCategoria = val);
          _aplicarFiltros();
        },
        onSucursalChanged: (val) {
          setState(() => _idSucursalFiltro = val);
          _aplicarFiltros();
        },
        onMarcaChanged: (val) {
          setState(() => _marca = val);
          _aplicarFiltros();
        },
        onAnioChanged: (val) {
          setState(() => _anio = val);
          _aplicarFiltros();
        },
        onLimpiarFiltros: () {
          _limpiarFiltros();
          Navigator.of(context).pop();
        },
      ),
      appBar: AppBar(
        backgroundColor: AppPalette.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: AppPalette.textPrimary),
          onPressed: () {
            if (widget.onOpenMenuDrawer != null) {
              widget.onOpenMenuDrawer!();
            } else {
              Scaffold.of(context).openDrawer();
            }
          },
          tooltip: 'Menú principal',
        ),
        actions: const [
          SizedBox.shrink(),
        ],
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CATÁLOGO DE REPUESTOS',
              style: AppTypography.title,
            ),
            if (!_isLoadingInitial && _errorMessage == null)
              Text(
                '$_totalCount repuestos disponibles',
                style: AppTypography.small.copyWith(fontSize: 12),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onVentaRapida,
        backgroundColor: AppPalette.secondary,
        foregroundColor: AppPalette.background,
        elevation: 0,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: AppPalette.background, size: 28),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Barra de Búsqueda + Botón de Filtros (48x48 px) ────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: AppTypography.body,
                      decoration: InputDecoration(
                        hintText: 'Buscar por marca, modelo o SKU...',
                        hintStyle: AppTypography.body.copyWith(
                          color: AppPalette.textSecondary,
                        ),
                        filled: true,
                        fillColor: AppPalette.surface,
                        prefixIcon: const Icon(
                          Icons.search,
                          color: AppPalette.textSecondary,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: AppPalette.textSecondary),
                                onPressed: _onClearSearch,
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: const BorderSide(color: AppPalette.primary, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  // Botón para abrir FiltrosDrawer con Touch Target 48x48
                  Builder(
                    builder: (scaffoldCtx) => SizedBox(
                      width: 48.0,
                      height: 48.0,
                      child: Material(
                        color: _tieneFiltrosActivos
                            ? AppPalette.primary
                            : AppPalette.surface,
                        borderRadius: BorderRadius.circular(12.0),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12.0),
                          onTap: () => Scaffold.of(scaffoldCtx).openEndDrawer(),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                Icons.tune,
                                color: _tieneFiltrosActivos
                                    ? AppPalette.textPrimary
                                    : AppPalette.textSecondary,
                                size: 22,
                              ),
                              if (_tieneFiltrosActivos)
                                Positioned(
                                  top: 9,
                                  right: 9,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: AppPalette.secondary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Fila de Chips de Filtros Activos ────────────────────────────
            if (_tieneFiltrosActivos)
              Container(
                height: 36,
                margin: const EdgeInsets.only(bottom: 8.0),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  children: [
                    if (_idCategoria != null)
                      _buildActiveFilterChip(
                        label: _idCategoria == 1 ? 'Motores' : 'Cajas',
                        onDeleted: () {
                          setState(() => _idCategoria = null);
                          _aplicarFiltros();
                        },
                      ),
                    if (_idSucursalFiltro != null)
                      _buildActiveFilterChip(
                        label: _idSucursalFiltro == 1 ? 'Viña del Mar' : 'Limache',
                        onDeleted: () {
                          setState(() => _idSucursalFiltro = null);
                          _aplicarFiltros();
                        },
                      ),
                    if (_marca != null)
                      _buildActiveFilterChip(
                        label: _marca!,
                        onDeleted: () {
                          setState(() => _marca = null);
                          _aplicarFiltros();
                        },
                      ),
                    if (_anio != null)
                      _buildActiveFilterChip(
                        label: 'Año: $_anio',
                        onDeleted: () {
                          setState(() => _anio = null);
                          _aplicarFiltros();
                        },
                      ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: ActionChip(
                        label: const Text(
                          'Limpiar todos',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppPalette.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: AppPalette.surface,
                        side: BorderSide.none,
                        onPressed: _limpiarFiltros,
                      ),
                    ),
                  ],
                ),
              ),

            // ── Contenido Principal (Lista / Carga / Error) ─────────────────
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFilterChip({
    required String label,
    required VoidCallback onDeleted,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 6.0),
      child: Chip(
        label: Text(
          label,
          style: const TextStyle(
            color: AppPalette.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        deleteIcon: const Icon(
          Icons.close,
          size: 14,
          color: AppPalette.textPrimary,
        ),
        onDeleted: onDeleted,
        backgroundColor: AppPalette.primary.withValues(alpha: 0.25),
        side: const BorderSide(color: AppPalette.primary, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoadingInitial) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppPalette.primary,
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppPalette.error),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(color: AppPalette.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _fetchCatalogo(resetPagination: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.primary,
                  foregroundColor: AppPalette.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                size: 56,
                color: AppPalette.neutral,
              ),
              const SizedBox(height: 12),
              const Text(
                'No se encontraron repuestos',
                style: AppTypography.title,
              ),
              const SizedBox(height: 6),
              Text(
                _tieneFiltrosActivos || _searchController.text.isNotEmpty
                    ? 'Intenta ajustar los filtros o el término de búsqueda.'
                    : 'No hay repuestos disponibles en el inventario.',
                textAlign: TextAlign.center,
                style: AppTypography.small.copyWith(color: AppPalette.textSecondary),
              ),
              if (_tieneFiltrosActivos || _searchController.text.isNotEmpty) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    _searchController.clear();
                    _limpiarFiltros();
                  },
                  child: Text(
                    'Limpiar todos los filtros',
                    style: AppTypography.button.copyWith(color: AppPalette.primary),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppPalette.primary,
      backgroundColor: AppPalette.surface,
      onRefresh: () => _fetchCatalogo(resetPagination: true),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 80.0), // Margen inferior para el FAB
        itemCount: _items.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppPalette.primary,
                  ),
                ),
              ),
            );
          }

          final item = _items[index];
          return CatalogoItemCard(
            item: item,
            vendedorSucursalId: _vendedorSucursalId,
            onAddToCart: () => _onAddToCart(item),
            onTap: () => _showDetalleRepuesto(item),
          );
        },
      ),
    );
  }
}
