import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../services/ticket_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CREAR TICKET SCREEN (HU-2.7)
// Formulario industrial para PDA Sunmi L3.
// Touch targets ≥ 48dp · Alto contraste Dark Mode · Sin colores hardcoded.
// ─────────────────────────────────────────────────────────────────────────────
class CrearTicketScreen extends StatefulWidget {
  const CrearTicketScreen({super.key});

  @override
  State<CrearTicketScreen> createState() => _CrearTicketScreenState();
}

class _CrearTicketScreenState extends State<CrearTicketScreen> {
  // ── Opciones de los selectores ─────────────────────────────────────────────
  static const List<String> _tiposTicket = [
    'Bug',
    'Consulta',
    'Incidencia',
    'Solicitud',
    'Acceso',
  ];

  static const List<String> _prioridades = ['Baja', 'Media', 'Alta', 'Urgente'];

  // ── Estado del formulario ──────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _asuntoController = TextEditingController();
  final _descripcionController = TextEditingController();

  String _tipoSeleccionado = _tiposTicket.first;
  String _prioridadSeleccionada = 'Media';
  bool _isLoading = false;

  @override
  void dispose() {
    _asuntoController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  // ── Color semántico de prioridad ───────────────────────────────────────────
  Color _prioridadColor(String p) {
    switch (p.toLowerCase()) {
      case 'urgente':
        return AppPalette.error;
      case 'alta':
        return const Color(0xFFFF7043);
      case 'media':
        return AppPalette.secondary;
      case 'baja':
        return AppPalette.success;
      default:
        return AppPalette.neutral;
    }
  }

  // ── Envío del formulario ───────────────────────────────────────────────────
  Future<void> _enviarTicket() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await TicketService.crearTicket(
      tipoTicket: _tipoSeleccionado,
      prioridad: _prioridadSeleccionada,
      asunto: _asuntoController.text.trim(),
      descripcion: _descripcionController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      // Limpiar formulario tras éxito
      _asuntoController.clear();
      _descripcionController.clear();
      setState(() {
        _tipoSeleccionado = _tiposTicket.first;
        _prioridadSeleccionada = 'Media';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: AppPalette.textPrimary),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Ticket enviado correctamente',
                  style: AppTypography.body,
                ),
              ),
            ],
          ),
          backgroundColor: AppPalette.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppPalette.textPrimary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result.errorMessage ?? 'Error al enviar el ticket',
                  style: AppTypography.body,
                ),
              ),
            ],
          ),
          backgroundColor: AppPalette.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Encabezado ────────────────────────────────────────────────
            Text(
              'Nuevo Ticket de Soporte',
              style: AppTypography.title,
            ),
            const SizedBox(height: 4),
            const Text(
              'Complete los datos del incidente o consulta.',
              style: AppTypography.small,
            ),
            const SizedBox(height: 24),

            // ── Tipo de Ticket (Dropdown) ──────────────────────────────────
            _SectionLabel(label: 'TIPO DE TICKET'),
            const SizedBox(height: 8),
            _buildDropdown(),
            const SizedBox(height: 20),

            // ── Prioridad (Botones seleccionables) ────────────────────────
            _SectionLabel(label: 'PRIORIDAD'),
            const SizedBox(height: 8),
            _buildPrioridadSelector(),
            const SizedBox(height: 20),

            // ── Asunto ─────────────────────────────────────────────────────
            _SectionLabel(label: 'ASUNTO'),
            const SizedBox(height: 8),
            _buildAsuntoField(),
            const SizedBox(height: 20),

            // ── Descripción ────────────────────────────────────────────────
            _SectionLabel(label: 'DESCRIPCIÓN DETALLADA'),
            const SizedBox(height: 8),
            _buildDescripcionField(),
            const SizedBox(height: 32),

            // ── Botón Enviar ───────────────────────────────────────────────
            _buildEnviarButton(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Dropdown de tipo ───────────────────────────────────────────────────────
  Widget _buildDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _tipoSeleccionado,
          dropdownColor: AppPalette.surface,
          style: AppTypography.body,
          iconEnabledColor: AppPalette.primary,
          items: _tiposTicket
              .map(
                (tipo) => DropdownMenuItem(
                  value: tipo,
                  child: Text(tipo, style: AppTypography.body),
                ),
              )
              .toList(),
          onChanged: (val) => setState(() => _tipoSeleccionado = val!),
        ),
      ),
    );
  }

  // ── Selector de prioridad (chips táctiles ≥ 48dp) ─────────────────────────
  Widget _buildPrioridadSelector() {
    return Row(
      children: _prioridades.map((p) {
        final isSelected = p == _prioridadSeleccionada;
        final color = _prioridadColor(p);
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _prioridadSeleccionada = p),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 48, // W3C: touch target mínimo
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.20)
                    : AppPalette.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? color : AppPalette.neutral.withValues(alpha: 0.3),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    p,
                    style: AppTypography.small.copyWith(
                      color: isSelected ? color : AppPalette.textSecondary,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Campo Asunto ───────────────────────────────────────────────────────────
  Widget _buildAsuntoField() {
    return TextFormField(
      controller: _asuntoController,
      style: AppTypography.body,
      maxLength: 150,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        hintText: 'Ej: No puedo registrar un vehículo',
        hintStyle: AppTypography.small,
        counterStyle: AppTypography.small,
        prefixIcon: const Icon(Icons.title_outlined, color: AppPalette.primary),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) {
          return 'El asunto no puede estar vacío';
        }
        if (v.trim().length < 5) {
          return 'El asunto debe tener al menos 5 caracteres';
        }
        return null;
      },
    );
  }

  // ── Campo Descripción (multilínea) ─────────────────────────────────────────
  Widget _buildDescripcionField() {
    return TextFormField(
      controller: _descripcionController,
      style: AppTypography.body,
      maxLength: 1000,
      maxLines: 5,
      minLines: 4,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        hintText:
            'Describe el problema con el mayor detalle posible: pasos para reproducirlo, '
            'mensaje de error visible, acción que estabas realizando...',
        hintStyle: AppTypography.small,
        counterStyle: AppTypography.small,
        alignLabelWithHint: true,
        prefixIcon: const Padding(
          padding: EdgeInsets.only(bottom: 60),
          child: Icon(Icons.description_outlined, color: AppPalette.primary),
        ),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) {
          return 'La descripción no puede estar vacía';
        }
        if (v.trim().length < 10) {
          return 'La descripción debe tener al menos 10 caracteres';
        }
        return null;
      },
    );
  }

  // ── Botón Enviar ───────────────────────────────────────────────────────────
  Widget _buildEnviarButton() {
    if (_isLoading) {
      return const SizedBox(
        height: 52,
        child: Center(
          child: CircularProgressIndicator(
            color: AppPalette.primary,
            strokeWidth: 3,
          ),
        ),
      );
    }

    return GradientButton(
      height: 52,
      onPressed: _enviarTicket,
      gradient: const LinearGradient(
        colors: [AppPalette.primary, Color(0xFF1A6E8E)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.send_outlined, size: 20, color: AppPalette.textPrimary),
          SizedBox(width: 10),
          Text('ENVIAR TICKET', style: AppTypography.button),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER — Etiqueta de sección del formulario
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTypography.small.copyWith(
        color: AppPalette.textSecondary,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    );
  }
}
