import 'package:flutter/material.dart';
import 'package:app_de_rutas_de_transporte_en_villahermosa/screens/map_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Transportes Colectivos de Tabasco',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const MapScreen(), // Conectamos nuestra nueva pantalla aquí
    );
  }
}
