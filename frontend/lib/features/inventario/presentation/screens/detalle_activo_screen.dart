import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../../auth/services/auth_service.dart';
import '../../../paletizado/domain/models/etiqueta_data.dart';
import '../widgets/editar_activo_modal.dart';

class DetalleActivoScreen extends StatefulWidget {
  final Map<String, dynamic> activo;

  const DetalleActivoScreen({super.key, required this.activo});

  @override
  State<DetalleActivoScreen> createState() => _DetalleActivoScreenState();
}

class _DetalleActivoScreenState extends State<DetalleActivoScreen> {
  int _currentImageIndex = 0;

  // Refleja localmente el estado qr_impreso para actualizar el botón
  // sin tener que recargar toda la pantalla desde el backend.
  late bool _qrImpreso;
  late Map<String, dynamic> _activo;
  bool _puedeEditar = false;

  @override
  void initState() {
    super.initState();
    _activo = Map<String, dynamic>.from(widget.activo);
    _qrImpreso = _activo['qr_impreso'] as bool? ?? false;
    _verificarRolUsuario();
  }

  bool get _esEstadoEditable {
    final estado = (_activo['estado'] ?? '').toString().toUpperCase();
    return estado == 'DISPONIBLE' || estado == 'PALETIZADO';
  }

  Future<void> _verificarRolUsuario() async {
    final idRol = await AuthService.getIdRol();
    final rol = await AuthService.getRol();
    final rLower = rol?.toLowerCase() ?? '';
    final esBodegueroOAdmin = idRol == 1 ||
        idRol == 5 ||
        rLower == 'bodeguero' ||
        rLower == 'administrador' ||
        rLower == 'admin';

    if (mounted) {
      setState(() {
        _puedeEditar = esBodegueroOAdmin;
      });
    }
  }

  Future<void> _abrirModalEdicion() async {
    final resultado = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditarActivoModal(activo: _activo),
    );

    if (!mounted || resultado == null) return;

    if (resultado['conflict'] == true) {
      return;
    }

