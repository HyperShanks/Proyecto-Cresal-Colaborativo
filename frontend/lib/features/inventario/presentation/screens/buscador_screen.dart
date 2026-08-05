import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../services/inventario_service.dart';
// Importamos la tarjeta de resultados que creaste en la carpeta widgets
import '../widgets/resultado_card.dart';

class BuscadorScreen extends StatefulWidget {
  const BuscadorScreen({Key? key}) : super(key: key);

  @override
  State<BuscadorScreen> createState() => _BuscadorScreenState();
}

class _BuscadorScreenState extends State<BuscadorScreen> {
  bool _isLoadingFiltros = true;
  String _errorFiltros = '';
  bool _isSearching = false;
  List<dynamic> _resultados = [];

  // Datos desde la BD
  Map<String, List<String>> _opcionesFiltros = {};

  // Variables de estado para lo que el usuario selecciona
  String? _categoria;
  String? _pasillo;
  String? _pallet;
  String? _marca;
  String? _modelo;
  String? _cilindrada;
  String? _combustible;
  String? _transmision;

  @override
  void initState() {
    super.initState();
    _cargarFiltros();
  }

  Future<void> _cargarFiltros() async {
    try {
      final opciones = await InventarioService.obtenerOpcionesFiltros();
      setState(() {
        _opcionesFiltros = opciones;
        _isLoadingFiltros = false;
      });
    } catch (e) {
      setState(() {
        _errorFiltros = e.toString();
        _isLoadingFiltros = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: Text(
          'INVENTARIO',
          style: AppTypography.headline.copyWith(
            color: AppPalette.textPrimary,
            letterSpacing: 1.5,
          ),
        ),
        backgroundColor: AppPalette.surface,
        iconTheme: const IconThemeData(color: AppPalette.primary),
      ),
      body: _isLoadingFiltros
          ? const Center(
              child: CircularProgressIndicator(color: AppPalette.primary),
            )
          : _errorFiltros.isNotEmpty
          ? Center(
              child: Text(
                'Error cargando filtros: $_errorFiltros',
                style: const TextStyle(color: AppPalette.error),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── FILTRO PRINCIPAL (Categoría) ──
                  _buildDropdown(
                    label: 'CATEGORÍA DE INVENTARIO',
                    value: _categoria,
                    items: [
                      'MOTORES',
                      'CAJAS DE CAMBIO',
                      'ACCESORIOS',
                    ], // Esto suele ser fijo
                    onChanged: (val) => setState(() => _categoria = val),
                    isFeatured: true,
                  ),
                  const SizedBox(height: 16),

                  // ── FILTROS SECUNDARIOS (En cuadrícula) ──
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          label: 'PASILLO',
                          value: _pasillo,
                          items: _opcionesFiltros['pasillos'] ?? [],
                          onChanged: (val) => setState(() => _pasillo = val),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDropdown(
                          label: 'PALLET',
                          value: _pallet,
                          items: _opcionesFiltros['pallets'] ?? [],
                          onChanged: (val) => setState(() => _pallet = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          label: 'MARCA',
                          value: _marca,
                          items: _opcionesFiltros['marcas'] ?? [],
                          onChanged: (val) => setState(() => _marca = val),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDropdown(
                          label: 'MODELO',
                          value: _modelo,
                          items: _opcionesFiltros['modelos'] ?? [],
                          onChanged: (val) => setState(() => _modelo = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDropdown(
                    label: 'CILINDRADA',
                    value: _cilindrada,
                    items: _opcionesFiltros['cilindradas'] ?? [],
                    onChanged: (val) => setState(() => _cilindrada = val),
                  ),
                  const SizedBox(height: 12),
                  _buildDropdown(
                    label: 'TIPO COMBUSTIBLE',
                    value: _combustible,
                    items: _opcionesFiltros['combustibles'] ?? [],
                    onChanged: (val) => setState(() => _combustible = val),
                  ),
                  const SizedBox(height: 12),
                  _buildDropdown(
                    label: 'TIPO TRANSMISIÓN',
                    value: _transmision,
                    items: _opcionesFiltros['transmisiones'] ?? [],
                    onChanged: (val) => setState(() => _transmision = val),
                  ),

                  const SizedBox(height: 24),

                  // ── BOTÓN BUSCAR ──
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: _isSearching
                          ? null
                          : () async {
                              setState(() => _isSearching = true);
                              try {
                                final resultados =
                                    await InventarioService.buscarRepuestos(
                                      categoria: _categoria,
                                      pasillo: _pasillo,
                                      pallet: _pallet,
                                      marca: _marca,
                                      modelo: _modelo,
                                      cilindrada: _cilindrada,
                                      combustible: _combustible,
                                      transmision: _transmision,
                                    );
                                setState(() {
                                  _resultados = resultados;
                                });
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Error: $e',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    backgroundColor: AppPalette.error,
                                  ),
                                );
                              } finally {
                                setState(() => _isSearching = false);
                              }
                            },
                      icon: _isSearching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: AppPalette.background,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.search,
                              color: AppPalette.textPrimary,
                            ),
                      label: Text(
                        _isSearching ? 'BUSCANDO...' : 'BUSCAR REPUESTOS',
                        style: AppTypography.button.copyWith(
                          color: AppPalette.textPrimary,
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

                  const SizedBox(height: 32),

                  // ── SECCIÓN DE RESULTADOS DINÁMICA ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Resultados (${_resultados.length})',
                        style: AppTypography.title,
                      ),
                      if (_resultados.isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            // Limpiar filtros
                            setState(() {
                              _categoria = null;
                              _pasillo = null;
                              _pallet = null;
                              _marca = null;
                              _modelo = null;
                              _cilindrada = null;
                              _combustible = null;
                              _transmision = null;
                              _resultados = [];
                            });
                          },
                          icon: const Icon(
                            Icons.clear_all,
                            size: 18,
                            color: AppPalette.secondary,
                          ),
                          label: Text(
                            'Limpiar',
                            style: AppTypography.small.copyWith(
                              color: AppPalette.secondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_resultados.isEmpty && !_isSearching)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text(
                          'Seleccione los filtros y presione buscar.',
                          style: AppTypography.small.copyWith(
                            color: AppPalette.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),

                  // ── ITERACIÓN DE TARJETAS DE RESULTADO ──
                  ..._resultados.map((item) {
                    return ResultadoCard(
                      itemCompleto: item, // ⚠️ PASAMOS TODO EL ITEM AQUÍ
                      marca: item['marca']?.toString() ?? 'Desconocida',
                      modelo: item['modelo']?.toString() ?? 'Desconocido',
                      sku: item['sku']?.toString() ?? 'S/N',
                      ubicacion: item['ubicacion']?.toString() ?? 'S/P - S/P',
                      estado: item['estado']?.toString() ?? 'DISPONIBLE',
                    );
                  }).toList(),
                ],
              ),
            ),
    );
  }

  // ── WIDGET REUTILIZABLE CORREGIDO ──
  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
    bool isFeatured = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.small.copyWith(
            color: isFeatured
                ? AppPalette.textPrimary
                : AppPalette.textSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          // ⚠️ FIX: isExpanded en true evita el error "RenderFlex overflowed by 89 pixels"
          isExpanded: true,
          value: value,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppPalette.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isFeatured
                    ? AppPalette.primary
                    : AppPalette.neutral.withValues(alpha: 0.3),
                width: isFeatured ? 2 : 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isFeatured
                    ? AppPalette.primary
                    : AppPalette.neutral.withValues(alpha: 0.3),
                width: isFeatured ? 2 : 1,
              ),
            ),
          ),
          dropdownColor: AppPalette.surface,
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: isFeatured ? AppPalette.primary : AppPalette.textSecondary,
          ),
          // ⚠️ FIX: Eliminamos el 'hint' e inyectamos un valor nulo manual en los items
          // Esto permite que el usuario pueda "deseleccionar" un filtro dejándolo en "TODAS"
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(
                isFeatured ? '[ SELECCIONE ]' : 'TODAS',
                style: AppTypography.body.copyWith(
                  color: isFeatured
                      ? AppPalette.textPrimary
                      : AppPalette.textSecondary,
                  fontWeight: isFeatured ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            ...items.map((item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  style: AppTypography.body,
                  overflow: TextOverflow
                      .ellipsis, // Protección extra contra desbordes
                ),
              );
            }).toList(),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}
