import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../../paletizado/domain/models/etiqueta_data.dart';

class DetalleActivoScreen extends StatefulWidget {
  final Map<String, dynamic> activo;

  const DetalleActivoScreen({Key? key, required this.activo}) : super(key: key);

  @override
  State<DetalleActivoScreen> createState() => _DetalleActivoScreenState();
}

class _DetalleActivoScreenState extends State<DetalleActivoScreen> {
  int _currentImageIndex = 0;

  // Refleja localmente el estado qr_impreso para actualizar el botón
  // sin tener que recargar toda la pantalla desde el backend.
  late bool _qrImpreso;

  @override
  void initState() {
    super.initState();
    _qrImpreso = widget.activo['qr_impreso'] as bool? ?? false;
  }

  String _formatearUbicacionHumana() {
    final pasillo = widget.activo['pasillo']?.toString().trim() ?? '';
    final pallet = widget.activo['pallet']?.toString().trim() ?? '';
    final galpon = widget.activo['galpon']?.toString().trim() ?? '';

    final bool tienePasillo = pasillo.isNotEmpty && pasillo != 'S/P' && pasillo != 'null';
    final bool tienePallet = pallet.isNotEmpty && pallet != 'S/P' && pallet != 'null';
    final bool tieneGalpon = galpon.isNotEmpty && galpon != 'S/G' && galpon != 'null';

    if (!tienePasillo && !tienePallet && !tieneGalpon) {
      final rawUbicacion = widget.activo['ubicacion']?.toString().trim() ?? '';
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
    final String categoria = widget.activo['categoria']?.toString() ?? 'Activo';
    final bool esMotor =
        categoria.toUpperCase() == 'MOTOR' ||
        categoria.toUpperCase() == 'MOTORES';

    final String marca = widget.activo['marca']?.toString() ?? 'Desconocida';
    final String modelo = widget.activo['modelo']?.toString() ?? 'Desconocido';
    final String sku = widget.activo['sku']?.toString() ?? 'S/N';
    final String estado = widget.activo['estado']?.toString() ?? 'DISPONIBLE';

    final String numeroIngreso =
        widget.activo['numero_ingreso']?.toString() ?? 'N/A';

    final String cilindrada = widget.activo['cilindrada']?.toString() ?? 'N/A';
    final String combustible =
        widget.activo['combustible']?.toString() ?? 'N/A';
    final String transmision =
        widget.activo['transmision']?.toString() ?? 'N/A';
    final String observacion =
        widget.activo['observacion']?.toString() ??
        'Sin observaciones registradas.';

    final List<dynamic> rawImages = widget.activo['imagenes'] ?? [];
    final List<String> imagenesReales = rawImages.isNotEmpty
        ? rawImages.map((e) => e.toString()).toList()
        : ['NO_IMAGE'];

    final etiqueta = EtiquetaData(
      idActivo: widget.activo['id_activo']?.toString() ?? '',
      numeroIngreso: numeroIngreso,
      marca: marca,
      modelo: modelo,
      anio: (widget.activo['anio'] as num?)?.toInt() ?? 0,
      cilindrada: cilindrada == 'N/A' ? null : cilindrada,
      combustible: combustible == 'N/A' ? null : combustible,
      transmision: transmision == 'N/A' ? null : transmision,
      galpon: widget.activo['galpon']?.toString() ?? '',
      pasillo: widget.activo['pasillo']?.toString() ?? '',
      pallet: widget.activo['pallet']?.toString() ?? '',
      skuQrFisico: sku,
    );

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

                  if (esMotor) ...[
                    _buildSpecCard('CILINDRADA', cilindrada),
                    _buildSpecCard('COMBUSTIBLE', combustible),
                  ],

                  _buildSpecCard('TRANSMISIÓN', transmision),

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
