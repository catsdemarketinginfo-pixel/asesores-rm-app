import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; 
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class VisitasTab extends StatefulWidget {
  const VisitasTab({super.key});

  @override
  State<VisitasTab> createState() => _VisitasTabState();
}

class _VisitasTabState extends State<VisitasTab> {
  // --- ESTADOS DE DATOS Y PAGINACIÓN ---
  List<dynamic> _visitas = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _errorMessage = '';
  
  int _currentPage = 1;
  final int _limit = 15;
  int _totalVisits = 0;

  // --- FILTROS ---
  String _searchQuery = '';
  
  // MAGIA UX: Inicializamos los filtros con el mes y año actual
  String? _selectedMonth = DateTime.now().month.toString();
  String? _selectedYear = DateTime.now().year.toString();
  
  Timer? _debounce;
  final ScrollController _scrollController = ScrollController();

  // --- CATÁLOGOS DE FILTROS ---
  final List<String> _years = List.generate(10, (index) => (DateTime.now().year - index).toString());
  final List<Map<String, String>> _months = [
    {'id': '1', 'name': 'Enero'}, {'id': '2', 'name': 'Febrero'}, {'id': '3', 'name': 'Marzo'},
    {'id': '4', 'name': 'Abril'}, {'id': '5', 'name': 'Mayo'}, {'id': '6', 'name': 'Junio'},
    {'id': '7', 'name': 'Julio'}, {'id': '8', 'name': 'Agosto'}, {'id': '9', 'name': 'Septiembre'},
    {'id': '10', 'name': 'Octubre'}, {'id': '11', 'name': 'Noviembre'}, {'id': '12', 'name': 'Diciembre'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchVisitas(refresh: true);
    
    // Listener para Paginación Asíncrona (Infinite Scroll)
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (_hasMore && !_isLoadingMore && !_isLoading) {
          _fetchVisitas(refresh: false);
        }
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  // =========================================================================
  // BÚSQUEDA CON DEBOUNCE
  // =========================================================================
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() { _searchQuery = query; });
      _fetchVisitas(refresh: true);
    });
  }

  // =========================================================================
  // 1. LEER VISITAS (GET) CON PAGINACIÓN Y FILTROS
  // =========================================================================
  Future<void> _fetchVisitas({required bool refresh}) async {
    if (refresh) {
      setState(() { _isLoading = true; _errorMessage = ''; _currentPage = 1; _hasMore = true; _visitas.clear(); });
    } else {
      setState(() { _isLoadingMore = true; });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null) {
        setState(() { _errorMessage = 'Sesión caducada.'; _isLoading = false; _isLoadingMore = false; });
        return;
      }

      // Armamos la URL con los Query Parameters
      String url = '${ApiConfig.apiMobileVisits}?page=$_currentPage&limit=$_limit';
      if (_searchQuery.isNotEmpty) url += '&search=$_searchQuery';
      if (_selectedMonth != null) url += '&month=$_selectedMonth';
      if (_selectedYear != null) url += '&year=$_selectedYear';

      final response = await http.get(Uri.parse(url), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> fetchedVisits = data['data'] ?? [];
        final pagination = data['pagination'];

        setState(() {
          if (refresh) {
            _visitas = fetchedVisits;
          } else {
            _visitas.addAll(fetchedVisits);
          }
          
          _totalVisits = pagination['total'];
          _currentPage++;
          _hasMore = _currentPage <= pagination['total_pages'];
          _isLoading = false;
          _isLoadingMore = false;
        });
      } else {
        setState(() { _errorMessage = 'Error del servidor: ${response.statusCode}'; _isLoading = false; _isLoadingMore = false; });
      }
    } catch (e) {
      setState(() { _errorMessage = 'Error de conexión'; _isLoading = false; _isLoadingMore = false; });
    }
  }

  // =========================================================================
  // 2. GUARDAR / EDITAR
  // =========================================================================
  Future<void> _saveVisita(Map<String, dynamic> data, {int? id}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator(color: Colors.white)));

    try {
      http.Response response;
      if (id == null) {
        response = await http.post(Uri.parse(ApiConfig.apiMobileVisits), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'}, body: jsonEncode(data));
      } else {
        response = await http.put(Uri.parse('${ApiConfig.apiMobileVisits}/$id'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'}, body: jsonEncode(data));
      }
      Navigator.pop(context);

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.pop(context);
        _fetchVisitas(refresh: true); // Recargamos la lista
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Visita guardada!'), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: ${response.statusCode}'), backgroundColor: Colors.red));
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error de conexión'), backgroundColor: Colors.red));
    }
  }

  // =========================================================================
  // 3. ELIMINAR
  // =========================================================================
  Future<void> _deleteVisita(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    try {
      final response = await http.delete(Uri.parse('${ApiConfig.apiMobileVisits}/$id'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'});
      if (response.statusCode == 200) {
        _fetchVisitas(refresh: true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Visita eliminada'), backgroundColor: Colors.black));
      }
    } catch (e) { print(e); }
  }

  // =========================================================================
  // UI: FORMULARIO (Añadir/Editar)
  // =========================================================================
  void _showVisitForm({Map<String, dynamic>? visit}) {
    final bool isEdit = visit != null;
    final TextEditingController descCtrl = TextEditingController(text: isEdit ? visit['description'] : '');
    DateTime selectedDate = isEdit ? (DateTime.tryParse(visit['date_at']?.toString() ?? '') ?? DateTime.now()) : DateTime.now();
    TimeOfDay selectedTime = TimeOfDay(hour: selectedDate.hour, minute: selectedDate.minute);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setModalState) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(isEdit ? 'Editar Visita' : 'Añadir Visita', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                          IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context))
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: descCtrl,
                        maxLines: 4,
                        decoration: InputDecoration(hintText: 'Descripción...', filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final date = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                                if (date != null) setModalState(() => selectedDate = date);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.calendar_today, size: 16), const SizedBox(width: 8), Text(DateFormat('dd/MM/yyyy').format(selectedDate), style: const TextStyle(fontWeight: FontWeight.bold))]),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final time = await showTimePicker(context: context, initialTime: selectedTime);
                                if (time != null) setModalState(() => selectedTime = time);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.access_time, size: 16), const SizedBox(width: 8), Text(selectedTime.format(context), style: const TextStyle(fontWeight: FontWeight.bold))]),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity, height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: Text(isEdit ? 'GUARDAR CAMBIOS' : 'AÑADIR VISITA', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            if (descCtrl.text.isEmpty) return;
                            final finalDateTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute);
                            final data = {'description': descCtrl.text, 'date_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(finalDateTime)};
                            _saveVisita(data, id: isEdit ? int.parse(visit['id'].toString()) : null);
                          },
                        ),
                      )
                    ],
                  );
                }
              ),
            ),
          ),
        );
      }
    );
  }

  // =========================================================================
  // UI PRINCIPAL
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // CABECERA Y FILTROS
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Visitas Agendadas', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black)),
                    Text('$_totalVisits total', style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                
                // BUSCADOR DE TEXTO
                TextField(
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Buscar por descripción...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true, fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                // FILTROS DE FECHA (MES Y AÑO)
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedMonth,
                        decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 12), filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                        hint: const Text('Mes', style: TextStyle(fontSize: 14)),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Todos los meses', style: TextStyle(fontSize: 14))),
                          ..._months.map((m) => DropdownMenuItem(value: m['id'], child: Text(m['name']!, style: const TextStyle(fontSize: 14)))).toList()
                        ],
                        onChanged: (val) { setState(() => _selectedMonth = val); _fetchVisitas(refresh: true); },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedYear,
                        decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 12), filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                        hint: const Text('Año', style: TextStyle(fontSize: 14)),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Todos los años', style: TextStyle(fontSize: 14))),
                          ..._years.map((y) => DropdownMenuItem(value: y, child: Text(y, style: const TextStyle(fontSize: 14)))).toList()
                        ],
                        onChanged: (val) { setState(() => _selectedYear = val); _fetchVisitas(refresh: true); },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // LISTADO DE RESULTADOS
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.black))
                : _errorMessage.isNotEmpty
                    ? Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(_errorMessage, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold), textAlign: TextAlign.center)))
                    : _visitas.isEmpty
                        ? const Center(child: Text('No hay visitas con estos filtros', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)))
                        : RefreshIndicator(
                            onRefresh: () => _fetchVisitas(refresh: true),
                            color: Colors.black,
                            child: ListView.builder(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(), // Evita que se trave si hay poquitos elementos
                              padding: const EdgeInsets.all(16),
                              itemCount: _visitas.length + (_isLoadingMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == _visitas.length) {
                                  return const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator(color: Colors.black)));
                                }
                                return _buildVisitaCard(_visitas[index]);
                              },
                            ),
                          ),
          ),
        ],
      ),
      
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        onPressed: () => _showVisitForm(), 
      ),
    );
  }

  // =========================================================================
  // WIDGET: TARJETA DE VISITA
  // =========================================================================
  Widget _buildVisitaCard(Map<String, dynamic> visita) {
    DateTime dateAt = DateTime.tryParse(visita['date_at']?.toString() ?? '') ?? DateTime.now();
    String month = DateFormat('MMM', 'es').format(dateAt).toUpperCase();
    String day = DateFormat('dd').format(dateAt);
    String time = DateFormat('hh:mm a').format(dateAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 80,
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)), border: Border(right: BorderSide(color: Colors.grey.shade200))),
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(month, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.red.shade600, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(day, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black, height: 1)),
                  const SizedBox(height: 8),
                  Text(time, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600), textAlign: TextAlign.center),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(visita['description'] ?? 'Sin descripción', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87, height: 1.4))),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                      onSelected: (value) {
                        if (value == 'edit') _showVisitForm(visit: visita);
                        if (value == 'delete') {
                          showDialog(context: context, builder: (c) => AlertDialog(
                            title: const Text('Eliminar Visita', style: TextStyle(fontWeight: FontWeight.bold)),
                            content: const Text('¿Estás seguro de que deseas eliminar esta visita?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
                              ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () { Navigator.pop(c); _deleteVisita(int.parse(visita['id'].toString())); }, child: const Text('Eliminar', style: TextStyle(color: Colors.white)))
                            ],
                          ));
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text('Editar')])),
                        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 16, color: Colors.red), SizedBox(width: 8), Text('Eliminar', style: TextStyle(color: Colors.red))])),
                      ],
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}