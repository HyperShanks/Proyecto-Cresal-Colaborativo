# Guía de Patrones de Layout, Responsividad y Prevención de Desbordamientos (Cresal-SaaS)

> **Propósito de esta guía:**  
> Este documento resume los principios, mentalidad arquitectónica y técnicas que utiliza la industria en Flutter para construir interfaces de usuario que se adapten de forma orgánica a múltiples dispositivos (PDA industrial, pantallas de mostrador y monitores ejecutivos).  
> **No busca imponer medidas fijas ("usar siempre 200px")**, sino entregar el abanico de herramientas disponibles y los patrones de diseño para evitar los errores más comunes de alineación, márgenes y desbordamientos (`RenderFlex overflowed`).

---

## 1. La Regla de Oro del Layout en Flutter

En Flutter rige un principio fundamental que todo desarrollador debe tener presente:

$$\text{Constraints go down } \longrightarrow \text{ Sizes go up } \longrightarrow \text{ Parent sets position}$$

1. **El padre entrega restricciones** (*constraints*): "Tienes un ancho entre $0$ y $1200\text{ px}$, y un alto infinito".
2. **El hijo decide su tamaño** (*size*): "Dentro de esas restricciones, quiero medir $350\text{ px}$ de ancho y $80\text{ px}$ de alto".
3. **El padre ubica al hijo en pantalla** (*position*): Lo alinea al centro, a la izquierda, arriba, etc.

> [!IMPORTANT]
> Los errores de diseño (desbordamientos amarillos/negros, elementos pegados a los bordes, tablas con espacios vacíos) ocurren **casi siempre** cuando un hijo intenta medir más de lo que su padre le permite, o cuando un contenedor asume un tamaño infinito sin estar envuelto adecuadamente.

---

## 2. Diferencias de Contexto por Rol y Dispositivo

En Cresal conviven perfiles con hardware y escenarios de trabajo radicalmente diferentes:

| Perfil / Rol | Dispositivo Principal | Entorno Operativo | Requerimiento de Layout |
| :--- | :--- | :--- | :--- |
| **Rol 1 (Bodeguero / Operario)** | PDA Sunmi / Zebra (~400px ancho) | Patio de desarme, luz solar, guantes, escaneo QR | Vista vertical única, botones táctiles grandes, sin scroll horizontal, alto contraste. |
| **Roles 2 y 3 (Vendedor / Caja)** | Touch POS o Laptop (1024px – 1366px) | Mesón de atención rápida | Split-screen (catálogo a la izquierda, carrito/pago a la derecha), diálogos modales ágiles. |
| **Roles 4 y 5 (Gerente / Admin)** | Monitor Desktop (1366px – 1920px+) | Oficina ejecutiva, análisis financiero | Sidebar lateral colapsable, cuadros de mando con KPIs, tablas densas y visualización de datos. |

---

## 3. Las 5 Técnicas de la Industria para Layouts Adaptativos

En lugar de calcular píxeles fijos, la industria utiliza 5 patrones complementarios:

```
                  ┌──────────────────────────────────────────────┐
                  │        ESTRATEGIAS DE LAYOUT FLUIDO          │
                  └──────┬──────────────┬──────────────┬─────────┘
                         │              │              │
             ┌───────────┴───┐   ┌──────┴──────┐  ┌────┴──────────┐
             │ 1. Flex Ratio │   │ 2. Adaptive │  │ 3. Auto Flow  │
             │ (Expanded/    │   │    Grid     │  │ (Wrap + Gap)  │
             │  Flexible)    │   │ (LayoutB.)  │  └───────────────┘
             └───────────────┘   └─────────────┘
                         │              │
             ┌───────────┴───┐   ┌──────┴──────┐
             │ 4. Elastic    │   │ 5. Safe     │
             │ Constraints   │   │ Horizontal  │
             │ (Min/Max Box) │   │ Scroll      │
             └───────────────┘   └─────────────┘
```

### Técnica 1: Proporción Flex (`Expanded` / `Flexible` con factor `flex`)
- **Cómo funciona:** En lugar de darle anchos absolutos a las columnas (`width: 150`), se les asignan pesos relativos:
  ```dart
  Row(
    children: [
      Expanded(flex: 2, child: Text('SKU')),        // 2/10 del ancho total (~20%)
      Expanded(flex: 5, child: Text('DESCRIPCIÓN')), // 5/10 del ancho total (~50%)
      Expanded(flex: 3, child: Text('PRECIO')),      // 3/10 del ancho total (~30%)
    ],
  )
  ```
