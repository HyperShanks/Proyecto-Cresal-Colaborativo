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
  int _ocrFailedAttempts = 0;

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

    if (!mounted) return;

    if (datos != null) {
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ No se encontraron datos para esta patente.'),
          backgroundColor: AppPalette.error,
        ),
      );
    }

    setState(() {
      _isSearchingPatente = false;
    });
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

            const SizedBox(height: 24),

            // Banner instructivo de validación obligatoria OCR
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppPalette.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppPalette.secondary.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.camera_alt_outlined,
                    color: AppPalette.secondary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '📸 Validación Obligatoria: Al continuar se solicitará fotografiar el N° de ingreso físico para validación automática vía OCR.',
                      style: AppTypography.body.copyWith(
                        color: AppPalette.textPrimary,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),

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
        _ocrFailedAttempts = 0;
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
        _ocrFailedAttempts++;
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
            content: Text('❌ $feedback (Intento $_ocrFailedAttempts/5)'),
            backgroundColor: AppPalette.error,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );

        if (_ocrFailedAttempts >= 5 && mounted) {
          _mostrarModalIngresoManual(context, datosNuevos);
        }
      }
    } catch (e) {
      _ocrFailedAttempts++;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Error de conexión o fallo en servicio OCR.'),
            backgroundColor: AppPalette.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Fallo de red / API de Google Cloud Vision -> Dispara contingencia manual
        _mostrarModalIngresoManual(context, datosNuevos);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  // ── MODALES DE CONTINGENCIA / VALIDACIÓN MANUAL (HU-2.3 Poka-Yoke Fallback) ──

  Future<void> _mostrarModalIngresoManual(
    BuildContext context,
    Map<String, dynamic> datosNuevos,
  ) async {
    final TextEditingController manualIngresoController =
        TextEditingController(text: numeroIngreso != "Cargando..." ? numeroIngreso : "");

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppPalette.secondary, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Validación Manual OCR',
                style: AppTypography.cardTitle.copyWith(fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No logramos detectar el número automáticamente o hubo un problema de conexión. Ingresa manualmente el N° de Ingreso visible en el vehículo o pieza.',
              style: AppTypography.body.copyWith(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('input_numero_ingreso_manual'),
              controller: manualIngresoController,
              decoration: const InputDecoration(
                labelText: 'N° de Ingreso Físico',
                hintText: 'Ej: 1001',
                prefixIcon: Icon(Icons.confirmation_number_outlined, color: AppPalette.primary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            key: const Key('btn_reintentar_camara'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Reintentar con Cámara',
              style: AppTypography.button.copyWith(color: AppPalette.textSecondary),
            ),
          ),
          ElevatedButton(
            key: const Key('btn_confirmar_ingreso_manual'),
            onPressed: () {
              if (manualIngresoController.text.trim().isNotEmpty) {
                Navigator.of(ctx).pop(true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppPalette.primary),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final numeroManual = manualIngresoController.text.trim();
      await _mostrarModalDobleConfirmacion(datosNuevos, numeroManual);
    }
  }

  Future<void> _mostrarModalDobleConfirmacion(
    Map<String, dynamic> datosNuevos,
    String numeroManual,
  ) async {
    if (!mounted) return;
    final doubleConfirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.verified_user_outlined, color: AppPalette.primary, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Confirmación de Seguridad',
                style: AppTypography.cardTitle.copyWith(fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          '¿Confirmas que el N° de Ingreso $numeroManual corresponde fielmente al vehículo/pieza física?',
          style: AppTypography.body.copyWith(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancelar',
              style: AppTypography.button.copyWith(color: AppPalette.textSecondary),
            ),
          ),
          ElevatedButton(
            key: const Key('btn_aceptar_doble_confirmacion'),
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppPalette.success),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );

    if (doubleConfirmed == true && mounted) {
      setState(() {
        _isUploading = true;
        _ocrFailedAttempts = 0;
      });

      final datosFinales = Map<String, dynamic>.from(datosNuevos);
      datosFinales["correlativo_ingreso"] = numeroManual;

      try {
        final res = await _vehiculoService.guardarIngresoManual(datosFinales);
        if (!mounted) return;

        if (res['exito'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Vehículo registrado exitosamente con validación manual.'),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ ${res['mensaje']}'),
              backgroundColor: AppPalette.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error al guardar: $e'),
              backgroundColor: AppPalette.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isUploading = false);
        }
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
      initialValue: value,
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
