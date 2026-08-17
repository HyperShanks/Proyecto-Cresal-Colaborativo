import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../services/paletizado_service.dart';
import '../../services/print_service.dart';
import '../../domain/exceptions/printer_exceptions.dart';
import '../../domain/models/etiqueta_data.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class PaletizadoScreen extends StatefulWidget {
  const PaletizadoScreen({super.key});

  @override
  State<PaletizadoScreen> createState() => _PaletizadoScreenState();
}

class _PaletizadoScreenState extends State<PaletizadoScreen> {
  final TextEditingController _searchController = TextEditingController();
  final PaletizadoService _paletizadoService = PaletizadoService();

  final TextEditingController _galponController = TextEditingController();
  final TextEditingController _pasilloController = TextEditingController();
  final TextEditingController _palletController = TextEditingController();
  final TextEditingController _observacionController = TextEditingController();

  bool _isLoading = false;
  bool _vehiculoEncontrado = false;
  bool _isLoadingPendientes = false;
  List<dynamic> _pendientesPaletizado = [];

  String _marca = "";
  String _modelo = "";
  String _anio = "";
  // Datos técnicos específicos del activo
  Map<String, dynamic> _datosMotor = {};
  Map<String, dynamic> _datosCaja = {};

  String _tipoActivoSeleccionado = 'Motor';
  List<String> _opcionesRepuestos = []; // ⚠️ NUEVA LISTA DINÁMICA

  bool _isValidatingOCR = false;

  final ImagePicker _picker = ImagePicker();
  List<XFile> _fotosComerciales = [];

  @override
  void initState() {
    super.initState();
    _cargarPendientes();
  }

  Future<void> _cargarPendientes() async {
    setState(() => _isLoadingPendientes = true);
    try {
      final pendientes = await _paletizadoService.obtenerPendientesPaletizado();
      if (!mounted) return;
      setState(() {
        _pendientesPaletizado = pendientes;
      });
    } catch (e) {
      debugPrint('Error al cargar pendientes de paletizado: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingPendientes = false);
      }
    }
  }

