// frontend/lib/features/gerencia/presentation/screens/inventario_gerencia_view.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../../ventas/models/catalogo_model.dart';
import '../../../inventario/services/inventario_service.dart';
import '../../services/gerencia_service.dart';
import '../../../ventas/presentation/widgets/visor_imagen_completa_dialog.dart';

enum ModoVistaStock { tarjetas, tabla }

/// Visor Maestro de Inventario Multi-Sucursal y Tasación de Repuestos Paletizados (HU-5.3).
/// Replica fielmente la experiencia visual, componentes interactivos y filtros de `prototipo_gerencia_v1.html`.
class InventarioGerenciaView extends StatefulWidget {
  final int? idSucursalInicial;
  final bool filtroSinTasarInicial;
  final VoidCallback? onStockMutado;

  const InventarioGerenciaView({
    super.key,
    this.idSucursalInicial,
    this.filtroSinTasarInicial = false,
    this.onStockMutado,
  });

  @override
  State<InventarioGerenciaView> createState() => InventarioGerenciaViewState();
}

class InventarioGerenciaViewState extends State<InventarioGerenciaView> {
  late final TextEditingController _busquedaController;
  Timer? _debounceTimer;

  /// Permite a vistas contenedoras (como [DashboardGerenciaView]) solicitar una recarga explícita.
  Future<void> refrescar({int? idSucursal, bool actualizarSucursal = false}) async {
    if (actualizarSucursal) {
      _idSucursal = idSucursal;
    }
    setState(() => _paginaActual = 1);
    await _cargarOpcionesUbicacion();
    await _cargarInventario(pagina: 1);
  }

  int? _idSucursal;
  bool _soloSinTasar = false;
  ModoVistaStock _modoVista = ModoVistaStock.tarjetas;

  // Filtros Secundarios
  String _categoria = 'todas';
  String _galpon = 'todas';
  String _pasillo = 'todas';
  String _pallet = 'todas';
  String _combustible = 'todos';
  String _transmision = 'todas';
  String _estado = 'todos';

  // Listas de opciones dinámicas según stock real
  List<String> _galponesDisponibles = [];
  List<String> _pasillosDisponibles = [];
  List<String> _palletsDisponibles = [];

  // Paginación y Estado
  int _paginaActual = 1;
  final int _limitePorPagina = 12;

  bool _isLoading = false;
  String? _errorMessage;
  List<CatalogoItem> _items = [];
  int _totalCount = 0;
  int _pendientesTasacionCount = 0;

  @override
  void initState() {
    super.initState();
    _idSucursal = widget.idSucursalInicial;
    _soloSinTasar = widget.filtroSinTasarInicial;
    _busquedaController = TextEditingController();
    _cargarOpcionesUbicacion();
    _cargarInventario();
  }

  Future<void> _cargarOpcionesUbicacion() async {
    try {
      final opciones = await InventarioService.obtenerOpcionesFiltros(
        galpon: _galpon != 'todas' && _galpon != 'todos' ? _galpon : null,
        pasillo: _pasillo != 'todas' && _pasillo != 'todos' ? _pasillo : null,
      );
      if (!mounted) return;
      setState(() {
        _galponesDisponibles = opciones['galpones'] ?? [];
        _pasillosDisponibles = opciones['pasillos'] ?? [];
        _palletsDisponibles = opciones['pallets'] ?? [];

        if (_pasillo != 'todas' && !_pasillosDisponibles.contains(_pasillo.toUpperCase())) {
          _pasillo = 'todas';
        }
        if (_pallet != 'todas' && !_palletsDisponibles.contains(_pallet.toUpperCase())) {
          _pallet = 'todas';
        }
      });
    } catch (_) {
      // Fallback silencioso
    }
  }

