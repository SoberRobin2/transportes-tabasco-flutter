import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/route_model.dart';
import '../services/routing_service.dart';
import '../services/mock_data.dart';

class RouteDetailScreen extends StatefulWidget {
  final RouteModel route;
  const RouteDetailScreen({super.key, required this.route});

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final route = widget.route;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ENCABEZADO DINÁMICO (Toma el color de la combi)
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: route.companyColor, // ¡Pinta toda la barra del color oficial!
            actions: [
              IconButton(
                icon: Icon(
                  favoriteRouteIds.contains(route.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    toggleFavorite(route.id);
                  });
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                padding: const EdgeInsets.only(top: 80, left: 24, right: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: CircleAvatar(backgroundColor: route.companyColor, radius: 12),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(route.name, style: Theme.of(context).textTheme.titleLarge, maxLines: 2)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      route.stops.isNotEmpty ? '${route.stops.first.name} -> ${route.stops.last.name}' : 'Ruta circular',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // CUADRÍCULA DE DATOS (Grid Pantalla 4)
                  Row(
                    children: [
                      Expanded(child: _buildInfoBlock(route.stops.length.toString(), 'Paradas totales')),
                      const SizedBox(width: 16),
                      Expanded(child: _buildInfoBlock(route.duration, 'Duración aprox')),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // LISTA DE DATOS TÉCNICOS
                  _buildDataRow(Icons.access_time_rounded, 'Horario de servicio', route.schedule),
                  const Divider(color: Color(0xFFE0E0E0)),
                  _buildDataRow(Icons.update_rounded, 'Frecuencia', route.frequency),
                  const Divider(color: Color(0xFFE0E0E0)),
                  _buildDataRow(Icons.payments_rounded, 'Tarifa', route.fare),
                  const Divider(color: Color(0xFFE0E0E0)),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.color_lens_rounded, color: route.companyColor), // Icono dinámico
                        const SizedBox(width: 16),
                        const Text('Color de combi', style: TextStyle(fontSize: 14, color: Color(0xFF757575))),
                        const Spacer(),
                        Container(width: 24, height: 24, decoration: BoxDecoration(color: route.companyColor, shape: BoxShape.circle)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text('Recorrido en mapa', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
                  const SizedBox(height: 16),
                  _buildMiniMap(),
                  const SizedBox(height: 32),
                  const Text('Línea de paradas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
                  const SizedBox(height: 16),
                  // LÍNEA DE TIEMPO (Timeline Pantalla 3)
                  ...route.stops.asMap().entries.map((entry) {
                    int idx = entry.key;
                    var stop = entry.value;
                    bool isFirst = idx == 0;
                    bool isLast = idx == route.stops.length - 1;
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Column(
                            children: [
                              Container(width: 2, height: 16, color: isFirst ? Colors.transparent : const Color(0xFFE0E0E0)),
                              Container(
                                width: 14, height: 14,
                                decoration: BoxDecoration(
                                  color: isFirst || isLast ? route.companyColor : Colors.white,
                                  border: Border.all(color: route.companyColor, width: 3),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Expanded(child: Container(width: 2, color: isLast ? Colors.transparent : const Color(0xFFE0E0E0))),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  Expanded(child: Text(stop.name, style: Theme.of(context).textTheme.bodyLarge)),
                                  if (isFirst)
                                    _buildBadge('Inicio', Colors.green),
                                  if (isLast)
                                    _buildBadge('Final', Colors.red),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBlock(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0E0E0))),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: widget.route.companyColor)), // Títulos dinámicos
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 14, color: Color(0xFF757575))),
        ],
      ),
    );
  }

  Widget _buildDataRow(IconData icon, String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Row(children: [Icon(icon, color: widget.route.companyColor), const SizedBox(width: 16), Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF757575)))), Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)))]));
  }

  Widget _buildBadge(String text, Color color) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)));
  }

  // Widget extraído para el Mini-Mapa de previsualización
  Widget _buildMiniMap() {
    final route = widget.route; // <- Añadimos esta línea para definir 'route'

    // Calculamos los límites para que quepa toda la ruta en la tarjeta
    final bounds = LatLngBounds.fromPoints(route.coordinates);

    return Container(
      height: 220, // Altura fija para la tarjeta del mapa
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FutureBuilder<List<LatLng>>(
          future: RoutingService.getRoutePolyline(route.coordinates),
          builder: (context, snapshot) {
            final points = snapshot.data ?? route.coordinates;
            
            return FlutterMap(
              options: MapOptions(
                initialCameraFit: CameraFit.bounds(
                  bounds: bounds,
                  padding: const EdgeInsets.all(24),
                ),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none, // Desactiva gestos para no estorbar el scroll de la pantalla
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.app_de_rutas_de_transporte_en_villahermosa',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(points: points, color: route.companyColor, strokeWidth: 5.0),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    if (route.stops.isNotEmpty)
                      Marker(point: route.stops.first.location, width: 14, height: 14, child: Container(decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
                    if (route.stops.isNotEmpty)
                      Marker(point: route.stops.last.location, width: 14, height: 14, child: Container(decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}