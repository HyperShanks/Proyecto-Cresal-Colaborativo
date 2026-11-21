# SPEC-HU-TAREA-15: Visualización de Imágenes del Repuesto en la Interfaz de Tasación

## 1. Contexto y Archivos Afectados
- **Objetivo**: Proveer a Gerencia y Jefatura de Ventas una vista visual de la pieza (fotografías tomadas en recepción) integrada directamente en el modal o pantalla de Tasación, posibilitando valuar el precio de referencia de forma exacta según el desgaste real del activo.
- **Archivos a crear**:
  - Frontend: `lib/features/ventas/presentation/widgets/galeria_activo_widget.dart` (Carrusel y visor de imágenes).
  - Frontend: `lib/features/ventas/presentation/widgets/visor_imagen_completa_dialog.dart` (Modal de ampliación y zoom).
- **Archivos a modificar**:
  - Frontend: `lib/features/ventas/presentation/screens/bandeja_precios_screen.dart` (o su modal de edición) para inyectar la galería al lado del campo de `precio_referencia`.
  - Backend: `backend/routers/inventario.py` (Garantizar que el endpoint que trae la bandeja de precios incluya el arreglo de URLs asociadas de la tabla `Multimedia_Activo`).

## 2. Contratos de Datos y Firmas de API
- **Modelos Backend**: Asegurar que el DTO `PendientePrecioDTO` incluya un array `fotografias: List[str]` extrayéndolas del modelo `Multimedia_Activo.url_storage`.
- **Endpoints**: `GET /api/v1/ventas/bandeja-precios`.
- **Modelos Frontend**: `PendientePrecioModel` debe soportar `List<String> fotografias`.

## 3. Reglas de Negocio, Casos de Borde y Seguridad (Matriz de Errores)
- **Navegación Múltiple**: Si el activo posee varias fotos, se debe mostrar "Foto X de Y" e incluir flechas/deslizador tipo carrusel.
- **Ampliación Detallada**: Al pulsar la imagen, debe expandirse a pantalla completa para examinar imperfecciones de la pieza, con un cierre fácil (cruz o tocando fuera) para no perder el monto digitado en tasación.

**Mensajería Intuitiva Exigida y Control de Excepciones**:
1. **Frontend: Empty State Visual (Sin Fotos)**:
   - *Causa*: El bodeguero omitió la fotografía o el activo es muy antiguo.
   - *Mensaje UI (En un recuadro gris central)*: `"Activo sin fotografías registradas."`
2. **Frontend: Fallo de Carga de Imagen por Red**:
   - *Causa*: Lentitud de internet o enlace al bucket AWS/Supabase roto.
   - *Mensaje UI*: Mostrar un ícono de advertencia con el texto `"Error al cargar la imagen. Presione para reintentar."` No debe bloquear el input de precio.

## 4. Checklist de Tareas de Implementación (TDD)
- [ ] **Tarea 1 (Backend - Relaciones ORM)**: Asegurar que la query de `bandeja-precios` extraiga eficientemente los `Multimedia_Activo` de cada pieza (evitando el N+1).
- [ ] **Tarea 2 (Frontend - Galería Base)**: Construir `galeria_activo_widget.dart` soportando navegación entre fotos si hay >1.
- [ ] **Tarea 3 (Frontend - Visor Expandido)**: Implementar el modal de pantalla completa `visor_imagen_completa_dialog.dart` con soporte basico de Zoom.
- [ ] **Tarea 4 (Frontend - Integración)**: Inyectar el widget de galería en el formulario de tasación actual.
- [ ] **Tarea 5 (Frontend - Empty y Error States)**: Manejar los escenarios sin imagen y fallo de descarga descritos en la matriz de errores, renderizando el UI fallback apropiado.
- [ ] **Tarea 6 (Frontend - Pruebas Widget)**: Testear la renderización del mensaje "Activo sin fotografías registradas" cuando el array llega vacío.
- [ ] **Tarea 7 (Documentación)**: Registrar en el `DICCIONARIO_ERRORES.md`.

## 5. Criterios de Validación Automatizada
- Backend Tests: Ejecutar `pytest tests/test_bandeja_precios_multimedia.py -v`.
- Frontend Tests: Ejecutar `flutter test test/features/ventas/galeria_tasacion_test.dart`.
- Frontend Linter: Ejecutar `flutter analyze lib/features/ventas/`.
