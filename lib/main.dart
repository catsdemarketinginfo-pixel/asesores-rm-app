import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart'; // 1. IMPORTAMOS LA LIBRERÍA DE IDIOMAS
import 'screens/login_screen.dart'; 

void main() async {
  // 2. ASEGURAMOS QUE FLUTTER ESTÉ INICIALIZADO ANTES DE CARGAR DATOS
  WidgetsFlutterBinding.ensureInitialized();
  
  // 3. INICIALIZAMOS EL IDIOMA ESPAÑOL PARA LAS FECHAS
  await initializeDateFormatting('es', null); 

  runApp(const AgilizadorApp());
}

class AgilizadorApp extends StatelessWidget {
  const AgilizadorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Asesores RM',
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Colors.black, 
          secondary: Color(0xFF8C8C8C), 
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        useMaterial3: true,
        fontFamily: 'Roboto', 
      ),
      home: const LoginScreen(), 
    );
  }
}