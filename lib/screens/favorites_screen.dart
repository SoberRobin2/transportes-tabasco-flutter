import 'package:flutter/material.dart';
import '../services/mock_data.dart';
import 'route_detail_screen.dart';
import 'routes_search_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  Widget build(BuildContext context) {
    final favoriteRoutes = mockRoutes.where((r) => favoriteRouteIds.contains(r.id)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis favoritos'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(30),
          child: Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text('Rutas guardadas frecuentes', style: TextStyle(color: Colors.white70, fontSize: 14)),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: favoriteRoutes.isEmpty
                ? const Center(child: Text('Aún no tienes rutas favoritas', style: TextStyle(color: Color(0xFF757575))))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: favoriteRoutes.length,
                    itemBuilder: (context, index) {
                      final route = favoriteRoutes[index];
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE0E0E0))),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: CircleAvatar(backgroundColor: route.companyColor, radius: 24),
                          title: Text(route.name, style: Theme.of(context).textTheme.bodyLarge),
                          subtitle: Text('${route.stops.length} paradas', style: Theme.of(context).textTheme.bodyMedium),
                          trailing: IconButton(
                            icon: const Icon(Icons.bookmark_remove_rounded, color: Color(0xFF1565C0)),
                            onPressed: () {
                              setState(() {
                                toggleFavorite(route.id);
                              });
                            },
                          ),
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => RouteDetailScreen(route: route))).then((_) {
                              setState(() {}); // Actualiza la lista por si se quitó el favorito desde los detalles
                            });
                          },
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RoutesSearchScreen()),
                ).then((_) => setState(() {})); // Refresca la lista al volver
              },
              icon: const Icon(Icons.add, color: Color(0xFF1565C0)),
              label: const Text('Agregar ruta favorita', style: TextStyle(color: Color(0xFF1565C0), fontSize: 16, fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }
}