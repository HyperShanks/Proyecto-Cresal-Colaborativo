import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../routes/app_routes.dart';
import '../../../auth/services/auth_service.dart';
import '../../models/vehiculo_recepcion_model.dart';
import '../../services/recepcion_service.dart';

class RecepcionHomeScreen extends StatefulWidget {
  const RecepcionHomeScreen({super.key});

  @override
  State<RecepcionHomeScreen> createState() => _RecepcionHomeScreenState();
}

class _RecepcionHomeScreenState extends State<RecepcionHomeScreen> {
  final RecepcionService _recepcionService = RecepcionService();
  final TextEditingController _searchController = TextEditingController();

  String _siguienteIngreso = '...';
  bool _isLoadingFolio = true;
  bool _isLoadingRecientes = true;
  List<VehiculoRecepcionModel> _recientes = [];
  String? _userNombre;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _cargarDatosUsuario();
    _cargarDatos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosUsuario() async {
    final cached = AuthService.cachedUser;
    if (cached != null) {
      setState(() {
        _userNombre = cached.nombreCompleto;
        _userEmail = cached.email;
      });
    } else {
      final nombre = await AuthService.getNombreUsuario();
      final email = await AuthService.getEmailUsuario();
      setState(() {
        _userNombre = nombre ?? 'Gloria';
        _userEmail = email ?? 'gloria@cresal.cl';
      });
    }
  }

  Future<void> _cargarDatos() async {
    await Future.wait([
      _cargarSiguienteFolio(),
      _cargarRecientes(),
    ]);
  }

  Future<void> _cargarSiguienteFolio() async {
    setState(() => _isLoadingFolio = true);
    final folio = await _recepcionService.obtenerSiguienteIngreso();
    if (mounted) {
      setState(() {
        _siguienteIngreso = folio;
        _isLoadingFolio = false;
      });
    }
  }

  Future<void> _cargarRecientes([String? busqueda]) async {
    setState(() => _isLoadingRecientes = true);
    final lista = await _recepcionService.obtenerRecientes(busqueda: busqueda);
    if (mounted) {
      setState(() {
        _recientes = lista;
        _isLoadingRecientes = false;
      });
    }
  }

  Future<void> _copiarFormatoMatriz() async {
    if (_recientes.isEmpty) {
      _mostrarSnackBar('No hay registros recientes para copiar', AppPalette.warning);
      return;
    }

    final headers = VehiculoRecepcionModel.tsvHeaders();
    final filas = _recientes.map((v) => v.toTsvRow()).join('\n');
    final tsvFinal = '$headers\n$filas';

    await Clipboard.setData(ClipboardData(text: tsvFinal));
    _mostrarSnackBar(
      '📋 ${_recientes.length} filas copiadas en formato Matriz Excel (Columnas A a M). ¡Listo para pegar!',
      AppPalette.success,
    );
  }

  Future<void> _exportarCsvMatriz() async {
    final res = await _recepcionService.exportarMatriz();
    if (res['exito'] == true) {
      final tsv = res['tsv'] as String;
      await Clipboard.setData(ClipboardData(text: tsv));
      _mostrarSnackBar(
        '📥 Matriz exportada y copiada al portapapeles (${res['total']} vehículos A-M).',
        AppPalette.success,
      );
    } else {
      _mostrarSnackBar('Error al exportar matriz: ${res['mensaje']}', AppPalette.error);
    }
  }

