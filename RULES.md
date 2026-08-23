# REGLAS ARQUITECTÓNICAS Y DE SEGURIDAD INQUEBRANTABLES (RULES.md)
**Proyecto:** Cresal-SaaS (Backend FastAPI + Frontend Flutter + PostgreSQL/Supabase)
**Audiencia:** Agentes de Desarrollo Autónomo (Antigravity IDE / CLI)

Cualquier código generado en este repositorio DEBE cumplir de forma irrestricta con las siguientes directrices. Si una solución entra en conflicto con estas reglas, la regla tiene prioridad absoluta.

---

## 1. SEGURIDAD ZERO TRUST Y CONTROL DE ACCESO (OWASP TOP 10)

* **Secretos y Variables de Entorno:**
  * Queda estrictamente PROHIBIDO escribir credenciales, API keys, URLs de conexión o secretos criptográficos quemados (*hardcoded*) en el código fuente.
  * Todo secreto debe residir en `.env` y consumirse vía `backend/core/config.py` tipado con Pydantic Settings (`ConfigDict(env_file=".env")`).
* **Autenticación y RBAC Obligatorio:**
  * Ningún endpoint de mutación o lectura de datos de negocio puede ser público.
  * Todo endpoint debe inyectar la dependencia `current_user: Usuario = Depends(get_current_user)` o middlewares de verificación de rol (`Depends(require_role([id_rol]))`).
  * El endpoint `POST /api/auth/register` solo puede ser ejecutado por usuarios con rol Administrador (`id_rol == 5`).
* **Inyección SQL y ORM:**
  * Prohibido el uso de concatenación de strings o sentencias SQL sin sanitizar. Todas las consultas deben realizarse a través del ORM SQLAlchemy parametrizado.

---

## 2. PERSISTENCIA, TRANSACCIONALIDAD ACID Y CONCURRENCIA

* **Atomicidad Obligatoria (`try / except rollback`):**
  * Toda función que realice más de una mutación en base de datos (`add`, `delete`, `update`) o que cambie estados de inventario/órdenes debe estar envuelta en un bloque:
    ```python
    try:
        # Operaciones de base de datos...
        db.commit()
        db.refresh(instancia)
    except HTTPException:
        db.rollback()
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error transaccional: {str(e)}")
    ```
* **Control de Concurrencia Optimista (`version_lock`):**
  * Toda mutación sobre la tabla `Activo_Inventariado` (reserva, venta, cambio de precio o salida) debe validar e incrementar `activo.version_lock = (activo.version_lock or 1) + 1` para prevenir condiciones de carrera.

---

## 3. GESTIÓN ESTRICTA DE FECHAS Y ZONAS HORARIAS

* **Almacenamiento en Base de Datos:**
  * Todas las marcas de tiempo (`fecha_creacion`, `fecha_actualizacion`, `fecha_pago`) deben persistirse en **UTC sin tzinfo**:
    ```python
    from datetime import datetime, timezone
    datetime.now(timezone.utc).replace(tzinfo=None)
    ```
* **Filtrado por Día Calendario Local (Chile):**
  * Las consultas del día (ej. ventas de hoy o arqueos) deben calcular el inicio y fin del día en `America/Santiago` y convertirse a UTC antes de filtrar:
    ```python
    from zoneinfo import ZoneInfo
    tz_chile = ZoneInfo("America/Santiago")
    ahora_chile = datetime.now(tz_chile)
    inicio_utc = datetime.combine(ahora_chile.date(), datetime.time.min, tzinfo=tz_chile).astimezone(timezone.utc).replace(tzinfo=None)
    fin_utc = datetime.combine(ahora_chile.date(), datetime.time.max, tzinfo=tz_chile).astimezone(timezone.utc).replace(tzinfo=None)
    ```

---

## 4. ESTÁNDARES FRONTEND (FLUTTER 3.3X MULTIPLATAFORMA)

* **Adaptabilidad por Dispositivo y Rol:**
  * **Bodega / Recepción (PDA / Móvil):** Layout vertical compacto, áreas táctiles >= 48px, integración con escaneo y servicios ZPL.
  * **Mesón / Ventas (Tablet):** Vista adaptable, catálogo en grid/cards, interacción táctil fluida.
  * **Caja / Auditoría (Desktop / PC):** Sidebar fija, DataGrids, atajos de teclado físico (Numpad, Tab, Enter) y resolución mínima de 1366x768.
* **Ciclo de Vida y Asincronía (`BuildContext`):**
  * Toda operación asíncrona (`await`) en un `StatefulWidget` que utilice `BuildContext` debe incluir un guardián de montaje previo: `if (!mounted) return;`.
* **Gestión de Recursos y Memoria:**
  * Todo controlador (`TextEditingController`, `ScrollController`, `AnimationController`, `FocusNode`) y `Timer` debe ser liberado explícitamente en el método `dispose()`.
* **Deprecaciones de Framework:**
  * Prohibido `.withOpacity(x)` (usar `.withValues(alpha: x)`).
  * Prohibido `activeColor` (usar `activeThumbColor`).

## 5. PROTOCOLO TDD Y CRITERIOS DE PARADA DEL AGENTE

El agente NO dará por terminada ninguna tarea hasta que los siguientes comandos se ejecuten con éxito en la terminal:

1. **Backend Tests:** `pytest -v` -> 100% pruebas pasando, 0 fallos.
2. **Backend Linting:** `flake8 . --count --select=E9,F63,F7,F82` -> 0 errores fatales.
3. **Frontend Tests:** `flutter test` -> 100% pruebas pasando, 0 fallos.
4. **Frontend Analyzer:** `flutter analyze` -> 0 errores y 0 warnings.