# Arquitectura de Enrutamiento y Tematización por Roles (SSOT)
**Proyecto:** Cresal-SaaS (Frontend Flutter + Backend FastAPI)  
**Estándar:** Single Source of Truth (SSOT) & Role-Based Access Control (RBAC)  
**Audiencia:** Desarrolladores, Arquitectos de Software y Mantenedores del Sistema  

---

## 1. Contexto y Propósito

Este documento describe la arquitectura unificada para la resolución de rutas de inicio (*landing pages*), control de acceso seguro (RBAC) y **asignación reactiva del tema visual (Dark/Light)** según el rol del usuario en la aplicación cliente de Cresal-SaaS.

El objetivo de este diseño es:
1. **Evitar la dispersión de lógica:** Que no existan múltiples árboles de decisión condicionales (`if-else`) repartidos en distintos controladores o vistas.
2. **Garantizar la previsibilidad:** Que el inicio de sesión, el desbloqueo por PIN y la recarga de página (`F5`) siempre conduzcan al usuario al panel exacto que le corresponde con el tema visual ergonómicamente adecuado.
3. **Separación de incumbencias (Ortogonalidad):** El rol determina el tema cromático; la pantalla física determina la geometría del layout. Ninguno debe sobreescribir al otro.
4. **Facilitar la extensibilidad futura:** Permitir la incorporación de nuevos perfiles o módulos modificando un único punto centralizado.

---

## 2. El Problema Anterior (Deuda Técnica y Hardcoding)

En las etapas tempranas de desarrollo, la redirección posterior al inicio de sesión y la tematización se construyeron de manera fragmentada:

* **Controlador de Login (`login_controller.dart`)** evaluaba si el usuario era de Caja (`/caja`) o de Ventas (`/ventas_main`), y cualquier otro rol caía en un bloque `else` que navegaba a `/home` (Terminal de Bodega).
* **Pantalla de Carga (`splash_screen.dart`)** duplicaba exactamente el mismo bloque `if-else` al restaurar la sesión desde el token guardado.
* **Pantalla de Inicio (`home_screen.dart`)** tenía una guarda interna que solo expulsaba a usuarios de Caja y Ventas, pero dejaba pasar a Gerentes, rotulándolos estáticamente con el texto quemado *"Operador de Bodega"*.
* **Arranque (`main.dart`)** definía un mapa de rutas local que no incluía la ruta `/gerencia`, pese a que la vista ya estaba desarrollada.
* **Módulo de Soporte (`tickets_screen.dart`)** acoplaba erróneamente el tema visual al ancho del viewport (`width >= 768 ? lightTheme : darkTheme`), forzando modo claro a los bodegueros en escritorio y modo oscuro a cajeros si achicaban la ventana.

### Consecuencia:
Cuando el **Gerente (Roberto, `id_rol = 4`)** ingresaba al sistema, caía forzosamente en la vista de Bodega, viendo tareas de paletizado y recepción en lugar de su Dashboard Ejecutivo. Asimismo, los roles de soporte sufrían cambios bruscos de paleta cromática al redimensionar ventanas.

---

## 3. El Nuevo Paradigma: Fuentes Únicas de Verdad (SSOT)

Para resolver esto de raíz y con estándar senior, se desacopló la decisión de navegación y tematización de las pantallas y se centralizó en dos componentes especializados:
- **`AppRoutes` (`frontend/lib/routes/app_routes.dart`)**: Fuente única de verdad para navegación y guardas RBAC.
- **`ThemeController` (`frontend/lib/core/theme/theme_controller.dart`)**: Fuente única de verdad para la tematización de la aplicación según el rol.

```
                      [Inicio de Sesión / Recarga Web / Splash]
                                      │
                                      ▼
                      AuthService.getIdRol() (Ej: 4)
                                      │
                    ┌─────────────────┴─────────────────┐
                    ▼                                   ▼
    AppRoutes.getHomeRouteForRole(idRol)    ThemeController.actualizarPorRol(idRol)
                    │                                   │
                    ▼                                   ▼
          Navegación al Módulo                 Propagación Reactiva del Tema
         ('/gerencia', '/caja', etc.)             (ThemeMode.light / dark)
```

### Componentes de la Arquitectura:

1. **`AppRoutes.getHomeRouteForRole(int? idRol)`**:
   Es el **único método** en todo el frontend autorizado para responder: *"¿A qué pantalla principal pertenece este rol?"*.
2. **`AppRoutes.isRouteAllowedForRole(int? idRol, String route)`**:
   Es el **único método** que valida si un rol tiene permiso para ingresar a una sub-ruta específica (Guarda RBAC).
