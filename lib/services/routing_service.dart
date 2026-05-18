import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RoutingService {
  // Usamos el servidor público gratuito de OSRM (Open Source Routing Machine)
  // Es ideal para desarrollo. Más adelante puedes cambiarlo por OpenRouteService.
  static const String _baseUrl = 'https://router.project-osrm.org/route/v1/driving';

  static Future<List<LatLng>> getRoutePolyline(List<LatLng> waypoints) async {
    // Si hay menos de 2 puntos, no podemos trazar una ruta
    if (waypoints.length < 2) return waypoints;

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
        final data = json.decode(response.body);
        final routes = data['routes'] as List;
        
        if (routes.isNotEmpty) {
          // Extraemos la lista de puntos exactos que forman las calles
          final geometry = routes[0]['geometry']['coordinates'] as List;
          // Convertimos de [longitud, latitud] a objetos LatLng de Flutter
          return geometry.map((coord) => LatLng(coord[1] as double, coord[0] as double)).toList();
        }
      }
    } catch (e) {
      print('Error al calcular ruta real: $e');
    }
    return waypoints; // Si falla, devuelve las líneas rectas por defecto
  }
}