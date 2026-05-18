import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/route_model.dart';
import '../services/mock_data.dart';
import '../services/routing_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'search_screen.dart'; // Importamos la nueva pantalla

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
    for (var route in mockRoutes) {
      // Llamamos a la API por cada ruta de prueba
      final detailedPoints = await RoutingService.getRoutePolyline(route.coordinates);
      
      // Actualizamos la pantalla con la nueva ruta curveada
      if (mounted) {
        setState(() {
          _detailedRoutes[route.id] = detailedPoints;
        });
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
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
    }

    try {
      // Obtenemos la ubicación más actualizada en segundo plano
      Position position = await Geolocator.getCurrentPosition();
      
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
        // Mueve la cámara del mapa a la ubicación del usuario
        _mapController.move(_currentLocation!, 17.0); // Zoom más cercano y automático
      }
    } catch (e) {
      debugPrint("Error obteniendo ubicación: \$e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // Evita que la pantalla se congele al ocultarse el teclado
      // Usamos un Stack para poner capas una sobre otra (Mapa, Buscador, Botones, Menú)
      body: Stack(
        children: [
          // 1. EL MAPA (Al fondo)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _villahermosaCenter,
              initialZoom: 14.0,
              onTap: (tapPosition, point) {
                // Si tocamos cualquier parte del mapa, ocultamos la etiqueta
                if (_selectedStop != null) {
                  setState(() {
                    _selectedStop = null;
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app_de_rutas_de_transporte_en_villahermosa',
                tileProvider: CachedTileProvider(), // Conectamos nuestro sistema de caché aquí
              ),
              // Capa de Rutas: Ahora se filtra dinámicamente según lo que selecciones
              PolylineLayer(
                polylines: [
                  // Rutas de transporte activas
                  ...mockRoutes
                      .where((route) => _activeRouteIds.contains(route.id))
                      .map((RouteModel route) {
                    return Polyline(
                      // Si ya se descargó la ruta de la calle la usamos, si no, usa la recta
                      points: _detailedRoutes[route.id] ?? route.coordinates,
                      color: route.companyColor,
                      strokeWidth: 6.0,
                    );
                  }),
                  // Línea de ruta hacia el destino buscado
                  if (_routeToDestination.isNotEmpty)
                    Polyline(
                      points: _routeToDestination,
                      color: Colors.blue.shade800, // Azul fuerte para destacarla de las combis
                      strokeWidth: 5.0,
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  // 1. DIBUJAMOS LAS PARADAS DE LAS RUTAS ACTIVAS
                  ...mockRoutes
                      .where((route) => _activeRouteIds.contains(route.id))
                      .expand((route) {
                    return route.stops.map((stop) {
                      return Marker(
                        point: stop.location,
                        width: 40, // Área táctil ampliada
                        height: 40,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedStop = stop;
                            });
                            // Opcional: Centra el mapa en la parada al tocarla
                            _mapController.move(stop.location, 15.5);
                          },
                          child: Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: _selectedStop == stop ? 24 : 16, // Crece si está seleccionada
                              height: _selectedStop == stop ? 24 : 16,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: route.companyColor, width: _selectedStop == stop ? 6 : 4),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    });
                  }),
                  
                  // 1.5 DIBUJAMOS EL DESTINO BUSCADO (Un pin rojo grande)
                  if (_destinationPlace != null)
                    Marker(
                      point: _destinationPlace!.location,
                      width: 50,
                      height: 50,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedStop = _destinationPlace;
                          });
                        },
                        child: const Icon(Icons.location_on, color: Colors.red, size: 50),
                      ),
                    ),
                    
                  // 2. DIBUJAMOS LA UBICACIÓN DEL USUARIO (Por encima de las paradas)
                  if (_currentLocation != null)
                    Marker(
                      point: _currentLocation!,
                  width: 80, // Aumentamos el tamaño total para el halo animado
                  height: 80,
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              // Halo animado que se expande y desvanece
                              Container(
                            width: 80 * _pulseController.value,
                            height: 80 * _pulseController.value,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.blue.withOpacity((1.0 - _pulseController.value).clamp(0.0, 1.0)),
                                ),
                              ),
                          // Punto central (Ubicación real con ícono de persona)
                              Container(
                            width: 36,
                            height: 36,
                                decoration: BoxDecoration(
                              color: Colors.blue.shade600,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4),
                                  ],
                                ),
                            child: const Center(
                              child: Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                ],
              ),
            ],
          ),

          // 2.5 ETIQUETA FLOTANTE DE LA PARADA SELECCIONADA (Aparece suavemente)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16, // Sube ya que no hay barra estorbando
            left: 0,
            right: 0,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0, -0.5), end: Offset.zero).animate(animation),
                    child: child,
                  ),
                );
              },
              child: _selectedStop != null
                  ? Center(
                      key: ValueKey(_selectedStop!.name),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900, // Modo oscuro elegante
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.place, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              _selectedStop!.name,
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('empty')),
            ),
          ),

          // 3. BOTÓN DEL GPS DINÁMICO (Sube y baja esquivando el menú)
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
                      child: FloatingActionButton(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue.shade700,
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // Cuadrado redondeado
                        onPressed: _obtenerUbicacionYCentrar,
                        child: const Icon(Icons.my_location),
                      ),
                    ),
                  );
                },
              );
            },
          ),

          // 4. PANEL DESLIZABLE MODERNO (Bottom Sheet)
          NotificationListener<DraggableScrollableNotification>(
            onNotification: (notification) {
              // Actualizamos la posición del botón GPS suavemente al arrastrar
              _sheetExtent.value = notification.extent;
              return true;
            },
            child: DraggableScrollableSheet(
              initialChildSize: 0.24, // Altura perfecta para mostrar buscador y botones
              minChildSize: 0.15, // Lo mínimo que se puede cerrar
              maxChildSize: 0.85, // Se abre más para ver las listas sugeridas
              builder: (context, scrollController) {
                return Container(
                  clipBehavior: Clip.antiAlias, // Evita que el scroll rebase las esquinas curvas
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 20,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: CustomScrollView(
                    controller: scrollController, // Importante conectarlo al CustomScrollView
                    slivers: [
                      // CABECERA FIJA (Siempre visible aunque hagas scroll hacia abajo)
                      SliverAppBar(
                        pinned: true,
                        elevation: 0, // Quitamos la sombra estática para que se sienta plano
                        backgroundColor: Colors.white,
                        toolbarHeight: 90,
                        flexibleSpace: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // PÍLDORA INDICADORA DE ARRASTRE
                            Container(
                              margin: const EdgeInsets.only(top: 12, bottom: 12),
                              width: 48,
                              height: 5,                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            // BUSCADOR INTEGRADO (Ahora se queda pegado arriba)
                            GestureDetector(
                              onTap: () async {
                                // Abrimos la pantalla de búsqueda y esperamos el resultado
                                final selectedPlace = await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const SearchScreen()),
                                );
                                
                                if (selectedPlace != null && selectedPlace is StopModel) {
                                  setState(() {
                                    _destinationPlace = selectedPlace;
                                    _selectedStop = selectedPlace; // Automáticamente abrimos su etiqueta flotante
                                    _routeToDestination.clear(); // Limpiar ruta por si había una antes
                                  });
                                  
                                  // Esperamos 350ms para que el teclado termine de ocultarse 
                                  // y el Layout vuelva a su tamaño normal sin congelar la app.
                                  Future.delayed(const Duration(milliseconds: 500), () async {
                                    if (mounted) {
                                      if (_sheetController.isAttached) {
                                        // Colapsamos el panel para que pueda ver el mapa
                                        _sheetController.animateTo(0.24, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                                      }
                                      // ¡Hacemos un viaje automático con la cámara hacia el destino!
                                      _mapController.move(selectedPlace.location, 16.5);
                                      
                                      // Y calculamos la ruta real usando nuestra API de OSRM
                                      if (_currentLocation != null) {
                                        final routePoints = await RoutingService.getRoutePolyline([_currentLocation!, selectedPlace.location]);
                                        if (mounted) {
                                          setState(() {
                                            _routeToDestination = routePoints;
                                          });
                                        }
                                      }
                                    }
                                  });
                                }
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 20),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.search, color: Colors.blue.shade700),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _destinationPlace != null ? _destinationPlace!.name : '¿A dónde quieres ir?',
                                        style: TextStyle(
                                          color: _destinationPlace != null ? Colors.black87 : Colors.grey.shade600, 
                                          fontSize: 16, 
                                          fontWeight: _destinationPlace != null ? FontWeight.bold : FontWeight.w500
                                        ),
                                        maxLines: 1, // Si el nombre es muy largo, lo corta con puntos suspensivos
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (_destinationPlace != null)
                                      IconButton(
                                        icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () {
                                          setState(() {
                                            _destinationPlace = null;
                                            _selectedStop = null;
                                            _routeToDestination.clear();
                                          });
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10), // Espacio bajo el buscador
                          ],
                        ),
                      ),
                      // CONTENIDO DESPLAZABLE (Listas y Sugerencias)
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ACCESOS RÁPIDOS (NUEVO DISEÑO)
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              child: Row(
                                children: [
                                  _buildQuickActionChip(Icons.home_rounded, 'Casa', Colors.blue),
                                  const SizedBox(width: 12),
                                  _buildQuickActionChip(Icons.work_rounded, 'Trabajo', Colors.orange),
                                  const SizedBox(width: 12),
                                  _buildQuickActionChip(Icons.star_rounded, 'Favoritos', Colors.amber),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Padding(
                              padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 12),
                              child: Text(
                                'Explorar Circuitos',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // LISTA DE RUTAS MAPEADA A SLIVERS
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Widget extraído para mantener limpio el código principal.
  // Este widget tiene animaciones implícitas muy elegantes.
  Widget _buildRouteCard(RouteModel route, bool isActive, {bool isSuggested = false}) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isActive) {
            _activeRouteIds.remove(route.id);
            // Si apagamos la ruta y su parada estaba seleccionada, ocultamos la etiqueta
            if (_selectedStop != null && route.stops.contains(_selectedStop)) {
              _selectedStop = null;
            }
          } else {
            _activeRouteIds.add(route.id);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          // Si está activa, le ponemos un fondo muy transparente del color de su empresa
          color: isActive ? route.companyColor.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? route.companyColor.withOpacity(0.5) : Colors.grey.shade200,
            width: isActive ? 2 : 1,
          ),
          boxShadow: [
            if (!isActive)
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            // Ícono de la empresa
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: route.companyColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(Icons.directions_bus_rounded, color: route.companyColor),
              ),
            ),
            const SizedBox(width: 16),
            // Texto con la ruta
            Expanded(
              child: Text(
                route.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            // Check animado que aparece/desaparece
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isActive ? route.companyColor : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive ? route.companyColor : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: AnimatedScale(
                scale: isActive ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Nuevo Widget para los "Chips" de acciones rápidas
  Widget _buildQuickActionChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color.withOpacity(0.9), fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// NUEVO: Proveedor de mapas para guardar en caché (memoria y disco)
class CachedTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return CachedNetworkImageProvider(
      getTileUrl(coordinates, options),
      headers: const {
        'User-Agent': 'TransportesColectivosTabascoApp/1.0', // Obligatorio para OpenStreetMap
      },
    );
  }
}