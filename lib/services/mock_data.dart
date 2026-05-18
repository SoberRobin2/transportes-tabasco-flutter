import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/route_model.dart';

// Aquí simulamos lo que más adelante te devolvería una Base de Datos o una API
final List<RouteModel> mockRoutes = [
  RouteModel(
    id: '1',
    name: 'Ruta Mendez / Centro (UTPCAM)',
    companyColor: Colors.green, // Combi Verde
    coordinates: [
      const LatLng(17.9895, -92.9475),
      const LatLng(17.9920, -92.9460),
      const LatLng(17.9950, -92.9440),
      const LatLng(17.9975, -92.9420),
    ],
    stops: [
      StopModel(name: 'Parque Juárez', location: const LatLng(17.9895, -92.9475)),
      StopModel(name: 'Mendez y Pagés', location: const LatLng(17.9950, -92.9440)),
    ],
  ),
  RouteModel(
    id: '2',
    name: 'Ruta 27 de Febrero (Vicosertra)',
    companyColor: Colors.brown, // Combi Café/Amarilla
    coordinates: [
      const LatLng(17.9895, -92.9475),
      const LatLng(17.9870, -92.9490),
      const LatLng(17.9840, -92.9510),
      const LatLng(17.9810, -92.9530),
      const LatLng(17.9780, -92.9550),
    ],
    stops: [
      StopModel(name: 'Catedral', location: const LatLng(17.9870, -92.9490)),
      StopModel(name: 'Reloj de Tres Caras', location: const LatLng(17.9810, -92.9530)),
    ],
  ),
  RouteModel(
    id: '3',
    name: 'Corredor Las Mercedes - Reclusorio',
    companyColor: Colors.green, // UTPCAM
    coordinates: [
      const LatLng(17.9250, -92.9280), // Las Mercedes
      const LatLng(17.9500, -92.9300), // Periférico Sur
      const LatLng(17.9715, -92.9315), // Guayabal
      const LatLng(17.9800, -92.9150), // Universidad
      const LatLng(17.9850, -92.8970), // Reclusorio
    ],
    stops: [
      StopModel(name: 'Fracc. Las Mercedes', location: const LatLng(17.9250, -92.9280)),
      StopModel(name: 'Distribuidor Guayabal', location: const LatLng(17.9715, -92.9315)),
      StopModel(name: 'Reclusorio (CREST)', location: const LatLng(17.9850, -92.8970)),
    ],
  ),
];