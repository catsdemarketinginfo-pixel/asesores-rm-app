import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart'; 
import '../config/api_config.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'dart:typed_data';

class GestionInmuebleScreen extends StatefulWidget {
  final String propertyId;

  const GestionInmuebleScreen({super.key, required this.propertyId});

  @override
  State<GestionInmuebleScreen> createState() => _GestionInmuebleScreenState();
}

class _GestionInmuebleScreenState extends State<GestionInmuebleScreen> {
  bool _isLoading = true;
  bool _isUploadingImages = false; 
  Map<String, dynamic> _propertyData = {};

  // --- CATÁLOGOS MAESTROS ---
  List<dynamic> _areaTypes = [];
  List<dynamic> _marketTypes = [];
  List<dynamic> _housingTypes = [];
  List<dynamic> _businessModels = [];
  List<dynamic> _states = [];
  List<dynamic> _municipalities = [];
  List<dynamic> _cities = [];
  
  List<dynamic> _aceaCatalog = [];
  List<dynamic> _aceaOptions = [];
  List<dynamic> _businessConditionsCatalog = [];

  // --- IMÁGENES Y DOCUMENTOS ---
  List<dynamic> _images = []; 
  List<dynamic> _documents = []; 
  final ImagePicker _picker = ImagePicker(); 

 // --- MAPS CONFIG (OPENSTREETMAP - GRATIS) ---
  final MapController _mapController = MapController();
  LatLng _currentLocation = const LatLng(10.4806, -66.8983); // Caracas por defecto
  LatLng? _selectedLocation;

  // --- CONTROLADORES ---
  final TextEditingController _ownerCtrl = TextEditingController();
  final TextEditingController _ownerPhoneCtrl = TextEditingController();
  final TextEditingController _ownerMailCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _priceAdditionalCtrl = TextEditingController(); // <--- LÍNEA NUEVA
  final TextEditingController _bedroomsCtrl = TextEditingController();
  final TextEditingController _bathroomsCtrl = TextEditingController();
  final TextEditingController _garagesCtrl = TextEditingController();
  final TextEditingController _landCtrl = TextEditingController();
  final TextEditingController _constCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();

  String? _selAreaType;
  String? _selMarketType;
  String? _selHousingType;
  String? _selBusinessModel;
  String? _selState;
  String? _selMunicipality;
  String? _selCity;

  // --- CHECKBOXES ---
  List<String> _selectedConditions = [];
  List<String> _selectedEnvironments = [];
  List<String> _selectedAmenities = []; 
  List<String> _selectedExterior = [];
  List<String> _selectedAdjacencies = [];

