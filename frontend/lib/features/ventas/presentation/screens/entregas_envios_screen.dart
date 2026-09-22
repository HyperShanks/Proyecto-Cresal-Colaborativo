import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../../auth/services/auth_service.dart';
import '../widgets/qr_ticket_dialog.dart';
import '../../services/ordenes_service.dart';
import '../../services/ordenes_sync_notifier.dart';

/// Pantalla colaborativa para el Módulo 'Entregas y Envíos'
/// Permite gestionar retiros en sucursal y despachos externos con filtros avanzados,
/// trazabilidad de vendedores, tarjetas limpias y modal de detalle exhaustivo.
class EntregasEnviosScreen extends StatefulWidget {
  const EntregasEnviosScreen({super.key});

  @override
  State<EntregasEnviosScreen> createState() => _EntregasEnviosScreenState();
}

class _EntregasEnviosScreenState extends State<EntregasEnviosScreen> {
  // Controladores y Estados de Filtros
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _clienteFilterController = TextEditingController();
  final TextEditingController _vendedorFilterController = TextEditingController();
  String _searchQuery = '';
  bool _soloMisAsignadas = false;
  String? _currentUserId;
  String? _currentUserName;
  String _estadoPagoFilter = 'todos'; // 'todos', 'pagados', 'pendientes'
  String _tipoEntregaFilter = 'todos'; // 'todos', 'retiro', 'despacho', 'traslado'