- **Cuándo usarla:**
  - Tablas densas de datos (como en `Historial de Órdenes` e `Inventario`).
  - Barras divididas o paneles maestros/detalle (Split views).
- **Ventaja:** La tabla **siempre cubre el 100% exacto** de la tarjeta sin importar si el usuario usa una laptop de 13 pulgadas o un monitor de 32 pulgadas.

---

### Técnica 2: Grillas Adaptativas con `LayoutBuilder` (No con `MediaQuery`)
- **La trampa común de `MediaQuery`:**
  `MediaQuery.of(context).size.width` entrega el ancho de toda la ventana física del monitor. Si la app tiene un menú lateral (sidebar de 288px) que se puede colapsar o expandir, `MediaQuery` no sabe que el área de contenido ahora tiene más o menos espacio.
- **La solución profesional con `LayoutBuilder`:**
  `LayoutBuilder` mide **únicamente el espacio disponible real** donde se pintará el widget:
  ```dart
  LayoutBuilder(
    builder: (context, constraints) {
      final anchoDisponible = constraints.maxWidth;
      int columnas = 4;
      if (anchoDisponible < 680) {
        columnas = 1; // Móvil o split view angosto
      } else if (anchoDisponible < 1080) {
        columnas = 2; // Laptop estándar con sidebar abierto
      } else if (anchoDisponible < 1520) {
        columnas = 3; // Full HD 1080p
      } else {
        columnas = 4; // Pantallas panorámicas 2K/4K
      }

      return GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columnas,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          mainAxisExtent: 420, // Altura balanceada para evitar recortes
        ),
        itemBuilder: (context, index) => TarjetaRepuesto(...),
      );
    },
  )
  ```
- **Cuándo usarla:** Catálogos de productos, paneles de tarjetas, vitrinas de repuestos paletizados.

---

### Técnica 3: Flujo Autónomo con `Wrap`
- **Por qué falla un `Row`:**
  Un `Row` obliga a todos sus hijos a caber en una sola línea horizontal. Si colocas un Buscador, un Dropdown de Sucursal, un Selector de Fechas y un Botón en un `Row`, en pantallas medianas inevitablemente arrojará un error de desbordamiento.
- **La solución con `Wrap`:**
  ```dart
  Wrap(
    spacing: 12,    // Separación horizontal entre elementos
    runSpacing: 12, // Separación vertical si caen a la siguiente fila
    alignment: WrapAlignment.start,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      BuscadorInput(),
      SelectorEstadoDropdown(),
      BotonLimpiarFiltros(),
    ],
  )
  ```
- **Cuándo usarla:** Barras de filtros, chips de categorías, grupos de botones de acción rápida. Si el ancho de pantalla disminuye, los elementos fluyen naturalmente hacia abajo sin romper la interfaz.

---

### Técnica 4: Restricciones Elásticas (`ConstrainedBox` con rangos `minWidth` / `maxWidth`)
- **Problema:** Un campo de texto que se estira indefinidamente en una pantalla de 34 pulgadas se vuelve incómodo para el usuario; pero si se fija en `width: 300`, en una pantalla pequeña puede ser demasiado ancho.
- **Solución:** Darle libertad elástica con límites:
  ```dart
  ConstrainedBox(
    constraints: const BoxConstraints(
      minWidth: 280, // Nunca más angosto que 280px (legible)
      maxWidth: 420, // Nunca más ancho que 420px (ergonómico)
    ),
    child: BuscadorPredictivo(),
  )
  ```
- **En Menús Desplegables (`PopupMenuButton`):**
  Flutter impone un `maxWidth` de 280px a los menús flotantes por defecto. Si tus opciones tienen nombres extensos como *"Todas las Sucursales (Consolidado)"*, debes asignarle restricciones explícitas:
  ```dart
  PopupMenuButton(
    constraints: const BoxConstraints(minWidth: 320, maxWidth: 390),
    ...
  )
  ```

---

### Técnica 5: Vista Desplazable de Resguardo Horizontal
- Para tablas densas con 8 o más columnas (ej. Auditoría forense de órdenes o inventario con SKU, pieza, ubicación, estado, precio y botones):
- Si el usuario achica la ventana a menos de 980px, la tabla no debe "aplastarse" hasta volverse ilegible.
- **Patrón:**
  ```dart
  LayoutBuilder(
    builder: (context, constraints) {
      // Si la pantalla es amplia, la tabla se estira al 100%.
      // Si la pantalla es menor a 980px, activa el scroll horizontal seguro.
      final tableWidth = math.max(constraints.maxWidth, 980.0);

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: tableWidth,
          child: MiTablaProporcional(),
        ),
      );
    },
  )
  ```

