import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart'; 
import '../config/api_config.dart';

class BusquedasTab extends StatefulWidget {
  const BusquedasTab({super.key});

  @override
  State<BusquedasTab> createState() => _BusquedasTabState();
}

class _BusquedasTabState extends State<BusquedasTab> {
  List<dynamic> _allSearches = [];
  List<dynamic> _mySearches = [];
  
  List<dynamic> _housingTypes = [];
  List<dynamic> _businessModels = [];
  
  bool _isLoadingAll = true;
  bool _isLoadingMine = true;
  
  String _errorAll = '';
  String _errorMine = '';

  @override
  void initState() {
    super.initState();
    _fetchFormData(); 
    _fetchAllSearches();
    _fetchMySearches();
  }

  // =========================================================================
  // CARGAR CATÁLOGOS DINÁMICOS
  // =========================================================================
  Future<void> _fetchFormData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/mobile/searches/form-data'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        setState(() {
          _housingTypes = body['data']['housing_types'] ?? [];
          _businessModels = body['data']['business_models'] ?? [];
        });
      }
    } catch (e) {
      print("Error cargando catálogos: $e");
    }
  }

  // =========================================================================
  // WHATSAPP
  // =========================================================================
  Future<void> _shareOnWhatsApp(Map<String, dynamic> search) async {
    final String type = (search['housingtype_name']?.toString() ?? 'INMUEBLE').toUpperCase();
    final String business = (search['businessmodel_name']?.toString() ?? 'NEGOCIO').toUpperCase();
    final String location = search['location']?.toString() ?? 'Ubicación a convenir';
    final String desc = search['description']?.toString() ?? '';
    final String price = search['estimate_price']?.toString() ?? '0';
    final String agent = search['author']?.toString() ?? 'Asesor RM';

    final String message = 
      "Asesores RM está en la búsqueda de:\n\n"
      "🔎 *$type EN $business* 🔎\n\n"
      "📍 Ubicado en $location\n\n"
      "✍️ El cliente se encuentra altamente interesado. Detalles:\n"
      "$desc\n\n"
      "REF: $price\n\n"
      "👤 Agente: $agent\n\n"
      "📞 Teléfono: +58 4120388680";

    final Uri url = Uri.parse("https://wa.me/?text=${Uri.encodeComponent(message)}");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir WhatsApp')));
    }
  }

  // =========================================================================
  // API: LÓGICA DE DATOS
  // =========================================================================
  Future<void> _fetchAllSearches() async {
    setState(() { _isLoadingAll = true; _errorAll = ''; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/mobile/searches/all'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() { _allSearches = data['data'] ?? []; _isLoadingAll = false; });
      } else {
        setState(() { _errorAll = 'Error al cargar búsquedas generales.'; _isLoadingAll = false; });
      }
    } catch (e) {
      setState(() { _errorAll = 'Error de conexión'; _isLoadingAll = false; });
    }
  }

  Future<void> _fetchMySearches() async {
    setState(() { _isLoadingMine = true; _errorMine = ''; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/mobile/searches/me'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() { _mySearches = data['data'] ?? []; _isLoadingMine = false; });
      } else {
        setState(() { _errorMine = 'Error al cargar tus búsquedas.'; _isLoadingMine = false; });
      }
    } catch (e) {
      setState(() { _errorMine = 'Error de conexión'; _isLoadingMine = false; });
    }
  }

  Future<void> _saveSearch(Map<String, dynamic> data, {int? id}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator(color: Colors.white)));

    try {
      http.Response response;
      if (id == null) {
        response = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/api/v1/mobile/searches'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
          body: jsonEncode(data),
        );
      } else {
        response = await http.put(
          Uri.parse('${ApiConfig.baseUrl}/api/v1/mobile/searches/$id'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
          body: jsonEncode(data),
        );
      }

      Navigator.pop(context); // Cierra loading

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.pop(context); // Cierra modal
        _fetchAllSearches(); 
        _fetchMySearches();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Publicación guardada exitosamente!'), backgroundColor: Colors.green));
      } else {
        String errorMsg = 'Error ${response.statusCode}';
        try {
          final body = jsonDecode(response.body);
          errorMsg = body['message']?.toString() ?? body['messages']?.toString() ?? errorMsg;
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.red, duration: const Duration(seconds: 4)));
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error de conexión con el servidor'), backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteSearch(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/mobile/searches/$id'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        _fetchAllSearches();
        _fetchMySearches();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Búsqueda eliminada correctamente'), backgroundColor: Colors.black));
      }
    } catch (e) {
      print(e);
    }
  }

  // =========================================================================
  // UI: FORMULARIO
  // =========================================================================
  void _showSearchForm({Map<String, dynamic>? search}) {
    if (_businessModels.isEmpty || _housingTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cargando catálogos... intenta de nuevo.')));
      _fetchFormData();
      return;
    }

    final bool isEdit = search != null;
    
    final TextEditingController descCtrl = TextEditingController(text: isEdit ? search['description']?.toString() : '');
    final TextEditingController priceCtrl = TextEditingController(text: isEdit ? search['estimate_price']?.toString() : '');
    final TextEditingController locationCtrl = TextEditingController(text: isEdit ? search['location']?.toString() : '');
    
    bool businessExists = isEdit && _businessModels.any((b) => b['id'].toString() == search['id_businessmodel'].toString());
    String? selectedBusiness = businessExists ? search['id_businessmodel'].toString() : _businessModels.first['id'].toString();
    
    bool housingExists = isEdit && _housingTypes.any((h) => h['id'].toString() == search['id_housingtype'].toString());
    String? selectedHousing = housingExists ? search['id_housingtype'].toString() : _housingTypes.first['id'].toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setModalState) {
                  return Column(
                    mainAxisSize: MainAxisSize.min, 
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(isEdit ? 'Editar Búsqueda' : 'Nueva Búsqueda', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                          IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context))
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: selectedBusiness,
                              decoration: const InputDecoration(labelText: 'Negocio', border: OutlineInputBorder()),
                              items: _businessModels.map<DropdownMenuItem<String>>((b) {
                                return DropdownMenuItem<String>(
                                  value: b['id'].toString(),
                                  child: Text(b['name'].toString(), overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (val) => setModalState(() => selectedBusiness = val!),
                            )
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: selectedHousing,
                              decoration: const InputDecoration(labelText: 'Inmueble', border: OutlineInputBorder()),
                              items: _housingTypes.map<DropdownMenuItem<String>>((h) {
                                return DropdownMenuItem<String>(
                                  value: h['id'].toString(),
                                  child: Text(h['name'].toString(), overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (val) => setModalState(() => selectedHousing = val!),
                            )
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: priceCtrl, 
                        keyboardType: TextInputType.number, 
                        decoration: const InputDecoration(labelText: 'Presupuesto (\$)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money))
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: locationCtrl, 
                        decoration: const InputDecoration(labelText: 'Ubicación', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_on))
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: descCtrl, 
                        maxLines: 4, 
                        decoration: const InputDecoration(labelText: 'Descripción detallada', border: OutlineInputBorder(), alignLabelWithHint: true)
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity, 
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          onPressed: () {
                            if (descCtrl.text.isEmpty || priceCtrl.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Presupuesto y Descripción obligatorios')));
                              return;
                            }
                            final data = {
                              'id_businessmodel': int.parse(selectedBusiness!),
                              'id_housingtype': int.parse(selectedHousing!),
                              'estimate_price': priceCtrl.text.trim(),
                              'location': locationCtrl.text.trim(),
                              'description': descCtrl.text.trim(),
                            };
                            _saveSearch(data, id: isEdit ? int.parse(search['id'].toString()) : null);
                          },
                          child: Text(isEdit ? 'ACTUALIZAR DATOS' : 'PUBLICAR EN EL MURO', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 10),
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
  // UI: INTERFAZ PRINCIPAL
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(150), // <-- Altura ajustada
          child: SafeArea( // <-- SafeArea agregado para proteger del notch
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.only(top: 10, left: 20, right: 20), // <-- Padding superior ajustado
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Búsquedas', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black)),
                  const Text('Muro colaborativo de requerimientos', style: TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 16),
                  Container(
                    height: 45,
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                    child: TabBar(
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10)),
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.black54,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      tabs: const [Tab(text: 'Muro General'), Tab(text: 'Mis Búsquedas')],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _buildSearchList(_allSearches, _isLoadingAll, _errorAll, isMine: false),
            _buildSearchList(_mySearches, _isLoadingMine, _errorMine, isMine: true),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          child: const Icon(Icons.add),
          onPressed: () => _showSearchForm(), 
        ),
      ),
    );
  }

  Widget _buildSearchList(List<dynamic> searches, bool isLoading, String error, {required bool isMine}) {
    if (isLoading) return const Center(child: CircularProgressIndicator(color: Colors.black));
    if (error.isNotEmpty) return Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red))));
    if (searches.isEmpty) return Center(child: Text(isMine ? 'No tienes búsquedas publicadas' : 'No hay búsquedas en el muro', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)));

    return RefreshIndicator(
      onRefresh: isMine ? _fetchMySearches : _fetchAllSearches,
      color: Colors.black,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: searches.length,
        itemBuilder: (context, index) => _buildSearchCard(searches[index], isMine: isMine),
      ),
    );
  }

  Widget _buildSearchCard(Map<String, dynamic> search, {required bool isMine}) {
    final priceFormatter = NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 0);
    final String price = priceFormatter.format(double.tryParse(search['estimate_price']?.toString() ?? '0') ?? 0);
    
    DateTime dateAt = DateTime.tryParse(search['created_at']?.toString() ?? '') ?? DateTime.now();
    String formattedDate = DateFormat('dd/MM/yyyy', 'es').format(dateAt);

    String authorName = search['author']?.toString() ?? 'Asesor RM';
    String housingName = search['housingtype_name']?.toString() ?? 'INMUEBLE';
    String businessName = search['businessmodel_name']?.toString() ?? 'NEGOCIO';
    String description = search['description']?.toString() ?? 'Sin descripción';
    String location = search['location']?.toString() ?? 'Ubicación a convenir';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
          // =========================================================
          // MAGIA ANTI-OVERFLOW: crossAxisAlignment Center y botones manuales
          // =========================================================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center, // Centrado vertical perfecto
            children: [
              Expanded( 
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: isMine ? Colors.black : Colors.blue.shade50,
                      child: Icon(isMine ? Icons.person : Icons.support_agent, size: 16, color: isMine ? Colors.white : Colors.blue.shade700),
                    ),
                    const SizedBox(width: 8),
                    Expanded( 
                      child: Text(
                        isMine ? 'Mi Publicación' : authorName,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isMine ? Colors.black : Colors.blue.shade700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8), 
              
              // NUESTRO BOTÓN WHATSAPP HECHO A MANO (INMUNE AL OVERFLOW)
              if (!isMine)
                InkWell(
                  onTap: () => _shareOnWhatsApp(search),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.share_outlined, size: 14, color: Colors.green),
                        SizedBox(width: 4),
                        Text('WhatsApp', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 28, // Altura restringida para que no llore
                  width: 28,
                  child: PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_horiz, color: Colors.grey),
                    onSelected: (value) {
                      if (value == 'edit') _showSearchForm(search: search);
                      if (value == 'delete') {
                        showDialog(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Eliminar', style: TextStyle(fontWeight: FontWeight.bold)),
                            content: const Text('¿Deseas borrar esta publicación del muro?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                onPressed: () { Navigator.pop(c); _deleteSearch(int.parse(search['id'].toString())); }, 
                                child: const Text('Borrar', style: TextStyle(color: Colors.white))
                              )
                            ],
                          )
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text('Editar')])),
                      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 16, color: Colors.red), SizedBox(width: 8), Text('Eliminar', style: TextStyle(color: Colors.red))])),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          
          Text("$housingName en $businessName".toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          
          Text(description, style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4)),
          
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.location_on, size: 14, color: Colors.grey), 
                    const SizedBox(width: 4), 
                    Expanded(
                      child: Text(
                        location, 
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        maxLines: 1, 
                        overflow: TextOverflow.ellipsis,
                      )
                    )
                  ]
                ),
              ),
              const SizedBox(width: 8),
              Text(price, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.green, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 4),
          Align(alignment: Alignment.centerRight, child: Text(formattedDate, style: const TextStyle(fontSize: 10, color: Colors.grey))),
        ],
      ),
    );
  }
}