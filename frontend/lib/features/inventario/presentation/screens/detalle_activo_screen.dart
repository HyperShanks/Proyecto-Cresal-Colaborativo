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
    final String ubicacion =
        widget.activo['ubicacion']?.toString() ?? 'No asignada';

    // ⚠️ NUEVO: Extraemos el número de ingreso
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
    // Si no hay fotos, metemos un string identificador para renderizar el fallback nativo
    final List<String> imagenesReales = rawImages.isNotEmpty
        ? rawImages.map((e) => e.toString()).toList()
        : ['NO_IMAGE'];

    // ── Construimos el EtiquetaData para pasarlo a EtiquetaPreviewScreen ──
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
          // ⚠️ TÍTULO DINÁMICO
          'Detalle de $categoria',
          style: AppTypography.title.copyWith(color: AppPalette.textPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppPalette.primary),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildBadgeEstado(estado),
                      Text(
                        'ID: $sku',
                        style: AppTypography.small.copyWith(
                          color: AppPalette.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  RichText(
                    text: TextSpan(
                      style: AppTypography.headline.copyWith(fontSize: 28),
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
                  // Si tiene una URL válida, dibuja la foto
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
                  }
                  // Si no hay foto, dibuja un contenedor gris con un ícono
                  else {
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
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'UBICACIÓN ACTUAL',
                              style: AppTypography.small.copyWith(
                                color: AppPalette.textSecondary,
                                letterSpacing: 1.2,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              ubicacion,
                              style: AppTypography.title.copyWith(
                                color: AppPalette.primary,
                                fontSize: 22,
                              ),
                            ),
                          ],
                        ),
                        const Icon(
                          Icons.location_on_outlined,
                          color: AppPalette.primary,
                          size: 32,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  Text(
                    'ESPECIFICACIONES TÉCNICAS',
                    style: AppTypography.small.copyWith(
                      color: AppPalette.textSecondary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildSpecCard('Nº DE INGRESO VEHÍCULO', numeroIngreso),

                  // ⚠️ OCULTAMOS ESTOS DATOS SI ES UNA CAJA DE CAMBIO O ACCESORIO
                  if (esMotor) ...[
                    _buildSpecCard('CILINDRADA', cilindrada),
                    _buildSpecCard('COMBUSTIBLE', combustible),
                  ],

                  _buildSpecCard('TRANSMISIÓN', transmision),

                  Container(
                    margin: const EdgeInsets.only(bottom: 32),
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
                  // Regla de Negocio: el botón NUNCA se oculta.
                  // Si qr_impreso=false → "IMPRIMIR". Si qr_impreso=true → "REIMPRIMIR".
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        // Navega a la Vista Previa pasando el EtiquetaData construido
                        final resultado = await Navigator.of(
                          context,
                        ).pushNamed('/etiqueta-preview', arguments: etiqueta);

                        // Si la pantalla retornó true → la etiqueta fue impresa
                        // Actualizamos el estado local del botón sin ir al backend de nuevo
                        if (resultado == true && mounted) {
                          setState(() => _qrImpreso = true);
                          debugPrint(
                            '📌 [DETALLE_SCREEN] ✅ Retorno exitoso de EtiquetaPreview. qr_impreso → true',
                          );
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
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        // Verde para primera impresión, ámbar para reimpresión
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
                    height: 55,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.list_alt, color: Colors.white),
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
                  const SizedBox(height: 32),
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