---

## 4. Los 4 Errores de Diseño Más Comunes y su Vacuna

### ❌ Error A: `RIGHT OVERFLOWED BY XX PIXELS` en un `Row`
- **Causa:** El `Row` contiene un `Text` largo dentro de una columna sin acotar. Como el `Row` entrega ancho infinito a sus hijos no expandidos, el texto empuja el borde hacia afuera.
- **Vacuna:**
  ```dart
  // MAL:
  Row(children: [Icon(...), Text('Texto muy largo que desborda...')])

  // BIEN:
  Row(
    children: [
      Icon(...),
      const SizedBox(width: 8),
      Expanded( // o Flexible
        child: Text(
          'Texto muy largo que se adapta suavemente...',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  )
  ```

---

### ❌ Error B: "Elementos pegados al borde lateral" (Pérdida de bordes perimetrales)
- **Causa:** La vista hija se monta directamente en el `body` o `Expanded` sin un margen exterior (`Padding`). Los bordes de las tarjetas (`Border.all`) quedan dibujados a la coordenada $X = 0$, colisionando visualmente con la barra lateral.
- **Vacuna:**
  El armazón principal (Layout Shell) debe proveer un padding perimetral unificado:
  ```dart
  // En DashboardGerenciaView o en el contenedor de vistas:
  Expanded(
    child: Padding(
      padding: const EdgeInsets.all(24), // Margen perimetral estándar (p-6)
      child: VistaActiva(),
    ),
  )
  ```

---

### ❌ Error C: "Tablas corridas o con hueco vacío a la derecha"
- **Causa:** Usar `DataTable` nativo sin envoltorio elástico. `DataTable` calcula el ancho sumando los anchos intrínsecos de cada celda; si esa suma es 750px y la pantalla mide 1400px, la tabla se amontona a la izquierda dejando 650px vacíos a la derecha.
- **Vacuna:**
  Usar la arquitectura de **Flex Proporcional** (`Row` + `Expanded(flex: N)`) o envolver el `DataTable` en `ConstrainedBox(minWidth: constraints.maxWidth)` con columnas distribuidas.

---

### ❌ Error D: Deshabilitados Invisibles por Filtración de Modo Oscuro
- **Causa:** Al estar la raíz en modo oscuro o heredar valores por defecto, los botones deshabilitados (`onPressed: null`) pintan su texto en blanco translúcido (`onSurface` al 38%). Sobre una tarjeta blanca (`#FFFFFF`), el texto blanco sobre blanco desaparece.
- **Vacuna:**
  Asignar explícitamente `disabledForegroundColor: const Color(0xFF94A3B8)` (Slate-400) y borde `Color(0xFFE2E8F0)` en los botones con estado deshabilitado.

---

## 5. Checklist de Verificación para Desarrolladores

Antes de dar por terminada cualquier nueva vista o componente en Cresal-SaaS, realiza este chequeo mental de 6 puntos:

1. **¿El contenedor principal respira?**  
   Verifica que la vista tenga un margen perimetral adecuado respecto a los bordes de la ventana y el sidebar (ej. 24px en Desktop).
2. **¿Los textos dentro de filas horizontales (`Row`) están protegidos?**  
   Si el texto puede crecer o variar según la base de datos (nombres de repuestos, sucursales, clientes), ¿está envuelto en `Expanded` o `Flexible` con `TextOverflow.ellipsis`?
3. **¿La tabla cubre el ancho natural de la pantalla?**  
   Si estás en un monitor de 1080p, ¿la tabla aprovecha armónicamente el espacio o se ve amontonada a la izquierda?
4. **¿Los menús flotantes (`PopupMenuButton`) tienen espacio suficiente?**  
   Si el menú tiene títulos descriptivos y subtítulos, ¿cuenta con `constraints: BoxConstraints(minWidth: ..., maxWidth: ...)` para evitar la franja de overflow?
5. **¿Qué pasa si la ventana se reduce a la mitad?**  
   Redimensiona la ventana del navegador o activa el modo responsivo de DevTools: ¿Los filtros caen en cascada limpia con `Wrap` o aparece una franja roja/amarilla?
6. **¿El contraste es legible en fondos blancos?**  
   Verifica que los textos secundarios, placeholders y botones deshabilitados utilicen tonos legibles (como Slate-400 `#94A3B8` o Slate-500 `#64748B`), sin heredar opacidades de tema oscuro.
