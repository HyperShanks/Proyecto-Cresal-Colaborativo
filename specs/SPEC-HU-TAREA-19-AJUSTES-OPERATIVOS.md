# SPEC-HU-TAREA-19: Ajustes Operativos y Refinamiento de Flujos (Backorders, Barreras y Bodega)

## 1. Contexto y Archivos Afectados
- **Objetivo**: Implementar correcciones operativas solicitadas por el negocio para agilizar el mesón de ventas y proteger el flujo de bodega. Incluye renombramientos, eliminación de bypasses en entregas, corrección de concurrencia en la liberación de stock por anulación, y retención de tareas de preparación en bodega post-pago.
- **Archivos a modificar**:
  - **Frontend (Renombramiento)**: `lib/features/caja/presentation/widgets/bandeja_cobros_panel.dart`, `checkout_wizard_screen.dart`, y cualquier otra UI (Mesón/Gerencia) que diga "Reservas Backorder" debe decir "Ventas en Verde".
  - **Frontend (Entregas)**: `lib/features/ventas/presentation/screens/entregas_envios_screen.dart` (Para eliminar el botón `Confirmar Entrega`).
  - **Frontend (Bodega Tareas)**: `lib/features/alertas/presentation/widgets/task_card.dart` (Para no ocultar el botón "LISTO" cuando la tarea pasa a estado `LIBERADA`).
  - **Backend (Logística Inversa)**: `backend/routers/bodega.py` (Endpoint `confirmar_reingreso`).

## 2. Contratos de Datos y Firmas de API
- **Modelos**: No hay cambios en la firma de las peticiones ni en las respuestas JSON.
- **Base de Datos**: Ninguna tabla es modificada estructuralmente, pero se altera el flujo de mutación de `Activo_Inventariado.id_estado` durante la logística inversa.

## 3. Reglas de Negocio, Casos de Borde y Seguridad (Matriz de Resolución)

1. **Renombramiento Comercial (Ventas en Verde)**:
   - *Regla*: El término técnico "Backorder" o "Reservas Backorder" causa fricción comercial. Debe ser reemplazado visualmente en todos los *labels*, *tabs*, y *botones* por **"Ventas en Verde"**. (Nota: A nivel de código interno/variables puede mantenerse `backorder` para no quebrar lógica subyacente).

2. **Eliminación del Bypass en Entregas y Envíos**:
   - *Problema*: Cuando una orden se paga, aparece en la vista de Entregas/Envíos con un botón de "Confirmar Entrega", el cual marca la orden como completada saltándose el flujo obligatorio de "Barrera de Salida" (PDA del bodeguero).
   - *Solución*: Eliminar ese botón y su modal de confirmación en la UI. La tarjeta solo debe ser informativa y el cambio a "Entregado" debe ocurrir obligatoria y exclusivamente por el escaneo de la pistola/PDA en la Barrera de Salida de bodega.

3. **Inmediatez de Disponibilidad al Anular y Bodega Notificada**:
   - *Problema*: Al anular una orden, el vendedor libera los repuestos, pero el bodeguero, al pulsar "Confirmar Reingreso" en su PDA, sobrescribía el estado a `Disponible`. El botón en bodega no debe ser responsable de cambiar el estado comercial.
   - *Solución*: En el endpoint `confirmar_reingreso` de `bodega.py`, **se debe eliminar** la mutación `activo.id_estado = 1` y el incremento de su `version_lock`. La responsabilidad del endpoint se limita estricta y únicamente a cambiar `estado_preparacion = 'Reingresado'` y actualizar los campos físicos de `ubicacion_pasillo`/`pallet`. El activo comercialmente *ya es Disponible* gracias al backend de ventas que lo liberó al momento de la anulación.

4. **Supervivencia de la Tarea de Pre-Entrega Post-Pago**:
   - *Problema*: Cuando un vendedor envía una pieza a pre-entrega (con notas de preparación para el bodeguero) y el cliente paga inmediatamente en caja, el activo reduce su `monto_pendiente` a 0 y la tarea en la PDA cambia a tipo `LIBERADA`. El componente visual `task_card.dart` estaba ocultando el botón "LISTO" para forzar el botón "BARRERA", impidiendo que el bodeguero termine de leer y marcar su trabajo de preparación física.
   - *Solución*: En `task_card.dart`, si la alerta es `LIBERADA`, **no se debe ocultar el botón "LISTO"**. El operario de bodega DEBE poder marcar como "LISTO" la preparación (lo que elimina la tarea de la lista de Alertas) independientemente de que el cliente ya haya pagado.

## 4. Checklist de Tareas de Implementación (TDD)
- [ ] **Tarea 1 (Refactor Textos)**: Buscar globalmente la frase "Reservas Backorder" y "Backorder" en la UI de Flutter y reemplazar por "Ventas en Verde".
- [ ] **Tarea 2 (Remover Bypass)**: Borrar el `ElevatedButton` ("Confirmar Entrega") y sus callbacks asociados en la vista `entregas_envios_screen.dart` del vendedor.
- [ ] **Tarea 3 (Backend Reingreso)**: Editar `confirmar_reingreso` en `routers/bodega.py` para extirpar la lógica de alteración de `id_estado` de la tabla `Activo_Inventariado`.
- [ ] **Tarea 4 (Bodega Tareas)**: Editar `task_card.dart` para que el renderizado condicional de los botones incluya "LISTO" incluso cuando `tarea.tipoAlerta == 'LIBERADA'`.
- [ ] **Tarea 5 (Testing)**: Probar el flujo completo creando una orden con notas, pagándola en caja, verificando que la PDA de bodega aún permita tocar el botón "LISTO" de la pre-entrega.

## 5. Criterios de Validación Automatizada
- Backend Tests: El unit test de anulación debe comprobar que el stock vuelve a estado 1 (Disponible) instantáneamente sin requerir el paso de bodega.
- Frontend Linter: Ejecutar `flutter analyze` tras los refactors visuales.
