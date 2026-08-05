import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';

class DetalleActivoScreen extends StatefulWidget {
  final Map<String, dynamic> activo;

  const DetalleActivoScreen({Key? key, required this.activo}) : super(key: key);

  @override
  State<DetalleActivoScreen> createState() => _DetalleActivoScreenState();
}

class _DetalleActivoScreenState extends State<DetalleActivoScreen> {
  int _currentImageIndex = 0;

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

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Conexión futura a Bluetooth ESC/POS
                      },
                      icon: const Icon(
                        Icons.qr_code_scanner,
                        color: Colors.white,
                      ),
                      label: Text(
                        'IMPRIMIR ETIQUETA QR',
                        style: AppTypography.button.copyWith(
                          color: Colors.white,
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
              color: Colors.white,
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
      case 'RESERVADO':
        estadoColor = AppPalette.secondary;
        break;
      case 'VENDIDO':
        estadoColor = AppPalette.error;
        break;
      default:
        estadoColor = AppPalette.neutral;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: estadoColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
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
