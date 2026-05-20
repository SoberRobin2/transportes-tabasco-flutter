# Documentación del Proyecto: Transportes Colectivos de Tabasco

Este documento sirve como un registro vivo de la arquitectura, estado y bugs de la aplicación. **Debe ser proporcionado a la IA como contexto en futuras sesiones de desarrollo.**

## 📌 Información General
- **Objetivo:** Aplicación para visualizar, buscar y trazar rutas del transporte público (combis) en la ciudad de Villahermosa, Tabasco.
- **Tecnología:** Flutter (Dart)
- **Arquitectura actual:** Layer-first (`screens`, `models`, `services`). (Aún sin Backend conectado, usando Mock Data).

## 🚀 Features Implementadas (Estado Actual)
1. **Mapa Base (OpenStreetMap):** Implementado con `flutter_map`.
2. **Geolocalización en Tiempo Real:** Implementado con `geolocator`. 
   - Animación de "Pulso de Radar" azul para la ubicación del usuario.
   - Botón dinámico que centra y hace zoom (`17.0`) a la ubicación.
3. **API de Calles (Routing):** Las rutas de prueba (líneas rectas) se transforman automáticamente al trazado de las calles reales consumiendo la API de **OSRM (Open Source Routing Machine)**.
   - **Caché Integrado:** Uso de `cached_network_image` para guardar mapas en disco y ahorrar datos móviles.
4. **Selector de Capas:** Toggle integrado para alternar entre mapa estándar (OSM) y Vista Satelital (Esri World Imagery).
4. **UI Moderna (Material 3 / Bottom Sheet):**
   - Menú de circuitos deslizable usando `CustomScrollView` y `Slivers` (Para mantener el buscador "Sticky" anclado arriba al hacer scroll).
5. **Búsqueda Integrada:**
   - Pestaña de `SearchScreen` que auto-despliega el teclado, permite buscar lugares clave en Villahermosa, y al regresar centra la cámara de forma automática poniendo un Pin Rojo.
6. **Animaciones Premium:**
   - Etiquetas flotantes que se deslizan (`AnimatedSwitcher`).
   - Transiciones de color y tamaño en tarjetas.
   - Controles elásticos (`Curves.elasticOut`).

## ⚠️ Registro de Errores y Soluciones (Troubleshooting)
Si la app vuelve a presentar estos problemas, aquí está la solución histórica:

- **Error:** `NDK did not have a source.properties file` / `Gradle Task Timeout`
  - *Causa:* Descarga corrupta del NDK al primer arranque por lentitud de red.
  - *Solución:* Borrar carpeta en `AppData\Local\Android\sdk\ndk` y volver a correr `flutter run`.
- **Error (Pantalla Roja):** Falla en `withOpacity(1.0 - _pulseController.value)`.
  - *Causa:* Desbordamiento matemático de decimales menores a 0.
  - *Solución:* Se agregó `.clamp(0.0, 1.0)` para obligar a que el valor se mantenga en el rango permitido.
- **Error (App Congelada / Freeze):** Al regresar de `SearchScreen` al `MapScreen`.
  - *Causa:* El ocultamiento del teclado de Android redimensionaba la pantalla exactamente en el mismo milisegundo en que `DraggableScrollableSheet` intentaba animarse, causando un colapso en el renderizado (Layout Constraints).
  - *Solución:* Se implementó `FocusScope.of(context).unfocus()` al salir y un `Future.delayed` de 350ms antes de mover la cámara y animar el BottomSheet.

## 🎯 Próximos Pasos Sugeridos (To-Do)
- [x] **Algoritmo de Sugerencia:** Dibujar una "Línea de Ruta" que una el GPS del usuario (`_currentLocation`) con el destino buscado (`_destinationPlace`).
- [x] **Selector de Capas:** Agregar un botón flotante extra para alternar entre Mapa Base y Vista Satelital.
- [x] **Clustering:** Agrupar los iconitos de paradas para no saturar el mapa visualmente al alejar la vista.