3. **`ThemeController.actualizarPorRol(int? idRol)`**:
   Es el **único método** que establece el `ThemeMode` reactivo global consumido por `MaterialApp`.
4. **`AppRoutes.getRoutes()`**:
   Es el registro maestro de todas las pantallas de la aplicación. `main.dart` simplemente consume `routes: AppRoutes.getRoutes()`.

---

## 4. Matriz Maestra de Roles, Destino Inicial y Tema Visual

| ID Rol | Nombre del Perfil | Destino Inicial | Tema Visual (SSOT) | Propósito y Naturaleza del Acceso |
| :---: | :--- | :---: | :---: | :--- |
| **1** | **Bodeguero** | `/home` | **Dark Mode** (`ThemeMode.dark`) | Operaciones físicas de almacén: recepción vehicular OCR, paletizado, búsqueda física y despacho en barrera digital. Alto contraste para PDA y luz solar. |
| **2** | **Vendedor (Mesón)** | `/ventas_main` | **Light Mode** (`ThemeMode.light`) | Búsqueda multicriterio en catálogo, radar de stock inter-sucursal, carrito temporal y checkout CRM en mesón iluminado. |
| **3** | **Caja** | `/caja` | **Light Mode** (`ThemeMode.light`) | Terminal desktop optimizada para teclado numérico: cobros de mesón, split-payments y emisión de QR de salida. |
| **4** | **Gerente** | `/gerencia` | **Light Mode** (`ThemeMode.light`) | **Dashboard Ejecutivo**: KPIs de facturación hoy/mes, desglose por métodos de pago, alertas operativas y auditoría general. |
| **5** | **Administrador Técnico** | `/home` | **Light Mode** (`ThemeMode.light`) | **Cuenta técnica para el equipo de desarrollo**: Aterriza en el panel base operativo con permisos globales irrestrictos para configuración y administración (`POST /api/auth/register`). |
| **6** | **Jefe de Ventas** | `/ventas_main` | **Light Mode** (`ThemeMode.light`) | Módulo de ventas con acceso adicional a la Bandeja de Tasación de Precios (`/bandeja_precios`). |
| **7** | **Vendedor Online** | `/ventas_main` | **Light Mode** (`ThemeMode.light`) | Ventas remotas con acceso directo a la coordinación de envíos a regiones (`/entregas-envios`). |

---

## 5. El Rol "Administrador" vs "Gerente" en Cresal

Es importante clarificar la distinción de negocio entre ambos roles:

* **En la estructura real de Cresal, la máxima autoridad de negocio es el Gerente (`id_rol = 4`)**.  
  El Gerente no opera grúas horquilla ni pistolas de escaneo; requiere una vista panorámica con métricas financieras consolidadas, tiempos de respuesta de sucursales y flujo de ingresos. Por esta razón, su pantalla de bienvenida obligatoria es `/gerencia`.
* **El rol Administrador (`id_rol = 5`) no es un cargo operativo de la empresa**, sino una **cuenta técnica reservada para los desarrolladores y soporte de infraestructura**.  
  Como los desarrolladores necesitamos probar la recepción, verificar el escaneo de piezas y auditar el sistema desde la raíz operativa, su aterrizaje se mantiene en `/home`, pero conservando autorización irrestricta para navegar a cualquier pantalla privada del sistema.

---

## 6. Estrategia de Tematización Reactiva por Rol (`ThemeController`)

El control del tema visual (`ThemeMode.dark` vs `ThemeMode.light`) sigue el mismo principio de **Single Source of Truth** que el enrutamiento:

```dart
// frontend/lib/core/theme/theme_controller.dart
class ThemeController {
  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.dark);

  static void actualizarPorRol(int? idRol) {
    if (idRol == 1) {
      // Bodega: PDA industrial con pantalla OLED, uso en patio y galpón
      themeMode.value = ThemeMode.dark;
    } else if (idRol != null && [2, 3, 4, 5, 6, 7].contains(idRol)) {
      // Ventas, Caja, Gerencia, Admin: Oficinas y mostradores iluminados
      themeMode.value = ThemeMode.light;
    } else {
      // Fallback seguro de desarrollo/desconexión
      themeMode.value = ThemeMode.dark;
    }
  }

  static void reset() {
    themeMode.value = ThemeMode.dark;
  }
}
```

### Ciclo de Vida del Tema en la Aplicación:
1. **Inicio de Sesión (`login_controller.dart`)**:
   Tras validar las credenciales o PIN, se invoca `ThemeController.actualizarPorRol(effectiveIdRol)` antes de navegar a la ruta destino.
2. **Restauración de Sesión / Recarga F5 (`splash_screen.dart`)**:
   Al leer el token almacenado y recuperar el `idRol`, se sincroniza de inmediato `ThemeController.actualizarPorRol(idRol)`.
