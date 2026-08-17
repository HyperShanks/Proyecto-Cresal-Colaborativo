import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// Rutas relativas hacia la capa core y services del feature
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../services/vehiculo_service.dart';

class RecepcionVehiculoScreen extends StatefulWidget {
  const RecepcionVehiculoScreen({super.key});

  @override
  State<RecepcionVehiculoScreen> createState() =>
      _RecepcionVehiculoScreenState();
}

class _RecepcionVehiculoScreenState extends State<RecepcionVehiculoScreen> {
  // Variables de Estado
  String numeroIngreso = "Cargando...";
  bool isLoading = true;
  final VehiculoService _vehiculoService = VehiculoService();

  // Variables para los selectores obligatorios
  String? traccionSeleccionada;
  String? transmisionSeleccionada;
  String? combustibleSeleccionado;

  // Controladores de texto
  final TextEditingController _patenteController = TextEditingController();
  final TextEditingController _marcaController = TextEditingController();
  final TextEditingController _modeloController = TextEditingController();
  final TextEditingController _anoController = TextEditingController();
  final TextEditingController _cilindradaController = TextEditingController();
  final TextEditingController _motorController = TextEditingController();

  // Variables para la cámara
  final ImagePicker _picker = ImagePicker();

  // Variable para manejar la pantalla de carga del OCR y Scraping
  bool _isUploading = false;
  bool _isSearchingPatente = false;

  @override
  void initState() {
    super.initState();
    _cargarFolioDesdeBackend();
  }

  Future<void> _cargarFolioDesdeBackend() async {
    final folio = await _vehiculoService.obtenerSiguienteIngreso();

    if (mounted) {
      setState(() {
        numeroIngreso = folio;
        isLoading = false;
      });
    }
  }