  void _mostrarSnackBar(String mensaje, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.surface,
        title: const Text('Cerrar Sesión', style: TextStyle(color: AppPalette.textPrimary)),
        content: const Text(
          '¿Deseas salir del módulo de Recepción de Patio?',
          style: TextStyle(color: AppPalette.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: AppPalette.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppPalette.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cerrar Sesión', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await AuthService.logout();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (r) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        backgroundColor: AppPalette.surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_car_filled_rounded, color: AppPalette.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Recepción de Patio',
                  style: const TextStyle(color: AppPalette.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Text(
              '${_userNombre ?? 'Operario'} (${_userEmail ?? 'gloria@cresal.cl'})',
              style: const TextStyle(color: AppPalette.textSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppPalette.primary),
            tooltip: 'Actualizar bandeja',
            onPressed: _cargarDatos,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppPalette.error),
            tooltip: 'Cerrar sesión',
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _cargarDatos,
        color: AppPalette.primary,
        backgroundColor: AppPalette.surface,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. BANNER EN VIVO: SIGUIENTE INGRESO
              _buildFolioLiveBanner(),

              const SizedBox(height: 16),

              // 2. BOTÓN PRINCIPAL: + INGRESAR VEHÍCULO A PATIO (ALTA VISIBILIDAD)
              _buildBotonIngresarVehiculo(),

              const SizedBox(height: 24),

              // 3. HERRAMIENTAS MATRIZ CENTRAL EXCEL (A-M)
              _buildHerramientasMatriz(),

              const SizedBox(height: 24),

              // 4. BUSCADOR RÁPIDO PARA EVITAR DUPLICADOS
              _buildBuscadorRapido(),

              const SizedBox(height: 16),

              // 5. BANDEJA DE ENTRADAS RECIENTES
              _buildBandejaRecientes(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFolioLiveBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.primary.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppPalette.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.tag_rounded, color: AppPalette.primary, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CORRELATIVO EN VIVO',
                  style: const TextStyle(
                    color: AppPalette.textSecondary,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Text(
                      'Siguiente Ingreso: ',
                      style: TextStyle(color: AppPalette.textPrimary, fontSize: 14),
                    ),
                    Text(
                      _isLoadingFolio ? '...' : 'N° $_siguienteIngreso',
                      style: const TextStyle(
                        color: AppPalette.secondary,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.sync_rounded, color: AppPalette.textSecondary),
            onPressed: _cargarSiguienteFolio,
            tooltip: 'Refrescar correlativo',
          ),
        ],
      ),
    );
  }

  Widget _buildBotonIngresarVehiculo() {
    return SizedBox(
      height: 60,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        onPressed: () async {
          final creado = await Navigator.of(context).pushNamed(AppRoutes.recepcionRegistro);
          if (creado == true) {
            _cargarDatos();
          }
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_circle_outline_rounded, size: 26),
            const SizedBox(width: 10),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: const Text(
                  '+ INGRESAR VEHÍCULO A PATIO',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHerramientasMatriz() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.neutral.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.table_view_rounded, color: AppPalette.secondary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Herramientas Matriz Central (13 Columnas A-M)',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                    color: AppPalette.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppPalette.textPrimary,
                    side: const BorderSide(color: AppPalette.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.content_copy_rounded, size: 18, color: AppPalette.primary),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('📋 Copiar TSV', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  onPressed: _copiarFormatoMatriz,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppPalette.textPrimary,
                    side: const BorderSide(color: AppPalette.secondary),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.file_download_outlined, size: 18, color: AppPalette.secondary),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('📥 Exportar Matriz', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  onPressed: _exportarCsvMatriz,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBuscadorRapido() {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.neutral.withValues(alpha: 0.3)),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: AppPalette.textPrimary),
        decoration: InputDecoration(
          hintText: 'Buscar por Patente, Folio N°, Marca o Chofer...',
          hintStyle: const TextStyle(color: AppPalette.textSecondary),
          prefixIcon: const Icon(Icons.search_rounded, color: AppPalette.primary),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: AppPalette.textSecondary),
                  onPressed: () {
                    _searchController.clear();
                    _cargarRecientes();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
        onSubmitted: (val) => _cargarRecientes(val),
      ),
    );
  }

  Widget _buildBandejaRecientes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Bandeja de Entradas Recientes (${_recientes.length})',
                style: const TextStyle(
                  color: AppPalette.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Verificación',
              style: TextStyle(color: AppPalette.textSecondary, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingRecientes)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(color: AppPalette.primary),
            ),
          )
        else if (_recientes.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppPalette.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                children: const [
                  Icon(Icons.no_crash_rounded, color: AppPalette.textSecondary, size: 48),
                  SizedBox(height: 12),
                  Text(
                    'No hay ingresos vehiculares registrados aún',
                    style: TextStyle(color: AppPalette.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recientes.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (ctx, idx) {
              final v = _recientes[idx];
              return _buildVehiculoCard(v);
            },
          ),
      ],
    );
  }

  Widget _buildVehiculoCard(VehiculoRecepcionModel v) {
    final esSppu = v.esSppu;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _mostrarDetalleVehiculo(v),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppPalette.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppPalette.neutral.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Folio N°
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppPalette.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'N° ${v.numeroIngreso}',
                      style: const TextStyle(
                        color: AppPalette.secondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  // Patente / Badge SPPU
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: esSppu ? Colors.orange.withValues(alpha: 0.2) : AppPalette.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: esSppu ? Colors.orange : AppPalette.primary,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      v.patente ?? 'S/PPU',
                      style: TextStyle(
                        color: esSppu ? Colors.orangeAccent : Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${v.marca} ${v.modelo} ${v.anio != null ? "(${v.anio})" : ""}',
                style: const TextStyle(
                  color: AppPalette.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (v.origen != null) ...[
                    const Icon(Icons.store_rounded, size: 14, color: AppPalette.textSecondary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        v.origen!,
                        style: const TextStyle(color: AppPalette.textSecondary, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (v.grua != null) ...[
                    const Icon(Icons.local_shipping_rounded, size: 14, color: AppPalette.textSecondary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Grúa: ${v.grua}',
                        style: const TextStyle(color: AppPalette.textSecondary, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              if (v.observaciones != null && v.observaciones!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppPalette.background,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Obs: ${v.observaciones}',
                    style: const TextStyle(
                      color: AppPalette.textSecondary,
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarDetalleVehiculo(VehiculoRecepcionModel v) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppPalette.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Folio N° ${v.numeroIngreso}',
                        style: const TextStyle(
                          color: AppPalette.secondary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: v.esSppu ? Colors.orange.withValues(alpha: 0.2) : AppPalette.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: v.esSppu ? Colors.orange : AppPalette.primary,
                          ),
                        ),
                        child: Text(
                          v.patente ?? 'S/PPU',
                          style: TextStyle(
                            color: v.esSppu ? Colors.orangeAccent : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 12),
                  _buildDetalleFila('Marca:', v.marca),
                  _buildDetalleFila('Modelo:', v.modelo),
                  _buildDetalleFila('Año:', v.anio?.toString() ?? 'S/I'),
                  _buildDetalleFila('Color:', v.color ?? 'S/I'),
                  _buildDetalleFila('N° Motor:', v.numeroMotor ?? 'S/I'),
                  _buildDetalleFila('Tracción:', v.traccion ?? 'S/I'),
                  _buildDetalleFila('Destino:', v.destino),
                  _buildDetalleFila('Origen:', v.origen ?? 'S/I'),
                  _buildDetalleFila('Factura:', v.factura ?? 'S/I'),
                  _buildDetalleFila('Fecha Ingreso:', v.fechaIngresoFormateada),
                  _buildDetalleFila('Grúa:', v.grua ?? 'S/I'),
                  _buildDetalleFila('Observaciones:', v.observaciones ?? 'Sin observaciones'),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppPalette.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('CERRAR FICHA', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetalleFila(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppPalette.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
