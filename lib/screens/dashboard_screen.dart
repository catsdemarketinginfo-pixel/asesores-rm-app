import 'package:flutter/material.dart';

// Importamos los 6 archivos en orden de los TABS
import '../tabs/inicio.dart';
import '../tabs/inmuebles.dart';
import '../tabs/busquedas.dart';
import '../tabs/visitas.dart';
import '../tabs/catalogo.dart';
import '../tabs/documentos_tab.dart';

// Importamos la pantalla de login para poder redireccionar al cerrar sesión
import 'login_screen.dart'; 

class DashboardScreen extends StatefulWidget {
  final String nombreUsuario;
  const DashboardScreen({super.key, required this.nombreUsuario});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // Conectamos la barra inferior con el orden de las vistas
    _pages = [
      InicioTab(nombreUsuario: widget.nombreUsuario), // 0: Inicio
      const InmueblesTab(),                           // 1: Inmuebles
      const BusquedasTab(),                           // 2: Búsquedas
      const VisitasTab(),                             // 3: Visitas
      const CatalogoTab(),                            // 4: Catálogo
      const DocumentosTab(),                          // 5: Documentos
    ];
  }

  // =========================================================================
  // FUNCIÓN: Modal de confirmación para cerrar sesión
  // =========================================================================
  void _mostrarDialogoCerrarSesion(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cerrar Sesión', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('¿Estás seguro de que deseas salir de tu cuenta?', style: TextStyle(color: Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Cierra el modal sin hacer nada
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              // Navega al Login y ELIMINA todo el historial de pantallas hacia atrás
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (Route<dynamic> route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
            ),
            child: const Text('Salir', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // =====================================================================
      // BARRA SUPERIOR (APPBAR) MODIFICADA
      // =====================================================================
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: Image.asset('assets/asesores-rm-new-white.webp', height: 25),
        
        // 1. Lado Izquierdo (Avatar con la Inicial)
        leading: Padding(
          padding: const EdgeInsets.all(10.0),
          child: CircleAvatar(
            backgroundColor: Colors.grey.shade900,
            // Extraemos la primera letra del nombre del usuario
            child: Text(
              widget.nombreUsuario.isNotEmpty ? widget.nombreUsuario[0].toUpperCase() : 'U',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ),
        
        // 2. Lado Derecho (Botón de Cerrar Sesión)
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white, size: 22),
            tooltip: 'Cerrar Sesión',
            onPressed: () => _mostrarDialogoCerrarSesion(context),
          ),
          const SizedBox(width: 8), // Margen visual
        ],
      ),

      // CUERPO PRINCIPAL
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _pages[_selectedIndex],
      ),

      // BARRA DE NAVEGACIÓN INFERIOR
      bottomNavigationBar: Container(
        decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed, // Mantiene los 5 botones fijos y estables
          backgroundColor: Colors.white,
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 10), // Letra un poco más pequeña para que quepan los 5
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Inicio'),
            BottomNavigationBarItem(icon: Icon(Icons.home_work_outlined), activeIcon: Icon(Icons.home_work), label: 'Inmuebles'),
            BottomNavigationBarItem(icon: Icon(Icons.person_search_outlined), activeIcon: Icon(Icons.person_search), label: 'Búsquedas'),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_month_outlined), activeIcon: Icon(Icons.calendar_month), label: 'Visitas'),
            BottomNavigationBarItem(icon: Icon(Icons.grid_view_outlined), activeIcon: Icon(Icons.grid_view_rounded), label: 'Catálogo'),
            BottomNavigationBarItem(icon: Icon(Icons.folder_copy_outlined), activeIcon: Icon(Icons.folder_copy), label: 'Documentos'),
          ],
        ),
      ),
    );
  }
}