    setState(() {
      if (resultado['ubicacion_pasillo'] != null) {
        _activo['pasillo'] = resultado['ubicacion_pasillo'];
        _activo['ubicacion_pasillo'] = resultado['ubicacion_pasillo'];
      }
      if (resultado['ubicacion_pallet'] != null) {
        _activo['pallet'] = resultado['ubicacion_pallet'];
        _activo['ubicacion_pallet'] = resultado['ubicacion_pallet'];
      }
      if (resultado['ubicacion_galpon'] != null) {
        _activo['galpon'] = resultado['ubicacion_galpon'];
        _activo['ubicacion_galpon'] = resultado['ubicacion_galpon'];
      }
      if (resultado['observacion_estado'] != null) {
        _activo['observacion'] = resultado['observacion_estado'];
        _activo['observacion_estado'] = resultado['observacion_estado'];
      }
      if (resultado['numero_motor'] != null) {
        _activo['numero_motor'] = resultado['numero_motor'];
      }
      if (resultado['cilindrada'] != null) {
        _activo['cilindrada'] = resultado['cilindrada'];
      }
      if (resultado['version_lock'] != null) {
        _activo['version_lock'] = resultado['version_lock'];
      }
    });
  }

  String _formatearUbicacionHumana() {
    final pasillo = _activo['pasillo']?.toString().trim() ?? '';
    final pallet = _activo['pallet']?.toString().trim() ?? '';
    final galpon = _activo['galpon']?.toString().trim() ?? '';

    final bool tienePasillo = pasillo.isNotEmpty && pasillo != 'S/P' && pasillo != 'null';
    final bool tienePallet = pallet.isNotEmpty && pallet != 'S/P' && pallet != 'null';
    final bool tieneGalpon = galpon.isNotEmpty && galpon != 'S/G' && galpon != 'null';

    if (!tienePasillo && !tienePallet && !tieneGalpon) {
      final rawUbicacion = _activo['ubicacion']?.toString().trim() ?? '';
      if (rawUbicacion.isNotEmpty &&
          rawUbicacion != 'S/P - S/P' &&
          rawUbicacion != 'No asignada' &&
          rawUbicacion != 'null') {
        return rawUbicacion;
      }
      return 'Sin Paletizar / Sin Ubicación Asignada';
    }

    final pStr = tienePasillo ? pasillo : 'S/P';
    final paStr = tienePallet ? pallet : 'S/P';
    final gStr = tieneGalpon ? galpon : 'S/G';

    return 'Pasillo: $pStr | Pallet: $paStr | Galpón: $gStr';
  }

  @override
  Widget build(BuildContext context) {
    final String categoria = _activo['categoria']?.toString() ?? 'Activo';
    final bool esMotor =
        categoria.toUpperCase() == 'MOTOR' ||
        categoria.toUpperCase() == 'MOTORES';
    final int idCategoria = (_activo['id_categoria'] ?? _activo['idCategoria']) as int? ??
        (esMotor ? 1 : (categoria.toUpperCase().contains('CAJA') ? 2 : 0));

    final String marca = _activo['marca']?.toString() ?? 'Desconocida';
    final String modelo = _activo['modelo']?.toString() ?? 'Desconocido';
    final String sku = _activo['sku']?.toString() ?? 'S/N';
    final String estado = _activo['estado']?.toString() ?? 'DISPONIBLE';

    final String numeroIngreso =
        _activo['numero_ingreso']?.toString() ?? 'N/A';

    final String? numeroMotor =
        (_activo['numero_motor'] ?? _activo['numeroMotor'])?.toString();
    final String? traccion = _activo['traccion']?.toString();
    final String cilindrada = _activo['cilindrada']?.toString() ?? 'N/A';
    final String combustible =
        _activo['combustible']?.toString() ?? 'N/A';
    final String transmision =
        (_activo['transmision'] ?? _activo['transmision_tipo'] ?? _activo['transmisionTipo'])?.toString() ?? 'N/A';
    final String observacion =
        _activo['observacion']?.toString() ??
        'Sin observaciones registradas.';

    final List<dynamic> rawImages = _activo['imagenes'] ?? [];
    final List<String> imagenesReales = rawImages.isNotEmpty
        ? rawImages.map((e) => e.toString()).toList()
        : ['NO_IMAGE'];

    final etiqueta = EtiquetaData.fromMap(_activo);

    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: Text(
          'Detalle de $categoria',
          style: AppTypography.title.copyWith(color: AppPalette.textPrimary, fontSize: 18),
        ),
        backgroundColor: AppPalette.surface,
        foregroundColor: AppPalette.textPrimary,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppPalette.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Volver',
        ),
        actions: [
          if (_puedeEditar && _esEstadoEditable)
            IconButton(
              key: const Key('btn_editar_activo'),
              icon: const Icon(Icons.edit_location_alt_outlined, color: AppPalette.primary),
              tooltip: 'Editar ubicación de activo',
              onPressed: _abrirModalEdicion,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildBadgeEstado(estado),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppPalette.surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppPalette.neutral.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          'ID: $sku',
                          style: AppTypography.small.copyWith(
                            color: AppPalette.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  RichText(
                    text: TextSpan(
                      style: AppTypography.headline.copyWith(fontSize: 26, fontWeight: FontWeight.bold),
                      children: [
                        TextSpan(
                          text: '$marca ',
                          style: const TextStyle(color: Colors.white),
                        ),
                        TextSpan(
                          text: modelo,
                          style: const TextStyle(color: AppPalette.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── CARRUSEL DE IMÁGENES CON FALLBACK NATIVO ──
            SizedBox(
              height: 260,
              child: PageView.builder(
                itemCount: imagenesReales.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentImageIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  if (imagenesReales[index].startsWith('http')) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: NetworkImage(imagenesReales[index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  } else {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16.0),
                      decoration: BoxDecoration(
                        color: AppPalette.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppPalette.neutral.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.image_not_supported_outlined,
                              color: AppPalette.textSecondary,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Sin registro fotográfico',
                              style: AppTypography.small.copyWith(
                                color: AppPalette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                imagenesReales.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentImageIndex == index
                        ? AppPalette.primary
                        : AppPalette.neutral.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppPalette.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppPalette.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'UBICACIÓN ACTUAL',
                                style: AppTypography.small.copyWith(
                                  color: AppPalette.textSecondary,
                                  letterSpacing: 1.2,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _formatearUbicacionHumana(),
                                style: AppTypography.title.copyWith(
                                  color: AppPalette.primary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppPalette.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: AppPalette.primary,
                            size: 26,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  Text(
                    'ESPECIFICACIONES TÉCNICAS',
                    style: AppTypography.small.copyWith(
                      color: AppPalette.textSecondary,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),

                  _buildSpecCard('Nº DE INGRESO VEHÍCULO', numeroIngreso),

                  if (idCategoria == 1 && numeroMotor != null && numeroMotor.isNotEmpty && numeroMotor != 'N/A')
                    _buildSpecCard('Número de Motor', numeroMotor),

                  // Renderizado dinámico de especificaciones técnicas compartidas (SPEC-HU-TAREA-17)
                  ...[
                    if (cilindrada.isNotEmpty && (cilindrada != 'N/A' || esMotor || idCategoria == 2))
                      {'titulo': 'CILINDRADA', 'valor': cilindrada},
                    if (combustible.isNotEmpty && (combustible != 'N/A' || esMotor || idCategoria == 2))
                      {'titulo': 'COMBUSTIBLE', 'valor': combustible},
                    if (transmision.isNotEmpty && transmision != 'N/A')
                      {'titulo': 'TRANSMISIÓN', 'valor': transmision},
                    if (traccion != null && traccion.isNotEmpty && traccion != 'N/A')
                      {'titulo': 'TRACCIÓN', 'valor': traccion},
                  ].map((spec) => _buildSpecCard(spec['titulo']!, spec['valor']!)),

                  Container(
                    margin: const EdgeInsets.only(bottom: 28),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppPalette.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppPalette.neutral.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.description_outlined,
                            color: AppPalette.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Observación',
                                style: AppTypography.body.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                observacion,
                                style: AppTypography.small.copyWith(
                                  color: AppPalette.textPrimary,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Botón de Impresión / Reimpresión (HU-2.4 Fase 4) ──
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final resultado = await Navigator.of(
                          context,
                        ).pushNamed('/etiqueta-preview', arguments: etiqueta);

                        if (resultado == true && mounted) {
                          setState(() => _qrImpreso = true);
                        }
                      },
                      icon: Icon(
                        _qrImpreso ? Icons.replay : Icons.qr_code_scanner,
                        color: Colors.white,
                      ),
                      label: Text(
                        _qrImpreso
                            ? 'REIMPRIMIR ETIQUETA QR'
                            : 'IMPRIMIR ETIQUETA QR',
                        style: AppTypography.button.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _qrImpreso
                            ? AppPalette.secondary
                            : AppPalette.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.list_alt, color: Colors.white, size: 18),
                      label: Text(
                        'VOLVER AL LISTADO',
                        style: AppTypography.button.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: AppPalette.neutral.withValues(alpha: 0.3),
                        ),
                        backgroundColor: AppPalette.background,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
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

  Widget _buildSpecCard(String title, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.small.copyWith(
              color: AppPalette.textSecondary,
              fontSize: 9,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.bold,
              color: AppPalette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeEstado(String estado) {
    Color estadoColor;
    switch (estado.toUpperCase()) {
      case 'DISPONIBLE':
        estadoColor = AppPalette.success;
        break;
      case 'VENDIDO':
        estadoColor = AppPalette.secondary;
        break;
      case 'RESERVADO':
        estadoColor = Colors.orange;
        break;
      default:
        estadoColor = AppPalette.neutral;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: estadoColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: estadoColor, width: 1),
      ),
      child: Text(
        estado.toUpperCase(),
        style: AppTypography.small.copyWith(
          color: estadoColor,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }
}
