import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Para respuestas de la API de OSRM (Objetos JSON)
Map<String, dynamic> _parseJsonMap(String responseBody) {
  return json.decode(responseBody) as Map<String, dynamic>;
}

// Para leer la memoria caché local (Listas JSON)
List<dynamic> _parseJsonList(String responseBody) {
  return json.decode(responseBody) as List<dynamic>;
}

class RoutingService {
  // Usamos el servidor público gratuito de OSRM (Open Source Routing Machine)
  // Es ideal para desarrollo. Más adelante puedes cambiarlo por OpenRouteService.
  static const String _baseUrl = 'https://router.project-osrm.org/route/v1/driving';

  // Caché ultrarrápido en memoria RAM. Evita decodificar múltiples veces en la misma sesión.
  static final Map<String, List<LatLng>> _memoryCache = {};

  static Future<List<LatLng>> getRoutePolyline(List<LatLng> waypoints, {String? routeId}) async {
    // Si hay menos de 2 puntos, no podemos trazar una ruta
    if (waypoints.length < 2) return waypoints;

    // 0. REVISAR LA RAM PRIMERO (Lectura instantánea en 0.0001s)
    if (routeId != null && _memoryCache.containsKey(routeId)) {
      return _memoryCache[routeId]!;
    }

    // 1. REVISAR EL CACHÉ PRIMERO (Memoria del Teléfono)
    if (routeId != null) {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('route_$routeId');
      if (cachedData != null) {
        // Eliminamos 'compute' porque el overhead de crear un hilo secundario asfixia el procesador
        final List decoded = _parseJsonList(cachedData);
        final result = decoded.map((c) => LatLng((c[0] as num).toDouble(), (c[1] as num).toDouble())).toList();
        _memoryCache[routeId] = result; // Guardar en RAM para la próxima vez
        return result;
      }
    }

    // 2. SI NO ESTÁ EN CACHÉ, PEDIRLO A INTERNET
    try {
      // OSRM requiere las coordenadas en formato "longitud,latitud;longitud,latitud..."
      final String coordinatesString = waypoints
          .map((point) => '${point.longitude},${point.latitude}')
          .join(';');

      // Armamos la URL pidiendo la geometría completa en formato GeoJSON
      final Uri url = Uri.parse(
          '$_baseUrl/$coordinatesString?overview=full&geometries=geojson');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        // Decodificación directa y rápida
        final data = _parseJsonMap(response.body);
        
        if (data['code'] == 'Ok') {
          final routes = data['routes'] as List;
          if (routes.isNotEmpty) {
            final geometry = routes[0]['geometry']['coordinates'] as List;
            // Aceptamos int o double usando 'num' y lo forzamos a double de forma segura
            final result = geometry.map((coord) => LatLng((coord[1] as num).toDouble(), (coord[0] as num).toDouble())).toList();
            
            // GUARDAR EN CACHÉ PARA LA PRÓXIMA VEZ
            if (routeId != null) {
              final prefs = await SharedPreferences.getInstance();
              final encoded = json.encode(result.map((ll) => [ll.latitude, ll.longitude]).toList());
              prefs.setString('route_$routeId', encoded); // Guardado silencioso
              _memoryCache[routeId] = result; // Guardar en RAM
            }
            return result;
          }
        }
      }
    } catch (e) {
      debugPrint('Error al calcular ruta real completa: $e');
    }

    // FALLBACK: Si OSRM falla con la ruta completa (ej. vueltas prohibidas en avenidas),
    // lo calculamos segmento por segmento de punto A a punto B y unimos las líneas.
    List<LatLng> fallbackRoute = [];
    for (int i = 0; i < waypoints.length - 1; i++) {
      try {
        final start = waypoints[i];
        final end = waypoints[i + 1];
        final String coordString = '${start.longitude},${start.latitude};${end.longitude},${end.latitude}';
        final Uri fallbackUrl = Uri.parse('$_baseUrl/$coordString?overview=full&geometries=geojson');
        
        final response = await http.get(fallbackUrl);
        if (response.statusCode == 200) {
          final data = _parseJsonMap(response.body);
          if (data['code'] == 'Ok' && (data['routes'] as List).isNotEmpty) {
            final geometry = data['routes'][0]['geometry']['coordinates'] as List;
            // Aceptamos int o double usando 'num' y lo forzamos a double de forma segura
            final segment = geometry.map((coord) => LatLng((coord[1] as num).toDouble(), (coord[0] as num).toDouble())).toList();
            
            if (fallbackRoute.isNotEmpty && segment.isNotEmpty) segment.removeAt(0); // Evitar salto visual duplicado
            fallbackRoute.addAll(segment);
            continue;
          }
        }
      } catch (e) {
        debugPrint('Error en segmento de ruta: $e');
      }
      // Si el segmento falla, unimos con línea recta
      if (fallbackRoute.isEmpty) fallbackRoute.add(waypoints[i]);
      fallbackRoute.add(waypoints[i + 1]);
    }
    
    // GUARDAR EL FALLBACK EN CACHÉ PARA NO TENER QUE VOLVER A CALCULARLO
    if (fallbackRoute.isNotEmpty) {
      if (routeId != null) {
        final prefs = await SharedPreferences.getInstance();
        final encoded = json.encode(fallbackRoute.map((ll) => [ll.latitude, ll.longitude]).toList());
        prefs.setString('route_$routeId', encoded);
        _memoryCache[routeId] = fallbackRoute; // Guardar en RAM
      }
      return fallbackRoute;
    }
    return waypoints;
  }
}