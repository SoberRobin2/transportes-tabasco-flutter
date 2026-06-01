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

  // Lista de base de datos local con todas las coordenadas.
  final List<StopModel> _localPlaces = [
    StopModel(name: 'Plaza Altabrisa', location: const LatLng(17.96617955, -92.94080136)),
    StopModel(name: 'Parque Tabasco Dora María', location: const LatLng(18.015200, -92.969600)), // Corregida (la anterior apuntaba a otro lado)
    StopModel(name: 'Galerías Tabasco 2000', location: const LatLng(17.996700, -92.946500)), // Corregida
    StopModel(name: 'Parque Tomás Garrido Canabal', location: const LatLng(17.99866610, -92.93607057)),
    StopModel(name: 'Catedral del Señor de Tabasco', location: const LatLng(17.987800, -92.942100)), // Corregida
    StopModel(name: 'Plaza Las Américas', location: const LatLng(18.01441000, -92.91883000)),
    StopModel(name: 'Mercado Pino Suárez', location: const LatLng(17.99640556, -92.91436667)),
    StopModel(name: 'Ciudad Deportiva', location: const LatLng(17.981500, -92.935500)), // Corregida
    StopModel(name: 'UJAT Zona de la Cultura', location: const LatLng(17.994200, -92.935600)), // Corregida
    StopModel(name: 'ITVH', location: const LatLng(17.96430000, -92.94320000)),
    StopModel(name: 'UAG', location: const LatLng(17.99300000, -92.92600000)),
    StopModel(name: 'Hospital Rovirosa', location: const LatLng(17.98250000, -92.95750000)),
    StopModel(name: 'Hospital Juan Graham', location: const LatLng(17.95690000, -92.95240000)),
    StopModel(name: 'Hospital Ángeles', location: const LatLng(17.99390000, -92.96380000)),
    StopModel(name: 'Terminal ADO', location: const LatLng(17.98680000, -92.93880000)),
    StopModel(name: 'Central Camionera', location: const LatLng(17.97090000, -92.94940000)),
    StopModel(name: 'Zona arqueológica de Comalcalco', location: const LatLng(18.26690000, -93.22090000)),
    StopModel(name: 'Tapijulapa', location: const LatLng(17.45880000, -92.76270000)),
    StopModel(name: 'Palacio de Gobierno', location: const LatLng(17.98630000, -92.93150000)),
    StopModel(name: 'Fiscalía General del Estado', location: const LatLng(17.98690000, -92.93490000)),
    StopModel(name: 'Central Camionera Cunduacán', location: const LatLng(18.066200, -93.174600)),
    StopModel(name: 'Central Cardesa (Villahermosa)', location: const LatLng(17.996200, -92.914000)),
  ];
  
  // Obtenemos las primeras 8 para sugerencias rápidas
  List<StopModel> get _suggestedPlaces => _localPlaces.take(8).toList();

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

    // 1. Filtrar los lugares locales INMEDIATAMENTE
    final localMatches = _localPlaces
        .where((place) => place.name.toLowerCase().contains(query.trim().toLowerCase()))
        .toList();

    setState(() {
      _searchResults = localMatches;
      _isLoading = true; // Mostramos cargando porque también buscaremos en internet
    });

    // Esperamos 800ms después de que el usuario deje de escribir para llamar a la API
    _debounce = Timer(const Duration(milliseconds: 800), () {
      _searchPlaces(query.trim(), localMatches);
    });
  }

  Future<void> _searchPlaces(String query, List<StopModel> localMatches) async {
    try {
      final Uri url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$query, Tabasco, Mexico&format=json&limit=15');
      
      final response = await http.get(url, headers: {
        // OpenStreetMap requiere identificar qué app usa su API
        'User-Agent': 'AppDeRutasVillahermosa/1.0',
      });

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        
        if (mounted) {
          setState(() {
            final apiResults = data.map((item) {
              String placeName = item['name'] ?? '';
              if (placeName.isEmpty) {
                placeName = item['display_name'].split(',')[0];
              }
              return StopModel(
                name: placeName,
                location: LatLng(double.parse(item['lat']), double.parse(item['lon'])),
              );
            }).toList();
            
            // Combinamos los resultados locales con los de la API, evitando repetidos
            final localNames = localMatches.map((e) => e.name.toLowerCase()).toSet();
            final uniqueApiResults = apiResults.where((api) => !localNames.contains(api.name.toLowerCase())).toList();
            
            _searchResults = [...localMatches, ...uniqueApiResults];
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
                          onTap: () async {
                            // Ocultamos el teclado ANTES de regresar
                            FocusScope.of(context).unfocus();
                            await Future.delayed(const Duration(milliseconds: 250));
                            if (!context.mounted) return;
                            Navigator.pop(context, place);
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
                onTap: () async {
                  FocusScope.of(context).unfocus();
                  await Future.delayed(const Duration(milliseconds: 250));
                  if (!context.mounted) return;
                  Navigator.pop(context, place);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}