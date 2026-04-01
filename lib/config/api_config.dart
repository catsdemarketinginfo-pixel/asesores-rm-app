// lib/config/api_config.dart
import 'package:flutter/foundation.dart';

class ApiConfig {
  // =========================================================
  // EL SUICHE PRINCIPAL
  // 'false' para que apunte directamente a Producción
  // =========================================================
  static const bool isLocal = false;

  // =========================================================
  // URL DEL BACKEND (Automático)
  // =========================================================
  static String get baseUrl {
    if (isLocal) {
      if (kIsWeb) {
        return 'http://localhost:8080';
      } else {
        return 'http://10.0.2.2:8080'; 
      }
    } else {
      // PRODUCCIÓN: Tu dominio real en internet
      return 'https://rems.tuasesorrm.com.ve';
    }
  }

  // =========================================================
  // RUTAS ESPECÍFICAS DE LA APP
  // =========================================================
  
  // Login
  static String get apiLogin => '$baseUrl/api/v1/login';

  // Visitas (¡La que causaba el error!)
  static String get apiMobileVisits => '$baseUrl/api/v1/mobile/visits';

  // Búsquedas
  static String get apiMobileSearches => '$baseUrl/api/v1/mobile/searches';

  // Propiedades Móvil
  static String get apiMobileProperties => '$baseUrl/api/v1/mobile/properties';

  // Propiedades Públicas
  static String get apiPublicProperties => '$baseUrl/api/public/properties';
}