  List<EntregaEnvioModel> _todasEntregas = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    OrdenesSyncNotifier.instance.addListener(_onSyncNotification);
    _verificarPermisosYCargar();
  }

  void _onSyncNotification() {
    if (mounted) {
      if (_todasEntregas.isNotEmpty) {
        _cargarDatosSilencioso();
      } else {
        _cargarDatos();
      }
    }
  }

  Future<void> _cargarDatosSilencioso() async {
    try {
      final data = await OrdenesService.obtenerEntregasEnvios(
        busquedaCliente: _clienteFilterController.text.trim().isNotEmpty
            ? _clienteFilterController.text.trim()
            : null,
        busquedaVendedor: _vendedorFilterController.text.trim().isNotEmpty
            ? _vendedorFilterController.text.trim()
            : null,
        estadoPago: _estadoPagoFilter != 'todos' ? _estadoPagoFilter : null,
      );
      if (!mounted) return;
      setState(() {
        _todasEntregas = data;
        _errorMessage = null;
        _isLoading = false;
      });
    } catch (_) {
      // Silenciar errores transitorios en segundo plano
    }
  }

  Future<void> _verificarPermisosYCargar() async {
    final idRol = await AuthService.getIdRol();
    final rol = await AuthService.getRol();
    final esVendedorOnline = idRol == 7 ||
        rol?.toLowerCase() == 'vendedoronline' ||
        rol?.toLowerCase() == 'vendedor online';

    if (esVendedorOnline) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppPalette.surface,
          content: Text(
            'Acceso restringido: Las entregas presenciales son gestionadas por el equipo de sucursal.',
            style: TextStyle(color: AppPalette.error),
          ),
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    final authUser = await AuthService.getAuthUser();
    final nombre = await AuthService.getNombreUsuario();
    if (mounted) {
      setState(() {
        _currentUserId = authUser?.idUsuario;
        _currentUserName = nombre ?? authUser?.nombreCompleto;
      });
    }

    _cargarDatos();
  }

  @override
  void dispose() {
    OrdenesSyncNotifier.instance.removeListener(_onSyncNotification);
    _searchController.dispose();
    _clienteFilterController.dispose();
    _vendedorFilterController.dispose();
    super.dispose();
  }

  bool get _tieneFiltrosActivos =>
      _searchQuery.isNotEmpty ||
      _soloMisAsignadas ||
      _clienteFilterController.text.trim().isNotEmpty ||
      _vendedorFilterController.text.trim().isNotEmpty ||
      _estadoPagoFilter != 'todos' ||
      _tipoEntregaFilter != 'todos';

  Future<void> _cargarDatos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await OrdenesService.obtenerEntregasEnvios(
        busquedaCliente: _clienteFilterController.text.trim().isNotEmpty
            ? _clienteFilterController.text.trim()
            : null,
        busquedaVendedor: _vendedorFilterController.text.trim().isNotEmpty
            ? _vendedorFilterController.text.trim()
            : null,
        estadoPago: _estadoPagoFilter != 'todos' ? _estadoPagoFilter : null,
      );
      if (!mounted) return;
      setState(() {
        _todasEntregas = data;
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

  bool _isAsignadaAMi(EntregaEnvioModel e) {
    if (_currentUserId != null &&
        e.idVendedorAsignado != null &&
        e.idVendedorAsignado!.trim().isNotEmpty &&
        e.idVendedorAsignado == _currentUserId) {
      return true;
    }
    if (_currentUserName != null &&
        _currentUserName!.trim().isNotEmpty &&
        e.vendedorAsignadoNombre != null &&
        e.vendedorAsignadoNombre!.trim().isNotEmpty) {
      final userTokens = _currentUserName!
          .toLowerCase()
          .split(' ')
          .where((t) => t.length > 2);
      final asignadoLower = e.vendedorAsignadoNombre!.toLowerCase();
      for (final token in userTokens) {
        if (asignadoLower.contains(token)) return true;
      }
    }
    return false;
  }

  List<EntregaEnvioModel> get _ordenesFiltradas {
    var lista = _todasEntregas.where((e) {
      if (e.esVentaEnVerde && (!e.estaPagada || !e.tieneQrDisponible)) {
        return false;
      }
      return true;
    }).toList();

    // 1. Filtro rápido de "Mis Asignadas" (Responsabilidad de entrega física)
    if (_soloMisAsignadas) {
      lista = lista.where(_isAsignadaAMi).toList();
    }

    // 2. Filtro por Modalidad de Entrega
    if (_tipoEntregaFilter != 'todos') {
      if (_tipoEntregaFilter == 'despacho') {
        lista = lista
            .where((e) =>
                e.tipoEntrega.toLowerCase() == 'despacho' ||
                e.tipoEntrega.toLowerCase() == 'despacho domicilio')
            .toList();
      } else if (_tipoEntregaFilter == 'traslado') {
        lista = lista
            .where((e) => e.tipoEntrega.toLowerCase() == 'traslado')
            .toList();
      } else {
        lista = lista
            .where((e) => e.tipoEntrega.toLowerCase() == _tipoEntregaFilter)
            .toList();
      }
    }

    // 3. Filtro por Estado de Pago
    if (_estadoPagoFilter != 'todos') {
      if (_estadoPagoFilter == 'pagados') {
        lista = lista.where((e) => e.estaPagada).toList();
      } else if (_estadoPagoFilter == 'pendientes') {
        lista = lista.where((e) => e.tieneSaldoPendiente).toList();
      }
    }

    // 4. Buscador Reactivo Unificado (Folio, Cliente, RUT, Teléfono, Vendedor Online, Vendedor Responsable, Repuesto)
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      final qSinPuntos = q.replaceAll('.', '').replaceAll('-', '');
      lista = lista.where((e) {
        // Coincidencia por Folio
        if (e.folioDisplay.toLowerCase().contains(q) ||
            e.folio.toLowerCase().contains(q)) {
          return true;
        }
        // Coincidencia por Cliente (Nombre completo o display)
        if (e.cliente != null &&
            e.cliente!.nombreCompleto.toLowerCase().contains(q)) {
          return true;
        }
        if (e.clienteDisplay.toLowerCase().contains(q)) {
          return true;
        }
        // Coincidencia por RUT de Cliente (tolerante a puntos y guión)
        if (e.cliente != null && e.cliente!.rutCliente.isNotEmpty) {
          final rutLimpio = e.cliente!.rutCliente
              .replaceAll('.', '')
              .replaceAll('-', '')
              .toLowerCase();
          if (rutLimpio.contains(qSinPuntos)) return true;
        }
        // Coincidencia por Teléfono de Contacto
        if (e.cliente?.telefono != null && e.cliente!.telefono!.contains(q)) {
          return true;
        }
        if (e.despacho?.receptorTelefono != null &&
            e.despacho!.receptorTelefono.contains(q)) {
          return true;
        }
        // Coincidencia por Receptor y Comuna de Despacho
        if (e.despacho != null &&
            e.despacho!.receptorNombres.toLowerCase().contains(q)) {
          return true;
        }
        if (e.despacho?.comunaDestino != null &&
            e.despacho!.comunaDestino!.toLowerCase().contains(q)) {
          return true;
        }
        // Coincidencia por Vendedor Creador (Online / Central)
        if (e.vendedorNombre != null &&
            e.vendedorNombre!.toLowerCase().contains(q)) {
          return true;
        }
        // Coincidencia por Vendedor Asignado (Responsable en tienda de la entrega)
        if (e.vendedorAsignadoNombre != null &&
            e.vendedorAsignadoNombre!.toLowerCase().contains(q)) {
          return true;
        }
        // Coincidencia por Título o SKU del Repuesto
        if (e.detalles.any((d) =>
            d.tituloDisplay.toLowerCase().contains(q) ||
            (d.skuQrFisico != null &&
                d.skuQrFisico!.toLowerCase().contains(q)))) {
          return true;
        }

        return false;
      }).toList();
    }

    return lista;
  }

  void _limpiarFiltros() {
    _searchController.clear();
    _clienteFilterController.clear();
    _vendedorFilterController.clear();
    setState(() {
      _searchQuery = '';
      _soloMisAsignadas = false;
      _estadoPagoFilter = 'todos';
      _tipoEntregaFilter = 'todos';
    });
    Navigator.of(context).pop();
    _cargarDatos();
  }

  void _aplicarFiltros() {
    Navigator.of(context).pop();
    _cargarDatos();
  }

  void _abrirModalFiltros() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.88,
                ),
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 14,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Handle bar centrado
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),

                        // Cabecera del Modal de Filtros
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.tune_rounded, color: AppPalette.primary, size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  'Filtros de Búsqueda',
                                  style: AppTypography.title.copyWith(color: AppPalette.textPrimary),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: AppPalette.textSecondary),
                              onPressed: () => Navigator.of(ctx).pop(),
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white10, height: 20),

                        // Buscador 1: Cliente (Nombre, RUT, Teléfono)
                        Text(
                          'Búsqueda por Cliente',
                          style: AppTypography.small.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppPalette.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _clienteFilterController,
                          style: AppTypography.body.copyWith(fontSize: 14, color: AppPalette.textPrimary),
                          cursorColor: AppPalette.primary,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Nombre, RUT o Teléfono del cliente / receptor...',
                            hintStyle: AppTypography.small.copyWith(
                              color: AppPalette.textSecondary.withValues(alpha: 0.65),
                            ),
                            prefixIcon: const Icon(
                              Icons.person_search_outlined,
                              size: 20,
                              color: AppPalette.textSecondary,
                            ),
                            filled: true,
                            fillColor: AppPalette.background,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
                        ),
                        const SizedBox(height: 14),

                        // Buscador 2: Vendedor (Creador o Asignado)
                        Text(
                          'Búsqueda por Vendedor',
                          style: AppTypography.small.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppPalette.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _vendedorFilterController,
                          style: AppTypography.body.copyWith(fontSize: 14, color: AppPalette.textPrimary),
                          cursorColor: AppPalette.primary,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Nombre del vendedor creador o asignado...',
                            hintStyle: AppTypography.small.copyWith(
                              color: AppPalette.textSecondary.withValues(alpha: 0.65),
                            ),
                            prefixIcon: const Icon(
                              Icons.badge_outlined,
                              size: 20,
                              color: AppPalette.textSecondary,
                            ),
                            filled: true,
                            fillColor: AppPalette.background,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
                        ),
                        const SizedBox(height: 14),

                        // Filtro 3: Estado de Pago
                        Text(
                          'Estado de Pago / Liquidación',
                          style: AppTypography.small.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppPalette.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Todos'),
                              selected: _estadoPagoFilter == 'todos',
                              onSelected: (selected) {
                                if (selected) setModalState(() => _estadoPagoFilter = 'todos');
                              },
                              backgroundColor: AppPalette.background,
                              selectedColor: AppPalette.primary.withValues(alpha: 0.22),
                              side: BorderSide(
                                color: _estadoPagoFilter == 'todos'
                                    ? AppPalette.primary.withValues(alpha: 0.6)
                                    : Colors.white12,
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              labelStyle: TextStyle(
                                color: _estadoPagoFilter == 'todos' ? AppPalette.primary : AppPalette.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            ChoiceChip(
                              label: const Text('Pagados'),
                              selected: _estadoPagoFilter == 'pagados',
                              onSelected: (selected) {
                                if (selected) setModalState(() => _estadoPagoFilter = 'pagados');
                              },
                              backgroundColor: AppPalette.background,
                              selectedColor: AppPalette.success.withValues(alpha: 0.22),
                              side: BorderSide(
                                color: _estadoPagoFilter == 'pagados'
                                    ? AppPalette.success.withValues(alpha: 0.6)
                                    : Colors.white12,
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              labelStyle: TextStyle(
                                color: _estadoPagoFilter == 'pagados' ? AppPalette.success : AppPalette.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            ChoiceChip(
                              label: const Text('Con Saldo Pendiente'),
                              selected: _estadoPagoFilter == 'pendientes',
                              onSelected: (selected) {
                                if (selected) setModalState(() => _estadoPagoFilter = 'pendientes');
                              },
                              backgroundColor: AppPalette.background,
                              selectedColor: AppPalette.warning.withValues(alpha: 0.22),
                              side: BorderSide(
                                color: _estadoPagoFilter == 'pendientes'
                                    ? AppPalette.warning.withValues(alpha: 0.6)
                                    : Colors.white12,
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              labelStyle: TextStyle(
                                color: _estadoPagoFilter == 'pendientes' ? AppPalette.warning : AppPalette.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Filtro 4: Tipo de Pedido / Modalidad
                        Text(
                          'Tipo de Pedido / Modalidad',
                          style: AppTypography.small.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppPalette.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Todos'),
                              selected: _tipoEntregaFilter == 'todos',
                              onSelected: (selected) {
                                if (selected) setModalState(() => _tipoEntregaFilter = 'todos');
                              },
                              backgroundColor: AppPalette.background,
                              selectedColor: AppPalette.primary.withValues(alpha: 0.22),
                              side: BorderSide(
                                color: _tipoEntregaFilter == 'todos'
                                    ? AppPalette.primary.withValues(alpha: 0.6)
                                    : Colors.white12,
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              labelStyle: TextStyle(
                                color: _tipoEntregaFilter == 'todos' ? AppPalette.primary : AppPalette.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            ChoiceChip(
                              label: const Text('Solo Retiros'),
                              selected: _tipoEntregaFilter == 'retiro',
                              onSelected: (selected) {
                                if (selected) setModalState(() => _tipoEntregaFilter = 'retiro');
                              },
                              backgroundColor: AppPalette.background,
                              selectedColor: AppPalette.primary.withValues(alpha: 0.22),
                              side: BorderSide(
                                color: _tipoEntregaFilter == 'retiro'
                                    ? AppPalette.primary.withValues(alpha: 0.6)
                                    : Colors.white12,
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              labelStyle: TextStyle(
                                color: _tipoEntregaFilter == 'retiro' ? AppPalette.primary : AppPalette.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            ChoiceChip(
                              label: const Text('Solo Despachos'),
                              selected: _tipoEntregaFilter == 'despacho',
                              onSelected: (selected) {
                                if (selected) setModalState(() => _tipoEntregaFilter = 'despacho');
                              },
                              backgroundColor: AppPalette.background,
                              selectedColor: AppPalette.secondary.withValues(alpha: 0.22),
                              side: BorderSide(
                                color: _tipoEntregaFilter == 'despacho'
                                    ? AppPalette.secondary.withValues(alpha: 0.6)
                                    : Colors.white12,
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              labelStyle: TextStyle(
                                color: _tipoEntregaFilter == 'despacho' ? AppPalette.secondary : AppPalette.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            ChoiceChip(
                              label: const Text('Solo Traslados'),
                              selected: _tipoEntregaFilter == 'traslado',
                              onSelected: (selected) {
                                if (selected) setModalState(() => _tipoEntregaFilter = 'traslado');
                              },
                              backgroundColor: AppPalette.background,
                              selectedColor: const Color(0xFFAB47BC).withValues(alpha: 0.22),
                              side: BorderSide(
                                color: _tipoEntregaFilter == 'traslado'
                                    ? const Color(0xFFAB47BC).withValues(alpha: 0.6)
                                    : Colors.white12,
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              labelStyle: TextStyle(
                                color: _tipoEntregaFilter == 'traslado' ? const Color(0xFFAB47BC) : AppPalette.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Botonera de Acción del Modal
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppPalette.textSecondary,
                                  side: const BorderSide(color: Colors.white24),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: _limpiarFiltros,
                                child: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text('LIMPIAR'),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppPalette.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: _aplicarFiltros,
                                child: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'APLICAR FILTROS',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _abrirQrModal(EntregaEnvioModel orden) {
    QrTicketDialog.mostrar(context, orden.toHistorialModel());
  }



  Widget _buildDatoFila(IconData icon, String label, String valor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppPalette.textSecondary),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTypography.small.copyWith(
            color: AppPalette.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            valor,
            style: AppTypography.small.copyWith(
              color: AppPalette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// Confirmar entrega en tienda física (mostrador) para órdenes sin motor ni caja
  Future<void> _confirmarEntregaTienda(EntregaEnvioModel orden) async {
    if (orden.tieneSaldoPendiente) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppPalette.surface,
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              const Icon(Icons.lock_clock_rounded, color: AppPalette.warning, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No se puede entregar: Orden con saldo pendiente de ${orden.montoPendienteFormateado}. Requiere liquidación previa en Caja.',
                  style: const TextStyle(color: AppPalette.warning),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: AppPalette.success, size: 24),
            const SizedBox(width: 8),
            const Text('Confirmar Entrega', style: TextStyle(color: AppPalette.textPrimary)),
          ],
        ),
        content: Text(
          '¿Confirmar la entrega del pedido #${orden.folioDisplay} al cliente?\n\nEsta acción marcará la orden como Completada.',
          style: const TextStyle(color: AppPalette.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCELAR', style: TextStyle(color: AppPalette.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('CONFIRMAR ENTREGA', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await OrdenesService.confirmarEntregaTienda(orden.idOrden);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppPalette.surface,
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: AppPalette.success),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '¡Orden #${orden.folioDisplay} entregada exitosamente!',
                    style: const TextStyle(color: AppPalette.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        );
        _cargarDatos();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppPalette.surface,
            content: Text(
              'Error al confirmar entrega: ${e.toString().replaceAll("Exception: ", "")}',
              style: const TextStyle(color: AppPalette.error),
            ),
          ),
        );
      }
    }
  }

  /// Modal de Detalle Completo de la Orden al tocar la tarjeta (onTap)
  void _abrirDetalleCompleto(EntregaEnvioModel orden) {
    final bool saldoPendiente = orden.tieneSaldoPendiente;
    final desp = orden.despacho;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: ListView(
                controller: scrollController,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Cabecera: Folio + Fecha + Estado
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(orden.folioDisplay, style: AppTypography.title.copyWith(fontSize: 20)),
                          Text(orden.fechaFormateada, style: AppTypography.small.copyWith(color: AppPalette.textSecondary)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (orden.tipoEntrega.toLowerCase() == 'despacho'
                                  ? AppPalette.secondary
                                  : (orden.tipoEntrega.toLowerCase() == 'traslado'
                                      ? const Color(0xFFAB47BC)
                                      : AppPalette.primary))
                              .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (orden.tipoEntrega.toLowerCase() == 'despacho'
                                    ? AppPalette.secondary
                                    : (orden.tipoEntrega.toLowerCase() == 'traslado'
                                        ? const Color(0xFFAB47BC)
                                        : AppPalette.primary))
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          orden.tipoEntrega.toUpperCase(),
                          style: TextStyle(
                            color: orden.tipoEntrega.toLowerCase() == 'despacho'
                                ? AppPalette.secondary
                                : (orden.tipoEntrega.toLowerCase() == 'traslado'
                                    ? const Color(0xFFAB47BC)
                                    : AppPalette.primary),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 24),

                  // Ficha de Cliente
                  Text('DATOS DEL CLIENTE', style: AppTypography.small.copyWith(fontWeight: FontWeight.bold, color: AppPalette.textSecondary)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppPalette.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              orden.esConsumidorFinal ? Icons.receipt_long_outlined : Icons.person,
                              size: 16,
                              color: AppPalette.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                orden.esConsumidorFinal
                                    ? 'Orden: #${orden.folioDisplay} (Consumidor Final)'
                                    : 'Cliente: ${orden.cliente?.nombres ?? ""} ${orden.cliente?.apellidos ?? ""}'.trim(),
                                style: AppTypography.body.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          orden.esConsumidorFinal
                              ? 'Venta mostrador sin RUT personal registrado'
                              : 'RUT: ${orden.cliente?.rutCliente ?? "S/R"}  •  Tel: ${orden.cliente?.telefono ?? "S/T"}',
                          style: AppTypography.small.copyWith(color: AppPalette.textSecondary),
                        ),
                        if (orden.cliente?.correo != null && orden.cliente!.correo!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text('Correo: ${orden.cliente!.correo}', style: AppTypography.small.copyWith(color: AppPalette.textSecondary)),
                          ),
                      ],
                    ),
                  ),

                  // Ficha Completa de Despacho y Envío
                  if (desp != null) ...[
                    const SizedBox(height: 14),
                    Text('DATOS COMPLETOS DE DESPACHO Y ENVÍO', style: AppTypography.small.copyWith(fontWeight: FontWeight.bold, color: AppPalette.secondary)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppPalette.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppPalette.secondary.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.local_shipping, size: 18, color: AppPalette.secondary),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Despacho a Domicilio',
                                    style: AppTypography.body.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppPalette.secondary,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppPalette.secondary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppPalette.secondary.withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  desp.estadoDespacho,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppPalette.secondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white10, height: 16),
                          _buildDatoFila(
                            Icons.person_outline,
                            'Receptor:',
                            '${desp.receptorNombres} (${desp.receptorRut.isNotEmpty ? desp.receptorRut : "S/R"})',
                          ),
                          const SizedBox(height: 6),
                          _buildDatoFila(
                            Icons.phone_outlined,
                            'Teléfono:',
                            desp.receptorTelefono.isNotEmpty
                                ? desp.receptorTelefono
                                : (orden.cliente?.telefono?.isNotEmpty == true
                                    ? orden.cliente!.telefono!
                                    : 'No registrado'),
                          ),
                          const SizedBox(height: 6),
                          _buildDatoFila(
                            Icons.location_on_outlined,
                            'Dirección:',
                            desp.direccionEnvio,
                          ),
                          const SizedBox(height: 6),
                          _buildDatoFila(
                            Icons.map_outlined,
                            'Comuna Destino:',
                            (desp.comunaDestino != null && desp.comunaDestino!.isNotEmpty)
                                ? desp.comunaDestino!
                                : (orden.cliente?.comuna ?? 'No especificada'),
                          ),
                          const SizedBox(height: 6),
                          _buildDatoFila(
                            Icons.local_shipping_outlined,
                            'Transporte:',
                            desp.empresaTransporte ?? 'Chilexpress',
                          ),
                          const SizedBox(height: 6),
                          _buildDatoFila(
                            Icons.payments_outlined,
                            'Costo Envío:',
                            desp.costoEnvioFormateado,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Trazabilidad de Vendedores
                  Text('TRAZABILIDAD DE VENDEDORES', style: AppTypography.small.copyWith(fontWeight: FontWeight.bold, color: AppPalette.textSecondary)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppPalette.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person_pin_outlined, size: 16, color: AppPalette.textSecondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('Vendedor Creador: ${orden.vendedorNombre ?? "Vendedor Central"}', style: AppTypography.small),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.assignment_ind_outlined, size: 16, color: AppPalette.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('Responsable Asignado: ${orden.vendedorAsignadoNombre ?? "Mesón General (Todos)"}', style: AppTypography.small.copyWith(color: AppPalette.primary, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Desglose de Repuestos Exhaustivo
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'DESGLOSE DE REPUESTOS (${orden.totalItems})',
                          style: AppTypography.small.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppPalette.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildPreparacionBadge(orden.preparacionLista),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...orden.detalles.map((item) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppPalette.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  item.esInventariado ? Icons.inventory_2_outlined : Icons.edit_note_outlined,
                                  size: 16,
                                  color: item.esInventariado ? AppPalette.primary : AppPalette.secondary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.tituloDisplay,
                                    style: AppTypography.body.copyWith(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                                Text(item.subtotalFormateado, style: AppTypography.body.copyWith(fontWeight: FontWeight.bold, fontSize: 13, color: AppPalette.primary)),
                              ],
                            ),
                            if (item.skuQrFisico != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Text('SKU QR: ${item.skuQrFisico}', style: AppTypography.small.copyWith(color: AppPalette.textSecondary, fontSize: 11)),
                              ),
                            const SizedBox(height: 4.0),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                              decoration: BoxDecoration(
                                color: item.esMotorOCaja
                                    ? AppPalette.primary.withValues(alpha: 0.12)
                                    : AppPalette.secondary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4.0),
                                border: Border.all(
                                  color: item.esMotorOCaja
                                      ? AppPalette.primary.withValues(alpha: 0.3)
                                      : AppPalette.secondary.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    item.esMotorOCaja
                                        ? Icons.warehouse_outlined
                                        : Icons.storefront_outlined,
                                    size: 11.0,
                                    color: item.esMotorOCaja
                                        ? AppPalette.primary
                                        : AppPalette.secondary,
                                  ),
                                  const SizedBox(width: 4.0),
                                  Text(
                                    item.esMotorOCaja
                                        ? 'Retiro en Bodega (Barrera)'
                                        : 'Entrega Inmediata en Mesón',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: item.esMotorOCaja
                                          ? AppPalette.primary
                                          : AppPalette.secondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (item.notasPreparacion != null &&
                                item.notasPreparacion!.isNotEmpty &&
                                (item.esInventariado || item.esMotorOCaja))
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Text('Nota: ${item.notasPreparacion}', style: AppTypography.small.copyWith(color: AppPalette.warning, fontSize: 11)),
                              ),
                            const SizedBox(height: 4.0),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Cantidad: ${item.cantidad}x  •  Unitario: ${item.precioFinalFormateado}', style: AppTypography.small.copyWith(color: AppPalette.textSecondary, fontSize: 11)),
                                Text('Estado: ${item.estadoPreparacion ?? "Pendiente"}', style: TextStyle(color: item.preparacionLista ? AppPalette.success : AppPalette.warning, fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 16),

                  // Resumen Financiero
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppPalette.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: saldoPendiente ? AppPalette.warning.withValues(alpha: 0.5) : AppPalette.success.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TOTAL VENTA', style: TextStyle(color: AppPalette.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                            Text(orden.totalVentaFormateado, style: AppTypography.body.copyWith(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              saldoPendiente ? 'SALDO PENDIENTE' : 'ESTADO DE PAGO',
                              style: TextStyle(
                                color: saldoPendiente ? AppPalette.warning : AppPalette.success,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              saldoPendiente ? orden.montoPendienteFormateado : 'PAGADO COMPLETO',
                              style: TextStyle(
                                color: saldoPendiente ? AppPalette.warning : AppPalette.success,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Aviso Informativo para Orden Mixta
                  if (orden.esMixta) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppPalette.secondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppPalette.secondary.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.swap_horiz_rounded, color: AppPalette.secondary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Orden Mixta: Entrega los repuestos misceláneos al cliente en mostrador. El activo principal (motor/caja) debe retirarse en bodega con el Ticket QR.',
                              style: AppTypography.small.copyWith(
                                color: AppPalette.textPrimary,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Botonera de Acción en Detalle
                  Row(
                    children: [
                      if (orden.tipoEntrega.toLowerCase() == 'retiro') ...[
                        if (orden.contieneMotorOCaja) ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: orden.tieneQrDisponible
                                    ? AppPalette.primary
                                    : AppPalette.textSecondary,
                                side: BorderSide(
                                  color: orden.tieneQrDisponible
                                      ? AppPalette.primary
                                      : Colors.white24,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () {
                                if (!orden.tieneQrDisponible) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: AppPalette.surface,
                                      behavior: SnackBarBehavior.floating,
                                      content: Row(
                                        children: [
                                          const Icon(Icons.lock_clock_rounded,
                                              color: AppPalette.warning, size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              saldoPendiente
                                                  ? 'QR bloqueado: Orden con saldo pendiente de ${orden.montoPendienteFormateado}. Requiere confirmación de pago en Caja.'
                                                  : 'Esta orden no requiere código QR para retiro en bodega.',
                                              style: const TextStyle(color: AppPalette.warning),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                Navigator.of(ctx).pop();
                                _abrirQrModal(orden);
                              },
                              icon: Icon(
                                orden.tieneQrDisponible ? Icons.qr_code_2 : Icons.lock_outline,
                                size: 18,
                              ),
                              label: Text(
                                orden.tieneQrDisponible ? 'VER TICKET QR' : 'QR BLOQUEADO',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ] else ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: saldoPendiente ? AppPalette.surface : AppPalette.success,
                                foregroundColor: saldoPendiente ? AppPalette.textSecondary : Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: saldoPendiente ? Colors.white12 : AppPalette.success,
                                  ),
                                ),
                              ),
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                _confirmarEntregaTienda(orden);
                              },
                              icon: Icon(
                                saldoPendiente ? Icons.lock_outline : Icons.check_circle_outline,
                                size: 18,
                              ),
                              label: const Text(
                                'ENTREGADO',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ] else ...[
                        // Despacho: Permite visualizar Ticket QR para salida en Barrera de Bodega
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: orden.tieneQrDisponible
                                  ? AppPalette.secondary
                                  : AppPalette.surface,
                              foregroundColor: orden.tieneQrDisponible
                                  ? Colors.black
                                  : AppPalette.textSecondary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: orden.tieneQrDisponible
                                      ? AppPalette.secondary
                                      : Colors.white24,
                                ),
                              ),
                            ),
                            onPressed: () {
                              if (!orden.tieneQrDisponible) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppPalette.surface,
                                    behavior: SnackBarBehavior.floating,
                                    content: Row(
                                      children: [
                                        const Icon(Icons.lock_clock_rounded,
                                            color: AppPalette.warning, size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            saldoPendiente
                                                ? 'QR bloqueado: Orden con saldo pendiente de ${orden.montoPendienteFormateado}. Requiere confirmación de pago en Caja.'
                                                : 'Esta orden no tiene código QR disponible.',
                                            style: const TextStyle(color: AppPalette.warning),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                                return;
                              }
                              Navigator.of(ctx).pop();
                              _abrirQrModal(orden);
                            },
                            icon: Icon(
                              orden.tieneQrDisponible ? Icons.qr_code_2 : Icons.lock_outline,
                              size: 18,
                            ),
                            label: Text(
                              orden.tieneQrDisponible ? 'VER TICKET QR' : 'QR BLOQUEADO',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        backgroundColor: AppPalette.surface,
        foregroundColor: AppPalette.textPrimary,
        iconTheme: const IconThemeData(color: AppPalette.textPrimary),
        elevation: 0,
        titleSpacing: 12,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: AppPalette.textPrimary),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Volver',
              )
            : null,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_shipping_outlined, color: AppPalette.primary, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Retiro y Envíos',
                style: AppTypography.title.copyWith(fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!_isLoading) ...[
              const SizedBox(width: 8),
              _buildBadgeCount(_ordenesFiltradas.length, AppPalette.primary),
            ],
          ],
        ),
        actions: [
          // Botón de Filtros con indicador de estado
          IconButton(
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
            icon: Stack(
              children: [
                Icon(
                  Icons.tune_outlined,
                  size: 22,
                  color: _tieneFiltrosActivos ? AppPalette.primary : AppPalette.textPrimary,
                ),
                if (_tieneFiltrosActivos)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppPalette.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'Filtros de Búsqueda',
            onPressed: _abrirModalFiltros,
          ),
          const SizedBox(width: 4),
          IconButton(
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.refresh_rounded, color: AppPalette.textPrimary, size: 22),
            tooltip: 'Actualizar lista',
            onPressed: _cargarDatos,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading && _todasEntregas.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppPalette.primary))
          : _errorMessage != null && _todasEntregas.isEmpty
              ? _buildErrorView()
              : Column(
                  children: [
                    _buildSearchAndFiltersHeader(),
                    Expanded(child: _buildListaRetirosYEnvios()),
                  ],
                ),
    );
  }

  Widget _buildSearchAndFiltersHeader() {
    final validas = _todasEntregas.where((e) {
      if (e.esVentaEnVerde && (!e.estaPagada || !e.tieneQrDisponible)) {
        return false;
      }
      return true;
    }).toList();

    final misAsignadasCount = validas.where(_isAsignadaAMi).length;
    final retirosCount = validas
        .where((e) => e.tipoEntrega.toLowerCase() == 'retiro')
        .length;
    final despachosCount = validas
        .where((e) =>
            e.tipoEntrega.toLowerCase() == 'despacho' ||
            e.tipoEntrega.toLowerCase() == 'despacho domicilio')
        .length;
    final trasladosCount = validas
        .where((e) => e.tipoEntrega.toLowerCase() == 'traslado')
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 920;

        final searchBar = TextField(
          key: const Key('buscador_entregas_textfield'),
          controller: _searchController,
          onChanged: (val) {
            setState(() {
              _searchQuery = val;
            });
          },
          style: AppTypography.body.copyWith(
            color: AppPalette.textPrimary,
            fontSize: 13.5,
          ),
          cursorColor: AppPalette.primary,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Buscar por Folio, Cliente, RUT, Vendedor o SKU...',
            hintStyle: AppTypography.body.copyWith(
              color: AppPalette.textSecondary.withValues(alpha: 0.6),
              fontSize: 13,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppPalette.textSecondary,
              size: 20,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    key: const Key('btn_limpiar_busqueda_entregas'),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppPalette.textSecondary,
                      size: 18,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                    tooltip: 'Limpiar búsqueda',
                  )
                : null,
            filled: true,
            fillColor: AppPalette.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
        );

        final chipsRow = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Chip Especial: Mis Entregas Asignadas
            FilterChip(
              key: const Key('chip_mis_asignadas'),
              avatar: Icon(
                Icons.person_pin_circle_rounded,
                size: 16,
                color: _soloMisAsignadas ? Colors.white : AppPalette.primary,
              ),
              label: Text(
                'Mis Asignadas ($misAsignadasCount)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: _soloMisAsignadas ? Colors.white : AppPalette.primary,
                ),
              ),
              selected: _soloMisAsignadas,
              onSelected: (selected) {
                setState(() {
                  _soloMisAsignadas = selected;
                });
              },
              selectedColor: AppPalette.primary,
              backgroundColor: AppPalette.surface,
              side: BorderSide(
                color: _soloMisAsignadas
                    ? AppPalette.primary
                    : AppPalette.primary.withValues(alpha: 0.45),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 8),

            // Separador vertical sutil en tono oscuro
            Container(
              height: 20,
              width: 1,
              color: Colors.white12,
              margin: const EdgeInsets.symmetric(horizontal: 2),
            ),
            const SizedBox(width: 8),

            // Chip: Todos
            ChoiceChip(
              label: Text('Todas (${validas.length})'),
              selected: _tipoEntregaFilter == 'todos',
              onSelected: (selected) {
                if (selected) setState(() => _tipoEntregaFilter = 'todos');
              },
              backgroundColor: AppPalette.surface,
              selectedColor: AppPalette.primary.withValues(alpha: 0.22),
              side: BorderSide(
                color: _tipoEntregaFilter == 'todos'
                    ? AppPalette.primary.withValues(alpha: 0.6)
                    : Colors.white12,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              labelStyle: TextStyle(
                color: _tipoEntregaFilter == 'todos'
                    ? AppPalette.primary
                    : AppPalette.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),

            // Chip: Retiros
            ChoiceChip(
              label: Text('Retiros ($retirosCount)'),
              selected: _tipoEntregaFilter == 'retiro',
              onSelected: (selected) {
                if (selected) setState(() => _tipoEntregaFilter = 'retiro');
              },
              backgroundColor: AppPalette.surface,
              selectedColor: AppPalette.primary.withValues(alpha: 0.22),
              side: BorderSide(
                color: _tipoEntregaFilter == 'retiro'
                    ? AppPalette.primary.withValues(alpha: 0.6)
                    : Colors.white12,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              labelStyle: TextStyle(
                color: _tipoEntregaFilter == 'retiro'
                    ? AppPalette.primary
                    : AppPalette.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),

            // Chip: Despachos
            ChoiceChip(
              label: Text('Despachos ($despachosCount)'),
              selected: _tipoEntregaFilter == 'despacho',
              onSelected: (selected) {
                if (selected) setState(() => _tipoEntregaFilter = 'despacho');
              },
              backgroundColor: AppPalette.surface,
              selectedColor: AppPalette.secondary.withValues(alpha: 0.22),
              side: BorderSide(
                color: _tipoEntregaFilter == 'despacho'
                    ? AppPalette.secondary.withValues(alpha: 0.6)
                    : Colors.white12,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              labelStyle: TextStyle(
                color: _tipoEntregaFilter == 'despacho'
                    ? AppPalette.secondary
                    : AppPalette.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),

            // Chip: Traslados (si hay)
            if (trasladosCount > 0 || _tipoEntregaFilter == 'traslado') ...[
              ChoiceChip(
                label: Text('Traslados ($trasladosCount)'),
                selected: _tipoEntregaFilter == 'traslado',
                onSelected: (selected) {
                  if (selected) setState(() => _tipoEntregaFilter = 'traslado');
                },
                backgroundColor: AppPalette.surface,
                selectedColor: const Color(0xFFAB47BC).withValues(alpha: 0.22),
                side: BorderSide(
                  color: _tipoEntregaFilter == 'traslado'
                      ? const Color(0xFFAB47BC).withValues(alpha: 0.6)
                      : Colors.white12,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                labelStyle: TextStyle(
                  color: _tipoEntregaFilter == 'traslado'
                      ? const Color(0xFFAB47BC)
                      : AppPalette.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 6),
            ],

            // Chip rápido de limpiar si hay filtros activos
            if (_tieneFiltrosActivos) ...[
              ActionChip(
                avatar: const Icon(Icons.clear_all, size: 16, color: AppPalette.warning),
                label: const Text(
                  'Limpiar',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppPalette.warning,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: AppPalette.warning.withValues(alpha: 0.12),
                side: BorderSide(color: AppPalette.warning.withValues(alpha: 0.35)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                    _soloMisAsignadas = false;
                    _tipoEntregaFilter = 'todos';
                    _estadoPagoFilter = 'todos';
                    _clienteFilterController.clear();
                    _vendedorFilterController.clear();
                  });
                },
              ),
            ],
          ],
        );

        return Container(
          color: AppPalette.background,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 4,
                      child: searchBar,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 6,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: chipsRow,
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchBar,
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: chipsRow,
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildBadgeCount(int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppPalette.error, size: 54),
            const SizedBox(height: 16),
            Text('Error al cargar retiros y envíos', style: AppTypography.title),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Ocurrió un error inesperado.',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: AppPalette.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _cargarDatos,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListaRetirosYEnvios() {
    final lista = _ordenesFiltradas;
    if (lista.isEmpty) {
      return _buildEmptyView(
        icon: Icons.local_shipping_outlined,
        title: 'Sin Retiros o Envíos Pendientes',
        subtitle: _tieneFiltrosActivos
            ? 'No se encontraron órdenes con los filtros seleccionados.'
            : 'No hay pedidos pendientes en espera de retiro ni despachos.',
      );
    }

    return RefreshIndicator(
      color: AppPalette.primary,
      onRefresh: _cargarDatos,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: lista.length,
        itemBuilder: (context, index) {
          return _buildEntregaEnvioCard(lista[index]);
        },
      ),
    );
  }

  Widget _buildEmptyView({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppPalette.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(title, style: AppTypography.title.copyWith(color: AppPalette.textPrimary)),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: AppPalette.textSecondary),
            ),
            if (_tieneFiltrosActivos) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  _searchController.clear();
                  _clienteFilterController.clear();
                  _vendedorFilterController.clear();
                  setState(() {
                    _searchQuery = '';
                    _soloMisAsignadas = false;
                    _estadoPagoFilter = 'todos';
                    _tipoEntregaFilter = 'todos';
                  });
                  _cargarDatos();
                },
                icon: const Icon(Icons.filter_alt_off),
                label: const Text('Limpiar Filtros'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Tarjeta Unificada para Retiro en Tienda y Despacho Courier
  Widget _buildEntregaEnvioCard(EntregaEnvioModel orden) {
    final bool saldoPendiente = orden.tieneSaldoPendiente;
    final bool esDespacho = orden.esDespacho;
    final desp = orden.despacho;

    // Resumen simple de ítems
    final itemsResumen = orden.detalles.length == 1
        ? '${orden.detalles.first.cantidad}x ${orden.detalles.first.tituloDisplay}'
        : '${orden.totalItems} piezas (${orden.detalles.map((d) => d.tituloDisplay).take(2).join(", ")}${orden.detalles.length > 2 ? "..." : ""})';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: saldoPendiente
              ? AppPalette.warning.withValues(alpha: 0.35)
              : esDespacho
                  ? AppPalette.secondary.withValues(alpha: 0.35)
                  : AppPalette.success.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _abrirDetalleCompleto(orden),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fila 1: Folio + Fecha + Chip de Modalidad / Courier
              Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: (esDespacho ? AppPalette.secondary : AppPalette.primary)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              orden.folioDisplay,
                              style: AppTypography.body.copyWith(
                                fontWeight: FontWeight.bold,
                                color: esDespacho ? AppPalette.secondary : AppPalette.primary,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          orden.fechaFormateada,
                          style: AppTypography.small.copyWith(
                            color: AppPalette.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (esDespacho ? AppPalette.secondary : AppPalette.primary)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: (esDespacho ? AppPalette.secondary : AppPalette.primary)
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          esDespacho ? Icons.local_shipping : Icons.storefront,
                          size: 12,
                          color: esDespacho ? AppPalette.secondary : AppPalette.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          esDespacho
                              ? (desp?.empresaTransporte ?? 'Despacho')
                              : 'Retiro',
                          style: AppTypography.small.copyWith(
                            color: esDespacho ? AppPalette.secondary : AppPalette.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Fila 2: Datos de Cliente / Receptor y Despacho + Vendedor
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    esDespacho
                        ? Icons.location_on_outlined
                        : (orden.esConsumidorFinal ? Icons.receipt_long_outlined : Icons.person_outline),
                    size: 18,
                    color: esDespacho
                        ? AppPalette.secondary
                        : (orden.esConsumidorFinal ? AppPalette.primary : AppPalette.textSecondary),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          esDespacho
                              ? ((desp != null && desp.receptorNombres.isNotEmpty && desp.receptorNombres != "S/R")
                                  ? '${desp.receptorNombres} (${desp.comunaDestino ?? "Destino"})'
                                  : orden.clienteDisplay)
                              : orden.clienteDisplay,
                          style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: (!esDespacho && orden.esConsumidorFinal)
                                ? AppPalette.primary
                                : AppPalette.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        if (esDespacho && desp != null) ...[
                          Text(
                            'Destino: ${desp.direccionEnvio}${(desp.comunaDestino != null && desp.comunaDestino!.isNotEmpty) ? ", ${desp.comunaDestino!}" : ""}${desp.receptorTelefono.isNotEmpty ? " • Tel: ${desp.receptorTelefono}" : (orden.cliente?.telefono?.isNotEmpty == true ? " • Tel: ${orden.cliente!.telefono!}" : "")}',
                            style: AppTypography.small.copyWith(
                              color: AppPalette.textSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Courier: ${desp.empresaTransporte ?? "Chilexpress"} • ${desp.costoEnvioFormateado} • Estado: ${desp.estadoDespacho}',
                            style: AppTypography.small.copyWith(
                              color: AppPalette.secondary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        Text(
                          'Vendedor: ${orden.vendedorNombre ?? "Vendedor Central"} • Resp: ${orden.vendedorAsignadoNombre ?? "Mesón General"}',
                          style: AppTypography.small.copyWith(
                            color: AppPalette.textSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Fila 3: Resumen de ítems y Badge de estado financiero / despacho
              Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            itemsResumen,
                            style: AppTypography.body.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppPalette.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (orden.esMixta) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppPalette.secondary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppPalette.secondary.withValues(alpha: 0.4)),
                            ),
                            child: const Text(
                              'Mixta',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: AppPalette.secondary,
                              ),
                            ),
                          ),
                        ] else if (!orden.contieneMotorOCaja && !esDespacho) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppPalette.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppPalette.success.withValues(alpha: 0.3)),
                            ),
                            child: const Text(
                              'Mesón',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: AppPalette.success,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  saldoPendiente
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppPalette.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppPalette.warning),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'SALDO: ${orden.montoPendienteFormateado}',
                              style: const TextStyle(
                                color: AppPalette.warning,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppPalette.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppPalette.success),
                          ),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'PAGADO',
                              style: TextStyle(
                                color: AppPalette.success,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                ],
              ),
              const SizedBox(height: 12),

              // Fila 4: Botonera de Acción Rápida (Ticket QR para salida de barrera o Entrega en Mesón)
              if (esDespacho || orden.contieneMotorOCaja) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: InkWell(
                        onTap: () {
                          if (!orden.tieneQrDisponible) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppPalette.surface,
                                behavior: SnackBarBehavior.floating,
                                content: Row(
                                  children: [
                                    const Icon(Icons.lock_clock_rounded,
                                        color: AppPalette.warning, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        saldoPendiente
                                            ? 'QR bloqueado: Orden con saldo pendiente de ${orden.montoPendienteFormateado}. Requiere confirmación de pago en Caja.'
                                            : 'Esta orden no tiene código QR disponible.',
                                        style: const TextStyle(color: AppPalette.warning),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                            return;
                          }
                          _abrirQrModal(orden);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                orden.tieneQrDisponible ? Icons.qr_code_2 : Icons.lock_outline,
                                color: orden.tieneQrDisponible
                                    ? (esDespacho ? AppPalette.secondary : AppPalette.primary)
                                    : AppPalette.warning,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  orden.tieneQrDisponible ? 'Ticket QR' : 'QR Bloqueado',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.body.copyWith(
                                    color: orden.tieneQrDisponible
                                        ? (esDespacho ? AppPalette.secondary : AppPalette.primary)
                                        : AppPalette.warning,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppPalette.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.qr_code_scanner,
                              size: 15,
                              color: esDespacho
                                  ? AppPalette.secondary
                                  : (orden.esMixta ? AppPalette.secondary : AppPalette.textSecondary),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                esDespacho
                                    ? 'Salida en Barrera Bodega'
                                    : (orden.esMixta ? 'Mixta · Barrera Bodega' : 'Salida en Barrera Bodega'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.small.copyWith(
                                  color: esDespacho
                                      ? AppPalette.secondary
                                      : (orden.esMixta ? AppPalette.secondary : AppPalette.textSecondary),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () => _abrirDetalleCompleto(orden),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.receipt_long_outlined, color: AppPalette.textSecondary, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'Ver Detalle',
                              style: AppTypography.body.copyWith(
                                color: AppPalette.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 38,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: saldoPendiente
                              ? AppPalette.surface
                              : AppPalette.success,
                          foregroundColor: saldoPendiente
                              ? AppPalette.textSecondary
                              : Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: saldoPendiente
                                  ? Colors.white12
                                  : AppPalette.success,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        onPressed: () => _confirmarEntregaTienda(orden),
                        icon: Icon(
                          saldoPendiente ? Icons.lock_outline : Icons.check_circle_outline,
                          size: 18,
                        ),
                        label: const Text(
                          'Entregado',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreparacionBadge(bool lista) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: lista
            ? AppPalette.success.withValues(alpha: 0.15)
            : AppPalette.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        lista ? 'PREPARACIÓN LISTA' : 'EN PREPARACIÓN',
        style: TextStyle(
          color: lista ? AppPalette.success : AppPalette.warning,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
