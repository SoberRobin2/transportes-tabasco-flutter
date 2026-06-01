# Documentación del Proyecto: App de rutas de transporte en Villahermosa

## 📥 Descargar Aplicación (APK)
Puedes descargar la última versión de la aplicación lista para instalar en tu dispositivo Android desde la sección de **Releases** de este repositorio de GitHub.

Este documento sirve como un registro vivo de la arquitectura, estado y bugs de la aplicación. **Debe ser proporcionado a la IA como contexto en futuras sesiones de desarrollo.**

## 📌 Información General
- **Objetivo:** Aplicación para visualizar, buscar y trazar rutas del transporte público (combis) en la ciudad de Villahermosa, Tabasco.
- **Tecnología:** Flutter (Dart)
- **Arquitectura actual:** Layer-first (`screens`, `models`, `services`). Persistencia local con `SharedPreferences` y caché en RAM. (Aún sin Backend conectado, usando Mock Data).

## 🚀 Features Implementadas (Estado Actual)
1. **Mapa Base (OpenStreetMap):** Implementado con `flutter_map`.
2. **Geolocalización en Tiempo Real:** Implementado con `geolocator`. 
   - Animación de "Pulso de Radar" azul para la ubicación del usuario.
   - Botón dinámico que centra y hace zoom (`17.0`) a la ubicación.
3. **API de Calles (Routing):** Las rutas de prueba (líneas rectas) se transforman automáticamente al trazado de las calles reales consumiendo la API de **OSRM (Open Source Routing Machine)**.
   - **Caché Local Inteligente:** Las rutas trazadas se guardan de por vida usando `SharedPreferences` y se cargan instantáneamente en RAM, evitando consumos excesivos de internet y congelamientos en el inicio.
4. **UI Moderna (Material 3 / Bottom Sheet) e Íconos Dinámicos:**
   - Menú de circuitos deslizable usando `CustomScrollView` y `Slivers` (Para mantener el buscador "Sticky" anclado arriba al hacer scroll).
5. **Búsqueda Integrada:**
   - Pestaña de `SearchScreen` que auto-despliega el teclado, permite buscar lugares clave en Villahermosa, y al regresar centra la cámara de forma automática poniendo un Pin Rojo.
6. **Gestión de Favoritos:**
   - Guardado local de rutas favoritas usando `SharedPreferences`.
7. **Pantalla de Carga (Splash Screen):**
   - Verifica el estado del GPS y pre-carga la caché local con micro-pausas (25ms) en el hilo principal para una experiencia ultra fluida a 60FPS.
8. **Clustering Ultra-Optimizado (Nativo):**
   - Se reemplazó una librería pesada por un algoritmo propio que agrupa paradas con la misma lat/long y asigna íconos temáticos (Hospitales, Plazas, etc.) dinámicamente.
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
- **Error:** `type 'int' is not a subtype of type 'double' in type cast` al pedir rutas.
  - *Causa:* La API de OSRM envía coordenadas como enteros en lugar de decimales a veces.
  - *Solución:* Se decodifica forzando el tipo `num` y usando `.toDouble()` seguro: `(coord[1] as num).toDouble()`.
- **Error (Congelamiento - Signal 3 / Skipped Frames):**
  - *Causa:* El plugin externo `flutter_map_marker_cluster` calculaba colisiones por cada micro-movimiento del mapa. Además, abusábamos de la función `compute` para leer la memoria local en el arranque.
  - *Solución:* 1) Se eliminó el plugin y se creó un agrupamiento manual en base a la coordenada exacta. 2) Se eliminó `compute` para la lectura local de la caché, usando en su lugar un diccionario `_memoryCache` en RAM.
- **Error (App Congelada / Freeze):** Al regresar de `SearchScreen` al `MapScreen`.
  - *Causa:* El ocultamiento del teclado de Android redimensionaba la pantalla exactamente en el mismo milisegundo en que `DraggableScrollableSheet` intentaba animarse, causando un colapso en el renderizado (Layout Constraints).
  - *Solución:* Se implementó `FocusScope.of(context).unfocus()` al salir y un `Future.delayed` de 350ms antes de mover la cámara y animar el BottomSheet.

## 🎯 Próximos Pasos Sugeridos (To-Do)
- [x] **Algoritmo de Sugerencia:** Dibujar una "Línea de Ruta" que una el GPS del usuario (`_currentLocation`) con el destino buscado (`_destinationPlace`).
- [x] **Clustering Ultra Ligero:** Agrupamiento nativo sin dependencias de terceros para correr a 60FPS en cualquier celular.
- [ ] **Conectar con Firebase Firestore:** Reemplazar `mock_data.dart` para que las rutas puedan actualizarse desde la nube en tiempo real sin recompilar la app.