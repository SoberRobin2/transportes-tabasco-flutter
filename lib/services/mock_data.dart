import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/route_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Variable global inicializada vacía, se llenará al arrancar la app
Set<String> favoriteRouteIds = {};
SharedPreferences? _prefs;

// Función para cargar las preferencias al iniciar
Future<void> initPreferences() async {
  _prefs = await SharedPreferences.getInstance();
  final saved = _prefs?.getStringList('favoriteRoutes');
  if (saved != null) {
    favoriteRouteIds = saved.toSet();
  } else {
    favoriteRouteIds = {'utpcam_16', 'movitab_hosp'}; // Favoritos por defecto en la primera vez
  }
}

// Función para agregar/quitar y guardar inmediatamente
Future<void> toggleFavorite(String routeId) async {
  if (favoriteRouteIds.contains(routeId)) {
    favoriteRouteIds.remove(routeId);
  } else {
    favoriteRouteIds.add(routeId);
  }
  await _prefs?.setStringList('favoriteRoutes', favoriteRouteIds.toList());
}

// Aquí simulamos lo que más adelante te devolvería una Base de Datos o una API
final List<RouteModel> mockRoutes = [
  RouteModel(
    id: 'utpcam_16',
    name: 'UTPCAM: Américas - Altabrisa',
    companyColor: Colors.green,
    schedule: '5:00 am — 10:30 pm',
    frequency: 'Cada 8 minutos',
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
    id: 'vicosertra_51',
    name: 'VICOSERTRA: P. Tabasco - Mercado',
    companyColor: Colors.blue,
    schedule: '4:30 am — 11:00 pm',
    frequency: 'Cada 5 minutos',
    coordinates: [
      const LatLng(18.015200, -92.969600), // Parque Tabasco
      const LatLng(17.996464, -92.954734), // Europlaza
      const LatLng(17.987800, -92.942100), // Catedral (¡Punto de Transbordo con Ruta 1!)
      const LatLng(17.986300, -92.931500), // Palacio Gobierno
      const LatLng(17.996405, -92.914366), // Mercado Pino Suárez
    ],
    stops: [
      StopModel(name: 'Parque Tabasco', location: const LatLng(18.015200, -92.969600)),
      StopModel(name: 'Europlaza', location: const LatLng(17.996464, -92.954734)),
      StopModel(name: 'Catedral del Señor de Tabasco', location: const LatLng(17.987800, -92.942100)),
      StopModel(name: 'Palacio de Gobierno', location: const LatLng(17.986300, -92.931500)),
      StopModel(name: 'Mercado Pino Suárez', location: const LatLng(17.996405, -92.914366)),
    ],
  ),
  RouteModel(
    id: 'arvit_60',
    name: 'ARVIT: Hosp. Ángeles - Deportiva',
    companyColor: Colors.red,
    schedule: '6:00 am — 9:00 pm',
    frequency: 'Cada 12 minutos',
    coordinates: [
      const LatLng(17.993900, -92.963800), // Hospital Ángeles
      const LatLng(17.982500, -92.957500), // Rovirosa
      const LatLng(17.986800, -92.938800), // ADO (¡Punto de Transbordo con Ruta 1!)
      const LatLng(17.981500, -92.935500), // Deportiva
    ],
    stops: [
      StopModel(name: 'Hospital Ángeles', location: const LatLng(17.993900, -92.963800)),
      StopModel(name: 'Hospital Rovirosa', location: const LatLng(17.982500, -92.957500)),
      StopModel(name: 'Terminal ADO', location: const LatLng(17.986800, -92.938800)),
      StopModel(name: 'Ciudad Deportiva', location: const LatLng(17.981500, -92.935500)),
    ],
  ),
  RouteModel(
    id: 'movitab_hosp',
    name: 'MOVITAB: Corredor Hospitales',
    companyColor: const Color(0xFF800020),
    schedule: '5:30 am — 10:00 pm',
    frequency: 'Cada 15 minutos',
    coordinates: [
      const LatLng(17.996464, -92.954734), // Europlaza
      const LatLng(17.982500, -92.957500), // Rovirosa (¡Punto de Transbordo con Ruta 3!)
      const LatLng(17.970900, -92.949400), // Central Camionera
      const LatLng(17.966179, -92.940801), // Altabrisa
    ],
    stops: [
      StopModel(name: 'Europlaza', location: const LatLng(17.996464, -92.954734)),
      StopModel(name: 'Hospital Rovirosa', location: const LatLng(17.982500, -92.957500)),
      StopModel(name: 'Central Camionera', location: const LatLng(17.970900, -92.949400)),
      StopModel(name: 'Plaza Altabrisa', location: const LatLng(17.966179, -92.940801)),
    ],
  ),
  RouteModel(
    id: 'genesis_45',
    name: 'GÉNESIS XXI: Gaviotas - Tabasco 2000',
    companyColor: Colors.purple,
    schedule: '5:00 am — 9:30 pm',
    frequency: 'Cada 10 minutos',
    coordinates: [
      const LatLng(17.982000, -92.912000), // Col. Gaviotas (Ficticio para la demo)
      const LatLng(17.996405, -92.914366), // Mercado Pino Suárez
      const LatLng(17.987800, -92.942100), // Catedral
      const LatLng(17.996700, -92.946500), // Galerías Tabasco 2000
    ],
    stops: [
      StopModel(name: 'Col. Gaviotas Sur', location: const LatLng(17.982000, -92.912000)),
      StopModel(name: 'Mercado Pino Suárez', location: const LatLng(17.996405, -92.914366)),
      StopModel(name: 'Catedral del Señor de Tabasco', location: const LatLng(17.987800, -92.942100)),
      StopModel(name: 'Galerías Tabasco 2000', location: const LatLng(17.996700, -92.946500)),
    ],
  ),
  RouteModel(
    id: 'utucc_76',
    name: 'UTUCC: Rovirosa - ITVH',
    companyColor: Colors.green.shade800,
    schedule: '5:30 am — 10:00 pm',
    frequency: 'Cada 10 minutos',
    coordinates: [
      const LatLng(17.982500, -92.957500), // Rovirosa
      const LatLng(17.994200, -92.935600), // UJAT
      const LatLng(17.986900, -92.934900), // Fiscalía
      const LatLng(17.981500, -92.935500), // Deportiva
      const LatLng(17.964300, -92.943200), // ITVH
    ],
    stops: [
      StopModel(name: 'Hospital Rovirosa', location: const LatLng(17.982500, -92.957500)),
      StopModel(name: 'UJAT Zona de la Cultura', location: const LatLng(17.994200, -92.935600)),
      StopModel(name: 'Fiscalía General', location: const LatLng(17.986900, -92.934900)),
      StopModel(name: 'Ciudad Deportiva', location: const LatLng(17.981500, -92.935500)),
      StopModel(name: 'ITVH', location: const LatLng(17.964300, -92.943200)),
    ],
  ),
  RouteModel(
    id: 'setab_12',
    name: 'SETAB: P. Tabasco - Juan Graham',
    companyColor: Colors.teal,
    schedule: '6:00 am — 8:00 pm',
    frequency: 'Cada 20 minutos',
    coordinates: [
      const LatLng(18.015200, -92.969600), // Parque Tabasco
      const LatLng(17.993900, -92.963800), // Hospital Ángeles
      const LatLng(17.982500, -92.957500), // Rovirosa
      const LatLng(17.970900, -92.949400), // Central Camionera
      const LatLng(17.956900, -92.952400), // Juan Graham
    ],
    stops: [
      StopModel(name: 'Parque Tabasco', location: const LatLng(18.015200, -92.969600)),
      StopModel(name: 'Hospital Ángeles', location: const LatLng(17.993900, -92.963800)),
      StopModel(name: 'Hospital Rovirosa', location: const LatLng(17.982500, -92.957500)),
      StopModel(name: 'Central Camionera', location: const LatLng(17.970900, -92.949400)),
      StopModel(name: 'Hospital Juan Graham', location: const LatLng(17.956900, -92.952400)),
    ],
  ),
  RouteModel(
    id: 'transbus_uni',
    name: 'TRANSBUS: Corredor Américas - UAG',
    companyColor: Colors.orange.shade700,
    schedule: '5:00 am — 10:00 pm',
    frequency: 'Cada 15 minutos',
    coordinates: [
      const LatLng(18.014410, -92.918830), // Américas
      const LatLng(17.996405, -92.914366), // Mercado Pino Suárez
      const LatLng(17.986300, -92.931500), // Palacio Gobierno
      const LatLng(17.993000, -92.926000), // UAG
    ],
    stops: [
      StopModel(name: 'Plaza Las Américas', location: const LatLng(18.014410, -92.918830)),
      StopModel(name: 'Mercado Pino Suárez', location: const LatLng(17.996405, -92.914366)),
      StopModel(name: 'Palacio de Gobierno', location: const LatLng(17.986300, -92.931500)),
      StopModel(name: 'Universidad UAG', location: const LatLng(17.993000, -92.926000)),
    ],
  ),
  // NUEVAS RUTAS FORÁNEAS: CUNDUACÁN - VILLAHERMOSA (CENTRAL CARDESA)
  RouteModel(
    id: 'cunduacan_xicotencatl',
    name: 'XICOTÉNCATL: Cunduacán - Villahermosa',
    companyColor: Colors.deepOrange, 
    schedule: '4:30 am — 9:00 pm',
    frequency: 'Cada 15 minutos',
    coordinates: [
      const LatLng(18.066200, -93.174600), // Central Cunduacán
      const LatLng(18.046800, -93.170600), // UJAT Chontalpa
      const LatLng(17.999600, -93.047800), // Entronque La Isla
      const LatLng(17.996464, -92.954734), // Europlaza
      const LatLng(17.996200, -92.914000), // Central Cardesa
    ],
    stops: [
      StopModel(name: 'Central Camionera Cunduacán', location: const LatLng(18.066200, -93.174600)),
      StopModel(name: 'UJAT Chontalpa', location: const LatLng(18.046800, -93.170600)),
      StopModel(name: 'Entronque La Isla', location: const LatLng(17.999600, -93.047800)),
      StopModel(name: 'Europlaza', location: const LatLng(17.996464, -92.954734)),
      StopModel(name: 'Central Cardesa (Villahermosa)', location: const LatLng(17.996200, -92.914000)),
    ],
  ),
  RouteModel(
    id: 'cunduacan_sc',
    name: 'SC: Cunduacán - Villahermosa',
    companyColor: Colors.amber.shade600, // Representando la franja amarilla (el fondo es blanco)
    schedule: '4:30 am — 9:00 pm',
    frequency: 'Cada 15 minutos',
    coordinates: [
      const LatLng(18.066200, -93.174600),
      const LatLng(18.046800, -93.170600),
      const LatLng(17.999600, -93.047800),
      const LatLng(17.996464, -92.954734),
      const LatLng(17.996200, -92.914000),
    ],
    stops: [
      StopModel(name: 'Central Camionera Cunduacán', location: const LatLng(18.066200, -93.174600)),
      StopModel(name: 'UJAT Chontalpa', location: const LatLng(18.046800, -93.170600)),
      StopModel(name: 'Entronque La Isla', location: const LatLng(17.999600, -93.047800)),
      StopModel(name: 'Europlaza', location: const LatLng(17.996464, -92.954734)),
      StopModel(name: 'Central Cardesa (Villahermosa)', location: const LatLng(17.996200, -92.914000)),
    ],
  ),
  RouteModel(
    id: 'cunduacan_samaria',
    name: 'CAMPO SAMARIA: Cunduacán - VSA',
    companyColor: Colors.blue.shade600, // "Las azules"
    schedule: '4:30 am — 9:00 pm',
    frequency: 'Cada 15 minutos',
    coordinates: [
      const LatLng(18.066200, -93.174600),
      const LatLng(18.046800, -93.170600),
      const LatLng(17.999600, -93.047800),
      const LatLng(17.996464, -92.954734),
      const LatLng(17.996200, -92.914000),
    ],
    stops: [
      StopModel(name: 'Central Camionera Cunduacán', location: const LatLng(18.066200, -93.174600)),
      StopModel(name: 'UJAT Chontalpa', location: const LatLng(18.046800, -93.170600)),
      StopModel(name: 'Entronque La Isla', location: const LatLng(17.999600, -93.047800)),
      StopModel(name: 'Europlaza', location: const LatLng(17.996464, -92.954734)),
      StopModel(name: 'Central Cardesa (Villahermosa)', location: const LatLng(17.996200, -92.914000)),
    ],
  ),
];