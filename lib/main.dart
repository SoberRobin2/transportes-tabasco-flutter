import 'package:flutter/material.dart';
import 'package:app_de_rutas_de_transporte_en_villahermosa/screens/map_screen.dart';
import 'package:app_de_rutas_de_transporte_en_villahermosa/screens/routes_search_screen.dart';
import 'package:app_de_rutas_de_transporte_en_villahermosa/screens/favorites_screen.dart';
import 'package:app_de_rutas_de_transporte_en_villahermosa/screens/splash_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App de rutas de transporte en Villahermosa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // APLICANDO EL DESIGN SYSTEM SOLICITADO
        scaffoldBackgroundColor: const Color(0xFFF5F7FA), // Fondo casi blanco muy limpio
        primaryColor: const Color(0xFF1565C0), // Azul Primario (Azul Rey)
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          primary: const Color(0xFF1565C0),
          surface: const Color(0xFFF5F7FA),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1565C0),
          foregroundColor: Colors.white,
          centerTitle: true,
          shape: RoundedRectangleBorder(
            // Esquinas inferiores redondeadas solicitadas
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600), // 24sp Semi-Bold
          bodyLarge: TextStyle(color: Color(0xFF1A1A1A), fontSize: 16, fontWeight: FontWeight.w500), // Textos principales
          bodyMedium: TextStyle(color: Color(0xFF757575), fontSize: 14), // Textos secundarios
        ),
      ),
      home: const SplashScreen(), // Ahora iniciamos en la pantalla de carga (Checklist)
    );
  }
}

// WIDGET DE NAVEGACIÓN (Implementando el BottomNavigationBar solicitado)
class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _currentIndex = 0;

  // Aquí irán las nuevas pantallas del diseño
  final List<Widget> _screens = [
    const MapScreen(), 
    const RoutesSearchScreen(), // Directorio de Rutas
    const FavoritesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF1565C0), // Azul primario
        unselectedItemColor: const Color(0xFF757575), // Gris
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), activeIcon: Icon(Icons.map_rounded), label: 'Mapa'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_bus_outlined), activeIcon: Icon(Icons.directions_bus_rounded), label: 'Rutas'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite_outline), activeIcon: Icon(Icons.favorite_rounded), label: 'Favoritos'),
        ],
      ),
    );
  }
}
