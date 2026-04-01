import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para copiar al portapapeles
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert'; // Para codificar en Base64 el ID del colega

class PropertyDetailScreen extends StatefulWidget {
  final Map<String, dynamic> property;

  const PropertyDetailScreen({Key? key, required this.property}) : super(key: key);

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen> {
  int _currentImageIndex = 0;

  // =========================================================================
  // 1. GENERADOR DINÁMICO DE DESCRIPCIONES (Blindado contra Ceros)
  // =========================================================================
  String _getDynamicDescription() {
    final prop = widget.property;
    
    // 1. Si la API trae una descripción real y extensa, la priorizamos.
    final String originalDesc = (prop['public_observations'] ?? prop['description'] ?? '').toString().trim();
    // Verificamos que no sea la descripción genérica de 'Excellent opportunity'
    if (originalDesc.isNotEmpty && !originalDesc.contains('Excelente oportunidad. Inmueble con acabados')) {
      return originalDesc;
    }

    // 2. Si no hay descripción real, GENERAMOS una automática y persuasiva.
    final String type = (prop['housing_type_name'] ?? 'propiedad').toString().toLowerCase();
    final String business = (prop['business_model_name'] ?? 'venta').toString().toLowerCase();
    final String city = prop['city_name'] ?? prop['municipality_name'] ?? 'una excelente zona';
    
    // Convertimos y limpiamos los valores numéricos
    final String meters = (prop['meters_construction']?.toString() ?? '0').trim();
    final String hab = (prop['bedrooms']?.toString() ?? '0').trim();
    final String bath = (prop['bathrooms']?.toString() ?? '0').trim();

    // Recopilamos algunas características clave (ACEA) para nutrir el texto
    List<String> keyFeatures = [];
    if (prop['amenities_names'] != null && prop['amenities_names'].toString().isNotEmpty) {
      // Tomamos solo las primeras 3 comodidades para no saturar el párrafo
      var amenities = prop['amenities_names'].toString().split(',').take(3).map((e) => e.trim().toLowerCase()).toList();
      keyFeatures.addAll(amenities);
    }

    // Artículos y adjetivos dinámicos según el género del inmueble
    String article = (type.endsWith('a') || type == 'oficina' || type == 'quinta') ? 'Esta' : 'Este';
    String adj = (type.endsWith('a') || type == 'oficina' || type == 'quinta') ? 'exclusiva' : 'exclusivo';

    String generatedText = "$article $adj $type se encuentra disponible para $business en la cotizada zona de $city. ";
    
    // LÓGICA CONDICIONAL: Solo menciona habs/baños si existen (son distintos a '0')
    String roomsText = '';
    if (hab != '0' && bath != '0') {
      roomsText = ', ofreciendo $hab habitaciones y $bath baños';
    } else if (hab != '0') {
      roomsText = ', ofreciendo $hab habitaciones';
    } else if (bath != '0') {
      roomsText = ', ofreciendo $bath baños';
    }

    generatedText += "Cuenta con un área de $meters m² excelentemente distribuidos$roomsText para garantizar el máximo confort. ";
    
    if (keyFeatures.isNotEmpty) {
      generatedText += "Entre sus atractivos principales destacan sus espacios con ${keyFeatures.join(', ')}. ";
    }
    
    generatedText += "Es la oportunidad perfecta para quienes buscan calidad, ubicación estratégica y plusvalía garantizada. Agenda tu visita para conocer cada detalle.";

    return generatedText;
  }

  // =========================================================================
  // 2. LAUNCHER DE GOOGLE MAPS NATIVO
  // =========================================================================
  Future<void> _openGoogleMaps() async {
    // Las coordenadas suelen venir como "latitud, longitud" desde tu backend
    final String coords = widget.property['map_coordinates']?.toString() ?? '';
    if (coords.trim().isEmpty) return;

    final Uri url = Uri.parse("https://googleusercontent.com/maps.google.com/0");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir el mapa')));
    }
  }

  // =========================================================================
  // HELPERS DE FORMATO Y DATOS BÁSICOS
  // =========================================================================
  String _formatPrice() {
    double sale = double.tryParse(widget.property['price']?.toString() ?? '0') ?? 0;
    double rent = double.tryParse(widget.property['price_additional']?.toString() ?? '0') ?? 0;
    final formatter = NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 0);
    
