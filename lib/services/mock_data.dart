import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/route_model.dart';

// Aquí simulamos lo que más adelante te devolvería una Base de Datos o una API
final List<RouteModel> mockRoutes = [
  RouteModel(
    id: 'demo_ruta_1',
    name: 'Ruta 1: Américas - Altabrisa (Vía Catedral)',
    companyColor: Colors.green,
    coordinates: [
      const LatLng(18.014410, -92.918830), // Américas
      const LatLng(17.994200, -92.935600), // UJAT
      const LatLng(17.987800, -92.942100), // Catedral
      const LatLng(17.986800, -92.938800), // ADO
      const LatLng(17.966179, -92.940801), // Altabrisa
    ],
    stops: [
      StopModel(name: 'Plaza Las Américas', location: const LatLng(18.014410, -92.918830)),
      StopModel(name: 'UJAT Zona de la Cultura', location: const LatLng(17.994200, -92.935600)),
      StopModel(name: 'Catedral del Señor de Tabasco', location: const LatLng(17.987800, -92.942100)),
      StopModel(name: 'Terminal ADO', location: const LatLng(17.986800, -92.938800)),
      StopModel(name: 'Plaza Altabrisa', location: const LatLng(17.966179, -92.940801)),
    ],
  ),
  RouteModel(
    id: 'demo_ruta_2',
    name: 'Ruta 2: P. Tabasco - Mercado (Vía Catedral)',
    companyColor: Colors.blue,
    coordinates: [
      const LatLng(18.015200, -92.969600), // Parque Tabasco
      const LatLng(17.996464, -92.954734), // Europlaza
      const LatLng(17.987800, -92.942100), // Catedral (¡Punto de Transbordo con Ruta 1!)
      const LatLng(17.996405, -92.914366), // Mercado Pino Suárez
    ],
    stops: [
      StopModel(name: 'Parque Tabasco', location: const LatLng(18.015200, -92.969600)),
      StopModel(name: 'Europlaza', location: const LatLng(17.996464, -92.954734)),
      StopModel(name: 'Catedral del Señor de Tabasco', location: const LatLng(17.987800, -92.942100)),
      StopModel(name: 'Mercado Pino Suárez', location: const LatLng(17.996405, -92.914366)),
    ],
  ),
  RouteModel(
    id: 'demo_ruta_3',
    name: 'Ruta 3: Rovirosa - Deportiva (Vía ADO)',
    companyColor: Colors.red,
    coordinates: [
      const LatLng(17.982500, -92.957500), // Rovirosa
      const LatLng(17.986800, -92.938800), // ADO (¡Punto de Transbordo con Ruta 1!)
      const LatLng(17.981500, -92.935500), // Deportiva
    ],
    stops: [
      StopModel(name: 'Hospital Rovirosa', location: const LatLng(17.982500, -92.957500)),
      StopModel(name: 'Terminal ADO', location: const LatLng(17.986800, -92.938800)),
      StopModel(name: 'Ciudad Deportiva', location: const LatLng(17.981500, -92.935500)),
    ],
  ),
  RouteModel(
    id: 'demo_ruta_4',
    name: 'Ruta 4: Europlaza - Altabrisa (Periférico)',
    companyColor: const Color(0xFF800020),
    coordinates: [
      const LatLng(17.996464, -92.954734), // Europlaza
      const LatLng(17.982500, -92.957500), // Rovirosa (¡Punto de Transbordo con Ruta 3!)
      const LatLng(17.966179, -92.940801), // Altabrisa
    ],
    stops: [
      StopModel(name: 'Europlaza', location: const LatLng(17.996464, -92.954734)),
      StopModel(name: 'Hospital Rovirosa', location: const LatLng(17.982500, -92.957500)),
      StopModel(name: 'Plaza Altabrisa', location: const LatLng(17.966179, -92.940801)),
    ],
  ),
];