  @override
  void didUpdateWidget(covariant InventarioGerenciaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    bool shouldReload = false;
    if (oldWidget.idSucursalInicial != widget.idSucursalInicial) {
      _idSucursal = widget.idSucursalInicial;
      _paginaActual = 1;
      shouldReload = true;
    }
    if (oldWidget.filtroSinTasarInicial != widget.filtroSinTasarInicial) {
      _soloSinTasar = widget.filtroSinTasarInicial;
      _paginaActual = 1;
      shouldReload = true;
    }
    if (shouldReload) {
      _cargarInventario();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _busquedaController.dispose();
    super.dispose();
  }

  void _onBusquedaChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _paginaActual = 1);
      _cargarInventario();
    });
  }

  Future<void> _cargarInventario({int? pagina}) async {
    if (!mounted) return;

    final targetPage = pagina ?? _paginaActual;
    debugPrint('🏭 [GERENCIA-INVENTARIO] 🔄 Solicitando inventario (Sucursal: ${_idSucursal ?? "Todas"}, Sin Tasar: $_soloSinTasar, Categoría: $_categoria, Pág: $targetPage)...');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _paginaActual = targetPage;
    });

    try {
      int? catId;
      if (_categoria == '1') catId = 1;
      if (_categoria == '2') catId = 2;
      if (_categoria == '3') catId = 3;

      final offset = (targetPage - 1) * _limitePorPagina;

      final res = await GerenciaService.obtenerMaestroInventario(
        idSucursal: _idSucursal,
        idCategoria: catId,
        estado: _estado,
        combustible: _combustible,
        transmision: _transmision,
        galpon: _galpon,
        pasillo: _pasillo,
        pallet: _pallet,
        soloSinTasar: _soloSinTasar,
        busqueda: _busquedaController.text.trim(),
        limite: _limitePorPagina,
        offset: offset,
      );

      if (!mounted) return;

      // Filtro defensivo: excluir repuestos que no están físicamente en bodega (En Desarme o Entregado)
      final itemsValidos = res.items.where((item) {
        final est = (item.estadoActivo ?? '').trim().toLowerCase();
        final id = item.idEstado;
        if (id == 5 || id == 6) return false;
        if (est == 'en desarme' || est == 'desarme' || est == 'entregado') return false;
        return true;
      }).toList();

      debugPrint('🏭 [GERENCIA-INVENTARIO] ✅ OK 200 - Inventario cargado exitosamente:');
      debugPrint('   • Mostrando ${itemsValidos.length} piezas en página $targetPage (Total en BD: ${res.totalCount})');
      debugPrint('   • Repuestos pendientes de tasación comercial: ${res.pendientesTasacionCount}');

      setState(() {
        _items = itemsValidos;
        _totalCount = res.totalCount;
        _pendientesTasacionCount = res.pendientesTasacionCount;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('🏭 [GERENCIA-INVENTARIO] ❌ Error al cargar inventario: $e');
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _limpiarFiltros() {
    _busquedaController.clear();
    setState(() {
      _soloSinTasar = false;
      _categoria = 'todas';
      _galpon = 'todas';
      _pasillo = 'todas';
      _pallet = 'todas';
      _combustible = 'todos';
      _transmision = 'todas';
      _estado = 'todos';
      _paginaActual = 1;
    });
    _cargarOpcionesUbicacion();
    _cargarInventario();
  }

  int get _totalPaginas => (_totalCount / _limitePorPagina).ceil().clamp(1, 9999);

  // Formateador monetario CLP seguro
  String _formatoCLP(int? monto) {
    if (monto == null || monto <= 0) return 'Sin Tasar';
    final str = monto.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
    return '\$ $str';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Panel Superior de Búsqueda y Filtros
          _buildPanelFiltros(),
          const SizedBox(height: 16),

          // Área Central con Vistas o Estados de Carga
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppPalette.primary),
                  )
                : _errorMessage != null
                    ? _buildErrorState()
                    : _items.isEmpty
                        ? _buildEmptyState()
                        : _modoVista == ModoVistaStock.tarjetas
                            ? _buildVistaTarjetas()
                            : _buildVistaTabla(),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 1. PANEL SUPERIOR DE FILTROS Y CONTROL DE VISTAS (PROTOTIPO FILA 1 Y 2)
  // =========================================================================
  Widget _buildPanelFiltros() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fila 1: Buscador Reactivo + Acciones Rápidas + Switcher
          LayoutBuilder(
            builder: (context, constraints) {
              final esCompacto = constraints.maxWidth < 900;
              return esCompacto
                  ? Column(
                      children: [
                        _buildBuscadorInput(),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildBotonSinTasar(),
                            const SizedBox(width: 8),
                            _buildBotonLimpiar(),
                            const Spacer(),
                            _buildSwitcherModoVista(),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: _buildBuscadorInput()),
                        const SizedBox(width: 14),
                        _buildBotonSinTasar(),
                        const SizedBox(width: 8),
                        _buildBotonLimpiar(),
                        const SizedBox(width: 14),
                        _buildSwitcherModoVista(),
                      ],
                    );
            },
          ),
          const SizedBox(height: 12),

          // Fila 2: Filtros Técnicos Secundarios
          Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFFF1F5F9)),
              ),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.tune, size: 14, color: Color(0xFF94A3B8)),
                    SizedBox(width: 4),
                    Text(
                      'Filtros:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                // 1. Tipo / Categoría
                _buildDropdown(
                  value: _categoria,
                  items: const [
                    DropdownMenuItem(value: 'todas', child: Text('Tipo: Todos')),
                    DropdownMenuItem(value: '1', child: Text('Motores')),
                    DropdownMenuItem(value: '2', child: Text('Cajas de Cambio')),
                  ],
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() => _categoria = val);
                    _cargarInventario(pagina: 1);
                  },
                ),
                // 2. Galpón (Dinámico según stock real)
                _buildDropdown(
                  value: _galponesDisponibles.contains(_galpon.toUpperCase()) || _galpon == 'todas'
                      ? _galpon
                      : 'todas',
                  items: [
                    const DropdownMenuItem(value: 'todas', child: Text('Galpón: Todos')),
                    ..._galponesDisponibles.map(
                      (g) => DropdownMenuItem(value: g, child: Text('Galpón $g')),
                    ),
                  ],
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() {
                      _galpon = val;
                      _pasillo = 'todas';
                      _pallet = 'todas';
                    });
                    _cargarOpcionesUbicacion();
                    _cargarInventario(pagina: 1);
                  },
                ),
                // 3. Pasillo (Dinámico según galpón y stock real)
                _buildDropdown(
                  value: _pasillosDisponibles.contains(_pasillo.toUpperCase()) || _pasillo == 'todas'
                      ? _pasillo
                      : 'todas',
                  items: [
                    const DropdownMenuItem(value: 'todas', child: Text('Pasillo: Todos')),
                    ..._pasillosDisponibles.map(
                      (p) => DropdownMenuItem(value: p, child: Text('Pasillo $p')),
                    ),
                  ],
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() {
                      _pasillo = val;
                      _pallet = 'todas';
                    });
                    _cargarOpcionesUbicacion();
                    _cargarInventario(pagina: 1);
                  },
                ),
                // 4. Pallet (Dinámico según pasillo y stock real)
                _buildDropdown(
                  value: _palletsDisponibles.contains(_pallet.toUpperCase()) || _pallet == 'todas'
                      ? _pallet
                      : 'todas',
                  items: [
                    const DropdownMenuItem(value: 'todas', child: Text('Pallet: Todos')),
                    ..._palletsDisponibles.map(
                      (p) => DropdownMenuItem(value: p, child: Text('Pallet $p')),
                    ),
                  ],
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() => _pallet = val);
                    _cargarInventario(pagina: 1);
                  },
                ),
                // 3. Combustible
                _buildDropdown(
                  value: _combustible,
                  items: const [
                    DropdownMenuItem(value: 'todos', child: Text('Combustible: Todos')),
                    DropdownMenuItem(value: 'Diesel', child: Text('Diesel')),
                    DropdownMenuItem(value: 'Gasolina', child: Text('Gasolina')),
                  ],
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() => _combustible = val);
                    _cargarInventario(pagina: 1);
                  },
                ),
                // 4. Transmisión
                _buildDropdown(
                  value: _transmision,
                  items: const [
                    DropdownMenuItem(value: 'todas', child: Text('Transmisión: Todas')),
                    DropdownMenuItem(value: 'Automatica', child: Text('Automática')),
                    DropdownMenuItem(value: 'Mecanica', child: Text('Mecánica')),
                  ],
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() => _transmision = val);
                    _cargarInventario(pagina: 1);
                  },
                ),
                // 5. Estado Comercial
                _buildDropdown(
                  value: _estado,
                  items: const [
                    DropdownMenuItem(value: 'todos', child: Text('Estado: Todos')),
                    DropdownMenuItem(value: 'Paletizado', child: Text('Paletizado (Sin Tasar)')),
                    DropdownMenuItem(value: 'Disponible', child: Text('Disponible (En Venta)')),
                    DropdownMenuItem(value: 'Reservado', child: Text('Reservado')),
                    DropdownMenuItem(value: 'Vendido', child: Text('Vendido')),
                  ],
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() => _estado = val);
                    _cargarInventario(pagina: 1);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuscadorInput() {
    return TextField(
      controller: _busquedaController,
      onChanged: _onBusquedaChanged,
      style: AppTypography.small.copyWith(
        fontSize: 13,
        color: AppPalette.textPrimaryLight,
      ),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Buscar por SKU, Marca, Pasillo (A, B, C), Pallet o N° Ingreso...',
        hintStyle: AppTypography.small.copyWith(
          color: AppPalette.textSecondaryLight.withValues(alpha: 0.7),
          fontSize: 12,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 18,
          color: AppPalette.textSecondaryLight,
        ),
        suffixIcon: _busquedaController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 16),
                color: AppPalette.textSecondaryLight,
                onPressed: () {
                  _busquedaController.clear();
                  _onBusquedaChanged('');
                },
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        filled: true,
        fillColor: AppPalette.backgroundLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AppPalette.neutral.withValues(alpha: 0.25),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AppPalette.neutral.withValues(alpha: 0.25),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: AppPalette.tertiary,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildBotonSinTasar() {
    final activo = _soloSinTasar;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _soloSinTasar = !_soloSinTasar;
            _paginaActual = 1;
          });
          _cargarInventario();
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: activo ? const Color(0xFFEA580C) : const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: activo ? const Color(0xFFC2410C) : const Color(0xFFFED7AA),
            ),
            boxShadow: activo
                ? [
                    BoxShadow(
                      color: const Color(0xFFEA580C).withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.sell_outlined,
                size: 16,
                color: activo ? Colors.white : const Color(0xFF9A3412),
              ),
              const SizedBox(width: 6),
              Text(
                'Sin Tasar',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: activo ? Colors.white : const Color(0xFF9A3412),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: activo
                      ? Colors.black.withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$_pendientesTasacionCount',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: activo ? Colors.white : const Color(0xFF9A3412),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBotonLimpiar() {
    return OutlinedButton.icon(
      onPressed: _limpiarFiltros,
      icon: const Icon(Icons.filter_alt_off, size: 14),
      label: const Text('Limpiar'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF475569),
        backgroundColor: Colors.white,
        side: const BorderSide(color: AppPalette.borderLight),
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildSwitcherModoVista() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildBotonSwitcherItem(
            modo: ModoVistaStock.tarjetas,
            icon: Icons.calendar_view_month,
            label: 'Tarjetas',
          ),
          _buildBotonSwitcherItem(
            modo: ModoVistaStock.tabla,
            icon: Icons.table_rows,
            label: 'Tabla',
          ),
        ],
      ),
    );
  }

  Widget _buildBotonSwitcherItem({
    required ModoVistaStock modo,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _modoVista == modo;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _modoVista = modo),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? AppPalette.primary : const Color(0xFF64748B),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppPalette.primary : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    final effectiveValue = items.any((i) => i.value == value)
        ? value
        : (items.isNotEmpty ? items.first.value : null);

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppPalette.borderLight),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: effectiveValue,
          dropdownColor: Colors.white,
          icon: const Icon(Icons.expand_more, size: 16, color: Color(0xFF64748B)),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF334155),
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  // =========================================================================
  // 2. MODO 1: VISTA DE TARJETAS (GRID RESPONSIVO ANTI-OVERFLOW)
  // =========================================================================
  Widget _buildVistaTarjetas() {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              int crossAxisCount = 4;
              if (width < 680) {
                crossAxisCount = 1;
              } else if (width < 1080) {
                crossAxisCount = 2;
              } else if (width < 1520) {
                crossAxisCount = 3;
              }

              return GridView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  mainAxisExtent: 385, // Proporción balanceada anti-overflow y sin vacío blanco
                ),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return _buildItemCard(item);
                },
              );
            },
          ),
        ),
        _buildPaginador(),
      ],
    );
  }

  Widget _buildItemCard(CatalogoItem item) {
    final tienePrecio = item.precioReferencia != null && item.precioReferencia! > 0;
    final estadoNombre = item.estadoActivo ?? 'Disponible';
    final estLower = estadoNombre.toLowerCase().trim();
    final esPaletizado = estLower == 'paletizado';
    final bool puedeEditar = estLower == 'disponible' || estLower == 'paletizado';
    final bool esBloqueado = !puedeEditar;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.borderLight, width: 1.0),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera Fotográfica con Zoom suave por GPU y navegación interactiva
          Stack(
            children: [
              _CardImageZoom(
                imagenes: item.imagenes,
                fallbackBuilder: _buildFallbackImage,
                titulo: item.tituloRepuesto,
                sku: item.skuQrFisico,
              ),

              // Badge Superior Flotante: Estado Físico
              Positioned(
                top: 10,
                left: 10,
                child: IgnorePointer(
                  child: _buildBadgeEstado(estadoNombre),
                ),
              ),

              // Badge Inferior Flotante: SKU QR Físico
              Positioned(
                bottom: 8,
                left: 10,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      item.skuQrFisico,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        color: AppPalette.tertiary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

            // Cuerpo de la Tarjeta
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Chip Categoría + Sucursal
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: item.idCategoria == 1
                                ? const Color(0xFFE0F2FE)
                                : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.nombreCategoria,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: item.idCategoria == 1
                                  ? const Color(0xFF075985)
                                  : const Color(0xFF78350F),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.nombreSucursal,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Título Técnico del Repuesto (Vehículo Donante sin categoría redundante)
                    Text(
                      item.tituloVehiculo,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Chips Técnicos de Especificaciones
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (item.combustible != null)
                          _buildSpecChip(item.combustible!),
                        if (item.transmisionTipo != null)
                          _buildSpecChip(item.transmisionTipo!),
                        if (item.cilindrada != null)
                          _buildSpecChip('${item.cilindrada}L'),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Ubicación Física en Bodega (agrupada inmediatamente bajo los datos técnicos)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppPalette.borderLight),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.warehouse_outlined, size: 15, color: Color(0xFF94A3B8)),
                              SizedBox(width: 4),
                              Text(
                                'Ubicación:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'G${item.ubicacionGalpon ?? "1"} • Pasillo ${item.ubicacionPasillo ?? "-"} • Pallet ${item.ubicacionPallet ?? "-"}',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Spacer elástico para absorber diferencias de 1 vs 2 líneas en el título
                    const Spacer(),

                    // Fila de Precio y Acción
                    Container(
                      padding: const EdgeInsets.only(top: 8),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFFF1F5F9)),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PRECIO COMERCIAL',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tienePrecio ? _formatoCLP(item.precioReferencia) : '⚠️ Sin Tasar',
                                style: TextStyle(
                                  fontSize: tienePrecio ? 16 : 12,
                                  fontWeight: FontWeight.w900,
                                  color: tienePrecio ? const Color(0xFF0F172A) : const Color(0xFFEA580C),
                                ),
                              ),
                            ],
                          ),

                              // Botón de Acción
                              if (esBloqueado)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppPalette.borderLight),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.lock, size: 12, color: Color(0xFF94A3B8)),
                                      const SizedBox(width: 4),
                                      Text(
                                        estadoNombre,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                ElevatedButton.icon(
                                  onPressed: () => _abrirModalTasacion(item),
                                  icon: Icon(
                                    !tienePrecio || esPaletizado ? Icons.sell : Icons.edit,
                                    size: 14,
                                  ),
                                  label: Text(!tienePrecio || esPaletizado ? 'Tasar' : 'Precio'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: !tienePrecio || esPaletizado
                                        ? const Color(0xFFEA580C)
                                        : AppPalette.tertiary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
  }

  Widget _buildSpecChip(String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Color(0xFF334155),
        ),
      ),
    );
  }

  Widget _buildBadgeEstado(String estado) {
    Color bg;
    Color border;
    final estLower = estado.toLowerCase().trim();

    if (estLower == 'disponible') {
      bg = const Color(0xFF059669);
      border = const Color(0xFF047857);
    } else if (estLower == 'reservado') {
      bg = const Color(0xFFD97706);
      border = const Color(0xFFB45309);
    } else if (estLower == 'paletizado') {
      bg = const Color(0xFF0284C7);
      border = const Color(0xFF0369A1);
    } else if (estLower == 'vendido') {
      bg = const Color(0xFFDC2626);
      border = const Color(0xFFB91C1C);
    } else {
      bg = const Color(0xFF4F46E5);
      border = const Color(0xFF4338CA);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        estado.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: const Center(
        child: Icon(Icons.directions_car, size: 48, color: Color(0xFFCBD5E1)),
      ),
    );
  }

  // =========================================================================
  // 3. MODO 2: VISTA DE TABLA DENSA
  // =========================================================================
  Widget _buildVistaTabla() {
    return Column(
      children: [
        Expanded(
          child: Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppPalette.borderLight),
            ),
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final tableWidth = math.max(constraints.maxWidth, 980.0);
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: tableWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildTableHeader(),
                              Expanded(
                                child: ListView.separated(
                                  itemCount: _items.length,
                                  separatorBuilder: (context, index) => const Divider(
                                    height: 1,
                                    color: Color(0xFFF1F5F9),
                                  ),
                                  itemBuilder: (context, index) => _buildTableRow(_items[index]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Footer de Resumen de la Tabla
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border(top: BorderSide(color: AppPalette.borderLight)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text.rich(
                        TextSpan(
                          text: 'Total repuestos en vista: ',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          children: [
                            TextSpan(
                              text: '$_totalCount',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppPalette.tertiary),
                            ),
                          ],
                        ),
                      ),
                      Text.rich(
                        TextSpan(
                          text: 'Pendientes de Tasación: ',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          children: [
                            TextSpan(
                              text: '$_pendientesTasacionCount',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC2410C)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildPaginador(),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(color: AppPalette.borderLight),
        ),
      ),
      child: Row(
        children: [
          _buildHeaderCell('SKU / QR FÍSICO', flex: 2),
          _buildHeaderCell('PIEZA / FICHA TÉCNICA', flex: 4),
          _buildHeaderCell('UBICACIÓN FÍSICA', flex: 3),
          _buildHeaderCell('SUCURSAL', flex: 2),
          _buildHeaderCell('ESTADO FÍSICO', flex: 2, alignment: Alignment.center),
          _buildHeaderCell('PRECIO TASACIÓN', flex: 2, alignment: Alignment.centerRight),
          _buildHeaderCell('ACCIÓN', flex: 2, alignment: Alignment.center),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(
    String label, {
    required int flex,
    Alignment alignment = Alignment.centerLeft,
  }) {
    return Expanded(
      flex: flex,
      child: Container(
        alignment: alignment,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF475569),
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildTableRow(CatalogoItem item) {
    final tienePrecio = item.precioReferencia != null && item.precioReferencia! > 0;
    final estadoNombre = item.estadoActivo ?? 'Disponible';
    final estLower = estadoNombre.toLowerCase().trim();
    final esPaletizado = estLower == 'paletizado';
    final bool puedeEditar = estLower == 'disponible' || estLower == 'paletizado';
    final bool esBloqueado = !puedeEditar;

    return InkWell(
      hoverColor: const Color(0xFFF8FAFC),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // 1. SKU / QR Físico
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  item.skuQrFisico,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w900,
                    color: AppPalette.tertiary,
                    fontSize: 13,
                  ),
                ),
              ),
            ),

            // 2. Pieza / Ficha Técnica (con miniatura interactiva)
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    // Miniatura interactiva de foto con acceso directo al visor en grande
                    Tooltip(
                      message: item.imagenes.isNotEmpty
                          ? 'Click para ver ${item.imagenes.length} ${item.imagenes.length == 1 ? "foto" : "fotos"} en grande'
                          : 'Sin fotografías registradas',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: item.imagenes.isNotEmpty
                            ? () => VisorImagenCompletaDialog.show(
                                  context,
                                  fotografias: item.imagenes,
                                  initialIndex: 0,
                                  titulo: item.tituloRepuesto,
                                  sku: item.skuQrFisico,
                                )
                            : null,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppPalette.borderLight),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: item.imagenes.isNotEmpty
                                  ? Image.network(
                                      item.imagenes.first,
                                      fit: BoxFit.cover,
                                      cacheWidth: 150,
                                      cacheHeight: 150,
                                      errorBuilder: (_, _, _) => const Icon(
                                        Icons.directions_car,
                                        size: 20,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.directions_car,
                                      size: 20,
                                      color: Color(0xFFCBD5E1),
                                    ),
                            ),
                            if (item.imagenes.length > 1)
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.white24, width: 0.5),
                                  ),
                                  child: Text(
                                    '+${item.imagenes.length - 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: item.idCategoria == 1
                                      ? const Color(0xFFE0F2FE)
                                      : const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item.nombreCategoria,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: item.idCategoria == 1
                                        ? const Color(0xFF075985)
                                        : const Color(0xFF78350F),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  item.tituloVehiculo,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.combustible ?? ""} • ${item.transmisionTipo ?? ""}${item.cilindrada != null ? " • ${item.cilindrada!}L" : ""}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Ubicación Física
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppPalette.borderLight),
                    ),
                    child: Text(
                      'G${item.ubicacionGalpon ?? "1"} • Pasillo ${item.ubicacionPasillo ?? "-"} • Pallet ${item.ubicacionPallet ?? "-"}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 4. Sucursal
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  item.nombreSucursal,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                ),
              ),
            ),

            // 5. Estado Físico
            Expanded(
              flex: 2,
              child: Center(
                child: _buildBadgeEstado(estadoNombre),
              ),
            ),

            // 6. Precio Tasación
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: tienePrecio
                      ? Text(
                          _formatoCLP(item.precioReferencia),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            color: Color(0xFF0F172A),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEDD5),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFFED7AA)),
                          ),
                          child: const Text(
                            'SIN TASAR',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF9A3412),
                            ),
                          ),
                        ),
                ),
              ),
            ),

            // 7. Acción
            Expanded(
              flex: 2,
              child: Center(
                child: esBloqueado
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppPalette.borderLight),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock, size: 11, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 4),
                            Text(
                              estadoNombre,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: () => _abrirModalTasacion(item),
                        icon: Icon(
                          !tienePrecio || esPaletizado ? Icons.sell : Icons.edit,
                          size: 13,
                        ),
                        label: Text(!tienePrecio || esPaletizado ? 'Tasar' : 'Precio'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: !tienePrecio || esPaletizado
                              ? const Color(0xFFEA580C)
                              : AppPalette.tertiary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 4. BARRA DE PAGINACIÓN COMÚN
  // =========================================================================
  Widget _buildPaginador() {
    final start = _totalCount == 0 ? 0 : (_paginaActual - 1) * _limitePorPagina + 1;
    final end = (_paginaActual * _limitePorPagina).clamp(0, _totalCount);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.borderLight),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text.rich(
            TextSpan(
              text: 'Mostrando ',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              children: [
                TextSpan(
                  text: '$start - $end ',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const TextSpan(text: 'de '),
                TextSpan(
                  text: '$_totalCount ',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const TextSpan(text: 'repuestos'),
              ],
            ),
          ),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _paginaActual > 1
                    ? () => _cargarInventario(pagina: _paginaActual - 1)
                    : null,
                icon: const Icon(Icons.chevron_left, size: 16),
                label: const Text('Anterior'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  foregroundColor: AppPalette.primary,
                  disabledForegroundColor: const Color(0xFF94A3B8),
                  disabledIconColor: const Color(0xFF94A3B8),
                  side: BorderSide(
                    color: _paginaActual > 1 ? AppPalette.primary : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Página $_paginaActual de $_totalPaginas',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _paginaActual < _totalPaginas
                    ? () => _cargarInventario(pagina: _paginaActual + 1)
                    : null,
                icon: const Icon(Icons.chevron_right, size: 16),
                label: const Text('Siguiente'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  foregroundColor: AppPalette.primary,
                  disabledForegroundColor: const Color(0xFF94A3B8),
                  disabledIconColor: const Color(0xFF94A3B8),
                  side: BorderSide(
                    color: _paginaActual < _totalPaginas ? AppPalette.primary : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 5. MODAL DE TASACIÓN GERENCIAL (FIJAR PRECIO COMERCIAL)
  // =========================================================================
  void _abrirModalTasacion(CatalogoItem item) {
    final estLower = (item.estadoActivo ?? '').toLowerCase().trim();
    if (estLower != 'disponible' && estLower != 'paletizado') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No es posible modificar el precio de un repuesto en estado "${item.estadoActivo}". Solo está permitido en Disponible o Paletizado.',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppPalette.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final bool esEdicionPrevia = item.precioReferencia != null && item.precioReferencia! > 0;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _TasacionDialog(
        item: item,
        onSuccess: (nuevoPrecio) {
          _cargarInventario();
          widget.onStockMutado?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                esEdicionPrevia
                    ? '¡Precio de ${item.skuQrFisico} actualizado a ${_formatoCLP(nuevoPrecio)}!'
                    : '¡Precio de ${item.skuQrFisico} fijado a ${_formatoCLP(nuevoPrecio)}! Repuesto disponible en catálogo.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              backgroundColor: AppPalette.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.borderLight),
      ),
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 48, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 12),
            const Text(
              'No se encontraron repuestos',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Prueba ajustando los filtros de búsqueda, combustible, ubicación o estado.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _limpiarFiltros,
              child: const Text('Restablecer Filtros'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.error.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppPalette.error, size: 40),
            const SizedBox(height: 10),
            Text(
              _errorMessage ?? 'Ocurrió un error al cargar el inventario.',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () => _cargarInventario(),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(backgroundColor: AppPalette.primary, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// Diálogo Modal de Tasación Gerencial con Cabecera Azul Corporativa `#004C89`
class _TasacionDialog extends StatefulWidget {
  final CatalogoItem item;
  final ValueChanged<int> onSuccess;

  const _TasacionDialog({
    required this.item,
    required this.onSuccess,
  });

  @override
  State<_TasacionDialog> createState() => _TasacionDialogState();
}

class _TasacionDialogState extends State<_TasacionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _precioController;
  late final int _precioOriginal;
  late final bool _esEdicion;
  bool _enviando = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    final bool tienePrecio = widget.item.precioReferencia != null && widget.item.precioReferencia! > 0;
    _esEdicion = tienePrecio;
    _precioOriginal = tienePrecio ? widget.item.precioReferencia! : 0;
    final valorInicial = tienePrecio ? _precioOriginal.toString() : '';
    _precioController = TextEditingController(text: valorInicial);
    _precioController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _precioController.dispose();
    super.dispose();
  }

  int _extraerMontoLimpio(String texto) {
    final clean = texto.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(clean) ?? 0;
  }

  Future<void> _guardarTasacion() async {
    final monto = _extraerMontoLimpio(_precioController.text);
    if (monto <= 0) {
      setState(() => _errorMsg = 'El precio debe ser un monto entero positivo mayor a \$0.');
      return;
    }
    if (_esEdicion && monto == _precioOriginal) {
      setState(() => _errorMsg = 'No se han detectado cambios en el precio.');
      return;
    }

    setState(() {
      _enviando = true;
      _errorMsg = null;
    });

    try {
      await GerenciaService.tasarActivo(
        idActivo: widget.item.idActivo,
        precioReferencia: monto,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSuccess(monto);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = e.toString().replaceAll('Exception: ', '');
        _enviando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final montoActual = _extraerMontoLimpio(_precioController.text);
    final bool puedeGuardar = _esEdicion
        ? (montoActual > 0 && montoActual != _precioOriginal)
        : (montoActual > 0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppPalette.borderLight.withValues(alpha: 0.6), width: 1.0),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Encabezado Monolítico Azul Corporativo (#004C89)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                color: AppPalette.tertiary,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(_esEdicion ? Icons.edit_note_rounded : Icons.sell, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _esEdicion ? 'Actualizar Precio Comercial' : 'Fijar Precio de Tasación',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _esEdicion
                                ? 'Modificación de precio autorizado para catálogo'
                                : 'Autorización comercial Jefe de Ventas / Gerencia',
                            style: const TextStyle(
                              color: Color(0xFFBAE6FD),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Cuerpo del Modal
              Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Ficha Técnica Resumida del Repuesto
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppPalette.borderLight),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Tooltip(
                              message: widget.item.imagenes.isNotEmpty
                                  ? 'Click para ver fotos en alta resolución'
                                  : 'Sin fotos registradas',
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: widget.item.imagenes.isNotEmpty
                                    ? () => VisorImagenCompletaDialog.show(
                                          context,
                                          fotografias: widget.item.imagenes,
                                          initialIndex: 0,
                                          titulo: widget.item.tituloRepuesto,
                                          sku: widget.item.skuQrFisico,
                                        )
                                    : null,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        width: 64,
                                        height: 64,
                                        color: const Color(0xFFE2E8F0),
                                        child: widget.item.imagenes.isNotEmpty
                                            ? Image.network(
                                                widget.item.imagenes.first,
                                                fit: BoxFit.cover,
                                                cacheWidth: 200,
                                                cacheHeight: 200,
                                                errorBuilder: (context, error, stackTrace) => const Icon(
                                                  Icons.directions_car,
                                                  color: Color(0xFF94A3B8),
                                                ),
                                              )
                                            : const Icon(
                                                Icons.directions_car,
                                                color: Color(0xFF94A3B8),
                                              ),
                                      ),
                                    ),
                                    if (widget.item.imagenes.isNotEmpty)
                                      Positioned(
                                        right: 3,
                                        bottom: 3,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.75),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.fullscreen, size: 9, color: Colors.white70),
                                              if (widget.item.imagenes.length > 1) ...[
                                                const SizedBox(width: 2),
                                                Text(
                                                  '${widget.item.imagenes.length}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 9,
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
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: widget.item.idCategoria == 1
                                              ? const Color(0xFFE0F2FE)
                                              : const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          widget.item.nombreCategoria,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: widget.item.idCategoria == 1
                                                ? const Color(0xFF075985)
                                                : const Color(0xFF78350F),
                                          ),
                                        ),
                                      ),
                                      Text(
                                        widget.item.skuQrFisico,
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.w900,
                                          fontSize: 11,
                                          color: AppPalette.tertiary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.item.tituloRepuesto,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'G${widget.item.ubicacionGalpon ?? "1"} • Pasillo ${widget.item.ubicacionPasillo ?? "-"} • Pallet ${widget.item.ubicacionPallet ?? "-"}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (widget.item.imagenes.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    InkWell(
                                      onTap: () => VisorImagenCompletaDialog.show(
                                        context,
                                        fotografias: widget.item.imagenes,
                                        initialIndex: 0,
                                        titulo: widget.item.tituloRepuesto,
                                        sku: widget.item.skuQrFisico,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.fullscreen, size: 14, color: AppPalette.primary),
                                          const SizedBox(width: 4),
                                          Text(
                                            widget.item.imagenes.length > 1
                                                ? 'Ver las ${widget.item.imagenes.length} fotos en alta resolución'
                                                : 'Ver foto en alta resolución',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: AppPalette.primary,
                                              decoration: TextDecoration.underline,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Input de Precio Autorizado en CLP
                      const Text(
                        'PRECIO DE VENTA AUTORIZADO (\$ CLP):',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _precioController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFFFFFBF5),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(left: 14, right: 8),
                            child: Text(
                              '\$',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                          hintText: 'Ej: 1200000',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFFFB923C),
                              width: 1.5,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFFFB923C),
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFFEA580C),
                              width: 2.0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            _esEdicion ? Icons.info_outline_rounded : Icons.verified,
                            size: 14,
                            color: _esEdicion ? AppPalette.tertiary : const Color(0xFF059669),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _esEdicion
                                  ? 'El nuevo precio se actualizará inmediatamente en el catálogo de ventas.'
                                  : 'Al confirmar, el estado pasará a "Disponible" y se habilitará en el catálogo.',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),

                      if (_errorMsg != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _errorMsg!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppPalette.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Footer de Acciones del Modal
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(top: BorderSide(color: AppPalette.borderLight)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _enviando ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: (_enviando || !puedeGuardar) ? null : _guardarTasacion,
                      icon: _enviando
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Icon(_esEdicion ? Icons.check_circle_outline : Icons.check_circle, size: 16),
                      label: Text(
                        _enviando
                            ? 'Guardando...'
                            : _esEdicion
                                ? 'Confirmar'
                                : 'Aprobar y Habilitar Venta',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFE2E8F0),
                        disabledForegroundColor: const Color(0xFF94A3B8),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// Widget optimizado para el encabezado fotográfico con navegación multi-imagen,
/// carrusel de fotografías, zoom al pasar el mouse y apertura de visor en alta resolución.
/// Utiliza [AnimatedScale] en la capa del compositor de la GPU, garantizando 60/120 fps.
class _CardImageZoom extends StatefulWidget {
  final List<String> imagenes;
  final Widget Function() fallbackBuilder;
  final String? titulo;
  final String? sku;

  const _CardImageZoom({
    required this.imagenes,
    required this.fallbackBuilder,
    this.titulo,
    this.sku,
  });

  @override
  State<_CardImageZoom> createState() => _CardImageZoomState();
}

class _CardImageZoomState extends State<_CardImageZoom> {
  bool _isHovered = false;
  int _currentIndex = 0;

  @override
  void didUpdateWidget(covariant _CardImageZoom oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imagenes.length != oldWidget.imagenes.length) {
      if (_currentIndex >= widget.imagenes.length) {
        _currentIndex = math.max(0, widget.imagenes.length - 1);
      }
    }
  }

  void _irAAnterior() {
    if (widget.imagenes.length <= 1) return;
    setState(() {
      _currentIndex = (_currentIndex - 1 + widget.imagenes.length) % widget.imagenes.length;
    });
  }

  void _irASiguiente() {
    if (widget.imagenes.length <= 1) return;
    setState(() {
      _currentIndex = (_currentIndex + 1) % widget.imagenes.length;
    });
  }

  void _abrirVisorGrande() {
    if (widget.imagenes.isEmpty) return;
    VisorImagenCompletaDialog.show(
      context,
      fotografias: widget.imagenes,
      initialIndex: _currentIndex,
      titulo: widget.titulo,
      sku: widget.sku,
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalFotos = widget.imagenes.length;
    final tieneFotos = totalFotos > 0;

    return MouseRegion(
      cursor: tieneFotos ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        height: 155,
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFFF1F5F9),
          borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Capa interactiva de imagen con zoom suave por GPU
            GestureDetector(
              onTap: tieneFotos ? _abrirVisorGrande : null,
              onHorizontalDragEnd: (details) {
                if (totalFotos <= 1) return;
                if (details.primaryVelocity! < -80) {
                  _irASiguiente();
                } else if (details.primaryVelocity! > 80) {
                  _irAAnterior();
                }
              },
              child: AnimatedScale(
                scale: _isHovered ? 1.04 : 1.0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child: tieneFotos
                    ? AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                        child: Image.network(
                          widget.imagenes[_currentIndex.clamp(0, totalFotos - 1)],
                          key: ValueKey('card-img-${widget.imagenes[_currentIndex.clamp(0, totalFotos - 1)]}-$_currentIndex'),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 155,
                          cacheWidth: 600,
                          cacheHeight: 400,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: const Color(0xFFF1F5F9),
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                    color: AppPalette.primary.withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              widget.fallbackBuilder(),
                        ),
                      )
                    : widget.fallbackBuilder(),
              ),
            ),

            // Botón Ampliar Pantalla Completa (esquina superior derecha, aparece en hover)
            if (tieneFotos)
              Positioned(
                top: 8,
                right: 8,
                child: AnimatedOpacity(
                  opacity: _isHovered ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: Tooltip(
                    message: 'Ver en tamaño grande',
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(6),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: _abrirVisorGrande,
                        hoverColor: Colors.black.withValues(alpha: 0.85),
                        child: const Padding(
                          padding: EdgeInsets.all(5),
                          child: Icon(Icons.fullscreen, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Flechas laterales de carrusel (cuando hay más de 1 imagen)
            if (totalFotos > 1) ...[
              // Flecha Izquierda
              Positioned(
                left: 6,
                top: 0,
                bottom: 0,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _isHovered ? 1.0 : 0.75,
                    duration: const Duration(milliseconds: 150),
                    child: Tooltip(
                      message: 'Foto anterior',
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: _irAAnterior,
                          hoverColor: Colors.black.withValues(alpha: 0.85),
                          child: const Padding(
                            padding: EdgeInsets.all(5),
                            child: Icon(Icons.chevron_left, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Flecha Derecha
              Positioned(
                right: 6,
                top: 0,
                bottom: 0,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _isHovered ? 1.0 : 0.75,
                    duration: const Duration(milliseconds: 150),
                    child: Tooltip(
                      message: 'Foto siguiente',
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: _irASiguiente,
                          hoverColor: Colors.black.withValues(alpha: 0.85),
                          child: const Padding(
                            padding: EdgeInsets.all(5),
                            child: Icon(Icons.chevron_right, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Pill Contador de Fotos (esquina inferior derecha)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.photo_library_outlined, size: 11, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        '${_currentIndex + 1}/$totalFotos',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
