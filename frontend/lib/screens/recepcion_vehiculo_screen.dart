import 'package:flutter/material.dart';
import '../core/widgets/gradient_button.dart';
import '../core/theme/tokens/app_palette.dart';
import '../services/vehiculo_service.dart';
import 'package:image_picker/image_picker.dart';

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
  XFile? _fotoPuerta; // Aquí se guardará el archivo de la foto

  // Variable para manejar la pantalla de carga del OCR
  bool _isUploading = false;
  // Variable para manejar la carga del scraping de patente
  bool _isSearchingPatente = false;

  @override
  void initState() {
    super.initState();
    _cargarFolioDesdeBackend();
  }

  Future<void> _cargarFolioDesdeBackend() async {
    final folio = await _vehiculoService.obtenerSiguienteIngreso();

    setState(() {
      numeroIngreso = folio;
      isLoading = false;
    });
  }

  Future<void> _ejecutarScrapingPatente() async {
    final patente = _patenteController.text.trim();
    if (patente.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Ingresa una patente primero para buscar.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSearchingPatente = true;
    });

    // Llamamos al servicio que acabamos de crear
    final datos = await _vehiculoService.buscarDatosPorPatente(patente);

    if (datos != null && context.mounted) {
      setState(() {
        // Autocompletamos los campos con lo que encontró el backend
        _marcaController.text = datos['marca'] ?? '';
        _modeloController.text = datos['modelo'] ?? '';
        _anoController.text = datos['anio']?.toString() ?? '';
        _cilindradaController.text =
            datos['cilindrada'] ?? ''; // <- LÍNEA NUEVA
        _motorController.text = datos['numero_motor'] ?? '';

        // Opcional: Autocompletar listas desplegables si los nombres coinciden exacto
        // traccionSeleccionada = datos['traccion'];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Datos recuperados exitosamente.'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ No se encontraron datos para esta patente.'),
          backgroundColor: Colors.red,
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
      appBar: AppBar(title: const Text('Recepción de Vehículo')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. TARJETA DEL FOLIO (CORRELATIVO)
            SizedBox(
              width: double.infinity,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Column(
                    children: [
                      Text(
                        'NÚMERO DE INGRESO',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        numeroIngreso,
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(
                              fontSize: 56,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
            Text(
              'Datos Técnicos del Vehículo',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // 2. FORMULARIO COMPLETO
            // 2. FORMULARIO COMPLETO
            TextField(
              controller: _patenteController,
              textCapitalization:
                  TextCapitalization.characters, // Fuerza mayúsculas
              decoration: InputDecoration(
                labelText: 'Patente',
                hintText: 'Ej: XXYY11',
                prefixIcon: const Icon(Icons.directions_car),
                // Aquí cambiamos el ícono fijo por un botón interactivo y reactivo
                suffixIcon: _isSearchingPatente
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.search),
                        color: AppPalette.primary,
                        onPressed: _ejecutarScrapingPatente,
                        tooltip: 'Buscar datos del vehículo',
                      ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _marcaController,
                    decoration: const InputDecoration(labelText: 'Marca'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _modeloController,
                    decoration: const InputDecoration(labelText: 'Modelo'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _anoController,
                    keyboardType:
                        TextInputType.number, // Fuerza teclado numérico
                    decoration: const InputDecoration(labelText: 'Año'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _cilindradaController,
                    decoration: const InputDecoration(labelText: 'Cilindrada'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _motorController,
              decoration: const InputDecoration(labelText: 'Nro. de Motor'),
            ),
            const SizedBox(height: 16),

            // 3. SELECTORES OBLIGATORIOS
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Tracción'),
              value: traccionSeleccionada,
              items: ['4x2', '4x4', 'AWD'].map((String valor) {
                return DropdownMenuItem<String>(
                  value: valor,
                  child: Text(valor),
                );
              }).toList(),
              onChanged: (nuevoValor) =>
                  setState(() => traccionSeleccionada = nuevoValor),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Transmisión'),
              value: transmisionSeleccionada,
              items: ['Mecánica', 'Automática'].map((String valor) {
                return DropdownMenuItem<String>(
                  value: valor,
                  child: Text(valor),
                );
              }).toList(),
              onChanged: (nuevoValor) =>
                  setState(() => transmisionSeleccionada = nuevoValor),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Combustible'),
              value: combustibleSeleccionado,
              items: ['Gasolina', 'Diésel', 'Eléctrico', 'Híbrido'].map((
                String valor,
              ) {
                return DropdownMenuItem<String>(
                  value: valor,
                  child: Text(valor),
                );
              }).toList(),
              onChanged: (nuevoValor) =>
                  setState(() => combustibleSeleccionado = nuevoValor),
            ),

            const SizedBox(height: 32),
            Text(
              'Poka-Yoke: Validación Física',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // 4. ZONA DE CÁMARA PARA OCR
            InkWell(
              onTap: () async {
                final XFile? foto = await _picker.pickImage(
                  source: ImageSource.camera,
                );
                if (foto != null) {
                  setState(() {
                    _fotoPuerta = foto;
                  });
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  // Borde azul estándar si hay foto, sin verde validado
                  border: Border.all(
                    color: AppPalette.primary,
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  // Fondo sutil azul si ya se tomó la foto
                  color: _fotoPuerta != null
                      ? AppPalette.primary.withOpacity(0.1)
                      : Colors.transparent,
                ),
                child: Column(
                  children: [
                    Icon(
                      _fotoPuerta != null
                          ? Icons.photo_camera_front
                          : Icons.camera_alt,
                      size: 48,
                      color: AppPalette.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _fotoPuerta != null
                          ? '📸 Foto Adjunta (Pendiente de envío)'
                          : 'Tomar foto a la puerta',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppPalette.textPrimary,
                        fontWeight: _fotoPuerta != null
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _fotoPuerta != null
                          ? 'Presiona "Guardar Ingreso" para validar con IA'
                          : 'El OCR validará el código Posca',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppPalette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // 5. EL BOTÓN GUARDAR (LÓGICA CONECTADA)
            GradientButton(
              onPressed: _isUploading
                  ? () {} // Deshabilita el clic si la IA está analizando
                  : () async {
                      if (_patenteController.text.trim().isEmpty ||
                          _marcaController.text.trim().isEmpty ||
                          _fotoPuerta == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Bloqueo: Faltan datos o la foto de validación.',
                            ),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }

                      // Encendemos el círculo de carga y bloqueamos la pantalla
                      setState(() {
                        _isUploading = true;
                      });

                      final datosNuevos = {
                        "correlativo_ingreso": numeroIngreso,
                        "patente": _patenteController.text,
                        "marca": _marcaController.text,
                        "modelo": _modeloController.text,
                        "anio": int.tryParse(_anoController.text) ?? 2000,
                        "cilindrada": _cilindradaController.text,
                        "numero_motor": _motorController.text,
                        "traccion": traccionSeleccionada ?? "",
                        "transmision": transmisionSeleccionada ?? "",
                        "combustible": combustibleSeleccionado ?? "",
                        "estado": "EN_PATIO",
                      };

                      try {
                        bool exito = await _vehiculoService.guardarIngreso(
                          datosNuevos,
                          _fotoPuerta!,
                        );

                        if (exito && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                '✅ Poka-Yoke Superado: ¡Vehículo ingresado con éxito!',
                              ),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 4),
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
                            _fotoPuerta = null;
                          });

                          _cargarFolioDesdeBackend();
                        } else if (context.mounted) {
                          // Si es false, significa que el backend/IA lo rechazó (HTTP 400)
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                '❌ Error Poka-Yoke: La IA rechazó la foto o no coincide el folio.',
                              ),
                              backgroundColor: Colors.red,
                              duration: Duration(seconds: 6),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                '❌ Error de conexión con el servidor.',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        // Apagamos el círculo de carga, pase lo que pase
                        if (context.mounted) {
                          setState(() {
                            _isUploading = false;
                          });
                        }
                      }
                    },
              gradient: const LinearGradient(
                colors: [AppPalette.primary, AppPalette.secondary],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              child: _isUploading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : const Text(
                      'GUARDAR INGRESO',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