  // --- BLOQUEOS INDIVIDUALES ---
  bool _isOwnerLocked = false;
  bool _isPhoneLocked = false;
  bool _isMailLocked = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _fetchFormData();
    await _loadPropertyData();
  }

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
          _areaTypes = body['data']['area_types'] ?? [];
          _marketTypes = body['data']['market_types'] ?? [];
          _housingTypes = body['data']['housing_types'] ?? [];
          _businessModels = body['data']['business_models'] ?? [];
          _states = body['data']['states'] ?? [];
          _municipalities = body['data']['municipalities'] ?? [];
          _cities = body['data']['cities'] ?? [];
          _aceaCatalog = body['data']['acea'] ?? [];
          _aceaOptions = body['data']['acea_options'] ?? [];
          _businessConditionsCatalog = body['data']['business_conditions'] ?? [];
        });
      }
    } catch (e) { print(e); }
  }

  Future<void> _loadPropertyData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/mobile/properties/${widget.propertyId}'),
        headers: {'Authorization': 'Bearer ${prefs.getString('jwt_token')}'},
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        _propertyData = body['data'] ?? {};
        
        setState(() {
          // LLENADO SEGURO ANTI-NULOS
          _ownerCtrl.text = _propertyData['owner']?.toString() ?? '';
          _ownerPhoneCtrl.text = _propertyData['owner_phone']?.toString() ?? '';
          _ownerMailCtrl.text = _propertyData['owner_mail']?.toString() ?? '';
          _priceCtrl.text = _propertyData['price']?.toString() ?? '';
          _priceAdditionalCtrl.text = _propertyData['price_additional']?.toString() ?? ''; // <--- LÍNEA NUEVA
          _bedroomsCtrl.text = _propertyData['bedrooms']?.toString() ?? '';
          _bathroomsCtrl.text = _propertyData['bathrooms']?.toString() ?? '';
          _garagesCtrl.text = _propertyData['garages']?.toString() ?? '';
          _landCtrl.text = _propertyData['meters_land']?.toString() ?? '';
          _constCtrl.text = _propertyData['meters_construction']?.toString() ?? '';
          _addressCtrl.text = _propertyData['address']?.toString() ?? '';

          _selAreaType = _propertyData['area_type']?.toString();
          _selMarketType = _propertyData['market_type']?.toString();
          _selHousingType = _propertyData['housing_type']?.toString();
          _selBusinessModel = _propertyData['business_model']?.toString();
          _selState = _propertyData['state']?.toString();
          _selMunicipality = _propertyData['municipality']?.toString();
          _selCity = _propertyData['city']?.toString();

          _selectedConditions = _splitDbString(_propertyData['business_conditions']);
          _selectedEnvironments = _splitDbString(_propertyData['environments']);
          _selectedAmenities = _splitDbString(_propertyData['amenities']); 
          _selectedExterior = _splitDbString(_propertyData['exterior']);
          _selectedAdjacencies = _splitDbString(_propertyData['adjacencies']);

          // CARGAR COORDENADAS SI EXISTEN
          if (_propertyData['map_coordinates'] != null && _propertyData['map_coordinates'].toString().contains(',')) {
            List<String> coords = _propertyData['map_coordinates'].toString().split(',');
            if(coords.length == 2) {
              _selectedLocation = LatLng(double.parse(coords[0]), double.parse(coords[1]));
              _currentLocation = _selectedLocation!;
            }
          }

          // ---> ¡AQUÍ ESTABA EL ERROR! Faltaba leer los documentos <---
          _images = _propertyData['images'] ?? [];
          _documents = _propertyData['documents'] ?? []; // ¡LÍNEA RECUPERADA!

          // BLOQUEOS
          _isOwnerLocked = _ownerCtrl.text.trim().isNotEmpty;
          _isPhoneLocked = _ownerPhoneCtrl.text.trim().isNotEmpty;
          _isMailLocked = _ownerMailCtrl.text.trim().isNotEmpty;

          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<String> _splitDbString(dynamic dbValue) {
    if (dbValue == null || dbValue.toString().isEmpty || dbValue.toString() == 'null') return [];
    return dbValue.toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  Future<void> _updateBlock(Map<String, dynamic> dataToUpdate, String blockName) async {
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator(color: Colors.white)));
    try {
      final prefs = await SharedPreferences.getInstance();
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/mobile/properties/${widget.propertyId}'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${prefs.getString('jwt_token')}'},
        body: jsonEncode(dataToUpdate),
      );
      Navigator.pop(context);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Datos guardados exitosamente!'), backgroundColor: Colors.green));
        if (blockName == 'detalles') {
          setState(() {
            _isOwnerLocked = _ownerCtrl.text.trim().isNotEmpty;
            _isPhoneLocked = _ownerPhoneCtrl.text.trim().isNotEmpty;
            _isMailLocked = _ownerMailCtrl.text.trim().isNotEmpty;
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${response.statusCode}'), backgroundColor: Colors.red));
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error de conexión'), backgroundColor: Colors.red));
    }
  }

  // =========================================================================
  // IMÁGENES: API REAL (CON COMPRESIÓN Y PANTALLA DE CARGA)
  // =========================================================================
  Future<void> _pickAndUploadImages() async {
    final List<XFile> pickedFiles = await _picker.pickMultiImage(
      imageQuality: 70,
    );
    
    if (pickedFiles.isEmpty) return;

    setState(() => _isUploadingImages = true);

    // MOSTRAR DIÁLOGO DE CARGA BLOQUEANTE
    showDialog(
      context: context,
      barrierDismissible: false, // El usuario NO puede cerrarlo tocando afuera
      builder: (BuildContext context) {
        return const AlertDialog(
          backgroundColor: Colors.white,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                strokeWidth: 4,
              ),
              SizedBox(height: 20),
              Text(
                'Comprimiendo imágenes...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Por favor espere',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        );
      },
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      var request = http.MultipartRequest(
        'POST', 
        Uri.parse('${ApiConfig.baseUrl}/api/v1/mobile/properties/${widget.propertyId}/images')
      );
      request.headers['Authorization'] = 'Bearer ${prefs.getString('jwt_token')}';

      int successCount = 0;
      int failCount = 0;
      List<String> compressionLogs = [];
      
      // Procesamos cada imagen individualmente
      for (int i = 0; i < pickedFiles.length; i++) {
        XFile file = pickedFiles[i];
        try {
          // Actualizar mensaje si son muchas imágenes
          if (pickedFiles.length > 1) {
            // Nota: Para actualizar el diálogo necesitaríamos usar StatefulBuilder
            // Por ahora dejamos el mensaje genérico
          }
          
          // COMPRIMIMOS antes de enviar
          final compressedBytes = await _compressImage(file, targetSizeKB: 1000);
          
          if (compressedBytes == null || compressedBytes.isEmpty) {
            print('⚠️ No se pudo comprimir ${file.name}, se salta');
            failCount++;
            continue;
          }
          
          // Verificamos que no exceda 1.5MB después de comprimir
          if (compressedBytes.length > 1.5 * 1024 * 1024) {
            print('⚠️ ${file.name} sigue siendo muy grande, reintentando...');
            
            final recompressed = await FlutterImageCompress.compressWithList(
              compressedBytes,
              minWidth: 1280,
              minHeight: 720,
              quality: 70,
            );
            
            request.files.add(http.MultipartFile.fromBytes(
              'graphic[]', 
              recompressed,
              filename: file.name,
            ));
          } else {
            request.files.add(http.MultipartFile.fromBytes(
              'graphic[]', 
              compressedBytes,
              filename: file.name,
            ));
          }
          
          successCount++;
          
        } catch (e) {
          print('❌ Error procesando ${file.name}: $e');
          failCount++;
        }
      }

      // CERRAR DIÁLOGO DE COMPRESIÓN
      Navigator.of(context).pop();

      if (successCount == 0) {
        setState(() => _isUploadingImages = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudieron procesar las imágenes'), 
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // MOSTRAR DIÁLOGO DE SUBIDA
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            backgroundColor: Colors.white,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  strokeWidth: 4,
                ),
                SizedBox(height: 20),
                Text(
                  'Subiendo imágenes...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Conectando con el servidor',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        },
      );

      print('📤 Subiendo $successCount imágenes...');
      
      var response = await request.send().timeout(const Duration(seconds: 120));
      
      // CERRAR DIÁLOGO DE SUBIDA
      Navigator.of(context).pop();
      
      setState(() => _isUploadingImages = false);
      
      // Leemos la respuesta
      final responseString = await response.stream.bytesToString();
      print('📥 Respuesta servidor: $responseString');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡$successCount imágenes subidas exitosamente!${failCount > 0 ? ' ($failCount fallaron)' : ''}'), 
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        _loadPropertyData(); // Recargamos para verlas
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error del servidor: ${response.statusCode}'), 
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      
    } catch (e) {
      // ASEGURARNOS DE CERRAR EL DIÁLOGO SI HAY ERROR
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      setState(() => _isUploadingImages = false);
      print('❌ Error general: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al subir fotos: $e'), 
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _deleteImageFromApi(Map<String, dynamic> img) async {
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator(color: Colors.white)));
    try {
      final prefs = await SharedPreferences.getInstance();
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/mobile/properties/${widget.propertyId}/images/${img['id_images_property']}'),
        headers: {'Authorization': 'Bearer ${prefs.getString('jwt_token')}'},
      );
      Navigator.pop(context);
      if (response.statusCode == 200) {
        setState(() { _images.removeWhere((element) => element['id_images_property'] == img['id_images_property']); });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Imagen borrada'), backgroundColor: Colors.black));
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al borrar')));
    }
  }

  Future<void> _updateImagesOrderByApi() async {
    // Recopila el nuevo orden leyendo el archivo físico ('file_name' viene del backend)
    List<String> newOrderNames = _images.map((img) => img['file_name'].toString()).toList();
    try {
      final prefs = await SharedPreferences.getInstance();
      await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/mobile/properties/${widget.propertyId}/images/reorder'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${prefs.getString('jwt_token')}'},
        body: jsonEncode({'images': newOrderNames}),
      );
    } catch (e) { print('Error ordenando'); }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: Colors.white, body: Center(child: CircularProgressIndicator(color: Colors.black)));
    }

    return DefaultTabController(
      length: 4, // <--- AHORA SON 4
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.black), onPressed: () => Navigator.pop(context)),
          title: Text('Gestionar RM-${widget.propertyId}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
          bottom: const TabBar(
            indicatorColor: Colors.black,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            isScrollable: true, // <--- ESTO EVITA QUE SE AMONTONEN LAS LETRAS
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: [
              Tab(text: 'Información'),
              Tab(text: 'Ubicación'), // <--- EL NUEVO TAB
              Tab(text: 'Imágenes'),
              Tab(text: 'Documentos'),
            ],
          ),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildInfoTab(),
            _buildMapsTab(), // <--- LA NUEVA VISTA DE MAPA
            _buildImagesTab(),
            _buildDocsTab(),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 1: INFORMACIÓN GENERAL
  // =========================================================================
  Widget _buildInfoTab() {
    bool allProtectedFieldsLocked = _isOwnerLocked && _isPhoneLocked && _isMailLocked;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ---------------- BLOQUE 1: DETALLES DEL INMUEBLE ----------------
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ExpansionTile(
              title: const Text('Detalles del Inmueble', style: TextStyle(fontWeight: FontWeight.bold)),
              initiallyExpanded: true,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildDropdown('Área', _areaTypes, _selAreaType, (v) => _selAreaType = v, allProtectedFieldsLocked)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildDropdown('Mercado', _marketTypes, _selMarketType, (v) => _selMarketType = v, allProtectedFieldsLocked)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      _buildTextField('Propietario', _ownerCtrl, _isOwnerLocked),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTextField('Teléfono', _ownerPhoneCtrl, _isPhoneLocked)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField('Correo', _ownerMailCtrl, _isMailLocked)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTextField('Precio Venta', _priceCtrl, allProtectedFieldsLocked, isNumber: true)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField('Precio Alquiler', _priceAdditionalCtrl, allProtectedFieldsLocked, isNumber: true)),
                        ],
                      ),
                      const SizedBox(height: 12),

                      _buildTextField('Precio', _priceCtrl, allProtectedFieldsLocked, isNumber: true),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTextField('Habitaciones', _bedroomsCtrl, allProtectedFieldsLocked, isNumber: true)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField('Baños', _bathroomsCtrl, allProtectedFieldsLocked, isNumber: true)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTextField('M² Terreno', _landCtrl, allProtectedFieldsLocked, isNumber: true)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField('M² Const.', _constCtrl, allProtectedFieldsLocked, isNumber: true)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTextField('Puestos', _garagesCtrl, allProtectedFieldsLocked, isNumber: true),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildDropdown('Tipo Inmueble', _housingTypes, _selHousingType, (v) => _selHousingType = v, allProtectedFieldsLocked)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildDropdown('Negocio', _businessModels, _selBusinessModel, (v) => _selBusinessModel = v, allProtectedFieldsLocked)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildDropdown('Estado', _states, _selState, (v) {
                        setState(() { _selState = v; _selMunicipality = null; _selCity = null; });
                      }, allProtectedFieldsLocked),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildDropdown('Municipio', _municipalities.where((m) => m['id_state'].toString() == _selState).toList(), _selMunicipality, (v) => setState(() { _selMunicipality = v; _selCity = null; }), allProtectedFieldsLocked)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildDropdown('Ciudad', _cities.where((c) => c['id_municipality'].toString() == _selMunicipality).toList(), _selCity, (v) => _selCity = v, allProtectedFieldsLocked)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTextField('Dirección', _addressCtrl, allProtectedFieldsLocked, maxLines: 2),
                      
                      if (allProtectedFieldsLocked)
                        _buildLockedWarning()
                      else
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 12)),
                              icon: const Icon(Icons.save, color: Colors.white, size: 18),
                              label: const Text('Guardar Detalles', style: TextStyle(color: Colors.white)),
                              onPressed: () => _updateBlock({
                                'area_type': _selAreaType, 'market_type': _selMarketType,
                                'owner': _ownerCtrl.text, 'owner_phone': _ownerPhoneCtrl.text, 'owner_mail': _ownerMailCtrl.text,
                                'price': _priceCtrl.text, 'price_additional': _priceAdditionalCtrl.text, 'bedrooms': _bedroomsCtrl.text, 'bathrooms': _bathroomsCtrl.text,
                                'meters_land': _landCtrl.text, 'meters_construction': _constCtrl.text,
                                'garages': _garagesCtrl.text,
                                'housing_type': _selHousingType, 'business_model': _selBusinessModel,
                                'state': _selState, 'municipality': _selMunicipality, 'city': _selCity,
                                'address': _addressCtrl.text,
                              }, 'detalles'),
                            ),
                          ),
                        )
                    ],
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ---------------- BLOQUE 2: CONDICIONES DE NEGOCIO ----------------
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ExpansionTile(
              title: const Text('Condiciones de Negocio', style: TextStyle(fontWeight: FontWeight.bold)),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDynamicCheckboxGrid(_businessConditionsCatalog, _selectedConditions, 'id'), 
                      
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 12)),
                            icon: const Icon(Icons.save, color: Colors.white, size: 18),
                            label: const Text('Guardar Condiciones', style: TextStyle(color: Colors.white)),
                            onPressed: () => _updateBlock({'business_conditions': _selectedConditions.join(',')}, 'condiciones'),
                          ),
                        ),
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ---------------- BLOQUE 3: A.C.E.A ----------------
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ExpansionTile(
              title: const Text('A.C.E.A', style: TextStyle(fontWeight: FontWeight.bold)),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('El presente gestor actúa como un motor para la generación de memorias descriptivas.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 16),
                      
                      if (_aceaCatalog.isEmpty)
                        const Text('Cargando catálogo ACEA o no hay opciones...', style: TextStyle(color: Colors.orange, fontStyle: FontStyle.italic)),

                      ..._buildDynamicAceaSections(),

                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 12)),
                            icon: const Icon(Icons.save, color: Colors.white, size: 18),
                            label: const Text('Guardar ACEA', style: TextStyle(color: Colors.white)),
                            onPressed: () => _updateBlock({
                              'environments': _selectedEnvironments.join(','),
                              'amenities': _selectedAmenities.join(','), 
                              'exterior': _selectedExterior.join(','),
                              'adjacencies': _selectedAdjacencies.join(','),
                            }, 'acea'),
                          ),
                        ),
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // =========================================================================
  // AGRUPADOR CRUZADO DE ACEA (BLINDADO ANTI-NULLS)
  // =========================================================================
  List<Widget> _buildDynamicAceaSections() {
    Map<String, List<dynamic>> groupedAcea = {};
    
    // Iteramos el catálogo y agrupamos por el nombre real de la categoría
    for (var item in _aceaCatalog) {
      if (item == null) continue; // Blindaje 1

      String categoryId = item['acea']?.toString() ?? ''; 
      String categoryName = categoryId; 

      for (var opt in _aceaOptions) {
        if (opt == null) continue; // Blindaje 2
        
        if (opt['id']?.toString() == categoryId) {
          // Blindaje 3: Si 'name' es nulo, usamos el ID vacío para que no explote
          categoryName = (opt['name']?.toString() ?? '').toLowerCase();
          break;
        }
      }

      if (!groupedAcea.containsKey(categoryName)) groupedAcea[categoryName] = [];
      groupedAcea[categoryName]!.add(item);
    }

    // Dibujamos cada grupo
    return groupedAcea.keys.map((catName) {
      List<String> activeList = [];
      String title = catName.toUpperCase();
      
      // Asignación de listas
      if (catName.contains('env') || catName.contains('amb') || catName == '1') {
        activeList = _selectedEnvironments;
        title = 'Ambientes';
      } else if (catName.contains('amen') || catName.contains('com') || catName == '2') { 
        activeList = _selectedAmenities; 
        title = 'Comodidades'; 
      } else if (catName.contains('ext') || catName == '3') {
        activeList = _selectedExterior;
        title = 'Exterior';
      } else if (catName.contains('adj') || catName.contains('ady') || catName == '4') {
        activeList = _selectedAdjacencies;
        title = 'Adyacencias';
      } else {
        return const SizedBox.shrink(); // Oculta basura de la BD
      }
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          const SizedBox(height: 8),
          _buildDynamicCheckboxGrid(groupedAcea[catName]!, activeList, 'id_acea'),
          const Divider(height: 20),
        ],
      );
    }).toList();
  }

  Widget _buildDynamicCheckboxGrid(List<dynamic> catalog, List<String> selectedList, String idKey) {
    if (catalog.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 12,
      runSpacing: 0,
      children: catalog.map((opt) {
        String optionId = opt[idKey]?.toString() ?? ''; 
        String optionName = opt['name']?.toString() ?? ''; 
        if (optionId.isEmpty) return const SizedBox.shrink();

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              activeColor: Colors.black,
              value: selectedList.contains(optionId), 
              onChanged: (bool? val) {
                setState(() {
                  if (val == true) {
                    selectedList.add(optionId);
                  } else {
                    selectedList.remove(optionId);
                  }
                });
              },
            ),
            Flexible(child: Text(optionName, style: const TextStyle(fontSize: 13, color: Colors.black), overflow: TextOverflow.ellipsis)),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildLockedWarning() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(color: Colors.red.shade50, border: Border.all(color: Colors.red.shade200), borderRadius: BorderRadius.circular(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'IMPORTANTE: De necesitar modificar los datos previamente cargados, deberás dirigirte a la gerencia de ventas y solicitarlo.',
              style: TextStyle(color: Colors.red.shade800, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, bool isLocked, {bool isNumber = false, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      enabled: !isLocked, 
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: isLocked,
        fillColor: isLocked ? Colors.grey.shade200 : Colors.white,
      ),
    );
  }

  Widget _buildDropdown(String label, List items, String? val, Function(String?) onChanged, bool isLocked) {
    if (items.isNotEmpty && val != null && !items.any((e) => (e['id']?.toString() ?? e['id_state']?.toString() ?? '') == val)) {
      val = null;
    }
    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: val,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), filled: isLocked, fillColor: isLocked ? Colors.grey.shade200 : Colors.white),
      items: items.map((item) => DropdownMenuItem(value: (item['id'] ?? item['id_state'] ?? '').toString(), child: Text(item['name'] ?? '', overflow: TextOverflow.ellipsis))).toList(),
      onChanged: isLocked ? null : onChanged,
    );
  }

 // =========================================================================
  // TAB 2: UBICACIÓN (OPENSTREETMAP - 100% GRATIS)
  // =========================================================================
  Widget _buildMapsTab() {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _currentLocation,
                  initialZoom: 14.0,
                  // Con solo tocar el mapa, el pin se mueve a esa posición
                  onTap: (tapPosition, latLng) {
                    setState(() {
                      _selectedLocation = latLng;
                    });
                  },
                ),
                children: [
                  // Capa del mapa visual (Las calles y edificios gratuitos)
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.asesoresrm.app',
                  ),
                  // Capa del marcador rojo
                  if (_selectedLocation != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selectedLocation!,
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                        ),
                      ],
                    ),
                ],
              ),
              Positioned(
                top: 10, left: 10, right: 10,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      _selectedLocation == null 
                        ? "Toca cualquier punto del mapa para marcar la ubicación" 
                        : "Lat: ${_selectedLocation!.latitude.toStringAsFixed(6)} | Lng: ${_selectedLocation!.longitude.toStringAsFixed(6)}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, padding: const EdgeInsets.symmetric(vertical: 15)),
              icon: const Icon(Icons.save, color: Colors.white),
              label: const Text('Guardar Coordenadas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: _selectedLocation == null 
                ? null 
                : () => _updateBlock({
                    'map_coordinates': "${_selectedLocation!.latitude}, ${_selectedLocation!.longitude}"
                  }, 'mapa'),
            ),
          ),
        )
      ],
    );
  }

  // =========================================================================
  // TAB 2: IMÁGENES (LISTA VERTICAL, ORDEN, DESCARGA Y BORRADO)
  // =========================================================================
  Widget _buildImagesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: InkWell(
            onTap: _isUploadingImages ? null : _pickAndUploadImages,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(color: Colors.blue.shade50, border: Border.all(color: Colors.blue.shade200, style: BorderStyle.solid), borderRadius: BorderRadius.circular(12)),
              child: _isUploadingImages 
                  ? const Center(child: CircularProgressIndicator())
                  : Column(children: [Icon(Icons.add_photo_alternate, size: 40, color: Colors.blue.shade700), const SizedBox(height: 8), Text('Agregar Imágenes', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold)), const Text('Se guardarán automáticamente', style: TextStyle(fontSize: 11, color: Colors.grey)),]),
            ),
          ),
        ),
        
        const Divider(height: 1),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Align(alignment: Alignment.centerLeft, child: Text('Usa las flechas para cambiar el orden de las fotos', style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)))),

        Expanded(
          child: _images.isEmpty 
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.photo_library_outlined, size: 60, color: Colors.grey.shade300), const SizedBox(height: 16), const Text('No hay fotos en la galería', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),]))
              : ListView.builder( // <--- AHORA ES UNA LISTA VERTICAL
                  padding: const EdgeInsets.all(16),
                  itemCount: _images.length,
                  itemBuilder: (context, index) {
                    final img = _images[index];
                    return _buildImageListItem(img, index); // Llamamos al nuevo diseño
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildImageListItem(Map<String, dynamic> img, int index) {
    return Card(
      key: ValueKey(img['id_images_property'].toString()), 
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            // 1. Miniatura de la imagen
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 80,
                height: 80,
                color: Colors.grey.shade200,
                child: Image.network(
                  img['name'], 
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey, size: 30),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)));
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // 2. Información de Posición
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Posición: ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  const Text('Imagen de la propiedad', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),

            // 3. Controles (Flechas, Descarga, Eliminar)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mover hacia Arriba (Hacia el inicio)
                IconButton(
                  icon: Icon(Icons.arrow_upward_rounded, color: index > 0 ? Colors.blue : Colors.grey.shade300),
                  tooltip: 'Subir',
                  onPressed: index > 0 ? () => _moveImage(index, -1) : null,
                ),
                // Mover hacia Abajo (Hacia el final)
                IconButton(
                  icon: Icon(Icons.arrow_downward_rounded, color: index < _images.length - 1 ? Colors.blue : Colors.grey.shade300),
                  tooltip: 'Bajar',
                  onPressed: index < _images.length - 1 ? () => _moveImage(index, 1) : null,
                ),
                // Descargar
                IconButton(
                  icon: const Icon(Icons.download_rounded, color: Colors.green),
                  tooltip: 'Descargar',
                  onPressed: () => _downloadFile(img['name']), // <-- Reciclamos tu función de descargar docs
                ),
                // Eliminar
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  tooltip: 'Eliminar',
                  onPressed: () => _deleteImageFromApi(img),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Función para mover la imagen a la izquierda (-1) o derecha (1)
  void _moveImage(int currentIndex, int direction) {
    setState(() {
      // Extraemos la imagen de su posición actual
      final item = _images.removeAt(currentIndex);
      // La insertamos en la nueva posición (actual + dirección)
      _images.insert(currentIndex + direction, item);
    });
    
    // Llamamos a la misma función de la API que ya tenías lista para guardar el nuevo orden
    _updateImagesOrderByApi();
  }

  // =========================================================================
  // TAB 3: DOCUMENTOS
  // =========================================================================
  Widget _buildDocsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, minimumSize: const Size(double.infinity, 50)),
            icon: const Icon(Icons.add_link, color: Colors.white),
            label: const Text('Asociar Documento', style: TextStyle(color: Colors.white)),
            onPressed: _pickAndUploadDocument, 
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _documents.isEmpty 
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.picture_as_pdf_outlined, size: 60, color: Colors.grey.shade300), const SizedBox(height: 16), const Text('No hay documentos asociados', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),]))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _documents.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final doc = _documents[index];
                    // Evitamos que intente dibujar un documento que venga nulo de la BD
                    if (doc == null) return const SizedBox.shrink(); 
                    return _buildDocTile(doc);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDocTile(dynamic docData) {
    // 1. Blindaje: Nos aseguramos de que el dato sea un mapa válido
    if (docData is! Map) return const SizedBox.shrink();
    
    // 2. Blindaje: Si el nombre o URL vienen nulos, les asignamos un string vacío o por defecto
    String docName = docData['name']?.toString() ?? 'Documento sin nombre';
    String docUrl = docData['url']?.toString() ?? '';

    IconData fileIcon = Icons.insert_drive_file_outlined;
    if (docName.toLowerCase().endsWith('.pdf')) fileIcon = Icons.picture_as_pdf_rounded;
    if (docName.toLowerCase().endsWith('.doc') || docName.toLowerCase().endsWith('.docx')) fileIcon = Icons.description_rounded;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Icon(fileIcon, color: Colors.black54, size: 30),
        title: Text(
          docName, 
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), 
          maxLines: 1, 
          overflow: TextOverflow.ellipsis
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.download_rounded, color: Colors.green, size: 20), 
              // Pasamos la URL asegurada (ya no es nula)
              onPressed: () => _downloadFile(docUrl)
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20), 
              // Pasamos el nombre asegurado (ya no es nulo)
              onPressed: () => _deleteDocumentFromApi(docName)
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadFile(String urlString) async {
    // 3. Blindaje extra: Si el botón intenta descargar una URL vacía, lo detenemos
    if (urlString.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URL del documento no disponible'), backgroundColor: Colors.red));
      return;
    }
    
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir el enlace'), backgroundColor: Colors.red));
      }
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al intentar abrir el archivo'), backgroundColor: Colors.red));
    }
  }

  Future<void> _pickAndUploadDocument() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
      withData: true, // <--- CRÍTICO PARA LA WEB: Fuerza a cargar los bytes
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      
      // Verificamos que tengamos los bytes del archivo
      if (file.bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo leer el archivo'), backgroundColor: Colors.red));
        return;
      }

      showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator(color: Colors.white)));
      
      try {
        final prefs = await SharedPreferences.getInstance();
        var request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}/api/v1/mobile/properties/${widget.propertyId}/documentary'));
        request.headers['Authorization'] = 'Bearer ${prefs.getString('jwt_token')}';
        
        // MAGIA PARA WEB Y MÓVIL: Enviar los bytes directamente
        request.files.add(http.MultipartFile.fromBytes(
          'documentary', 
          file.bytes!,
          filename: file.name,
        ));

        var response = await request.send().timeout(const Duration(seconds: 120));
        Navigator.pop(context);

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Documento subido'), backgroundColor: Colors.green));
          _loadPropertyData(); // Recarga para ver el documento
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error del servidor: ${response.statusCode}'), backgroundColor: Colors.red));
        }
      } catch (e) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al subir documento'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deleteDocumentFromApi(String fileName) async {
    if (fileName.isEmpty || fileName == 'Documento sin nombre') return;

    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator(color: Colors.white)));
    try {
      final prefs = await SharedPreferences.getInstance();
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/mobile/properties/${widget.propertyId}/documentary/delete'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${prefs.getString('jwt_token')}'},
        body: jsonEncode({'file_name': fileName}),
      );
      Navigator.pop(context);
      
      if (response.statusCode == 200) {
        setState(() { _documents.removeWhere((doc) => doc['name'] == fileName); });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Documento borrado'), backgroundColor: Colors.black));
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al borrar documento')));
    }
  }

  /// Comprime una imagen XFile y retorna bytes optimizados
  /// targetSizeKB: tamaño objetivo aproximado en KB (por defecto 800KB = ~0.8MB)
  Future<Uint8List?> _compressImage(XFile file, {int targetSizeKB = 800}) async {
    try {
      final bytes = await file.readAsBytes();
      final originalSizeKB = bytes.length / 1024;
      
      print('🖼️ Imagen original: ${originalSizeKB.toStringAsFixed(2)} KB');
      
      // Si ya es pequeña, no comprimir
      if (originalSizeKB < targetSizeKB) {
        print('✅ Imagen ya es pequeña, no se comprime');
        return bytes;
      }
      
      // Usamos compressWithList para TODAS las plataformas (Web y Móvil)
      // Esto trabaja directamente con bytes en memoria, sin archivos temporales
      final compressedBytes = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 1920,      // Máximo ancho
        minHeight: 1080,     // Máximo alto  
        quality: 85,         // Calidad 0-100 (85 es buen balance)
        rotate: 0,
      );
      
      final compressedSizeKB = compressedBytes.length / 1024;
      final reduction = ((originalSizeKB - compressedSizeKB) / originalSizeKB * 100).toStringAsFixed(1);
      print('✅ Comprimida: ${compressedSizeKB.toStringAsFixed(2)} KB (reducción: $reduction%)');
      
      return compressedBytes;
        
    } catch (e) {
      print('❌ Error comprimiendo: $e');
      // Si falla la compresión, retornamos los bytes originales
      return await file.readAsBytes();
    }
  }
}