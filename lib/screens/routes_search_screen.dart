import 'package:flutter/material.dart';
import '../services/mock_data.dart';
import '../models/route_model.dart';
import 'route_detail_screen.dart';

class RoutesSearchScreen extends StatefulWidget {
  const RoutesSearchScreen({super.key});

  @override
  State<RoutesSearchScreen> createState() => _RoutesSearchScreenState();
}

class _RoutesSearchScreenState extends State<RoutesSearchScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    // Filtrar rutas por nombre
    final filteredRoutes = mockRoutes.where((r) => r.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Directorio de Rutas'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: const InputDecoration(
                  hintText: 'Buscar combi (ej. Movitab, Ruta 60)...',
                  hintStyle: TextStyle(color: Color(0xFF757575)),
                  prefixIcon: Icon(Icons.search, color: Color(0xFF757575)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: filteredRoutes.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final route = filteredRoutes[index];
          return _buildRouteCard(context, route);
        },
      ),
    );
  }

  Widget _buildRouteCard(BuildContext context, RouteModel route) {
    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => RouteDetailScreen(route: route)));
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: route.companyColor, radius: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(route.name, style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 4),
                  Text('Pasa por ${route.stops.isNotEmpty ? route.stops.last.name : "Varios puntos"}', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${route.stops.length} paradas', style: const TextStyle(color: Color(0xFF757575), fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(route.frequency.split(' ').take(3).join(' '), style: const TextStyle(color: Color(0xFF757575), fontSize: 12)),
              ],
            )
          ],
        ),
      ),
    );
  }
}