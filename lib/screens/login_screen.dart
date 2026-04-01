import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart'; 
import 'dashboard_screen.dart'; 

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false; 
  bool _obscurePassword = true; 
  
  // NUEVOS ESTADOS PARA LOS CHECKBOXES
  bool _recordarUsuario = false;
  bool _biometriaActiva = false;

  final LocalAuthentication auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _cargarPrepreferencias();
  }

  // Carga los datos si "Recordar usuario" estaba marcado
  Future<void> _cargarPrepreferencias() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recordarUsuario = prefs.getBool('pref_recordar') ?? false;
      _biometriaActiva = prefs.getBool('pref_biometria') ?? false;
      if (_recordarUsuario) {
        _emailController.text = prefs.getString('saved_email') ?? '';
      }
    });
  }

  // ===================================================================
  // LÓGICA DE INICIO DE SESIÓN CON BIOMETRÍA (VINCULADA)
  // ===================================================================
  Future<void> _biometricLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email');
    final savedPass = prefs.getString('saved_password');

    // Validación de seguridad: ¿Es el mismo usuario que guardó la huella?
    if (_emailController.text.trim() != savedEmail || savedPass == null) {
      _mostrarMensaje('Por seguridad, ingresa tu clave manualmente para vincular tu huella a esta cuenta.', esError: true);
      return;
    }

    try {
      // CÓDIGO SÚPER SIMPLIFICADO
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Autentícate para acceder a tu cuenta $savedEmail',
      );

      if (didAuthenticate) {
        _passwordController.text = savedPass;
        _hacerLogin(); 
      }
    } catch (e) {
      _mostrarMensaje('Error de autenticación biométrica', esError: true);
    }
  }

  Future<void> _hacerLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _mostrarMensaje('Por favor llena todos los campos', esError: true);
      return;
    }

    setState(() { _isLoading = true; });

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.apiLogin),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _emailController.text.trim(), 'password': _passwordController.text}),
      );

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (data.containsKey('token')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', data['token']);
        
        // GUARDADO DE PREFERENCIAS SEGÚN LOS CHECKBOXES
        await prefs.setBool('pref_recordar', _recordarUsuario);
        await prefs.setBool('pref_biometria', _biometriaActiva);

        if (_recordarUsuario || _biometriaActiva) {
          await prefs.setString('saved_email', _emailController.text.trim());
          await prefs.setString('saved_password', _passwordController.text);
        } else {
          // Si no quiere recordar nada, limpiamos la bóveda
          await prefs.remove('saved_email');
          await prefs.remove('saved_password');
        }

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DashboardScreen(nombreUsuario: data['data_user']['full_name'])),
        );
      } else {
        _mostrarMensaje('Credenciales incorrectas', esError: true);
      }
    } catch (e) {
      _mostrarMensaje('Error de conexión', esError: true);
    } finally {
      if(mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header estilo Banco (Oscuro)
            Container(
              width: double.infinity, height: 250,
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40))
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/asesores-rm-new-white.webp', height: 60),
                  const SizedBox(height: 10),
                  const Text('PANEL CORPORATIVO', style: TextStyle(color: Colors.white54, letterSpacing: 2, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bienvenido', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                  const Text('Gestiona tus propiedades de forma segura.', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 30),
                  
                  _buildInput("Correo Electrónico", _emailController, Icons.person_outline),
                  const SizedBox(height: 20),
                  _buildInput("Contraseña", _passwordController, Icons.lock_outline, isPass: true),
                  
                  const SizedBox(height: 15),
                  
                  // CHECKBOXES ESTILO BANCO
                  _buildCheckbox("Recordar usuario", _recordarUsuario, (v) => setState(() => _recordarUsuario = v!)),
                  _buildCheckbox("Autenticación biométrica", _biometriaActiva, (v) => setState(() => _biometriaActiva = v!)),
                  
                  const SizedBox(height: 30),
                  
                  SizedBox(
                    width: double.infinity, height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: _isLoading ? null : _hacerLogin,
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : const Text('INGRESAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  
                  if (_biometriaActiva)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Center(
                        child: IconButton(
                          icon: const Icon(Icons.fingerprint, size: 50, color: Colors.blueGrey),
                          onPressed: _biometricLogin,
                        ),
                      ),
                    ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, IconData icon, {bool isPass = false}) {
    return TextField(
      controller: ctrl,
      obscureText: isPass ? _obscurePassword : false,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.black),
        labelText: label,
        suffixIcon: isPass ? IconButton(icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(width: 2))
      ),
    );
  }

  Widget _buildCheckbox(String title, bool val, Function(bool?) onChanged) {
    return Row(
      children: [
        Checkbox(value: val, onChanged: onChanged, activeColor: Colors.black),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87)),
      ],
    );
  }

  void _mostrarMensaje(String mensaje, {bool esError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje), backgroundColor: esError ? Colors.red : Colors.black));
  }
}