# SPEC-HU-TAREA-16: Filtros de Estado y Visualización de Galpón/Ubicación en Inventario y Alertas

## 1. Contexto y Archivos Afectados
- **Objetivo**: Mejorar drásticamente los tiempos de desplazamiento físico del bodeguero exponiendo explícitamente el "Galpón" en todas las tarjetas de inventario y alertas, además de agregar capacidades de filtrado rápido por estados operativos (Disponibles, Reservados, Vendidos, Paletizados).
- **Archivos a modificar**:
  - Backend: `backend/routers/inventario.py` (Habilitar parámetros de filtrado por estados de `Activo_Inventariado`).
  - Frontend: `lib/features/inventario/presentation/screens/inventario_screen.dart` (Incorporar barra de chips o tabs de filtro superior).
  - Frontend: `lib/features/inventario/presentation/widgets/resultado_card.dart` (Inyectar visualización destacada de `ubicacion_galpon`).
  - Frontend: Componentes de Alertas (`alerta_preentrega_tab.dart`, etc.) para asegurar que el dato de Galpón sea obligatorio y preeminente.

## 2. Contratos de Datos y Firmas de API
- **Modelos Backend**: Asegurar que `ubicacion_galpon`, `ubicacion_pasillo`, `ubicacion_pallet` y `estado` viajen siempre en los DTOs de `GET /api/v1/inventario/buscar`.
- **Endpoints**: `GET /api/v1/inventario/buscar?estado=Disponibles` (y el mapeo SQL al `id_estado` real respectivo).
- **Modelos Frontend**: Mapeo directo del campo galpón en el UI.

## 3. Reglas de Negocio, Casos de Borde y Seguridad (Matriz de Errores)
- **Estados Operativos Clave**:
  - `Disponibles` -> id_estado = 1.
  - `Reservados` -> id_estado = 2.
  - `Vendidos` -> Piezas facturadas.
  - `Paletizados` -> En espera de tasación.
- **Destacado de Ubicación Fija**: El galpón debe ir en negrita o etiqueta colorida para indicar la 'nave' hacia la cual debe caminar el operario.

**Mensajería Intuitiva Exigida y Control de Excepciones**:
1. **Frontend: Activo Huérfano de Ubicación**:
   - *Causa*: En migraciones o piezas mal ingresadas, los campos de ubicación son nulos.
   - *Mensaje UI (Aviso preventivo en la tarjeta)*: `"Sin Galpón / Sin Ubicación asignada"`. (Instiga a editar el activo).
2. **Frontend: Cambio Rápido de Filtros sin Conexión**:
   - *Mensaje UI*: `"No hay conexión para aplicar este filtro. Mostrando caché temporal."`

## 4. Checklist de Tareas de Implementación (TDD)
- [ ] **Tarea 1 (Backend - Queries)**: Ajustar la función de búsqueda del inventario para recibir y operar la cláusula `WHERE` según los 4 estados principales filtrados.
- [ ] **Tarea 2 (Frontend - Filtros UI)**: Agregar una fila de *Filter Chips* horizontales deslizables en la cabecera de `inventario_screen.dart`.
- [ ] **Tarea 3 (Frontend - Enriquecimiento Visual de Galpón)**: Refactorizar las tarjetas de inventario y tareas de alertas para mostrar el "Galpón" en un chip o recuadro visual prominente, y "Pasillo X - Pallet Y" como subtítulo.
- [ ] **Tarea 4 (Frontend - Fallback Ubicación Nula)**: Programar el mensaje preventivo en caso de que `ubicacion_galpon` venga vacío o nulo.
- [ ] **Tarea 5 (Frontend - Reactividad de Lista)**: Asegurar que al tocar un Chip de estado, la lista se borre, muestre *Spinner*, y renderice los nuevos resultados. (Uso imperativo de `!mounted`).
- [ ] **Tarea 6 (Frontend - Pruebas Widget)**: Comprobar el toggle de los chips de filtro y su impacto en la petición de carga.
- [ ] **Tarea 7 (Documentación)**: Registrar en `DICCIONARIO_ERRORES.md` el comportamiento de activos sin ubicación.

## 5. Criterios de Validación Automatizada
- Backend Tests: Ejecutar `pytest tests/test_inventario_filtros.py -v`.
- Frontend Tests: Ejecutar `flutter test test/features/inventario/filtros_estado_test.dart`.
- Frontend Linter: Ejecutar `flutter analyze lib/features/inventario/ lib/features/alertas/`.
