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
            TextField(
              controller: _patenteController,
              decoration: const InputDecoration(
                labelText: 'Patente',
                hintText: 'Ej: XXYY11',
                prefixIcon: Icon(Icons.directions_car),
                suffixIcon: Icon(Icons.search),
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
                // Abre la cámara (o el explorador de archivos si estás en Web/PC sin cámara)
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
                  // Si ya hay foto, cambiamos el borde a verde para dar feedback
                  border: Border.all(
                    color: _fotoPuerta != null
                        ? Colors.green
                        : AppPalette.primary,
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  // Fondo sutilmente verde si ya se tomó la foto
                  color: _fotoPuerta != null
                      ? Colors.green.withOpacity(0.1)
                      : Colors.transparent,
                ),
                child: Column(
                  children: [
                    Icon(
                      _fotoPuerta != null
                          ? Icons.check_circle
                          : Icons.camera_alt,
                      size: 48,
                      color: _fotoPuerta != null
                          ? Colors.green
                          : AppPalette.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _fotoPuerta != null
                          ? '¡Foto capturada exitosamente!'
                          : 'Tomar foto a la puerta',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: _fotoPuerta != null
                            ? Colors.green
                            : AppPalette.textPrimary,
                        fontWeight: _fotoPuerta != null
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _fotoPuerta != null
                          ? 'Archivo listo para análisis OCR'
                          : 'El OCR validará el código Posca',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _fotoPuerta != null
                            ? Colors.green
                            : AppPalette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // 5. EL BOTÓN GUARDAR (LÓGICA CONECTADA)
            GradientButton(
              onPressed: () async {
                // --- NUEVO: 1. VALIDACIÓN POKA-YOKE Y DATOS OBLIGATORIOS ---
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
                  return; // 🛑 El "return" corta la función aquí. No avanza al backend.
                }
                // --- FIN DE LA VALIDACIÓN ---

                // 2. Armamos el JSON con los datos tipeados
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

                // 3. Feedback visual de carga
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Guardando ingreso en BD...')),
                );

                // 4. Disparamos la petición HTTP al backend (Ahora con la foto incluida)
                bool exito = await _vehiculoService.guardarIngreso(
                  datosNuevos,
                  _fotoPuerta!,
                );

                // 5. Manejamos la respuesta
                if (exito) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('¡Vehículo ingresado con éxito!'),
                        backgroundColor: Colors.green,
                      ),
                    );

                    // Limpiamos todo el formulario para el siguiente vehículo
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
                      _fotoPuerta = null; // Limpiamos la foto capturada
                    });

                    // Pedimos el siguiente folio automáticamente
                    _cargarFolioDesdeBackend();
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Error al guardar el vehículo.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              gradient: const LinearGradient(
                colors: [AppPalette.primary, AppPalette.secondary],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              child: const Text(
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
