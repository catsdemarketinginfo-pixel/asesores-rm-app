import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

// IMPORTANTE: Asegúrate de ajustar esta ruta según dónde guardaste la nueva pantalla
import '../screens/gestion_inmueble.dart'; 

class InmueblesTab extends StatefulWidget {
  const InmueblesTab({super.key});

  @override
  State<InmueblesTab> createState() => _InmueblesTabState();
}

class _InmueblesTabState extends State<InmueblesTab> {
  // --- CONTROL DE DATOS ---
  List<dynamic> _properties = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  bool _hasMore = true;
  String _searchQuery = '';
  Timer? _debounce;
  final ScrollController _scrollController = ScrollController();

  // --- CATÁLOGOS ---
  List<dynamic> _businessModels = [];
  List<dynamic> _housingTypes = [];
  List<dynamic> _states = [];
  List<dynamic> _municipalities = [];
  List<dynamic> _cities = [];

  @override
  void initState() {
    super.initState();
    _fetchProperties(refresh: true);
    _fetchFormData();
    
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (_hasMore && !_isLoadingMore && !_isLoading) _fetchProperties(refresh: false);
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
  // BUSCADOR CON DEBOUNCE
  // =========================================================================
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() => _searchQuery = query);
      _fetchProperties(refresh: true);
    });
  }

  // =========================================================================
  // LÓGICA DE API
  // =========================================================================
  Future<void> _fetchFormData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/mobile/properties/form-data'),
        headers: {'Authorization': 'Bearer ${prefs.getString('jwt_token')}'},
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        setState(() {
          _businessModels = body['data']['business_models'] ?? [];
          _housingTypes = body['data']['housing_types'] ?? [];
          _states = body['data']['states'] ?? [];
          _municipalities = body['data']['municipalities'] ?? [];
          _cities = body['data']['cities'] ?? [];
        });
      }
    } catch (e) { print(e); }
  }

  Future<void> _fetchProperties({bool refresh = false}) async {
    if (refresh) {
      setState(() { _isLoading = true; _currentPage = 1; _properties.clear(); _hasMore = true; });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      String url = '${ApiConfig.baseUrl}/api/v1/mobile/properties/me?page=$_currentPage&search=$_searchQuery';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer ${prefs.getString('jwt_token')}'},
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List fetchedData = body['data'] ?? [];
        setState(() {
          _properties.addAll(fetchedData);
          _currentPage++;
          _hasMore = _currentPage <= (body['pagination']['total_pages'] ?? 1);
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      setState(() { _isLoading = false; _isLoadingMore = false; });
    }
  }

  // =========================================================================
  // UI PRINCIPAL: Estilo Lista Google Drive
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Directorio Inmobiliario', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 22)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Buscar código o dirección...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : _properties.isEmpty
              ? const Center(child: Text('No se encontraron inmuebles', style: TextStyle(color: Colors.grey)))
              : RefreshIndicator(
                  onRefresh: () => _fetchProperties(refresh: true),
                  color: Colors.black,
                  child: ListView.separated(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _properties.length + (_hasMore ? 1 : 0),
                    separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200, indent: 70),
                    itemBuilder: (context, index) {
                      if (index == _properties.length) {
                        return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)));
                      }
                      return _buildFolderItem(_properties[index]);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        child: const Icon(Icons.create_new_folder, color: Colors.white),
        onPressed: _showCaptureForm,
      ),
    );
  }

  // =========================================================================
  // EL ITEM TIPO "CARPETA" EN LISTA (Navega a la Etapa 2)
  // =========================================================================
  Widget _buildFolderItem(Map<String, dynamic> prop) {
    // Lógica dinámica de precios
    String priceText = '';
    final p1 = prop['price']?.toString() ?? '';
    final p2 = prop['price_additional']?.toString() ?? '';
    
    bool hasP1 = p1.isNotEmpty && p1 != '0' && p1 != '0.00' && p1 != 'null';
    bool hasP2 = p2.isNotEmpty && p2 != '0' && p2 != '0.00' && p2 != 'null';

    if (hasP1 && hasP2) {
      priceText = 'V: \$$p1 | A: \$$p2';
    } else if (hasP1) {
      priceText = '\$$p1';
    } else if (hasP2) {
      priceText = '\$$p2';
    } else {
      priceText = 'Consultar';
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GestionInmuebleScreen(propertyId: prop['id_properties'].toString()),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.folder_open_rounded, color: Colors.blue.shade700, size: 26),
            ),
            const SizedBox(width: 16),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'RM-${prop['id_properties']}', 
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.black)
                      ),
                      const SizedBox(width: 8),
                      // Envolvemos el precio en Expanded por si es muy largo
                      Expanded(
                        child: Text(
                          priceText, 
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.green),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${prop['housing_name']} • ${prop['business_name']}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 12),
            
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(prop['status_name']).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    (prop['status_name'] ?? 'Pendiente').toUpperCase(),
                    style: TextStyle(color: _getStatusColor(prop['status_name']), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 4),
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    switch (status.toLowerCase()) {
      case 'activo': return Colors.green;
      case 'en revisión': return Colors.orange;
      case 'vendido': return Colors.blue;
      default: return Colors.grey;
    }
  }

  // =========================================================================
  // FORMULARIO ETAPA 1 (DATOS BÁSICOS EN CASCADA)
  // =========================================================================
  void _showCaptureForm() {
    if (_businessModels.isEmpty || _states.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sincronizando catálogos...')));
      _fetchFormData();
      return;
    }

    String? selectedBusiness;
    String? selectedHousing;
    String? selectedState;
    String? selectedMunicipality;
    String? selectedCity;
    
    final TextEditingController addressCtrl = TextEditingController();
    final TextEditingController priceCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            
            List<dynamic> filteredMunicipalities = selectedState == null 
                ? [] 
                : _municipalities.where((m) => m['id_state'].toString() == selectedState).toList();
                
            List<dynamic> filteredCities = selectedMunicipality == null 
                ? [] 
                : _cities.where((c) => c['id_municipality'].toString() == selectedMunicipality).toList();

            return Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.90),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(top: 24, left: 24, right: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Paso 1: Información Básica', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Tipo de Negocio', border: OutlineInputBorder()),
                          items: _businessModels.map((b) => DropdownMenuItem(value: b['id'].toString(), child: Text(b['name']))).toList(),
                          onChanged: (v) => setModalState(() => selectedBusiness = v),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Tipo de Inmueble', border: OutlineInputBorder()),
                          items: _housingTypes.map((h) => DropdownMenuItem(value: h['id'].toString(), child: Text(h['name']))).toList(),
                          onChanged: (v) => setModalState(() => selectedHousing = v),
                        )),
                      ],
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Estado', border: OutlineInputBorder()),
                      items: _states.map((s) => DropdownMenuItem(value: s['id'].toString(), child: Text(s['name']))).toList(),
                      onChanged: (v) => setModalState(() {
                        selectedState = v;
                        selectedMunicipality = null; 
                        selectedCity = null;
                      }),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: selectedMunicipality,
                          decoration: const InputDecoration(labelText: 'Municipio', border: OutlineInputBorder()),
                          items: filteredMunicipalities.map((m) => DropdownMenuItem(value: m['id'].toString(), child: Text(m['name'], overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) => setModalState(() {
                            selectedMunicipality = v;
                            selectedCity = null; 
                          }),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: selectedCity,
                          decoration: const InputDecoration(labelText: 'Ciudad', border: OutlineInputBorder()),
                          items: filteredCities.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['name'], overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) => setModalState(() => selectedCity = v),
                        )),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: addressCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Dirección del Inmueble', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Precio Sugerido (\$)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money)),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: const Text('REGISTRAR Y CONTINUAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          if (selectedBusiness == null || selectedHousing == null || selectedState == null || selectedMunicipality == null || selectedCity == null || addressCtrl.text.isEmpty || priceCtrl.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Todos los campos son obligatorios')));
                            return;
                          }
                          
                          _saveBasic({
                            'business_model': selectedBusiness,
                            'housing_type': selectedHousing,
                            'state': selectedState,
                            'municipality': selectedMunicipality,
                            'city': selectedCity,
                            'address': addressCtrl.text.trim(),
                            'price': priceCtrl.text.trim(),
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  Future<void> _saveBasic(Map<String, dynamic> data) async {
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator(color: Colors.white)));
    try {
      final prefs = await SharedPreferences.getInstance();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/mobile/properties'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${prefs.getString('jwt_token')}'},
        body: jsonEncode(data),
      );
      Navigator.pop(context); // Cierra loading
      
      if (response.statusCode == 201) {
        final res = jsonDecode(response.body);
        Navigator.pop(context); // Cierra modal
        _fetchProperties(refresh: true);
        
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Propiedad base creada!'), backgroundColor: Colors.green));
        
        // ABRIR DIRECTAMENTE LA ETAPA 2 AL CREARLA CON ÉXITO
        if (res['property_id'] != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GestionInmuebleScreen(propertyId: res['property_id'].toString()),
            ),
          );
        }
        
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${response.statusCode}'), backgroundColor: Colors.red));
      }
    } catch (e) { 
      Navigator.pop(context); 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error de conexión'), backgroundColor: Colors.red));
    }
  }
}