import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class StopModel {
  final String name;
  final LatLng location;

  StopModel({required this.name, required this.location});
}

class RouteModel {
  final String id;
  final String name;
  final Color companyColor;
  final List<LatLng> coordinates; // Los puntos que forman el circuito
  final List<StopModel> stops;    // Las paradas a lo largo de la ruta

  RouteModel({
    required this.id,
    required this.name,
    required this.companyColor,
    required this.coordinates,
    this.stops = const [], // Si no le pasamos paradas, por defecto estará vacío
  });
}