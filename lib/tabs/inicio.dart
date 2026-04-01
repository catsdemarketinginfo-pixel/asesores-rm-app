import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class InicioTab extends StatefulWidget {
  final String nombreUsuario;

  const InicioTab({super.key, required this.nombreUsuario});

  @override
  State<InicioTab> createState() => _InicioTabState();
}

class _InicioTabState extends State<InicioTab> {
  bool _isLoading = true;
  int _totalProperties = 0;
  List<dynamic> _statusMetrics = [];
  List<dynamic> _monthMetrics = [];
  String _currentYear = '';

  @override
  void initState() {
    super.initState();
    _fetchMetrics();
  }

  Future<void> _fetchMetrics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/mobile/dashboard/metrics'),
        headers: {'Authorization': 'Bearer ${prefs.getString('jwt_token')}'},
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        setState(() {
          _totalProperties = body['data']['total'] ?? 0;
          _statusMetrics = body['data']['by_status'] ?? [];
          _monthMetrics = body['data']['by_month'] ?? [];
          _currentYear = body['data']['year']?.toString() ?? '';
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _fetchMetrics,
      color: Colors.black,
      child: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.black))
        : SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SALUDO
                Text('¡Hola, ${widget.nombreUsuario}!', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.black)),
                const Text('Aquí tienes el resumen de tu gestión.', style: TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 24),

                // TARJETA PRINCIPAL (Total)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.real_estate_agent, color: Colors.white70, size: 30),
                      const SizedBox(height: 16),
                      Text(_totalProperties.toString(), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white, height: 1)),
                      const Text('Inmuebles Captados Totales', style: TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ESTATUS (Cuadrícula dinámica)
                const Text('Inmuebles por Estatus', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                if (_statusMetrics.isEmpty)
                  const Text('No hay propiedades registradas.', style: TextStyle(color: Colors.grey))
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.2
                    ),
                    itemCount: _statusMetrics.length,
                    itemBuilder: (context, index) {
                      final item = _statusMetrics[index];
                      // Asignar colores según estatus (puedes ajustarlos a los de tu marca)
                      Color dotColor = Colors.blue;
                      String statusName = item['name']?.toString().toLowerCase() ?? '';
                      if (statusName.contains('aprobado') || statusName.contains('activo')) dotColor = Colors.green;
                      if (statusName.contains('sin aprobar') || statusName.contains('pausa')) dotColor = Colors.orange;
                      if (statusName.contains('vendido') || statusName.contains('rechazado')) dotColor = Colors.red;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                        child: Row(
                          children: [
                            Container(width: 12, height: 12, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['count'].toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, height: 1)),
                                  Text(item['name'] ?? 'Desconocido', style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            )
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 32),

                // GRÁFICO MES A MES (Hecho en casa)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Captaciones en el Año', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    Text(_currentYear, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSimpleBarChart(),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
    );
  }

  // --- WIDGET PARA UN GRÁFICO DE BARRAS SENCILLO Y HERMOSO ---
  Widget _buildSimpleBarChart() {
    if (_monthMetrics.isEmpty) {
      return Container(
        width: double.infinity, padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
        child: const Center(child: Text('Aún no tienes captaciones este año.', style: TextStyle(color: Colors.grey))),
      );
    }

    // Buscamos el mes con más captaciones para definir la altura máxima (100%)
    int maxCount = 1;
    for (var m in _monthMetrics) {
      if (m['count'] > maxCount) maxCount = m['count'];
    }

    return Container(
      height: 180,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: _monthMetrics.map((data) {
          // Calculamos la altura de la barra en porcentaje
          double fillPercentage = data['count'] / maxCount;
          
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(data['count'].toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Container(
                width: 24,
                height: 100 * fillPercentage, // Altura máxima de la barra es 100px
                decoration: BoxDecoration(color: Colors.blue.shade600, borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(height: 8),
              Text(data['month'], style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
            ],
          );
        }).toList(),
      ),
    );
  }
}