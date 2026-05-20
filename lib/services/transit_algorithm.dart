import 'package:latlong2/latlong.dart';
import '../models/route_model.dart';

class TransitLeg {
  final RouteModel route;
  final LatLng boardingPoint;
  final LatLng dropOffPoint;

  TransitLeg({
    required this.route,
    required this.boardingPoint,
    required this.dropOffPoint,
  });
}

class TransitSuggestion {
  final List<TransitLeg> legs; // Lista ordenada de las combis a tomar
  final double totalWalkDistance;

  TransitSuggestion({
    required this.legs,
    required this.totalWalkDistance,
  });
}

class TransitAlgorithm {
  static const Distance _distance = Distance();

  // Busca la mejor ruta (directa o con 1 transbordo)
  static TransitSuggestion? findBestRoute(
      LatLng origin, LatLng destination, List<RouteModel> routes, {double maxWalkDistance = 800.0}) {
    
    TransitSuggestion? bestSuggestion;
    double shortestWalkTotal = double.infinity;

    // 1. BUSCAR VIAJES DIRECTOS (1 Combi)
    for (var route in routes) {
      LatLng? nearestOrigin;
      double minOriginDist = double.infinity;
      
      for (var point in route.coordinates) {
        double dist = _distance.as(LengthUnit.Meter, origin, point);
        if (dist < minOriginDist) {
          minOriginDist = dist;
          nearestOrigin = point;
        }
      }

      LatLng? nearestDest;
      double minDestDist = double.infinity;
      
      for (var point in route.coordinates) {
        double dist = _distance.as(LengthUnit.Meter, destination, point);
        if (dist < minDestDist) {
          minDestDist = dist;
          nearestDest = point;
        }
      }

      if (nearestOrigin != null && nearestDest != null && 
          minOriginDist <= maxWalkDistance && minDestDist <= maxWalkDistance) {
        
        double totalWalk = minOriginDist + minDestDist;
        
        if (totalWalk < shortestWalkTotal) {
          shortestWalkTotal = totalWalk;
          bestSuggestion = TransitSuggestion(
            legs: [
              TransitLeg(route: route, boardingPoint: nearestOrigin, dropOffPoint: nearestDest)
            ],
            totalWalkDistance: totalWalk,
          );
        }
      }
    }

    // Si encontramos una ruta directa, devolvemos esa (es más cómodo no transbordar)
    if (bestSuggestion != null) return bestSuggestion;

    // 2. BUSCAR VIAJES CON 1 TRANSBORDO (2 Combis)
    for (var routeA in routes) {
      LatLng? nearestOrigin;
      double minOriginDist = double.infinity;
      for (var point in routeA.coordinates) {
        double dist = _distance.as(LengthUnit.Meter, origin, point);
        if (dist < minOriginDist) { minOriginDist = dist; nearestOrigin = point; }
      }
      if (nearestOrigin == null || minOriginDist > maxWalkDistance) continue;

      for (var routeB in routes) {
        if (routeA.id == routeB.id) continue;

        LatLng? nearestDest;
        double minDestDist = double.infinity;
        for (var point in routeB.coordinates) {
          double dist = _distance.as(LengthUnit.Meter, destination, point);
          if (dist < minDestDist) { minDestDist = dist; nearestDest = point; }
        }
        if (nearestDest == null || minDestDist > maxWalkDistance) continue;

        // Buscar punto de intersección/transbordo entre las dos rutas
        LatLng? transferPointA;
        LatLng? transferPointB;
        double minTransferDist = double.infinity;

        for (var pointA in routeA.coordinates) {
          for (var pointB in routeB.coordinates) {
            double dist = _distance.as(LengthUnit.Meter, pointA, pointB);
            if (dist < minTransferDist) {
              minTransferDist = dist;
              transferPointA = pointA;
              transferPointB = pointB;
            }
          }
        }

        // Si el transbordo implica caminar menos de 300 metros entre paradas
        if (transferPointA != null && transferPointB != null && minTransferDist <= 300.0) {
          double totalWalk = minOriginDist + minDestDist + minTransferDist;
          if (totalWalk < shortestWalkTotal) {
            shortestWalkTotal = totalWalk;
            bestSuggestion = TransitSuggestion(
              legs: [
                TransitLeg(route: routeA, boardingPoint: nearestOrigin, dropOffPoint: transferPointA),
                TransitLeg(route: routeB, boardingPoint: transferPointB, dropOffPoint: nearestDest),
              ],
              totalWalkDistance: totalWalk,
            );
          }
        }
      }
    }

    return bestSuggestion;
  }
}