  Future<void> _tomarFotoComercial() async {
    if (_fotosComerciales.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Has alcanzado el límite de 10 fotografías.'),
          backgroundColor: AppPalette.secondary,
        ),
      );
      return;
    }

    try {
      // imageQuality: 70 ayuda a que las fotos no pesen 5MB cada una y saturen tu base de datos
      final XFile? foto = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );

      if (foto != null) {
        setState(() {
          _fotosComerciales.add(foto);
        });
      }
    } catch (e) {
      debugPrint("Error al abrir la cámara: $e");
    }
  }

  // ── Función para eliminar una foto por error ──
  void _eliminarFoto(int index) {
    setState(() {
      _fotosComerciales.removeAt(index);
    });
  }

  // ── Función para Validar OCR y Guardar ──
  Future<void> _validarYGuardar() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final folio = _searchController.text.trim();

    // 1. Validaciones básicas de interfaz
    if (_fotosComerciales.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe tomar al menos 1 foto comercial de la pieza.'),
          backgroundColor: AppPalette.secondary,
        ),
      );
      return;
    }

    if (_galponController.text.isEmpty ||
        _pasilloController.text.isEmpty ||
        _palletController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Por favor, complete todos los campos de ubicación física.',
          ),
          backgroundColor: AppPalette.error,
        ),
      );
      return;
    }

    // 2. Abrir cámara para la foto técnica (Poka-Yoke)
    final XFile? fotoOcr = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (fotoOcr == null)
      return; // Si el usuario cancela la cámara, no hacemos nada

    // 3. Bloquear la UI (Botón de carga activado para OCR + Subida a la nube)
    setState(() => _isValidatingOCR = true);

    // 4. Llamada al servicio de validación Poka-Yoke
    final resultadoOCR = await _paletizadoService.validarOCRPieza(
      folio,
      File(fotoOcr.path),
    );

    if (!mounted) return;

    // 5. Analizar el resultado de la Inteligencia Artificial
    if (resultadoOCR != null) {
      final bool esMatch = resultadoOCR['match'] ?? false;
      final String mensaje = resultadoOCR['mensaje'] ?? 'Error desconocido';

      if (esMatch) {
        // ¡ÉXITO OCR! Avisamos al usuario que ahora estamos guardando...
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Validación exitosa. Subiendo fotos a la nube...'),
            backgroundColor: AppPalette.success,
          ),
        );

        // --- 6. GUARDADO DEFINITIVO ---
        // Convertimos la lista de XFile a File para el servicio
        List<File> fotosArchivos = _fotosComerciales
            .map((x) => File(x.path))
            .toList();

        // Llamamos al guardado que envía los textos y las fotos
        final resultadoGuardado = await _paletizadoService
            .guardarPaletizadoDefinitivo(
              folio: folio,
              tipoRepuesto: _tipoActivoSeleccionado,
              galpon: _galponController.text.trim(),
              pasillo: _pasilloController.text.trim(),
              pallet: _palletController.text.trim(),
              observaciones: _observacionController.text.trim(),
              fotos: fotosArchivos,
            );

        if (!mounted) return;

        // Terminó el proceso pesado, detenemos el indicador de carga del botón
        setState(() => _isValidatingOCR = false);

        // HU-2.4: En lugar de un simple SnackBar, mostramos el modal interactivo
        if (resultadoGuardado != null) {
          // Construimos el EtiquetaData a partir de la respuesta enriquecida del backend
          final etiqueta = EtiquetaData.fromJson(resultadoGuardado);

          // Limpiamos el formulario ANTES de mostrar el modal
          _limpiarFormulario();

          // Mostramos el Modal Bottom Sheet con las 3 opciones
          await _mostrarModalExito(etiqueta);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Error al guardar en el servidor. Revise la consola.',
              ),
              backgroundColor: AppPalette.error,
            ),
          );
        }
      } else {
        // ERROR: La pieza no coincide.
        setState(() => _isValidatingOCR = false); // Detenemos la carga
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'ALERTA: $mensaje\nTexto detectado: ${resultadoOCR['texto_detectado']}',
            ),
            backgroundColor: AppPalette.error,
            duration: const Duration(
              seconds: 5,
            ), // Le damos más tiempo para leer
          ),
        );
      }
    } else {
      // Error de red al intentar conectar con el OCR
      setState(() => _isValidatingOCR = false); // Detenemos la carga
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error de conexión al intentar validar el código.'),
          backgroundColor: AppPalette.error,
        ),
      );
    }
  }

  /// Limpia todos los campos del formulario para preparar la siguiente operación.
  void _limpiarFormulario() {
    setState(() {
      _searchController.clear();
      _vehiculoEncontrado = false;
      _galponController.clear();
      _pasilloController.clear();
      _palletController.clear();
      _observacionController.clear();
      _fotosComerciales.clear();
      _tipoActivoSeleccionado = 'Motor';
    });
    _cargarPendientes();
  }

  // ── HU-2.4: Modal Bottom Sheet con 3 acciones post-guardado ──────────────
  //
  // Este método es el punto de entrada para el flujo de identidad digital.
  // Se invoca SOLO en caso de éxito, inyectando el [EtiquetaData] ya construido
  // para que los 3 botones puedan actuar sin otra llamada al backend.
  Future<void> _mostrarModalExito(EtiquetaData etiqueta) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isDismissible: false, // El operario debe elegir conscientemente
      enableDrag: false,
      builder: (ctx) => _ModalExitoContent(etiqueta: etiqueta),
    );
  }

  Future<void> _buscarVehiculo() async {
    final folio = _searchController.text.trim();
    if (folio.isEmpty) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _vehiculoEncontrado = false;
    });

    final datosVehiculo = await _paletizadoService.buscarVehiculoPorIngreso(
      folio,
    );

    if (!mounted) return;

    if (datosVehiculo != null) {
      // Guardamos los diccionarios de las piezas
      final datosMotorTemp = datosVehiculo['motor'] ?? {};
      final datosCajaTemp = datosVehiculo['caja_cambios'] ?? {};

      // ⚠️ LÓGICA DE BLOQUEO: Solo agregamos los que están en estado 5 (En Desarme)
      List<String> opcionesDisponibles = [];
      if (datosMotorTemp['id_estado'] == 5) opcionesDisponibles.add('Motor');
      if (datosCajaTemp['id_estado'] == 5)
        opcionesDisponibles.add('Caja de Cambios');

      // Si la lista quedó vacía, significa que ambos ya fueron paletizados (estado 1 u otro)
      if (opcionesDisponibles.isEmpty) {
        setState(() {
          _isLoading = false;
          _vehiculoEncontrado = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '✅ Todos los repuestos de este folio ya se encuentran paletizados.',
              ),
              backgroundColor: AppPalette.success,
            ),
          );
        }
        return; // Cortamos la ejecución aquí, no mostramos el formulario
      }

      // Si hay piezas pendientes, actualizamos la pantalla
      setState(() {
        _isLoading = false;
        _vehiculoEncontrado = true;

        final vehiculo = datosVehiculo['vehiculo'] ?? {};
        _marca = vehiculo['marca'] ?? 'Desconocida';
        _modelo = vehiculo['modelo'] ?? 'Desconocido';
        _anio = vehiculo['anio']?.toString() ?? 'S/A';

        _datosMotor = datosMotorTemp;
        _datosCaja = datosCajaTemp;

        _opcionesRepuestos = opcionesDisponibles; // Asignamos la lista filtrada
        _tipoActivoSeleccionado =
            _opcionesRepuestos.first; // Seleccionamos el primero por defecto
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        backgroundColor: AppPalette.background,
        title: const Text(
          'Paletizado y Enriquecimiento',
          style: AppTypography.title,
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. BUSCADOR ───────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Buscar N° Ingreso...',
                      prefixIcon: Icon(Icons.search, color: AppPalette.primary),
                    ),
                    onSubmitted: (_) => _buscarVehiculo(),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 55,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: _isLoading ? null : _buscarVehiculo,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.arrow_forward),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ── 2. FORMULARIO LOGÍSTICO ───────────────────────────
            if (_vehiculoEncontrado) ...[
              // Banner de información destacada
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: AppPalette.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('VEHÍCULO ORIGEN', style: AppTypography.small),
                        InkWell(
                          onTap: _limpiarFormulario,
                          child: Text(
                            'Volver a la lista',
                            style: AppTypography.small.copyWith(
                              color: AppPalette.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$_marca $_modelo',
                      style: AppTypography.headline.copyWith(
                        color: AppPalette.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text('Año: $_anio', style: AppTypography.title),
                    const SizedBox(height: 16),

                    // ── ESTADO DE LOS COMPONENTES PRINCIPALES ──
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppPalette.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _datosMotor['id_estado'] == 5
                                    ? AppPalette.success
                                    : AppPalette.neutral.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.settings, size: 16, color: AppPalette.primary),
                                    const SizedBox(width: 6),
                                    Text('MOTOR', style: AppTypography.small.copyWith(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _datosMotor['id_estado'] == 5
                                      ? 'Disponible para Paletizar'
                                      : (_datosMotor.isNotEmpty ? 'Ya Paletizado' : 'No Registrado'),
                                  style: AppTypography.small.copyWith(
                                    color: _datosMotor['id_estado'] == 5 ? AppPalette.success : AppPalette.textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppPalette.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _datosCaja['id_estado'] == 5
                                    ? AppPalette.success
                                    : AppPalette.neutral.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.swap_horiz, size: 16, color: AppPalette.primary),
                                    const SizedBox(width: 6),
                                    Text('CAJA CAMBIOS', style: AppTypography.small.copyWith(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _datosCaja['id_estado'] == 5
                                      ? 'Disponible para Paletizar'
                                      : (_datosCaja.isNotEmpty ? 'Ya Paletizada' : 'No Registrada'),
                                  style: AppTypography.small.copyWith(
                                    color: _datosCaja['id_estado'] == 5 ? AppPalette.success : AppPalette.textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              const Text('Datos del Activo a Paletizar', style: AppTypography.title),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _tipoActivoSeleccionado,
                dropdownColor: AppPalette.surface,
                style: const TextStyle(color: AppPalette.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Seleccionar Repuesto para Etiquetar',
                  prefixIcon: Icon(
                    Icons.build_circle_outlined,
                    color: AppPalette.primary,
                  ),
                ),
                items: _opcionesRepuestos.map((String valor) {
                  return DropdownMenuItem(value: valor, child: Text(valor));
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _tipoActivoSeleccionado = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppPalette.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppPalette.neutral.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Especificaciones Registradas:',
                      style: AppTypography.small.copyWith(
                        color: AppPalette.primary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (_tipoActivoSeleccionado == 'Motor') ...[
                      Text(
                        'N° Motor: ${_datosMotor['numero_motor'] ?? '-'}',
                        style: AppTypography.body,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Cilindrada: ${_datosMotor['cilindrada'] ?? '-'}',
                        style: AppTypography.body,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Combustible: ${_datosMotor['combustible'] ?? '-'}',
                        style: AppTypography.body,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Transmisión: ${_datosMotor['transmision_tipo'] ?? '-'}',
                        style: AppTypography.body,
                      ),
                    ] else if (_tipoActivoSeleccionado ==
                        'Caja de Cambios') ...[
                      Text(
                        'Transmisión: ${_datosCaja['transmision_tipo'] ?? '-'}',
                        style: AppTypography.body,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text('Ubicación Física', style: AppTypography.title),
              const SizedBox(height: 16),

              _buildTextField(_galponController, 'Galpón', Icons.warehouse),
              const SizedBox(height: 16),
              _buildTextField(_pasilloController, 'Pasillo', Icons.view_column),
              const SizedBox(height: 16),
              _buildTextField(_palletController, 'Pallet', Icons.layers),
              const SizedBox(height: 16),
              _buildTextField(
                _observacionController,
                'Observación del estado (Opcional)',
                Icons.note_alt_outlined,
                maxLines: 3,
              ),

              const SizedBox(height: 32),

              // ── C. CATÁLOGO COMERCIAL ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Catálogo Comercial (Max. 10)', style: AppTypography.title),
                  Text(
                    '${_fotosComerciales.length}/10',
                    style: AppTypography.small.copyWith(
                      color: _fotosComerciales.length == 10
                          ? AppPalette.secondary
                          : AppPalette.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Carrusel Horizontal de Fotos
              SizedBox(
                height: 140,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _fotosComerciales.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: InkWell(
                          onTap: _tomarFotoComercial,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 110,
                            decoration: BoxDecoration(
                              color: AppPalette.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppPalette.primary,
                                width: 2,
                              ),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.camera_alt,
                                  color: AppPalette.primary,
                                  size: 36,
                                ),
                                SizedBox(height: 8),
                                Text('Agregar', style: AppTypography.small),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    final fotoIndex = index - 1;
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(_fotosComerciales[fotoIndex].path),
                              width: 110,
                              height: 140,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _eliminarFoto(fotoIndex),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppPalette.error,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 40),

              // Botón Final
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isValidatingOCR ? null : _validarYGuardar,
                  icon: _isValidatingOCR
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.camera_alt, color: Colors.white),
                  label: Text(
                    _isValidatingOCR
                        ? 'ANALIZANDO CON IA...'
                        : 'VALIDAR CON OCR Y GUARDAR',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.primary,
                  ),
                ),
              ),
            ] else ...[
              // ── 2. SECCIÓN DE PIEZAS PENDIENTES O EMPTY STATE ────
              if (_isLoadingPendientes)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 48.0),
                    child: CircularProgressIndicator(color: AppPalette.primary),
                  ),
                )
              else if (_pendientesPaletizado.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppPalette.surface,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppPalette.success.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.check_circle_outline,
                            size: 56,
                            color: AppPalette.success,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No hay piezas pendientes para paletizar',
                          style: AppTypography.title.copyWith(fontSize: 18),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Todos los activos ingresados cuentan con ubicación física asignada en bodega.',
                          style: AppTypography.small.copyWith(
                            color: AppPalette.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        OutlinedButton.icon(
                          onPressed: _cargarPendientes,
                          icon: const Icon(Icons.refresh, color: AppPalette.primary, size: 18),
                          label: const Text(
                            'Actualizar Lista',
                            style: TextStyle(color: AppPalette.primary),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppPalette.primary),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Piezas Disponibles para Paletizar (${_pendientesPaletizado.length})',
                      style: AppTypography.title.copyWith(fontSize: 16),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.refresh,
                        color: AppPalette.primary,
                        size: 20,
                      ),
                      onPressed: _cargarPendientes,
                      tooltip: 'Actualizar lista',
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Selecciona una pieza para autocompletar o busca por Folio arriba.',
                  style: AppTypography.small.copyWith(
                    color: AppPalette.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _pendientesPaletizado.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _pendientesPaletizado[index];
                    final folio = item['numero_ingreso']?.toString() ?? 'S/F';
                    final marca = item['marca']?.toString() ?? 'Desconocida';
                    final modelo = item['modelo']?.toString() ?? 'Desconocido';
                    final anio = item['anio']?.toString() ?? '';
                    final categoria = item['tipo_repuesto']?.toString() ?? 'Repuesto';
                    final sku = item['sku_qr_fisico']?.toString() ?? '';

                    return InkWell(
                      key: Key('item_pendiente_paletizado_$index'),
                      onTap: () {
                        _searchController.text = folio;
                        _buscarVehiculo();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppPalette.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppPalette.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                categoria.toUpperCase().contains('MOTOR')
                                    ? Icons.settings
                                    : Icons.swap_horiz,
                                color: AppPalette.primary,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppPalette.primary.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Folio: $folio',
                                          style: const TextStyle(
                                            color: AppPalette.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        categoria,
                                        style: AppTypography.small.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '$marca $modelo $anio'.trim(),
                                    style: AppTypography.body.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (sku.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'SKU: $sku',
                                      style: AppTypography.small.copyWith(
                                        color: AppPalette.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              color: AppPalette.textSecondary,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: AppPalette.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppPalette.primary, size: 20),
      ),
    );
  }
}

// ── HU-2.4: Widget del Modal Bottom Sheet con las 3 acciones ─────────────────
//
// Se extrae como un StatefulWidget separado para encapsular su propio estado
// (ej. el indicador de carga del botón "Imprimir Ahora") sin contaminar
// el estado de PaletizadoScreen.
class _ModalExitoContent extends StatefulWidget {
  final EtiquetaData etiqueta;
  const _ModalExitoContent({required this.etiqueta});

  @override
  State<_ModalExitoContent> createState() => _ModalExitoContentState();
}

class _ModalExitoContentState extends State<_ModalExitoContent> {
  bool _isConnecting = false;
  final PaletizadoService _paletizadoService = PaletizadoService();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Indicador visual del modal ────────────────────────────────────
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppPalette.neutral,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // ── Ícono y título de éxito ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppPalette.success,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            '¡Activo Guardado!',
            style: AppTypography.headline.copyWith(
              color: AppPalette.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'SKU: ${widget.etiqueta.skuQrFisico}  •  Folio N° ${widget.etiqueta.numeroIngreso}',
            style: AppTypography.small.copyWith(color: AppPalette.primary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // ── Botón 1: Imprimir Ahora ───────────────────────────────────────
          // Impresión térmica industrial vía Sockets TCP (Puerto 9100 / ZPL).
          // Ver: lib/features/paletizado/services/print_service.dart
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isConnecting
                  ? null
                  : () async {
                      setState(() => _isConnecting = true);

                      try {
                        final exito = await PrintService.imprimirEtiqueta(widget.etiqueta);

                        if (!mounted) return;

                        if (exito) {
                          // Confirmación en Backend (PATCH qr_impreso = true)
                          await _paletizadoService.confirmarQrImpreso(widget.etiqueta.idActivo);

                          if (!mounted) return;
                          Navigator.of(context).pop(); // Cierra el modal
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '✅ Etiqueta impresa y registrada. SKU: ${widget.etiqueta.skuQrFisico}',
                              ),
                              backgroundColor: AppPalette.success,
                            ),
                          );
                        }
                      } on PrinterException catch (e) {
                        debugPrint('📌 [PALETIZADO_SCREEN] ❌ Error de dominio de impresora: ${e.mensaje}');
                        if (!mounted) return;
                        await showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: AppPalette.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: AppPalette.secondary, size: 28),
                                SizedBox(width: 10),
                                Text(
                                  'Error de Impresión',
                                  style: TextStyle(
                                    color: AppPalette.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                            content: Text(
                              e.mensaje,
                              style: const TextStyle(
                                color: AppPalette.textSecondary,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text(
                                  'ENTENDIDO',
                                  style: TextStyle(
                                    color: AppPalette.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      } catch (e) {
                        debugPrint('📌 [PALETIZADO_SCREEN] ❌ Excepción no controlada: $e');
                        if (!mounted) return;
                        await showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: AppPalette.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: const Row(
                              children: [
                                Icon(Icons.error_outline, color: AppPalette.secondary, size: 28),
                                SizedBox(width: 10),
                                Text(
                                  'Error Inesperado',
                                  style: TextStyle(
                                    color: AppPalette.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                            content: Text(
                              'Ocurrió un error inesperado al comunicarse con la impresora: $e',
                              style: const TextStyle(
                                color: AppPalette.textSecondary,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text(
                                  'ENTENDIDO',
                                  style: TextStyle(
                                    color: AppPalette.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      } finally {
                        if (mounted) {
                          setState(() => _isConnecting = false);
                        }
                      }
                    },
              icon: _isConnecting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.print, color: Colors.white),
              label: Text(_isConnecting ? 'CONECTANDO...' : 'Imprimir Ahora'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Botón 2: Ver Tarjeta ──────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop(); // Cierra el modal
                // Navega a la pantalla de previsualización con los datos de la etiqueta
                Navigator.of(
                  context,
                ).pushNamed('/etiqueta-preview', arguments: widget.etiqueta);
              },
              icon: const Icon(Icons.qr_code_2, color: AppPalette.primary),
              label: const Text(
                'Ver Tarjeta',
                style: TextStyle(color: AppPalette.primary),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppPalette.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Botón 3: Hacerlo más tarde ────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Hacerlo más tarde',
                style: TextStyle(color: AppPalette.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