  Future<void> _ejecutarScrapingPatente() async {
    final patente = _patenteController.text.trim().toUpperCase();
    if (patente.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Ingresa una patente primero para buscar.'),
          backgroundColor: AppPalette.secondary,
        ),
      );
      return;
    }

    setState(() {
      _isSearchingPatente = true;
    });

    // Ejecutar Scraping NATIVO
    final datos = await _vehiculoService.buscarDatosPorPatente(patente);

    if (datos != null && context.mounted) {
      setState(() {
        _marcaController.text = datos['marca'] ?? '';
        _modeloController.text = datos['modelo'] ?? '';
        _anoController.text = datos['anio']?.toString() ?? '';
        _cilindradaController.text = datos['cilindrada'] ?? '';
        _motorController.text = datos['numero_motor'] ?? '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Datos recuperados exitosamente.'),
          backgroundColor: AppPalette.success,
        ),
      );
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ No se encontraron datos para esta patente.'),
          backgroundColor: AppPalette.error,
        ),
      );
    }

    if (context.mounted) {
      setState(() {
        _isSearchingPatente = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background, // ⚠️ Aplicamos el fondo del token
      appBar: AppBar(
        title: const Text(
          'Recepción de Vehículo',
          style: AppTypography.title,
        ), // ⚠️ Aplicamos tipografía
        backgroundColor: AppPalette.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppPalette.primary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. TARJETA DEL FOLIO (Diseño alineado a Paletizado)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: 32.0,
                horizontal: 16.0,
              ),
              decoration: BoxDecoration(
                color: AppPalette.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'NÚMERO DE INGRESO',
                    style: AppTypography.small.copyWith(
                      color: AppPalette.primary,
                      letterSpacing: 2.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    numeroIngreso,
                    style: AppTypography.headline.copyWith(
                      fontSize: 56,
                      color: AppPalette.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            const Text(
              'Datos Técnicos del Vehículo',
              style: AppTypography.title, // ⚠️ Tipografía unificada
            ),
            const SizedBox(height: 16),

            // 2. FORMULARIO COMPLETO
            _buildTextField(
              controller: _patenteController,
              label: 'Patente (Ej: XXYY11)',
              icon: Icons.directions_car,
              isCapitalized: true,
              suffixWidget: _isSearchingPatente
                  ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppPalette.primary,
                        ),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.search),
                      color: AppPalette.primary,
                      onPressed: _ejecutarScrapingPatente,
                      tooltip: 'Buscar datos del vehículo',
                    ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _marcaController,
                    label: 'Marca',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _modeloController,
                    label: 'Modelo',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _anoController,
                    label: 'Año',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _cilindradaController,
                    label: 'Cilindrada',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildTextField(
              controller: _motorController,
              label: 'Nro. de Motor',
            ),
            const SizedBox(height: 16),

            // 3. SELECTORES OBLIGATORIOS
            _buildDropdown(
              label: 'Tracción',
              value: traccionSeleccionada,
              items: ['4x2', '4x4', 'AWD'],
              onChanged: (nuevoValor) =>
                  setState(() => traccionSeleccionada = nuevoValor),
            ),
            const SizedBox(height: 16),

            _buildDropdown(
              label: 'Transmisión',
              value: transmisionSeleccionada,
              items: ['Mecánica', 'Automática'],
              onChanged: (nuevoValor) =>
                  setState(() => transmisionSeleccionada = nuevoValor),
            ),
            const SizedBox(height: 16),

            _buildDropdown(
              label: 'Combustible',
              value: combustibleSeleccionado,
              items: ['Gasolina', 'Diésel', 'Eléctrico', 'Híbrido'],
              onChanged: (nuevoValor) =>
                  setState(() => combustibleSeleccionado = nuevoValor),
            ),

            const SizedBox(height: 32),

            // 4. EL BOTÓN GUARDAR / REGISTRAR CON OCR ATÓMICO
            GradientButton(
              key: const Key('btn_guardar_ingreso_ocr'),
              onPressed: _isUploading ? null : _ejecutarGuardadoConOCR,
              gradient: const LinearGradient(
                colors: [AppPalette.primary, AppPalette.primary],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              child: _isUploading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'VALIDANDO OCR Y GUARDANDO...',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt, color: Colors.white, size: 22),
                        SizedBox(width: 10),
                        Text(
                          'GUARDAR / REGISTRAR INGRESO',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Future<void> _ejecutarGuardadoConOCR() async {
    // 1. Validar campos manuales obligatorios
    if (_patenteController.text.trim().isEmpty ||
        _marcaController.text.trim().isEmpty ||
        _modeloController.text.trim().isEmpty ||
        _anoController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚠️ Bloqueo: Completa los datos obligatorios (Patente, Marca, Modelo y Año) antes de registrar.',
          ),
          backgroundColor: AppPalette.secondary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 2. Abrir automáticamente la cámara para capturar la foto física Poka-Yoke
    final XFile? foto = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );

    if (foto == null) {
      // El usuario canceló la cámara
      return;
    }

    setState(() {
      _isUploading = true;
    });

    final datosNuevos = {
      "correlativo_ingreso": numeroIngreso,
      "patente": _patenteController.text.trim().toUpperCase(),
      "marca": _marcaController.text.trim(),
      "modelo": _modeloController.text.trim(),
      "anio": int.tryParse(_anoController.text.trim()) ?? 2000,
      "cilindrada": _cilindradaController.text.trim(),
      "numero_motor": _motorController.text.trim(),
      "traccion": traccionSeleccionada ?? "",
      "transmision": transmisionSeleccionada ?? "",
      "combustible": combustibleSeleccionado ?? "",
      "estado": "EN_PATIO",
    };

    try {
      final resultado = await _vehiculoService.guardarIngresoConRespuesta(
        datosNuevos,
        foto,
      );

      if (!mounted) return;

      if (resultado['exito'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✅ Poka-Yoke Superado: ¡Vehículo ingresado con éxito!',
            ),
            backgroundColor: AppPalette.success,
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );

        _patenteController.clear();
        _marcaController.clear();
        _modeloController.clear();
        _anoController.clear();
        _cilindradaController.clear();
        _motorController.clear();
        setState(() {
          traccionSeleccionada = null;
          transmisionSeleccionada = null;
          combustibleSeleccionado = null;
          numeroIngreso = "Cargando...";
        });

        _cargarFolioDesdeBackend();
      } else {
        final mensajeError = resultado['mensaje']?.toString() ?? '';
        final String feedback;
        if (mensajeError.toLowerCase().contains('poka-yoke') ||
            mensajeError.toLowerCase().contains('ocr') ||
            mensajeError.toLowerCase().contains('foto') ||
            mensajeError.toLowerCase().contains('texto') ||
            mensajeError.toLowerCase().contains('corresponde')) {
          feedback = 'No se pudo validar el OCR de la pieza. Por favor, reintente con una foto más clara';
        } else {
          feedback = mensajeError.isNotEmpty
              ? mensajeError
              : 'No se pudo validar el OCR de la pieza. Por favor, reintente con una foto más clara';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $feedback'),
            backgroundColor: AppPalette.error,
            duration: const Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Error de conexión con el servidor.'),
            backgroundColor: AppPalette.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  // ── WIDGETS REUTILIZABLES PARA FORMULARIOS ──

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    bool isCapitalized = false,
    TextInputType? keyboardType,
    Widget? suffixWidget,
  }) {
    return TextField(
      controller: controller,
      style: AppTypography.body, // ⚠️ Tipografía correcta
      textCapitalization: isCapitalized
          ? TextCapitalization.characters
          : TextCapitalization.none,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTypography.small,
        prefixIcon: icon != null
            ? Icon(icon, color: AppPalette.primary, size: 20)
            : null,
        suffixIcon: suffixWidget,
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTypography.small,
      ),
      value: value,
      dropdownColor:
          AppPalette.surface, // ⚠️ Evita menús blancos en modo oscuro
      style: AppTypography.body, // ⚠️ Tipografía correcta
      icon: const Icon(Icons.keyboard_arrow_down, color: AppPalette.primary),
      items: items.map((String valor) {
        return DropdownMenuItem<String>(value: valor, child: Text(valor));
      }).toList(),
      onChanged: onChanged,
    );
  }
}
