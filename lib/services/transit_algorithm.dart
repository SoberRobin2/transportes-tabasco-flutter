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

  // Busca la mejor ruta (directa, 1 transbordo o hasta 2 transbordos / 3 combis)
  static TransitSuggestion? findBestRoute(
      LatLng origin, LatLng destination, List<RouteModel> routes, {double maxOriginDistance = 800.0, double maxDestDistance = 800.0, double maxTransferDistance = 300.0}) {
    
    TransitSuggestion? bestSuggestion;
    double shortestWalkTotal = double.infinity;

    // 0. PRE-CÁLCULO (Caché de origen y destino)
    // Evita recalcular distancias múltiples veces, acelerando el algoritmo
    Map<String, LatLng> originPoints = {};
    Map<String, double> originDists = {};
    Map<String, LatLng> destPoints = {};
    Map<String, double> destDists = {};

    for (var route in routes) {
      double minO = double.infinity;
      LatLng? pO;
      double minD = double.infinity;
      LatLng? pD;
      
      for (var point in route.coordinates) {
        double dO = _distance.as(LengthUnit.Meter, origin, point);
        if (dO < minO) { minO = dO; pO = point; }

        double dD = _distance.as(LengthUnit.Meter, destination, point);
        if (dD < minD) { minD = dD; pD = point; }
      }

      if (pO != null) {
        originPoints[route.id] = pO;
        originDists[route.id] = minO;
      }
      if (pD != null) {
        destPoints[route.id] = pD;
        destDists[route.id] = minD;
      }
    }

    // Caché de intersecciones entre pares de rutas para no iterar los mapas varias veces
    Map<String, _Intersection?> intersections = {};

    _Intersection? getIntersection(RouteModel r1, RouteModel r2) {
      String key1 = "${r1.id}_${r2.id}";
      if (intersections.containsKey(key1)) return intersections[key1];

      double minDist = double.infinity;
      LatLng? p1;
      LatLng? p2;

      for (var pt1 in r1.coordinates) {
        for (var pt2 in r2.coordinates) {
          double dist = _distance.as(LengthUnit.Meter, pt1, pt2);
          if (dist < minDist) {
            minDist = dist; p1 = pt1; p2 = pt2;
          }
        }
      }

      _Intersection? result = (p1 != null && p2 != null && minDist <= maxTransferDistance)
          ? _Intersection(p1, p2, minDist) : null;
          
      intersections["${r1.id}_${r2.id}"] = result;
      if (result != null) {
        intersections["${r2.id}_${r1.id}"] = _Intersection(result.p2, result.p1, minDist);
      } else {
        intersections["${r2.id}_${r1.id}"] = null;
      }
      return result;
    }

    // 1. BUSCAR VIAJES DIRECTOS (1 Combi)
    for (var route in routes) {
      if (originDists[route.id]! <= maxOriginDistance && destDists[route.id]! <= maxDestDistance) {
        double walk = originDists[route.id]! + destDists[route.id]!;
        if (walk < shortestWalkTotal) {
          shortestWalkTotal = walk;
          bestSuggestion = TransitSuggestion(
            legs: [TransitLeg(route: route, boardingPoint: originPoints[route.id]!, dropOffPoint: destPoints[route.id]!)],
            totalWalkDistance: walk,
          );
        }
      }
    }

    // 2. BUSCAR VIAJES CON 1 TRANSBORDO (2 Combis)
    for (var routeA in routes) {
      if (originDists[routeA.id]! > maxOriginDistance) continue;

      for (var routeB in routes) {
        if (routeA.id == routeB.id) continue;
        if (destDists[routeB.id]! > maxDestDistance) continue;

        var intersection = getIntersection(routeA, routeB);
        if (intersection != null) {
          double walk = originDists[routeA.id]! + destDists[routeB.id]! + intersection.distance;
          if (walk < shortestWalkTotal) {
            shortestWalkTotal = walk;
            bestSuggestion = TransitSuggestion(
              legs: [
                TransitLeg(route: routeA, boardingPoint: originPoints[routeA.id]!, dropOffPoint: intersection.p1),
                TransitLeg(route: routeB, boardingPoint: intersection.p2, dropOffPoint: destPoints[routeB.id]!),
              ],
              totalWalkDistance: walk,
            );
          }
        }
      }
    }

    // 3. BUSCAR VIAJES CON 2 TRANSBORDOS (3 Combis)
    for (var routeA in routes) {
      if (originDists[routeA.id]! > maxOriginDistance) continue;

      for (var routeC in routes) {
        if (routeA.id == routeC.id) continue;
        if (destDists[routeC.id]! > maxDestDistance) continue;

        for (var routeB in routes) {
          if (routeB.id == routeA.id || routeB.id == routeC.id) continue;

          var intersectAB = getIntersection(routeA, routeB);
          if (intersectAB == null) continue;

          var intersectBC = getIntersection(routeB, routeC);
          if (intersectBC == null) continue;

          double walk = originDists[routeA.id]! + destDists[routeC.id]! + intersectAB.distance + intersectBC.distance;
          
          if (walk < shortestWalkTotal) {
            shortestWalkTotal = walk;
            bestSuggestion = TransitSuggestion(
              legs: [
                TransitLeg(route: routeA, boardingPoint: originPoints[routeA.id]!, dropOffPoint: intersectAB.p1),
                TransitLeg(route: routeB, boardingPoint: intersectAB.p2, dropOffPoint: intersectBC.p1),
                TransitLeg(route: routeC, boardingPoint: intersectBC.p2, dropOffPoint: destPoints[routeC.id]!),
              ],
              totalWalkDistance: walk,
            );
          }
        }
      }
    }

    return bestSuggestion;
  }
}

class _Intersection {
  final LatLng p1;
  final LatLng p2;
  final double distance;
  _Intersection(this.p1, this.p2, this.distance);
}