import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import '../services/mock_data.dart';
import '../services/routing_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _currentTask = "Iniciando sistema...";

  @override
  void initState() {
    super.initState();
    _runSystemChecklist();
  }

  Future<void> _runSystemChecklist() async {
    // Tarea 1: Verificación de Antena GPS
    setState(() => _currentTask = "Verificando antena GPS...");
    await Future.delayed(const Duration(milliseconds: 800)); // Suave pausa visual
    await Geolocator.isLocationServiceEnabled(); // Solo verificamos, ya no lo mostramos en lista

    // Tarea 2: Verificación de Servidor de Rutas (OSRM)
    setState(() => _currentTask = "Conectando con servidor OSRM...");
    try {
      // Hacemos un "ping" real al servidor para saber si hay internet y si está vivo
      await http.get(Uri.parse('https://router.project-osrm.org/route/v1/driving/-92.9475,17.9895;-92.9475,17.9895?overview=false')).timeout(const Duration(seconds: 3));
    } catch (e) {
      // Ignoramos el error de conexión, la app seguirá funcionando en modo offline
    }

    // Tarea 3: Cargando Caché Local (Mapas y Favoritos)
    setState(() => _currentTask = "Cargando caché y preferencias...");
    await initPreferences();

    // Tarea 4: Trazar y descargar las calles reales de las rutas
    final prefs = await SharedPreferences.getInstance();
    for (int i = 0; i < mockRoutes.length; i++) {
      setState(() => _currentTask = "Trazando calles... (${i + 1}/${mockRoutes.length})");
      final route = mockRoutes[i];
      bool isCached = prefs.containsKey('route_${route.id}');
      await RoutingService.getRoutePolyline(route.coordinates, routeId: route.id);
      if (!isCached) {
        await Future.delayed(const Duration(milliseconds: 300)); // Evita saturar el servidor OSRM la primera vez
      } else {
        // ¡CRUCIAL! Dale 25ms de respiro al procesador. Esto evita que el hilo principal se bloquee y salva a la app del Signal 3.
        await Future.delayed(const Duration(milliseconds: 25));
      }
    }

    // Tarea 5: Preparación del entorno de la aplicación
    setState(() => _currentTask = "Pintando mapa base...");
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() {
        _currentTask = "¡Todo listo para iniciar! 🚀";
      });
    }
    
    await Future.delayed(const Duration(milliseconds: 600));

    // Transición elegante hacia la pantalla principal
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const MainNavigator(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Fondo negro idéntico al splash nativo por defecto
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            // El clásico logo de Flutter centrado
            const FlutterLogo(size: 140),
            const Spacer(),
            // Indicador de carga minimalista
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min, // Se adapta al texto
                children: [
                  if (_currentTask != "¡Todo listo para iniciar! 🚀")
                    const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.blueAccent),
                    )
                  else
                    const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 22),
                  const SizedBox(width: 16),
                  Text(
                    _currentTask, 
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}