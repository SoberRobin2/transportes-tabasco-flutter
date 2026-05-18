import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/route_model.dart'; // Usamos StopModel para representar el lugar

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<StopModel> _searchResults = [];
  bool _isLoading = false;
  Timer? _debounce;

  // Sugerencias iniciales antes de buscar
  final List<StopModel> _suggestedPlaces = [
    // Los que confirmaste como BIEN
    StopModel(name: 'Plaza Altabrisa', location: const LatLng(17.96617955, -92.94080136)),
    StopModel(name: 'Plaza Las Américas', location: const LatLng(18.01441000, -92.91883000)),
    StopModel(name: 'Mercado Pino Suárez', location: const LatLng(17.99640556, -92.91436667)),
    // Los que estaban MAL, corregidos con la máxima precisión
    StopModel(name: 'Parque Tabasco Dora María', location: const LatLng(18.0152, -92.9696)),
    StopModel(name: 'Galerías Tabasco 2000', location: const LatLng(17.9967, -92.9465)),
    StopModel(name: 'Catedral del Señor de Tabasco', location: const LatLng(17.9878, -92.9421)),
    StopModel(name: 'Europlaza', location: const LatLng(17.9937, -92.9556)),
    StopModel(name: 'Parque Museo La Venta', location: const LatLng(18.0007, -92.9401)),
    StopModel(name: 'Ciudad Deportiva', location: const LatLng(17.9815, -92.9355)),
    StopModel(name: 'UJAT Zona de la Cultura', location: const LatLng(17.9942, -92.9356)),
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    // Si el usuario sigue escribiendo, cancelamos la búsqueda anterior
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    // Esperamos 800ms después de que el usuario deje de escribir para llamar a la API
    _debounce = Timer(const Duration(milliseconds: 800), () {
      _searchPlaces(query.trim());
    });
  }

  Future<void> _searchPlaces(String query) async {
    setState(() => _isLoading = true);

    try {
      // Consultamos la API pública y gratuita de OpenStreetMap (Nominatim)
      // Añadimos "Tabasco, Mexico" al query para que no busque cosas en otros países
      final Uri url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$query, Tabasco, Mexico&format=json&limit=15');
      
      final response = await http.get(url, headers: {
        // OpenStreetMap requiere identificar qué app usa su API
        'User-Agent': 'TransportesColectivosTabascoApp/1.0',
      });

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        
        if (mounted) {
          setState(() {
            _searchResults = data.map((item) {
              // A veces 'name' viene vacío, extraemos el nombre principal
              String placeName = item['name'] ?? '';
              if (placeName.isEmpty) {
                placeName = item['display_name'].split(',')[0];
              }
              return StopModel(
                name: placeName,
                location: LatLng(double.parse(item['lat']), double.parse(item['lon'])),
              );
            }).toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Error en la API de búsqueda: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: TextField(
          controller: _searchController,
          autofocus: true, // ¡Esta magia hace que el teclado se abra automáticamente!
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Buscar en Villahermosa...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey.shade400),
          ),
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                _onSearchChanged('');
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator()) // Cargando...
          : _searchController.text.isEmpty
              ? _buildSuggestionsList() // Mostrar sugerencias si no ha escrito nada
              : _searchResults.isEmpty
                  ? Center(child: Text('No se encontraron lugares', style: TextStyle(color: Colors.grey.shade500)))
                  : ListView.separated(
                      itemCount: _searchResults.length,
                      separatorBuilder: (context, index) => Divider(color: Colors.grey.shade100, height: 1),
                      itemBuilder: (context, index) {
                        final place = _searchResults[index];
                        return ListTile(
                          leading: const Icon(Icons.place, color: Colors.blue),
                          title: Text(place.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: const Text('Tabasco, México', style: TextStyle(color: Colors.grey, fontSize: 13)),
                          onTap: () {
                            // Ocultamos el teclado ANTES de regresar
                            FocusScope.of(context).unfocus();
                            Future.delayed(const Duration(milliseconds: 250), () {
                              if (mounted) Navigator.pop(context, place);
                            });
                          },
                        );
                      },
                    ),
    );
  }

  // Widget extraído para mostrar la lista de lugares más visitados
  Widget _buildSuggestionsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Text(
            'Lugares más visitados',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: _suggestedPlaces.length,
            separatorBuilder: (context, index) => Divider(color: Colors.grey.shade100, height: 1),
            itemBuilder: (context, index) {
              final place = _suggestedPlaces[index];
              return ListTile(
                leading: Icon(Icons.star_rounded, color: Colors.amber.shade400),
                title: Text(place.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: const Text('Villahermosa, Tabasco', style: TextStyle(color: Colors.grey, fontSize: 13)),
                onTap: () {
                  FocusScope.of(context).unfocus();
                  Future.delayed(const Duration(milliseconds: 250), () {
                    if (mounted) Navigator.pop(context, place);
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }
}