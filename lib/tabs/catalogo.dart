import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/property_detail_screen.dart'; 
import '../config/api_config.dart';

class CatalogoTab extends StatefulWidget {
  const CatalogoTab({super.key});

  @override
  State<CatalogoTab> createState() => _CatalogoTabState();
}

class _CatalogoTabState extends State<CatalogoTab> {
  List<dynamic> _properties = [];
  bool _isLoading = true;
  bool _showFiltersPanel = false;
  bool _showAdvancedSection = false;

  // Paginación
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;

  // Catálogos
  List<dynamic> _housingTypes = [];
  List<dynamic> _states = [];
  List<dynamic> _municipalities = [];
  List<dynamic> _cities = [];
  List<dynamic> _agents = []; // <-- Lista de asesores

  // Variables Filtro
  String _selectedBusinessModel = ''; 
  String? _selectedHousingType;
  String? _selectedState;
  String? _selectedMunicipality;
  String? _selectedCity;
  String? _selectedAgent; // <-- Filtro por asesor

  // Controladores
  final TextEditingController _codeCtrl = TextEditingController();
  final TextEditingController _priceMinCtrl = TextEditingController();
  final TextEditingController _priceMaxCtrl = TextEditingController();
  final TextEditingController _metersMinCtrl = TextEditingController();
  final TextEditingController _metersMaxCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _fetchCatalogs();
    await _fetchAgents(); // <-- Cargar agentes
    await _fetchProperties();
  }

  Future<void> _fetchCatalogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/mobile/properties/form-data'),
        headers: {'Authorization': 'Bearer ${prefs.getString('jwt_token') ?? ''}'},
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        setState(() {
          _housingTypes = body['data']['housing_types'] ?? [];
          _states = body['data']['states'] ?? [];
          _municipalities = body['data']['municipalities'] ?? [];
          _cities = body['data']['cities'] ?? [];
        });
      }
    } catch (e) {
      print("Error catálogos: $e");
    }
  }

  // =========================================================================
  // NUEVO: Cargar lista de agentes/asesores
  // =========================================================================
  Future<void> _fetchAgents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/mobile/agents'),
        headers: {'Authorization': 'Bearer ${prefs.getString('jwt_token') ?? ''}'},
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['status'] == 'success') {
          setState(() {
            _agents = body['data'] ?? [];
          });
        }
      }
    } catch (e) {
      print("Error cargando agentes: $e");
    }
  }

  Future<void> _fetchProperties({int page = 1}) async {
    setState(() { _isLoading = true; _currentPage = page; });
    try {
      String baseUrl = '${ApiConfig.apiPublicProperties}?page=$_currentPage&limit=10';
      
      if (_codeCtrl.text.isNotEmpty) baseUrl += '&code=${_codeCtrl.text.trim()}';
      if (_selectedBusinessModel.isNotEmpty) baseUrl += '&business_model=$_selectedBusinessModel';
      if (_selectedHousingType != null) baseUrl += '&housing_type=$_selectedHousingType';
      if (_selectedState != null) baseUrl += '&state=$_selectedState';
      if (_selectedMunicipality != null) baseUrl += '&municipality=$_selectedMunicipality';
      if (_selectedCity != null) baseUrl += '&city=$_selectedCity';
      if (_selectedAgent != null) baseUrl += '&agent=$_selectedAgent'; // <-- Filtro por asesor
      if (_priceMinCtrl.text.isNotEmpty) baseUrl += '&min_price=${_priceMinCtrl.text.trim()}';
      if (_priceMaxCtrl.text.isNotEmpty) baseUrl += '&max_price=${_priceMaxCtrl.text.trim()}';
      if (_metersMinCtrl.text.isNotEmpty) baseUrl += '&min_meters=${_metersMinCtrl.text.trim()}';
      if (_metersMaxCtrl.text.isNotEmpty) baseUrl += '&max_meters=${_metersMaxCtrl.text.trim()}';

      final response = await http.get(Uri.parse(baseUrl));
      final data = jsonDecode(response.body);

      if (data['status'] == 'success') {
        setState(() {
          _properties = data['data'] ?? [];
          _totalPages = data['pagination']['total_pages'] ?? 1;
          _totalItems = data['pagination']['total'] ?? 0;
        });
      } else {
        setState(() => _properties = []);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al cargar'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _limpiarFiltros() {
    _codeCtrl.clear(); 
    _priceMinCtrl.clear(); 
    _priceMaxCtrl.clear(); 
    _metersMinCtrl.clear(); 
    _metersMaxCtrl.clear();
    setState(() { 
      _selectedBusinessModel = ''; 
      _selectedHousingType = null; 
      _selectedState = null; 
      _selectedMunicipality = null; 
      _selectedCity = null; 
      _selectedAgent = null; // <-- Limpiar asesor
    });
    _fetchProperties(page: 1);
  }

  String _formatPrice(Map<String, dynamic> prop) {
    double sale = double.tryParse(prop['price']?.toString() ?? '0') ?? 0;
    double rent = double.tryParse(prop['price_additional']?.toString() ?? '0') ?? 0;
    final formatter = NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 0);
    if (sale > 0) return formatter.format(sale);
    if (rent > 0) return '${formatter.format(rent)}/mes';
    return 'Consultar';
  }

  String _getLocation(Map<String, dynamic> prop) {
    List<String> loc = [];
    if (prop['city_name'] != null) loc.add(prop['city_name']);
    else if (prop['municipality_name'] != null) loc.add(prop['municipality_name']);
    if (prop['state_name'] != null && !loc.contains(prop['state_name'])) loc.add(prop['state_name']);
    return loc.isNotEmpty ? loc.join(', ') : 'No especificada';
  }

  String _getImage(Map<String, dynamic> prop) {
    if (prop['primary_image'] != null && prop['primary_image']['url'] != null) return prop['primary_image']['url'];
    if (prop['images'] != null && prop['images'].isNotEmpty && prop['images'][0]['url'] != null) return prop['images'][0]['url'];
    return 'https://images.unsplash.com/photo-1560518883-ce09059eeffa?w=500&h=300&fit=crop';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. CABECERA
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Catálogo REMS', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  Text('$_totalItems propiedades', style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: _showFiltersPanel ? Colors.black : Colors.white,
                  foregroundColor: _showFiltersPanel ? Colors.white : Colors.black,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: Icon(_showFiltersPanel ? Icons.close : Icons.filter_list, size: 18),
                label: Text(_showFiltersPanel ? 'Ocultar' : 'Filtros', style: const TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => setState(() => _showFiltersPanel = !_showFiltersPanel),
              )
            ],
          ),
        ),

        // 2. EL RESTO DE LA PANTALLA (Filtros desplegables y Lista)
        Expanded(
          child: Column(
            children: [
              // PANEL DE FILTROS
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: _showFiltersPanel 
                  ? ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.60),
                      child: SingleChildScrollView(child: _buildSuperFilterPanel()),
                    ) 
                  : const SizedBox.shrink(),
              ),

              // LISTA DE PROPIEDADES
              Expanded(
                child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.black))
                  : _properties.isEmpty
                      ? const Center(child: Text('No se encontraron propiedades.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)))
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            bool isMobile = constraints.maxWidth < 650; 
                            return ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _properties.length,
                              itemBuilder: (context, index) {
                                return _buildPropertyCardHorizontal(_properties[index], isMobile);
                              },
                            );
                          },
                        ),
              ),
            ],
          ),
        ),

        // 3. PAGINADOR
        if (!_isLoading && _totalPages > 1)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _currentPage > 1 ? () => _fetchProperties(page: _currentPage - 1) : null,
                  icon: const Icon(Icons.arrow_back_ios, size: 14),
                  label: const Text('Anterior', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(foregroundColor: Colors.black, disabledForegroundColor: Colors.grey.shade300),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                  child: Text('$_currentPage / $_totalPages', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                TextButton(
                  onPressed: _currentPage < _totalPages ? () => _fetchProperties(page: _currentPage + 1) : null,
                  style: TextButton.styleFrom(foregroundColor: Colors.black, disabledForegroundColor: Colors.grey.shade300),
                  child: const Row(children: [Text('Siguiente', style: TextStyle(fontWeight: FontWeight.bold)), SizedBox(width: 4), Icon(Icons.arrow_forward_ios, size: 14)]),
                ),
              ],
            ),
          )
      ],
    );
  }

  // ============================================================================
  // PANEL DE FILTROS (CON ASESOR EN AVANZADOS)
  // ============================================================================
  Widget _buildSuperFilterPanel() {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.filter_alt_outlined, size: 20), SizedBox(width: 8), Text('FILTROS DE BÚSQUEDA', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5))]),
          const SizedBox(height: 16),
          
          // Tipo de negocio (Venta/Alquiler)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text('¿QUÉ BUSCAS?', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(width: 8),
                _buildChip('TODO', ''), 
                _buildChip('VENTA', '1'), 
                _buildChip('ALQUILER', '2'), 
                _buildChip('FINANCIADO', '4'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // --- FILA 1: Inmueble, Estado, Municipio ---
          Row(
            children: [
              Expanded(child: _buildDropdownWrapper('INMUEBLE', _housingTypes, _selectedHousingType, (v) => setState(() => _selectedHousingType = v))),
              const SizedBox(width: 8),
              Expanded(child: _buildDropdownWrapper('ESTADO', _states, _selectedState, (v) => setState(() { _selectedState = v; _selectedMunicipality = null; _selectedCity = null; }))),
              const SizedBox(width: 8),
              Expanded(child: _buildDropdownWrapper('MUNICIPIO', _municipalities.where((m) => m['id_state'].toString() == _selectedState).toList(), _selectedMunicipality, (v) => setState(() { _selectedMunicipality = v; _selectedCity = null; }))),
            ],
          ),
          const SizedBox(height: 16),

          // --- FILA 2: Ciudad y Presupuesto ---
          Row(
            children: [
              Expanded(child: _buildDropdownWrapper('CIUDAD', _cities.where((c) => c['id_municipality'].toString() == _selectedMunicipality).toList(), _selectedCity, (v) => setState(() => _selectedCity = v))),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: _buildRangeWrapper('PRESUPUESTO (\$)', _priceMinCtrl, _priceMaxCtrl)),
            ],
          ),
          const SizedBox(height: 16),

          // --- BOTÓN AVANZADOS ---
          InkWell(
            onTap: () => setState(() => _showAdvancedSection = !_showAdvancedSection),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(6)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_showAdvancedSection ? 'OCULTAR AVANZADOS' : 'FILTROS AVANZADOS', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  Icon(_showAdvancedSection ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 16)
                ],
              ),
            ),
          ),

          // --- FILTROS AVANZADOS (Ahora incluye ASESOR) ---
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            child: _showAdvancedSection ? Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Column(
                children: [
                  // FILA DE METRAJE Y CÓDIGO
                  Row(
                    children: [
                      Expanded(child: _buildRangeWrapper('METRAJE CONST. (M²)', _metersMinCtrl, _metersMaxCtrl)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('CÓDIGO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                            const SizedBox(height: 6),
                            SizedBox(height: 40, child: TextField(controller: _codeCtrl, decoration: InputDecoration(hintText: 'Ej. RM00123', hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400), contentPadding: const EdgeInsets.symmetric(horizontal: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.grey.shade300)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Colors.black))))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // =========================================================================
                  // NUEVO: FILA DEL ASESOR INMOBILIARIO
                  // =========================================================================
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdownWrapper(
                          'ASESOR INMOBILIARIO', 
                          _agents, 
                          _selectedAgent, 
                          (v) => setState(() => _selectedAgent = v)
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ) : const SizedBox.shrink(),
          ),
          
          const Divider(height: 30),

          // --- BOTONES FINALES ---
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: _limpiarFiltros, child: const Text('Limpiar Todo', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                icon: const Icon(Icons.search, size: 18),
                label: const Text('BUSCAR', style: TextStyle(fontWeight: FontWeight.w900)),
                onPressed: () => _fetchProperties(page: 1),
              )
            ],
          )
        ],
      ),
    );
  }

  // --- COMPONENTES VISUALES ---
  Widget _buildChip(String label, String value) {
    bool isSelected = _selectedBusinessModel == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedBusinessModel = value),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: isSelected ? Colors.black : Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4)),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontSize: 10, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildDropdownWrapper(String label, List items, String? val, Function(String?) onChanged) {
    if (items.isNotEmpty && val != null && !items.any((e) => (e['id']?.toString() ?? e['id_state']?.toString() ?? '') == val)) val = null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
        SizedBox(
          height: 40,
          child: DropdownButtonFormField<String>(
            isExpanded: true, value: val,
            icon: const Icon(Icons.keyboard_arrow_down, size: 16),
            decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.grey.shade300)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Colors.black))),
            hint: Text('Todos', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
            items: items.map((item) => DropdownMenuItem(
              value: (item['id'] ?? item['id_state'] ?? '').toString(), 
              child: Text(
                item['full_name'] ?? item['name'] ?? '', // <-- Ahora soporta 'full_name' (agentes) y 'name' (catálogos)
                style: const TextStyle(fontSize: 12), 
                overflow: TextOverflow.ellipsis
              )
            )).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildRangeWrapper(String label, TextEditingController minCtrl, TextEditingController maxCtrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: SizedBox(height: 40, child: TextField(controller: minCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: 'Mín.', hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400), contentPadding: const EdgeInsets.symmetric(horizontal: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.grey.shade300)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Colors.black)))))),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 4.0), child: Text('-', style: TextStyle(color: Colors.grey))),
            Expanded(child: SizedBox(height: 40, child: TextField(controller: maxCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: 'Máx.', hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400), contentPadding: const EdgeInsets.symmetric(horizontal: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.grey.shade300)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Colors.black)))))),
          ],
        )
      ],
    );
  }

  // ============================================================================
  // TARJETA DE PROPIEDAD
  // ============================================================================
  Widget _buildPropertyCardHorizontal(Map<String, dynamic> prop, bool isMobile) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PropertyDetailScreen(property: prop))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: isMobile ? 220 : 220,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))]),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: isMobile ? 120 : 300, child: _buildImageSection(prop)),
            Expanded(child: _buildDetailsSection(prop, isMobile)),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(Map<String, dynamic> prop) {
    return Stack(
      children: [
        ClipRRect(borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8)), child: Image.network(_getImage(prop), width: double.infinity, height: double.infinity, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey.shade100, child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 50)))),
        Positioned(top: 8, left: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(4)), child: Text((prop['business_model_name'] ?? 'Inmueble').toString().toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)))),
      ],
    );
  }

  Widget _buildDetailsSection(Map<String, dynamic> prop, bool isMobile) {
    String title = '${prop['housing_type_name'] ?? 'Propiedad'} en ${prop['city_name'] ?? prop['municipality_name'] ?? 'Caracas'}';
    String description = prop['public_observations'] ?? prop['description'] ?? 'Excelente oportunidad ubicada en una de las mejores zonas...';
    String agentName = prop['agent_name'] ?? 'Asesor RM';
    
    final String? wasiLink = prop['wasi']?.toString();
    final bool hasWasi = wasiLink != null && wasiLink.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 12.0 : 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(_formatPrice(prop), style: TextStyle(fontSize: isMobile ? 16 : 24, fontWeight: FontWeight.bold, color: Colors.black))),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasWasi) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(color: Colors.blue.shade50, border: Border.all(color: Colors.blue.shade200), borderRadius: BorderRadius.circular(4)),
                      child: Text('WASI', style: TextStyle(color: Colors.blue.shade700, fontSize: isMobile ? 9 : 10, fontWeight: FontWeight.w900)),
                    ),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), 
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)), 
                    child: Text('RM00${prop['id_properties']}', style: TextStyle(color: Colors.grey.shade600, fontSize: isMobile ? 10 : 12, fontWeight: FontWeight.w600))
                  ),
                ],
              )
            ],
          ),
          
          SizedBox(height: isMobile ? 4 : 8),
          Text(title, style: TextStyle(fontSize: isMobile ? 12 : 16, fontWeight: FontWeight.w600, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
          SizedBox(height: isMobile ? 4 : 4),
          Row(children: [Icon(Icons.location_on_outlined, size: isMobile ? 12 : 16, color: Colors.grey.shade600), const SizedBox(width: 4), Expanded(child: Text(_getLocation(prop).toUpperCase(), style: TextStyle(color: Colors.grey.shade600, fontSize: isMobile ? 10 : 12, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis))]),
          SizedBox(height: isMobile ? 6 : 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), 
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(4)), 
            child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.badge_outlined, size: isMobile ? 12 : 14, color: Colors.black87), const SizedBox(width: 4), Text(agentName, style: TextStyle(fontSize: isMobile ? 9 : 11, fontWeight: FontWeight.bold, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis)])
          ),
          Expanded(child: Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(description, style: TextStyle(color: Colors.grey.shade600, fontSize: isMobile ? 11 : 13, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis))),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildFeatureStat(prop['bedrooms']?.toString() ?? '0', 'HAB', isMobile),
              Container(width: 1, height: isMobile ? 20 : 30, color: Colors.grey.shade200),
              _buildFeatureStat(prop['bathrooms']?.toString() ?? '0', 'BAÑOS', isMobile),
              Container(width: 1, height: isMobile ? 20 : 30, color: Colors.grey.shade200),
              _buildFeatureStat(prop['meters_construction']?.toString() ?? '0', 'M²', isMobile),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureStat(String value, String label, bool isMobile) {
    return Column(children: [Text(value, style: TextStyle(fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.bold, color: Colors.black)), const SizedBox(height: 2), Text(label, style: TextStyle(fontSize: isMobile ? 9 : 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600))]);
  }
}