3. **Cierre de Sesión (`auth_service.dart`)**:
   Al limpiar tokens y credenciales locales, se llama a `ThemeController.reset()`.
4. **Reactividad Raíz (`main.dart`)**:
   `MaterialApp` está envuelto en un `ValueListenableBuilder<ThemeMode>` suscrito a `ThemeController.themeMode`. El cambio de tema se propaga instantáneamente a todo el árbol de widgets sin reconstruir el estado de la aplicación.

### Regla Crítica para Pantallas Compartidas Multi-Rol:
Pantallas de uso transversal como `/tickets` (Soporte Técnico) o `/buscador` (Catálogo de Repuestos) son consumidas tanto por operarios de bodega como por personal administrativo y vendedores.
- **El tema visual lo dicta SIEMPRE el usuario autenticado**, consumiendo `Theme.of(context)` o `AppPalette`.
- **El layout geométrico lo dicta el viewport**: En pantallas compactas (`< 768px`) se renderiza vista por pestañas (`TabBarView`); en pantallas anchas (`>= 768px`) se renderiza panel dividido o vista master-detail.
- **Bajo ninguna circunstancia una pantalla debe forzar un tema por el ancho de la ventana.**

---

## 7. Guía Práctica: Cómo Añadir un Nuevo Rol en el Futuro

Para incorporar un nuevo perfil (por ejemplo: un rol *"Auditor Externo"* o *"Chofer de Reparto"*), se sigue un procedimiento estándar de **4 pasos**:

### Paso 1: Registrar el Rol en Base de Datos (Backend)
```sql
INSERT INTO "Rol" (id_rol, nombre_rol) VALUES (8, 'Chofer Reparto');
```

### Paso 2: Declarar la Ruta de Aterrizaje en `app_routes.dart`
```dart
static String getHomeRouteForRole(int? idRol) {
  if (idRol == 4) return gerencia;
  if (idRol == 3) return caja;
  if (idRol == 2 || idRol == 6 || idRol == 7) return ventasMain;
  if (idRol == 8) return entregasEnvios; // 👈 Nuevo rol redirigido a su panel
  return home;
}
```

### Paso 3: Asignar su Tema Visual en `theme_controller.dart`
Determinar el entorno físico de trabajo del nuevo perfil:
```dart
static void actualizarPorRol(int? idRol) {
  if (idRol == 1 || idRol == 8) {
    // Bodegueros y Choferes en exteriores / ruta: Modo Oscuro
    themeMode.value = ThemeMode.dark;
  } else if (idRol != null && [2, 3, 4, 5, 6, 7].contains(idRol)) {
    // Personal en escritorios o mostradores: Modo Claro
    themeMode.value = ThemeMode.light;
  }
}
```

### Paso 4: Configurar los Permisos RBAC en `app_routes.dart`
```dart
static const List<String> _choferRoutes = [
  entregasEnvios,
  buscador,
];

static bool isRouteAllowedForRole(int? idRol, String route) {
  if (idRol == 8) return _choferRoutes.contains(route);
  // ...
}
```

---

## 8. Anti-Patrones Prohibidos en la Arquitectura

Para mantener la robustez, elegancia y mantenibilidad del sistema, quedan estrictamente prohibidos los siguientes patrones:

1. **❌ Prohibido acoplar el Tema al Ancho de la Pantalla**:
   ```dart
   // ❌ ANTIPATRÓN GRAVE:
   final themeData = MediaQuery.sizeOf(context).width >= 768 ? AppTheme.lightTheme : AppTheme.darkTheme;
   return Theme(data: themeData, child: ...);
   ```
   *Razón:* Viola la ergonomía del usuario, destruye el SSOT de `ThemeController` y causa parpadeos visuales al cambiar el tamaño de ventana.

2. **❌ Prohibido duplicar lógica de enrutamiento por rol en pantallas**:
   ```dart
   // ❌ ANTIPATRÓN:
   if (user.idRol == 4) Navigator.pushNamed(context, '/gerencia');
   ```
   *Razón:* Descentraliza el control. Toda navegación post-autenticación debe pasar por `AppRoutes.getHomeRouteForRole(idRol)`.

3. **❌ Prohibido ignorar los tokens del tema en widgets hijos**:
   ```dart
   // ❌ ANTIPATRÓN:
   color: Colors.white, // Hardcodeado en componente que puede renderizarse en Dark Mode
   ```
   *Razón:* Crea textos invisibles o fondos rotos. Utilizar siempre `isDark ? AppPalette.surface : AppPalette.surfaceLight` o tokens semánticos de `AppPalette`.
