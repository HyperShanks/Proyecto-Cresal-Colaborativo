// frontend/lib/features/gerencia/presentation/screens/inventario_gerencia_view.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/tokens/app_palette.dart';
import '../../../ventas/models/catalogo_model.dart';
import '../../services/gerencia_service.dart';

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
  State<InventarioGerenciaView> createState() => _InventarioGerenciaViewState();
}

class _InventarioGerenciaViewState extends State<InventarioGerenciaView> {
  late final TextEditingController _busquedaController;
  Timer? _debounceTimer;

  int? _idSucursal;
  bool _soloSinTasar = false;
  ModoVistaStock _modoVista = ModoVistaStock.tarjetas;

  // Filtros Secundarios
  String _categoria = 'todas';
  String _ubicacion = 'todas';
  String _combustible = 'todos';
  String _transmision = 'todas';
  String _estado = 'todos';

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
    _cargarInventario();
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
        ubicacion: _ubicacion,
        soloSinTasar: _soloSinTasar,
        busqueda: _busquedaController.text.trim(),
        limite: _limitePorPagina,
        offset: offset,
      );

      if (!mounted) return;

      setState(() {
        _items = res.items;
        _totalCount = res.totalCount;
        _pendientesTasacionCount = res.pendientesTasacionCount;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
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
      _ubicacion = 'todas';
      _combustible = 'todos';
      _transmision = 'todas';
      _estado = 'todos';
      _paginaActual = 1;
    });
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
    return Column(
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
                // 2. Ubicación
                _buildDropdown(
                  value: _ubicacion,
                  items: const [
                    DropdownMenuItem(value: 'todas', child: Text('Ubicación: Todas')),
                    DropdownMenuItem(value: 'pasillo-A', child: Text('Pasillo A')),
                    DropdownMenuItem(value: 'pasillo-B', child: Text('Pasillo B')),
                    DropdownMenuItem(value: 'pasillo-C', child: Text('Pasillo C')),
                    DropdownMenuItem(value: 'pallet-1', child: Text('Pallet 1')),
                    DropdownMenuItem(value: 'pallet-2', child: Text('Pallet 2')),
                    DropdownMenuItem(value: 'pallet-4', child: Text('Pallet 4')),
                    DropdownMenuItem(value: 'pallet-8', child: Text('Pallet 8')),
                    DropdownMenuItem(value: 'galpon-1', child: Text('Galpón 1')),
                  ],
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() => _ubicacion = val);
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
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.borderLight),
      ),
      child: TextField(
        controller: _busquedaController,
        onChanged: _onBusquedaChanged,
        style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          prefixIcon: Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
          hintText: 'Buscar por SKU, Marca, Pasillo (A, B, C), Pallet o N° Ingreso...',
          hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          border: InputBorder.none,
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
          value: value,
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
              if (width < 750) {
                crossAxisCount = 1;
              } else if (width < 1150) {
                crossAxisCount = 2;
              } else if (width < 1500) {
                crossAxisCount = 3;
              }

              return GridView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  mainAxisExtent: 410, // Altura fija garantizada anti-overflow
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
    final esPaletizado = estadoNombre.toLowerCase() == 'paletizado' || item.idEstado == 7;
    final esBloqueado = (estadoNombre.toLowerCase() == 'reservado' || estadoNombre.toLowerCase() == 'vendido') && tienePrecio;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera Fotográfica
            Stack(
              children: [
                Container(
                  height: 160,
                  width: double.infinity,
                  color: const Color(0xFFF1F5F9),
                  child: item.imagenes.isNotEmpty
                      ? Image.network(
                          item.imagenes.first,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildFallbackImage(),
                        )
                      : _buildFallbackImage(),
                ),

                // Badge Superior Flotante: Estado Físico
                Positioned(
                  top: 10,
                  left: 10,
                  child: _buildBadgeEstado(estadoNombre),
                ),

                // Badge Inferior Flotante: SKU QR Físico
                Positioned(
                  bottom: 8,
                  left: 10,
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
              ],
            ),

            // Cuerpo de la Tarjeta
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
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

                        // Título Técnico del Repuesto
                        Text(
                          item.tituloRepuesto,
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
                      ],
                    ),

                    Column(
                      children: [
                        // Ubicación Física en Bodega
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
                                  Icon(Icons.warehouse_outlined, size: 14, color: Color(0xFF94A3B8)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Ubicación:',
                                    style: TextStyle(
                                      fontSize: 11,
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
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

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
                                      fontSize: tienePrecio ? 15 : 12,
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
                  ],
                ),
              ),
            ),
          ],
        ),
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
    final estLower = estado.toLowerCase();

    if (estLower == 'paletizado') {
      bg = const Color(0xFFF59E0B);
      border = const Color(0xFFD97706);
    } else if (estLower == 'disponible') {
      bg = const Color(0xFF059669);
      border = const Color(0xFF047857);
    } else if (estLower == 'reservado') {
      bg = const Color(0xFF334155);
      border = const Color(0xFF1E293B);
    } else {
      bg = const Color(0xFF475569);
      border = const Color(0xFF334155);
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
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppPalette.borderLight),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                        headingTextStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF475569),
                          letterSpacing: 0.5,
                        ),
                        dataTextStyle: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
                        dataRowMinHeight: 52,
                        dataRowMaxHeight: 64,
                        horizontalMargin: 16,
                        columnSpacing: 24,
                        columns: const [
                          DataColumn(label: Text('SKU / QR FÍSICO')),
                          DataColumn(label: Text('PIEZA / FICHA TÉCNICA')),
                          DataColumn(label: Text('UBICACIÓN FÍSICA')),
                          DataColumn(label: Text('SUCURSAL')),
                          DataColumn(label: Text('ESTADO FÍSICO')),
                          DataColumn(label: Text('PRECIO TASACIÓN')),
                          DataColumn(label: Text('ACCIÓN')),
                        ],
                        rows: _items.map((item) {
                          final tienePrecio = item.precioReferencia != null && item.precioReferencia! > 0;
                          final estadoNombre = item.estadoActivo ?? 'Disponible';
                          final esPaletizado = estadoNombre.toLowerCase() == 'paletizado' || item.idEstado == 7;
                          final esBloqueado = (estadoNombre.toLowerCase() == 'reservado' || estadoNombre.toLowerCase() == 'vendido') && tienePrecio;

                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  item.skuQrFisico,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w900,
                                    color: AppPalette.tertiary,
                                  ),
                                ),
                              ),
                              DataCell(
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
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
                                          Text(
                                            item.tituloRepuesto,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${item.combustible ?? ""} • ${item.transmisionTipo ?? ""}${item.cilindrada != null ? " • ${item.cilindrada!}L" : ""}',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
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
                              DataCell(Text(item.nombreSucursal)),
                              DataCell(_buildBadgeEstado(estadoNombre)),
                              DataCell(
                                tienePrecio
                                    ? Text(
                                        _formatoCLP(item.precioReferencia),
                                        style: const TextStyle(fontWeight: FontWeight.w900),
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
                              DataCell(
                                esBloqueado
                                    ? const Text(
                                        'Bloqueado',
                                        style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
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
                            ],
                          );
                        }).toList(),
                      ),
                    ),
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
                '¡Precio de ${item.skuQrFisico} fijado a ${_formatoCLP(nuevoPrecio)}! Repuesto disponible en catálogo.',
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
  bool _enviando = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    final valorInicial = (widget.item.precioReferencia != null && widget.item.precioReferencia! > 0)
        ? widget.item.precioReferencia.toString()
        : '';
    _precioController = TextEditingController(text: valorInicial);
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
                      child: const Icon(Icons.sell, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Fijar Precio de Tasación',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Autorización comercial Jefe de Ventas / Gerencia',
                            style: TextStyle(
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
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED).withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFFB923C),
                            width: 1.5,
                          ),
                        ),
                        child: TextField(
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
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            prefixIcon: Padding(
                              padding: EdgeInsets.only(left: 12, right: 6),
                              child: Text(
                                '\$',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                            prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
                            hintText: 'Ej: 1200000',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: const [
                          Icon(Icons.verified, size: 14, color: Color(0xFF059669)),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Al confirmar, el estado pasará a "Disponible" y se habilitará en el catálogo.',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
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
                      onPressed: _enviando ? null : _guardarTasacion,
                      icon: _enviando
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle, size: 16),
                      label: Text(_enviando ? 'Guardando...' : 'Aprobar y Habilitar Venta'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
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
