import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb; // Detecta si estamos en Web
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para rootBundle y AssetManifest
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart'; // Para abrir en Web

class DocumentosTab extends StatefulWidget {
  const DocumentosTab({super.key});

  @override
  State<DocumentosTab> createState() => _DocumentosTabState();
}

class _DocumentosTabState extends State<DocumentosTab> {
  List<String> _pdfPaths = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPdfAssets();
  }

  // =========================================================================
  // MAGIA: Leer la carpeta de assets (Compatible con Web y Móvil)
  // =========================================================================
  Future<void> _loadPdfAssets() async {
    try {
      // Forma moderna y segura de leer el manifiesto de assets en Flutter
      final AssetManifest manifest = await AssetManifest.loadFromAssetBundle(rootBundle);

      // Filtramos solo los que están en la carpeta documentos y son PDF
      final pdfs = manifest.listAssets()
          .where((String key) => key.contains('assets/documentos/'))
          .where((String key) => key.toLowerCase().endsWith('.pdf'))
          .toList();

      setState(() {
        _pdfPaths = pdfs;
        _isLoading = false;
      });
    } catch (e) {
      print("Error cargando PDFs: $e");
      setState(() => _isLoading = false);
    }
  }

  // =========================================================================
  // FUNCIÓN: Ver/Abrir el PDF (Adaptado al dispositivo)
  // =========================================================================
  Future<void> _viewPdf(String assetPath) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Abriendo documento...'), duration: Duration(seconds: 1)),
      );

      // LÓGICA PARA WEB (CHROME)
      if (kIsWeb) {
        // En web, los assets son accesibles directamente por su URL base.
        final String encodedPath = Uri.encodeFull(Uri.decodeFull(assetPath));
        final Uri url = Uri.parse(encodedPath);
        
        if (!await launchUrl(url, webOnlyWindowName: '_blank')) { // Abre en pestaña nueva
          throw Exception('No se pudo abrir el enlace web');
        }
        return; // Detenemos aquí si es web
      }

      // LÓGICA PARA MÓVILES (ANDROID / IOS)
      final byteData = await rootBundle.load(assetPath);
      final dir = await getTemporaryDirectory();
      
      // Decodificamos el nombre por si trae "%20" en lugar de espacios
      final fileName = Uri.decodeFull(assetPath.split('/').last);
      final file = File('${dir.path}/$fileName');
      
      await file.writeAsBytes(byteData.buffer.asUint8List());
      await OpenFilex.open(file.path);
      
    } catch (e) {
      print("Error abriendo PDF: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al intentar abrir el documento'), backgroundColor: Colors.red),
      );
    }
  }

  // =========================================================================
  // INTERFAZ DE USUARIO
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // CABECERA
        Container(
          padding: const EdgeInsets.all(20),
          width: double.infinity,
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Documentos', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black)),
              const SizedBox(height: 4),
              Text(
                '${_pdfPaths.length} formatos y contratos disponibles',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),

        // LISTA DE ARCHIVOS
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.black))
              : _pdfPaths.isEmpty
                  ? const Center(
                      child: Text('No se encontraron documentos en la carpeta.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _pdfPaths.length,
                      itemBuilder: (context, index) {
                        final path = _pdfPaths[index];
                        
                        // Decodificamos la URL para que los espacios ("%20") se vean normales
                        final decodedPath = Uri.decodeFull(path);
                        final rawName = decodedPath.split('/').last;
                        
                        // Quitamos la extensión .pdf para que se vea más limpio
                        final displayName = rawName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');

                        return _buildPdfCard(displayName, path);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildPdfCard(String title, String fullPath) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3))
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.picture_as_pdf, color: Colors.red.shade600, size: 28),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: const Text('Documento PDF', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
        
        // AL TOCAR LA TARJETA -> SE ABRE PARA VISUALIZAR
        onTap: () => _viewPdf(fullPath),
        
        // CORREGIDO: Solo mostramos el icono del Ojo en el lado derecho
        trailing: IconButton(
          icon: Icon(Icons.visibility_outlined, color: Colors.grey.shade600), // Usamos el ojo color gris
          onPressed: () => _viewPdf(fullPath), // Llama a la función de ver
          tooltip: 'Ver documento',
        ),
      ),
    );
  }
}