    if (sale > 0) return formatter.format(sale);
    if (rent > 0) return '${formatter.format(rent)}/mes';
    return 'Consultar';
  }

  String _getLocation() {
    List<String> loc = [];
    if (widget.property['city_name'] != null) loc.add(widget.property['city_name']);
    else if (widget.property['municipality_name'] != null) loc.add(widget.property['municipality_name']);
    if (widget.property['state_name'] != null && !loc.contains(widget.property['state_name'])) {
      loc.add(widget.property['state_name']);
    }
    return loc.isNotEmpty ? loc.join(', ') : 'Ubicación no especificada';
  }

  // =========================================================================
  // FUNCIONES DE COMPARTIR Y CONTACTO
  // =========================================================================
  Future<void> _openWhatsApp() async {
    String phone = widget.property['agent_phone'] ?? '584143156189';
    phone = phone.replaceAll(RegExp(r'[^\d]'), ''); 
    String message = "Hola ${widget.property['agent_name'] ?? 'Asesores RM'}. Quiero información de la propiedad RM00${widget.property['id_properties']}";
    final Uri url = Uri.parse("https://wa.me/$phone?text=${Uri.encodeComponent(message)}");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir WhatsApp')));
    }
  }

  Future<void> _shareViaWhatsApp(String link, bool isColleague) async {
    final prop = widget.property;
    String text = isColleague 
        ? "¡Hola! Te comparto esta propiedad de Asesores RM (Ficha sin datos de contacto): $link"
        : "¡Hola! Mira esta increíble propiedad en ${prop['municipality_name'] ?? 'Caracas'}: $link";
    final Uri url = Uri.parse("https://wa.me/?text=${Uri.encodeComponent(text)}");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir WhatsApp')));
    }
  }

  void _copyLink(String link, String successMessage) {
    Clipboard.setData(ClipboardData(text: link));
    Navigator.pop(context); // Cerramos el Modal
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(successMessage, style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.green.shade600, behavior: SnackBarBehavior.floating,
    ));
  }

  void _showShareModal() {
    final prop = widget.property;
    final String idStr = prop['id_properties'].toString();
    const String baseUrl = 'https://tuasesorrm.com.ve'; 
    final String directLink = '$baseUrl/propiedad/$idStr'; 
    final String encryptedId = base64Encode(utf8.encode(idStr));
    final String colleagueLink = '$baseUrl/ficha/$encryptedId';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))),
          padding: const EdgeInsets.all(24),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Compartir Propiedad', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black)),
                    IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context))
                  ],
                ),
                const SizedBox(height: 16),
                const Text('PARA TU CLIENTE DIRECTO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                const SizedBox(height: 4),
                const Text('Enlace normal con toda la marca y tus datos de contacto.', style: TextStyle(fontSize: 13, color: Colors.black54)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _copyLink(directLink, '¡Enlace Directo Copiado!'), icon: const Icon(Icons.copy, size: 18, color: Colors.black),
                        label: const Text('Copiar Link', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: BorderSide(color: Colors.grey.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () { Navigator.pop(context); _shareViaWhatsApp(directLink, false); },
                        icon: const Icon(Icons.chat, size: 18, color: Colors.white), 
                        label: const Text('WhatsApp', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
                      ),
                    ),
                  ],
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider()),
                Row(
                  children: [
                    const Text('PARA UN COLEGA ASESOR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black, letterSpacing: 1)),
                    const SizedBox(width: 8),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(4)), child: const Text('MARCA BLANCA', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('Ficha aislada. Sin logotipos, sin botón de WhatsApp y con código oculto.', style: TextStyle(fontSize: 13, color: Colors.black54)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _copyLink(colleagueLink, '¡Ficha de Colega Copiada!'), icon: const Icon(Icons.copy, size: 18, color: Colors.black),
                        label: const Text('Copiar Ficha', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: BorderSide(color: Colors.grey.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () { Navigator.pop(context); _shareViaWhatsApp(colleagueLink, true); },
                        icon: const Icon(Icons.chat, size: 18, color: Colors.white),
                        label: const Text('WhatsApp', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  // =========================================================================
  // INTERFAZ DE USUARIO PRINCIPAL (BUILD)
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    final prop = widget.property;
    final List<dynamic> images = prop['images'] ?? [{'url': 'https://images.unsplash.com/photo-1560518883-ce09059eeffa?w=800&q=80'}];
    final String title = '${prop['housing_type_name'] ?? 'Propiedad'} en ${prop['city_name'] ?? prop['municipality_name'] ?? 'Caracas'}';
    
    // Verificamos si la propiedad trae coordenadas válidas para mostrar la tarjeta del mapa
    final bool hasCoordinates = prop['map_coordinates'] != null && prop['map_coordinates'].toString().trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // 1. APP BAR CON FOTOS
          SliverAppBar(
            expandedHeight: 350, pinned: true, backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(icon: const Icon(Icons.ios_share, color: Colors.white), onPressed: _showShareModal, tooltip: 'Compartir Propiedad'),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    itemCount: images.length,
                    onPageChanged: (index) => setState(() => _currentImageIndex = index),
                    itemBuilder: (context, index) {
                      return Image.network(images[index]['url'], fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 50, color: Colors.grey));
                    },
                  ),
                  Positioned(bottom: 0, left: 0, right: 0, child: Container(height: 100, decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.8), Colors.transparent])))),
                  Positioned(
                    bottom: 16, left: 16, right: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)), child: Text((prop['business_model_name'] ?? 'En Venta').toString().toUpperCase(), style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1))),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)), child: Text('${_currentImageIndex + 1} / ${images.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),

          // 2. CONTENIDO PRINCIPAL
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // CABECERA
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black, height: 1.2)),
                            const SizedBox(height: 8),
                            Row(children: [Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade600), const SizedBox(width: 4), Expanded(child: Text(_getLocation(), style: TextStyle(color: Colors.grey.shade600, fontSize: 14)))]),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_formatPrice(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black)),
                          const SizedBox(height: 4),
                          Text('Ref: RM00${prop['id_properties']}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1)),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ESTADÍSTICAS DINÁMICAS (Renderizado Condicional: Oculta los ceros)
                  // Usamos Wrap en lugar de Row para que, si quedan pocas stats, no queden divisores flotando o huecos.
                  Wrap(
                    spacing: 16, runSpacing: 16, // Espaciado horizontal y vertical
                    children: [
                      if ((prop['bedrooms']?.toString() ?? '0') != '0')
                        _buildMainStat(Icons.bed_outlined, prop['bedrooms'].toString(), 'Habitaciones'),
                      
                      if ((prop['bathrooms']?.toString() ?? '0') != '0')
                        _buildMainStat(Icons.bathtub_outlined, prop['bathrooms'].toString(), 'Baños'),
                      
                      if ((prop['meters_construction']?.toString() ?? '0') != '0')
                        _buildMainStat(Icons.square_foot_outlined, prop['meters_construction'].toString(), 'M² Const.'),
                      
                      if ((prop['garages']?.toString() ?? '0') != '0')
                        _buildMainStat(Icons.directions_car_outlined, prop['garages'].toString(), 'Puestos'),
                    ],
                  ),
                  
                  const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Divider(color: Color(0xFFEEEEEE), thickness: 1)),

                  // DESCRIPCIÓN DINÁMICA
                  const Text('Descripción', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black)),
                  const SizedBox(height: 12),
                  Text(
                    _getDynamicDescription(),
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.6),
                  ),

                  const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Divider(color: Color(0xFFEEEEEE), thickness: 1)),

                  // CARACTERÍSTICAS ACEA
                  const Text('Características', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black)),
                  const SizedBox(height: 16),
                  
                  _buildAceaSection('Ambientes', prop['environments_names']),
                  _buildAceaSection('Comodidades', prop['amenities_names']),
                  _buildAceaSection('Exteriores', prop['exterior_names']),
                  _buildAceaSection('Adyacencias', prop['adjacencies_names']),

                  // SECCIÓN DE MAPA (Blanco y Negro - Estilo Minimalista)
                  if (hasCoordinates) ...[
                    const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Divider(color: Color(0xFFEEEEEE), thickness: 1)),
                    const Text('Ubicación', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black)),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _openGoogleMaps,
                      child: Container(
                        height: 160,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade100), // Borde gris muy suave
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 3. IMAGEN DE FONDO (Forzada a Blanco y Negro)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                // Usamos una imagen de mapa minimalista
                                'https://images.unsplash.com/photo-1569336415962-a4bd9f69cd83?w=800&q=80', 
                                fit: BoxFit.cover, 
                                width: double.infinity, 
                                height: double.infinity, 
                                // LA MAGIA BLANCO Y NEGRO: Mezclamos con blanco y usamos BlendMode.color
                                // Esto desatura la imagen completamente.
                                color: Colors.white,
                                colorBlendMode: BlendMode.color, 
                              ),
                            ),
                            // Capa de superposición para suavizar más (opcional, para look 'blanco')
                            Container(
                              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Colors.white.withOpacity(0.4)),
                            ),
                            // Botón central minimalista
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.map_outlined, color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text('Abrir en Google Maps', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 100), 
                ],
              ),
            ),
          )
        ],
      ),

      // 3. BARRA INFERIOR DE CONTACTO
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
        child: Row(
          children: [
            // Info del Agente - Blindado contra enlaces vacíos/nulos de Génesis
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade200)),
              child: ClipOval(
                child: Image.network(
                  prop['agent_photo']?.toString() ?? '', fit: BoxFit.cover,
                  // Si no hay foto, el errorBuilder muestra el icono de User
                  errorBuilder: (context, error, stackTrace) => Icon(Icons.person_outline, size: 28, color: Colors.grey.shade400),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(prop['agent_name'] ?? 'Asesor RM', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const Text('Agente Inmobiliario', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _openWhatsApp,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
              icon: const Icon(Icons.chat_bubble_outline, size: 18), label: const Text('Contactar', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMainStat(IconData icon, String value, String label) {
    return Container(
      width: 75, padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          Icon(icon, color: Colors.grey.shade400, size: 24), const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black)), const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 0.5), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildAceaSection(String title, dynamic aceaData) {
    if (aceaData == null || aceaData.toString().trim().isEmpty) return const SizedBox.shrink();
    List<String> items = aceaData.toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)), const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: items.map((item) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(20)), child: Text(item, style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500)))).toList(),
          ),
        ],
      ),
    );
  }
}