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
  final String schedule;          // Horario de servicio
  final String frequency;         // Frecuencia de paso
  final String fare;              // Tarifa
  final String duration;          // Duración estimada

  RouteModel({
    required this.id,
    required this.name,
    required this.companyColor,
    required this.coordinates,
    this.stops = const [], // Si no le pasamos paradas, por defecto estará vacío
    this.schedule = '5:30 am — 10:00 pm',
    this.frequency = 'Cada 10 minutos aprox.',
    this.fare = '\$9.50 MXN por viaje',
    this.duration = '~40 min',
  });
}