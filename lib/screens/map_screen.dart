import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/route_model.dart';
import '../services/mock_data.dart';
import '../services/routing_service.dart';
import 'search_screen.dart'; // Importamos la nueva pantalla
import '../services/transit_algorithm.dart';
import 'dart:async';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  // Coordenadas aproximadas del centro de Villahermosa
  final LatLng _villahermosaCenter = const LatLng(17.9895, -92.9475);

  // Controlador del mapa para poder mover la cámara mediante código
  final MapController _mapController = MapController();
  
  // Variable para guardar la ubicación actual del usuario
  LatLng? _currentLocation;

  // Estado para saber si la cámara está siguiendo la ubicación del usuario
  bool _isTrackingLocation = false;

  // Rutas activas (las que se muestran en el mapa)
  final Set<String> _activeRouteIds = {};

  // Diccionario para guardar las rutas detalladas (cientos de puntos que siguen la calle)
  final Map<String, List<LatLng>> _detailedRoutes = {};

  // Parada seleccionada para mostrar su info
  StopModel? _selectedStop;

  // Lugar buscado y seleccionado como destino
  StopModel? _destinationPlace;

  // Ruta dibujada desde el usuario hasta el destino
  List<LatLng> _routeToDestination = [];

  // Sugerencia de transporte y caminos a pie
  TransitSuggestion? _transitSuggestion;
  List<List<LatLng>> _walkingPaths = [];

  // Etiqueta de ubicación
  bool _showLocationTooltip = false;
  Timer? _tooltipTimer;


  // Estado para saber si el usuario ya inició el viaje sugerido
  bool _isTripActive = false;

  // Controlador del panel deslizable para poder abrirlo/cerrarlo mediante código
  final DraggableScrollableController _sheetController = DraggableScrollableController();

  // Animación del panel deslizable para mover el botón flotante
  final ValueNotifier<double> _sheetExtent = ValueNotifier(0.24); // Tamaño para mostrar buscador y botones rápidos

  // Controlador para el pulso continuo de la ubicación del usuario
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    // Configuramos la animación del halo azul para que dure 2 segundos y se repita infinito
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Al iniciar, activamos todas las rutas para que se vean por defecto
    _activeRouteIds.addAll(mockRoutes.map((r) => r.id));
    _obtenerUbicacionYCentrar();
    _cargarRutasPorCalles();
  }

  // Función que transforma nuestras líneas rectas en calles reales
  Future<void> _cargarRutasPorCalles() async {
    // Usamos un mapa temporal para no actualizar la pantalla a cada rato
    Map<String, List<LatLng>> temporaryRoutes = {};

    for (var route in mockRoutes) {
      final detailedPoints = await RoutingService.getRoutePolyline(route.coordinates, routeId: route.id);
      temporaryRoutes[route.id] = detailedPoints;
    }

    // Actualizamos la pantalla UNA SOLA VEZ al final.
    // Esto evita que el mapa y el Clustering se recalculen 11 veces de golpe.
    if (mounted) {
      setState(() {
        _detailedRoutes.addAll(temporaryRoutes);
      });
    }
  }

  // Función para encuadrar la cámara y mostrar toda la ruta completa sin que nada la tape
  void _fitRouteBounds() {
    List<LatLng> allPoints = [];

    if (_currentLocation != null) allPoints.add(_currentLocation!);
    if (_destinationPlace != null) allPoints.add(_destinationPlace!.location);
    if (_routeToDestination.isNotEmpty) allPoints.addAll(_routeToDestination);

    if (_transitSuggestion != null) {
      for (var path in _walkingPaths) {
        allPoints.addAll(path);
      }
      for (var leg in _transitSuggestion!.legs) {
        if (_detailedRoutes.containsKey(leg.route.id)) {
          allPoints.addAll(_detailedRoutes[leg.route.id]!);
        } else {
          allPoints.addAll(leg.route.coordinates);
        }
      }
    }

    if (allPoints.isEmpty) return;

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(allPoints),
        padding: const EdgeInsets.only(top: 120, bottom: 280, left: 40, right: 40), // El padding inferior evita que el menú tape la ruta
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _tooltipTimer?.cancel();
    _sheetController.dispose();
    _sheetExtent.dispose();
    super.dispose();
  }

  // Función para pedir permisos y obtener el GPS
  Future<void> _obtenerUbicacionYCentrar() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, enciende el GPS de tu celular.')),
        );
      }
      return; // Si el GPS está apagado, avisamos y no hace nada
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permisos de ubicación denegados.')),
          );
        }
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permisos denegados permanentemente. Ve a los ajustes de tu app.')),
        );
      }
      return;
    }

    // Si ya tenemos la ubicación de un cálculo anterior, centramos inmediatamente para que se sienta muy rápido
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 17.0); // Zoom más cercano y automático
      setState(() {
        _isTrackingLocation = true; // Activamos el estado de seguimiento
        _showLocationTooltip = true;
      });
      _iniciarTimerTooltip();
    } else {
      // OPTIMIZACIÓN GPS: Mostramos la última ubicación guardada al instante 
      // para que el mapa y la app no se queden congelados esperando a los satélites.
      Position? lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition != null && mounted) {
        setState(() {
          _currentLocation = LatLng(lastPosition.latitude, lastPosition.longitude);
        });
        _mapController.move(_currentLocation!, 17.0);
      }
    }

    try {
      // Pedimos ubicación satelital precisa de fondo
      Position position = await Geolocator.getCurrentPosition();
      
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _isTrackingLocation = true; // Activamos el estado de seguimiento
          _showLocationTooltip = true;
        });
        // Mueve la cámara del mapa a la ubicación del usuario
        _mapController.move(_currentLocation!, 17.0); // Zoom más cercano y automático
        _iniciarTimerTooltip();
      }
    } catch (e) {
      debugPrint("Error obteniendo ubicación: \$e");
    }
  }

  void _iniciarTimerTooltip() {
    _tooltipTimer?.cancel();
    _tooltipTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showLocationTooltip = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    // AGRUPACIÓN MANUAL DE PARADAS (OPTIMIZACIÓN EXTREMA)
    // Elimina el uso del plugin pesado y renderiza directo a 60 FPS
    Map<LatLng, Map<String, dynamic>> groupedStops = {};
    for (var route in mockRoutes.where((r) => _activeRouteIds.contains(r.id))) {
      for (var stop in route.stops) {
        if (!groupedStops.containsKey(stop.location)) {
          groupedStops[stop.location] = {
            'name': stop.name,
            'routes': <RouteModel>{}, // Usamos un Set para no duplicar rutas
          };
        }
        (groupedStops[stop.location]!['routes'] as Set<RouteModel>).add(route);
      }
    }

    // Filtramos para mostrar SOLO los nodos donde convergen 2 o más rutas (Puntos de Transbordo)
    groupedStops.removeWhere((key, value) => (value['routes'] as Set<RouteModel>).length <= 1);

    return Scaffold(
      resizeToAvoidBottomInset: false, // Evita que la pantalla se congele al ocultarse el teclado
      // Usamos un Stack para poner capas una sobre otra (Mapa, Buscador, Botones, Menú)
      body: Stack(
        children: [
          // 1. EL MAPA (Al fondo)
          Container(
            color: const Color(0xFFE0E8DC), // Color base de Pantalla 1 (Verde mapa neutro)
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _villahermosaCenter,
                initialZoom: 14.0,
                onTap: (tapPosition, point) {
                  if (_selectedStop != null) {
                    setState(() => _selectedStop = null);
                  }
                },
                onPositionChanged: (camera, hasGesture) {
                  // Si el usuario arrastra el mapa manualmente, desactivamos el color verde del botón
                  if (hasGesture && _isTrackingLocation) {
                    setState(() => _isTrackingLocation = false);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.app_de_rutas_de_transporte_en_villahermosa',
                ),
                PolylineLayer(
                  polylines: [
                    ...mockRoutes
                        .where((route) => _activeRouteIds.contains(route.id))
                        .map((RouteModel route) {
                      return Polyline(
                        points: _detailedRoutes[route.id] ?? route.coordinates,
                        color: route.companyColor,
                        strokeWidth: 6.0,
                      );
                    }),
                    if (_routeToDestination.isNotEmpty)
                      Polyline(points: _routeToDestination, color: const Color(0xFF1565C0), strokeWidth: 5.0),
                    if (_transitSuggestion != null && _walkingPaths.isNotEmpty)
                      ..._walkingPaths.map((path) => Polyline(
                        points: path, color: const Color(0xFF1A1A1A), strokeWidth: 4.5, isDotted: true,
                      )),
                  ],
                ),
                MarkerLayer(
                  markers: groupedStops.entries.map((entry) {
                    final location = entry.key;
                    final stopName = entry.value['name'] as String;
                    final routesInNode = (entry.value['routes'] as Set<RouteModel>).toList();
                    final isSelected = _selectedStop?.location == location;

                    return Marker(
                      point: location, 
                      width: isSelected ? 48 : 40, height: isSelected ? 48 : 40, // Crece ligeramente si lo tocas
                      rotate: true, // Mantiene el número siempre derecho sin importar cómo gires el mapa
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedStop = StopModel(name: stopName, location: location));
                          _mapController.move(location, 15.5);
                          
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.white,
                            isScrollControlled: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                            ),
                            builder: (context) {
                              return SafeArea(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 16.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(top: 12, bottom: 16),
                                        width: 40, height: 5,
                                        decoration: BoxDecoration(color: const Color(0xFFD0D0D0), borderRadius: BorderRadius.circular(10)),
                                      ),
                                      // DISEÑO ELEGANTE PARA EL NOMBRE DE LA PARADA
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                        child: Column(
                                          children: [
                                            Icon(_getIconForStop(stopName), color: const Color(0xFF1565C0), size: 32),
                                            const SizedBox(height: 8),
                                            Text(stopName, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFF1A1A1A))),
                                            const SizedBox(height: 4),
                                            const Text('Punto de transbordo', style: TextStyle(fontSize: 14, color: Color(0xFF757575), fontWeight: FontWeight.w500)),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      const Divider(height: 1, color: Color(0xFFE0E0E0)),
                                      const SizedBox(height: 8),
                                      Flexible(
                                        child: SingleChildScrollView(
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: routesInNode.map((r) => Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 10.0),
                                              child: Row(
                                                children: [
                                                  CircleAvatar(backgroundColor: r.companyColor, radius: 14),
                                                  const SizedBox(width: 16),
                                                  Expanded(child: Text(r.name.split(':').last.trim(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
                                                ],
                                              ),
                                            )).toList(),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ).whenComplete(() {
                            // Al deslizar el panel hacia abajo para cerrarlo, quitamos la selección visual del mapa
                            if (mounted) {
                              setState(() => _selectedStop = null);
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected ? routesInNode.first.companyColor : const Color(0xFF1565C0), // Vuelve a mostrar el color de la combi
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: isSelected ? 4 : 3), // Borde más grueso al tocar
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4)],
                          ),
                          child: Center(
                            child: Icon(
                              _getIconForStop(stopName),
                              color: Colors.white,
                              size: isSelected ? 24 : 20,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                MarkerLayer(
                  markers: [
                    if (_destinationPlace != null)
                      Marker(
                        point: _destinationPlace!.location, width: 50, height: 50, alignment: Alignment.topCenter, rotate: true,
                        child: const Icon(Icons.location_on, color: Color(0xFFD32F2F), size: 50),
                      ),
                    if (_currentLocation != null)
                      Marker(
                        point: _currentLocation!, width: 140, height: 120, rotate: true, // Ampliado para Etiqueta Flotante
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _showLocationTooltip = true);
                            _iniciarTimerTooltip();
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 80, height: 80,
                                child: AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (context, child) {
                                    return Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Container(
                                          width: 80 * _pulseController.value, height: 80 * _pulseController.value,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: const Color(0xFF1565C0).withValues(alpha: (1.0 - _pulseController.value).clamp(0.0, 1.0)),
                                          ),
                                        ),
                                        Container(
                                          width: 24, height: 24,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1565C0), shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 3),
                                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4)],
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                              // Etiqueta flotante estilo Tooltip (Pantalla 5)
                              AnimatedOpacity(
                                opacity: _showLocationTooltip ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 500),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white, borderRadius: BorderRadius.circular(12),
                                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))],
                                  ),
                                  child: const Text('Tu ubicación actual', style: TextStyle(color: Color(0xFF1A1A1A), fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // BUSCADOR FLOTANTE SUPERIOR (Pantalla 1)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: GestureDetector(
              onTap: () async {
                final selectedPlace = await Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchScreen()));
                
                if (selectedPlace != null && selectedPlace is StopModel) {
                  setState(() {
                    _destinationPlace = selectedPlace;
                    _selectedStop = selectedPlace; 
                    _routeToDestination.clear();
                    _transitSuggestion = null;
                    _walkingPaths.clear();
                    _isTripActive = false;
                  });
                  
                  Future.delayed(const Duration(milliseconds: 500), () async {
                    if (mounted) {
                      if (_sheetController.isAttached) _sheetController.animateTo(0.24, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                      
                      if (_currentLocation != null) {
                        _mapController.fitCamera(CameraFit.bounds(
                          bounds: LatLngBounds.fromPoints([_currentLocation!, selectedPlace.location]),
                          padding: const EdgeInsets.only(top: 120, bottom: 280, left: 40, right: 40),
                        ));
                      } else {
                        _mapController.move(selectedPlace.location, 16.5);
                      }
                      
                      if (_currentLocation != null) {
                        // 1. Intentar buscar combis caminables (800m)
                        TransitSuggestion? suggestion = TransitAlgorithm.findBestRoute(_currentLocation!, selectedPlace.location, mockRoutes, maxOriginDistance: 800.0, maxDestDistance: 800.0);
                        
                        // 2. Si estamos muy lejos (ej. Cunduacán), ampliamos el radio del origen (50km) para indicar a dónde acercarse
                        suggestion ??= TransitAlgorithm.findBestRoute(_currentLocation!, selectedPlace.location, mockRoutes, maxOriginDistance: 50000.0, maxDestDistance: 800.0);
                        if (suggestion != null) {
                          List<List<LatLng>> walks = [];
                          walks.add(await RoutingService.getRoutePolyline([_currentLocation!, suggestion.legs.first.boardingPoint]));
                          for (int i = 0; i < suggestion.legs.length - 1; i++) {
                            walks.add(await RoutingService.getRoutePolyline([suggestion.legs[i].dropOffPoint, suggestion.legs[i+1].boardingPoint]));
                          }
                          walks.add(await RoutingService.getRoutePolyline([suggestion.legs.last.dropOffPoint, selectedPlace.location]));
                          
                          if (mounted) {
                            setState(() {
                              _transitSuggestion = suggestion;
                              _walkingPaths = walks;
                              _activeRouteIds.clear();
                              for (var leg in suggestion!.legs) {
                                _activeRouteIds.add(leg.route.id);
                              }
                            });
                            _fitRouteBounds();
                          }
                        } else {
                          final routePoints = await RoutingService.getRoutePolyline([_currentLocation!, selectedPlace.location]);
                          if (mounted) {
                            setState(() {
                              _activeRouteIds.clear();
                              _routeToDestination = routePoints;
                            });
                            _fitRouteBounds();
                          }
                        }
                      }
                    }
                  });
                }
              },
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Color(0xFF757575)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _destinationPlace != null ? _destinationPlace!.name : '¿A dónde vas? (Lugares, plazas...)',
                          style: TextStyle(color: _destinationPlace != null ? const Color(0xFF1A1A1A) : const Color(0xFF757575), fontSize: 16, fontWeight: _destinationPlace != null ? FontWeight.bold : FontWeight.w500),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_destinationPlace != null)
                        IconButton(
                          icon: const Icon(Icons.close, color: Color(0xFF757575), size: 20),
                          padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                          onPressed: () {
                            setState(() {
                              _destinationPlace = null; _selectedStop = null; _routeToDestination.clear(); _transitSuggestion = null; _walkingPaths.clear();
                              _isTripActive = false;
                              _activeRouteIds.clear(); _activeRouteIds.addAll(mockRoutes.map((r) => r.id));
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // BOTONES GPS Y SATELITE
          ValueListenableBuilder<double>(
            valueListenable: _sheetExtent,
            builder: (context, extent, child) {
              final screenHeight = MediaQuery.of(context).size.height;
              // Envolvemos el botón para que aparezca "inflando" desde cero con rebote
              return TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Positioned(
                    right: 16,
                    bottom: (screenHeight * extent) + 16, // Calcula dónde termina el panel
                    child: Transform.scale(
                      scale: value,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FloatingActionButton(
                            heroTag: 'btnLocation',
                            backgroundColor: Colors.white,
                            // Si está siguiendo la ubicación, se pone Verde (Design System), si no, Azul primario
                            foregroundColor: _isTrackingLocation ? const Color(0xFF388E3C) : const Color(0xFF1565C0),
                            elevation: 4,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            onPressed: _obtenerUbicacionYCentrar,
                            child: const Icon(Icons.my_location),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),

          // PANEL DESLIZABLE MODERNO (Bottom Sheet)
          NotificationListener<DraggableScrollableNotification>(
            onNotification: (notification) {
              // Actualizamos la posición del botón GPS suavemente al arrastrar
              _sheetExtent.value = notification.extent;
              return true;
            },
            child: DraggableScrollableSheet(
              controller: _sheetController, 
              initialChildSize: 0.24, // Altura perfecta
              minChildSize: 0.10, // Más bajo para ocultar completamente las tarjetas y que no se vean cortadas
              maxChildSize: 0.85, // Se abre más para ver las listas sugeridas
              builder: (context, scrollController) {
                return Container(
                  clipBehavior: Clip.antiAlias, // Evita que el scroll rebase las esquinas curvas
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA), // Gris claro para resaltar las tarjetas blancas
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08), // Sombra más premium y difuminada
                        blurRadius: 24,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // PÍLDORA INDICADORA DE ARRASTRE FIJA (Fuera del scroll para no rebotar)
                      Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 4),
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD0D0D0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      // CONTENIDO DESPLAZABLE
                      Expanded(
                        child: CustomScrollView(
                          controller: scrollController, // Importante conectarlo aquí
                          slivers: [
                            SliverToBoxAdapter(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                            if (_transitSuggestion != null) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                                child: Text(
                                  _isTripActive
                                      ? '📍 Tu itinerario de viaje paso a paso:'
                                      : (_transitSuggestion!.totalWalkDistance > 1500 
                                          ? '⚠️ Estás lejos. Acércate al punto de abordaje:' 
                                          : (_transitSuggestion!.legs.length > 1 ? 'Itinerario: Transbordo Necesario' : 'Sugerencia de Viaje Directo')),
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1565C0)), // Azul primario
                                ),
                              ),
                              ..._transitSuggestion!.legs.asMap().entries.map((entry) {
                                int index = entry.key;
                                TransitLeg leg = entry.value;
                                
                                String nearestBoarding = "Punto cercano";
                                double minBoardDist = double.infinity;
                                for (var stop in leg.route.stops) {
                                  double d = const Distance().as(LengthUnit.Meter, stop.location, leg.boardingPoint);
                                  if (d < minBoardDist) {
                                    minBoardDist = d;
                                    nearestBoarding = stop.name;
                                  }
                                }
                                
                                String nearestDropOff = "Punto cercano";
                                double minDropDist = double.infinity;
                                for (var stop in leg.route.stops) {
                                  double d = const Distance().as(LengthUnit.Meter, stop.location, leg.dropOffPoint);
                                  if (d < minDropDist) {
                                    minDropDist = d;
                                    nearestDropOff = stop.name;
                                  }
                                }

                                return _buildRouteCard(
                                  leg.route, 
                                  _activeRouteIds.contains(leg.route.id), 
                                  isSuggested: true, 
                                  walkDistance: index == 0 ? _transitSuggestion!.totalWalkDistance : null, // Solo muestra tiempo de caminata en la primera combi
                                  stepNumber: index + 1,
                                  boardAt: nearestBoarding,
                                  dropOffAt: nearestDropOff,
                                );
                              }),
                            ] else if (_isTripActive && _routeToDestination.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                                child: Container(
                                   padding: const EdgeInsets.all(12),
                                   decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                                   child: const Text('No hay combis directas. Sigue la ruta marcada en el mapa.', style: TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.w500)),
                                )
                              ),
                            ],
                            
                            // BOTÓN LLAMATIVO PARA INICIAR EL VIAJE
                            if (_destinationPlace != null)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                                child: SizedBox(
                                  width: double.infinity, // Ocupa todo el ancho disponible
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      if (!_isTripActive) {
                                        // INICIAR VIAJE
                                        setState(() {
                                          _isTripActive = true;
                                          _activeRouteIds.clear();
                                          if (_transitSuggestion != null) {
                                            for (var leg in _transitSuggestion!.legs) {
                                              _activeRouteIds.add(leg.route.id);
                                            }
                                          }
                                        });
                                        // Dejamos el menú a un tamaño donde se vea el itinerario completo
                                        if (_sheetController.isAttached) {
                                          _sheetController.animateTo(0.40, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                                        }
                                        _fitRouteBounds();
                                      } else {
                                        // FINALIZAR VIAJE
                                        final destinoNombre = _destinationPlace?.name ?? 'tu destino';

                                        setState(() {
                                          _destinationPlace = null;
                                          _selectedStop = null;
                                          _routeToDestination.clear();
                                          _transitSuggestion = null;
                                          _walkingPaths.clear();
                                          _isTripActive = false;
                                          _activeRouteIds.clear();
                                          _activeRouteIds.addAll(mockRoutes.map((r) => r.id));
                                        });
                                        if (_sheetController.isAttached) {
                                          _sheetController.animateTo(0.24, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                                        }
                                        _obtenerUbicacionYCentrar();
                                        
                                        // Mostramos la alerta visual de celebración
                                        _mostrarDialogoLlegada(destinoNombre);
                                      }
                                    },
                                    icon: Icon(!_isTripActive ? Icons.explore_rounded : Icons.stop_circle_rounded, color: Colors.white, size: 24),
                                    label: Text(!_isTripActive ? '¡Llévame ahí! 🚀' : 'Finalizar viaje 🏁', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: !_isTripActive ? Colors.green.shade600 : Colors.red.shade600,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      elevation: 6,
                                      shadowColor: (!_isTripActive ? Colors.green : Colors.red).withValues(alpha: 0.5),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    ),
                                  ),
                                ),
                              ),

                            // Ocultamos el título si estamos en medio de un viaje
                            if (_destinationPlace == null)
                              const Padding(
                                padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
                                child: Text(
                                  'Rutas cercanas',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // LISTA DE RUTAS MAPEADA A SLIVERS (Se oculta completamente durante el viaje)
                      if (_destinationPlace == null)
                        SliverPadding(
                          padding: const EdgeInsets.only(bottom: 24),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final route = mockRoutes[index];
                                final isActive = _activeRouteIds.contains(route.id);
                                return _buildRouteCard(route, isActive);
                              },
                              childCount: mockRoutes.length,
                            ),
                          ),
                        ),
                    ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Método inteligente para asignar un ícono visual según el nombre del lugar
  IconData _getIconForStop(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('palacio') || lower.contains('gobierno') || lower.contains('fiscalía')) return Icons.account_balance_rounded; // Edificio clásico
    if (lower.contains('hospital') || lower.contains('rovirosa') || lower.contains('graham') || lower.contains('ángeles')) return Icons.local_hospital_rounded; // Cruz médica
    if (lower.contains('plaza') || lower.contains('galerías') || lower.contains('europlaza') || lower.contains('altabrisa') || lower.contains('américas')) return Icons.local_mall_rounded; // Bolsas de compras
    if (lower.contains('catedral') || lower.contains('iglesia')) return Icons.church_rounded; // Iglesia
    if (lower.contains('terminal') || lower.contains('central') || lower.contains('ado') || lower.contains('cardesa') || lower.contains('camionera')) return Icons.directions_bus_rounded; // Autobús
    if (lower.contains('universidad') || lower.contains('ujat') || lower.contains('uag') || lower.contains('itvh')) return Icons.school_rounded; // Birrete de graduación
    if (lower.contains('parque') || lower.contains('deportiva')) return Icons.park_rounded; // Árboles
    if (lower.contains('mercado')) return Icons.storefront_rounded; // Tienda
    
    return Icons.transfer_within_a_station_rounded; // Ícono por defecto (Persona con flechas)
  }

  // NUEVO: Alerta visual premium al finalizar el viaje
  void _mostrarDialogoLlegada(String destino) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.celebration_rounded, color: Colors.green, size: 48),
              ),
              const SizedBox(height: 24),
              const Text('¡Viaje Finalizado! 🏁', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
              const SizedBox(height: 12),
              Text(
                'Has llegado a:\n$destino',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Color(0xFF757575), height: 1.4),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Aceptar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  // Widget extraído para mantener limpio el código principal.
  // Este widget tiene animaciones implícitas muy elegantes.
  Widget _buildRouteCard(RouteModel route, bool isActive, {bool isSuggested = false, double? walkDistance, int? stepNumber, String? boardAt, String? dropOffAt}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isActive ? route.companyColor.withValues(alpha: 0.3) : const Color(0xFFE0E0E0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: route.companyColor,
          radius: 20,
          child: const Icon(Icons.directions_bus_rounded, color: Colors.white, size: 20),
        ),
        title: Row(
          children: [
            if (stepNumber != null) ...[
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: const Color(0xFF1565C0).withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Text('$stepNumber', style: const TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                route.name.split(':').last.trim(), // Nombre más limpio para el diseño
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    walkDistance != null 
                        ? (walkDistance > 1500 ? 'Parada a ${(walkDistance / 1000).toStringAsFixed(1)} km' : 'Parada a ${walkDistance.ceil()} m') 
                        : 'Ver ruta en mapa',
                    style: const TextStyle(color: Color(0xFF757575), fontSize: 13),
                  ),
                  if (isSuggested) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF388E3C).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        walkDistance != null && walkDistance > 1500 ? 'Lejos' : 'Cercana',
                        style: const TextStyle(color: Color(0xFF388E3C), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
              if (boardAt != null && dropOffAt != null) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on, size: 14, color: Colors.green),
                    const SizedBox(width: 4),
                    Expanded(child: Text('Sube cerca de: $boardAt', style: const TextStyle(fontSize: 12, color: Color(0xFF1A1A1A)))),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.flag, size: 14, color: Colors.red),
                    const SizedBox(width: 4),
                    Expanded(child: Text('Baja cerca de: $dropOffAt', style: const TextStyle(fontSize: 12, color: Color(0xFF1A1A1A)))),
                  ],
                ),
              ],
            ],
          ),
        ),
        trailing: _isTripActive ? null : Switch(
          value: isActive,
          onChanged: (bool value) {
            setState(() {
              if (value) {
                _activeRouteIds.add(route.id);
              } else {
                _activeRouteIds.remove(route.id);
                if (_selectedStop != null && route.stops.contains(_selectedStop)) {
                  _selectedStop = null;
                }
              }
            });
          },
          activeThumbColor: Colors.white,
          activeTrackColor: const Color(0xFF1565C0), // Azul Design System
          inactiveThumbColor: Colors.grey.shade400,
          inactiveTrackColor: Colors.grey.shade200,
        ),
      ),
    );
  }
}