import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import 'document_platform.dart';
import 'modules/projects/projects_module.dart';
import 'package:url_launcher/url_launcher.dart';

const _claveUsuariosLocales = 'edunova_usuarios_locales_v1';

Future<List<Map<String, String>>> _cargarUsuariosLocales(
  SharedPreferences preferencias,
) async {
  final guardados = preferencias.getString(_claveUsuariosLocales);
  if (guardados != null && guardados.isNotEmpty) {
    try {
      final datos = jsonDecode(guardados) as List;
      return datos
          .map((usuario) => Map<String, String>.from(usuario as Map))
          .toList();
    } catch (_) {
      await preferencias.remove(_claveUsuariosLocales);
    }
  }

  // Migra la cuenta de la versión anterior al nuevo almacenamiento local.
  final correoAnterior = preferencias.getString('edunova_cuenta_correo');
  final contrasenaAnterior = preferencias.getString('edunova_cuenta_contrasena');
  if (correoAnterior == null || contrasenaAnterior == null) return [];
  return [
    {
      'correo': correoAnterior,
      'contrasena': contrasenaAnterior,
      'nombre': preferencias.getString('edunova_cuenta_nombre') ?? 'Estudiante',
    },
  ];
}

Future<void> _guardarUsuariosLocales(
  SharedPreferences preferencias,
  List<Map<String, String>> usuarios,
) async {
  await preferencias.setString(_claveUsuariosLocales, jsonEncode(usuarios));
}

String _claveDatosUsuario(String prefijo, String correo) =>
    '${prefijo}_${base64UrlEncode(utf8.encode(correo.toLowerCase()))}';

String _claveFotoUsuario(String correo) =>
    _claveDatosUsuario('edunova_foto', correo);

class _FotoCircular extends StatelessWidget {
  final Uint8List? bytes;
  final double radio;

  const _FotoCircular({required this.bytes, required this.radio});

  @override
  Widget build(BuildContext context) {
    final lado = radio * 2;
    return Container(
      width: lado,
      height: lado,
      decoration: const BoxDecoration(
        color: Colors.blueAccent,
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: bytes == null
          ? Icon(Icons.person, size: radio, color: Colors.white)
          : Image.memory(
              bytes!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => Icon(
                Icons.person,
                size: radio,
                color: Colors.white,
              ),
            ),
    );
  }
}

void main() {
  runApp(const EduNovaApp());
}

class EduNovaApp extends StatelessWidget {
  const EduNovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EduNova - Sistema Académico',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A4D83),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F8FC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF083B66),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF5F8FB),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _cargando = true;
  bool _sesionIniciada = false;

  @override
  void initState() {
    super.initState();
    _comprobarSesion();
  }

  Future<void> _comprobarSesion() async {
    final preferencias = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _sesionIniciada = preferencias.getBool('edunova_sesion_activa') ?? false;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _sesionIniciada ? const PerfilScreen() : const AuthScreen();
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  final _nombre = TextEditingController();
  bool _registro = false;
  bool _mostrarContrasena = false;
  bool _procesando = false;

  @override
  void dispose() {
    _correo.dispose();
    _contrasena.dispose();
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _continuar() async {
    final correo = _correo.text.trim().toLowerCase();
    final contrasena = _contrasena.text;
    final nombre = _nombre.text.trim();
    if (!correo.contains('@') || contrasena.length < 6 || (_registro && nombre.isEmpty)) {
      _mensaje('Completa los datos. La contraseña debe tener al menos 6 caracteres.');
      return;
    }
    setState(() => _procesando = true);
    final preferencias = await SharedPreferences.getInstance();
    final usuarios = await _cargarUsuariosLocales(preferencias);
    if (_registro) {
      if (usuarios.any((usuario) => usuario['correo'] == correo)) {
        _mensaje('Ya existe una cuenta con ese correo.');
      } else if (usuarios.length >= 5) {
        _mensaje('La base local ya tiene cinco usuarios registrados.');
      } else {
        usuarios.add({'correo': correo, 'contrasena': contrasena, 'nombre': nombre});
        await _guardarUsuariosLocales(preferencias, usuarios);
        await preferencias.setBool('edunova_sesion_activa', false);
        _correo.clear();
        _contrasena.clear();
        _nombre.clear();
        if (mounted) {
          setState(() => _registro = false);
          _mensaje('Cuenta creada. Ahora inicia sesión con tu correo y contraseña.');
        }
      }
    } else if (usuarios.any((usuario) =>
        usuario['correo'] == correo && usuario['contrasena'] == contrasena)) {
      await preferencias.setString('edunova_usuario_actual', correo);
      await preferencias.setBool('edunova_sesion_activa', true);
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PerfilScreen()));
      }
    } else {
      _mensaje('Correo o contraseña incorrectos.');
    }
    if (mounted) setState(() => _procesando = false);
  }

  void _mensaje(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
    if (mounted) setState(() => _procesando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF062F55), Color(0xFF0B5B96), Color(0xFF4C9BD1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(top: -100, right: -60, child: _decorativeOrb(230, Colors.white.withAlpha(18))),
            Positioned(bottom: -80, left: -60, child: _decorativeOrb(210, Colors.black.withAlpha(18))),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Card(
                    elevation: 20,
                    shadowColor: Colors.black.withAlpha(70),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 30, 28, 24),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: const Color(0xFF0B568D), borderRadius: BorderRadius.circular(18)),
                            child: const Icon(Icons.explore, color: Colors.white, size: 38),
                          ),
                          const SizedBox(height: 14),
                          const Text('EDUNOVA', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2, color: Color(0xFF083B66))),
                          const SizedBox(height: 4),
                          Text(_registro ? 'Crea tu cuenta y comienza' : 'Descubre tu camino académico', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                          const SizedBox(height: 25),
                          if (_registro) ...[
                            TextField(controller: _nombre, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Nombre completo', prefixIcon: Icon(Icons.person_outline))),
                            const SizedBox(height: 14),
                          ],
                          TextField(controller: _correo, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Correo electrónico', prefixIcon: Icon(Icons.email_outlined))),
                          const SizedBox(height: 14),
                          TextField(controller: _contrasena, obscureText: !_mostrarContrasena, onSubmitted: (_) => _continuar(), decoration: InputDecoration(labelText: 'Contraseña', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => _mostrarContrasena = !_mostrarContrasena), icon: Icon(_mostrarContrasena ? Icons.visibility_off : Icons.visibility)))),
                          const SizedBox(height: 22),
                          SizedBox(width: double.infinity, child: FilledButton(onPressed: _procesando ? null : _continuar, style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0B568D), padding: const EdgeInsets.symmetric(vertical: 14)), child: Text(_procesando ? 'Procesando...' : (_registro ? 'Registrarme' : 'Iniciar sesión')))),
                          const SizedBox(height: 10),
                          TextButton(onPressed: _procesando ? null : () => setState(() => _registro = !_registro), child: Text(_registro ? 'Ya tengo una cuenta' : 'Crear una cuenta nueva')),
                          const SizedBox(height: 6),
                          const Text('Acceso local guardado en este navegador', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _decorativeOrb(double size, Color color) => Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

Future<void> _cerrarSesion(BuildContext context) async {
  final preferencias = await SharedPreferences.getInstance();
  await preferencias.setBool('edunova_sesion_activa', false);
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const AuthScreen()),
    (route) => false,
  );
}

// ==========================================
// 1. PANTALLA DE PERFIL (Etapa 1)
// ==========================================
class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  Uint8List? _fotoPerfil;

  final TextEditingController _txtNombreController = TextEditingController();
  final TextEditingController _txtEspecialidadController =
      TextEditingController(text: 'Desarrollo de Software');
  final TextEditingController _txtAnioController = TextEditingController(
    text: '3° Año',
  );

  @override
  void initState() {
    super.initState();
    _cargarFotoPerfil();
    _cargarCorreoUsuario();
  }

  Future<void> _cargarCorreoUsuario() async {
    final preferencias = await SharedPreferences.getInstance();
    final correo = preferencias.getString('edunova_usuario_actual');
    if (!mounted || correo == null || correo.isEmpty) return;
    if (_txtNombreController.text.isEmpty) {
      setState(() => _txtNombreController.text = correo);
    }
  }

  Future<void> _cargarFotoPerfil() async {
    final preferencias = await SharedPreferences.getInstance();
    final correo = preferencias.getString('edunova_usuario_actual');
    final guardada = correo == null
        ? preferencias.getString('edunova_foto_perfil')
        : preferencias.getString(_claveFotoUsuario(correo));
    if (!mounted || guardada == null || guardada.isEmpty) return;
    try {
      setState(() => _fotoPerfil = base64Decode(guardada));
    } catch (_) {
      final clave = correo == null
          ? 'edunova_foto_perfil'
          : _claveFotoUsuario(correo);
      await preferencias.remove(clave);
    }
  }

  Future<void> _seleccionarFoto() async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (resultado == null || resultado.files.isEmpty) return;
    final datosImagen = resultado.files.single.bytes;
    if (datosImagen == null || datosImagen.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo leer la fotografía seleccionada.')),
        );
      }
      return;
    }

    Uint8List imagenParaMostrar = Uint8List.fromList(datosImagen);
    try {
      final imagenDecodificada = img.decodeImage(datosImagen);
      if (imagenDecodificada != null) {
        final imagenReducida = img.copyResize(imagenDecodificada, width: 512);
        imagenParaMostrar = Uint8List.fromList(
          img.encodeJpg(imagenReducida, quality: 82),
        );
      }
    } catch (_) {
      // Si el formato no se puede optimizar, se conserva la imagen original.
    }

    // Mostrarla antes de escribir en localStorage: así nunca queda el avatar azul
    // aunque el navegador rechace una imagen demasiado grande.
    if (mounted) setState(() => _fotoPerfil = imagenParaMostrar);

    final preferencias = await SharedPreferences.getInstance();
    final correo = preferencias.getString('edunova_usuario_actual');
    final clave = correo == null
        ? 'edunova_foto_perfil'
        : _claveFotoUsuario(correo);
    try {
      await preferencias.setString(clave, base64Encode(imagenParaMostrar));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fotografía guardada correctamente.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La foto se muestra, pero el navegador no permitió guardarla.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EduNova - Perfil del Estudiante')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Center(
              child: GestureDetector(
                onTap: _seleccionarFoto,
                child: Stack(
                  children: [
                    _FotoCircular(bytes: _fotoPerfil, radio: 50),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.blueAccent,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 20,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: OutlinedButton.icon(
                onPressed: _seleccionarFoto,
                icon: const Icon(Icons.upload_file),
                label: const Text('Seleccionar fotografía'),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _txtNombreController,
              decoration: const InputDecoration(
                labelText: 'Nombre Completo',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _txtEspecialidadController,
              decoration: const InputDecoration(
                labelText: 'Especialidad',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _txtAnioController,
              decoration: const InputDecoration(
                labelText: 'Año de Bachillerato',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              onPressed: () {
                // Navegación hacia el Menú Principal
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MenuPrincipalScreen(
                      nombreEstudiante: _txtNombreController.text,
                      especialidad: _txtEspecialidadController.text,
                      anio: _txtAnioController.text,
                      fotoPerfil: _fotoPerfil,
                    ),
                  ),
                );
              },
              child: const Text('Continuar', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. PANTALLA DE MENÚ PRINCIPAL (Etapa 2)
// ==========================================
class MenuPrincipalScreen extends StatelessWidget {
  final String nombreEstudiante;
  final String especialidad;
  final String anio;
  final Uint8List? fotoPerfil;

  const MenuPrincipalScreen({
    super.key,
    required this.nombreEstudiante,
    required this.especialidad,
    required this.anio,
    this.fotoPerfil,
  });

  @override
  Widget build(BuildContext context) {
    // Módulos del sistema. Eventos y Permisos ya están habilitados.
    final List<Map<String, dynamic>> modulos = [
      {'titulo': 'Calificaciones', 'activo': true, 'icono': Icons.school},
      {'titulo': 'Proyectos', 'activo': true, 'icono': Icons.folder},
      {'titulo': 'Eventos', 'activo': true, 'icono': Icons.event},
      {
        'titulo': 'Permisos',
        'activo': true,
        'icono': Icons.assignment_turned_in,
      },
      {'titulo': 'Documentos', 'activo': true, 'icono': Icons.description},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('EduNova - Menú Principal'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => _cerrarSesion(context),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PerfilUsuarioScreen(
                    nombreEstudiante: nombreEstudiante,
                    especialidad: especialidad,
                    anio: anio,
                    fotoPerfil: fotoPerfil,
                  ),
                ),
              ),
              child: _FotoCircular(bytes: fotoPerfil, radio: 19),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5F9FD), Color(0xFFE7F1F9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [Color(0xFF073A66), Color(0xFF1684BC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, 8))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('DESCUBRE EDUNOVA', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.3)),
                        const SizedBox(height: 8),
                        Text('¡Bienvenido, $nombreEstudiante!', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        const Text('Explora tus espacios académicos y continúa aprendiendo.', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                  ),
                  Icon(Icons.explore, color: Colors.white.withAlpha(210), size: 72),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const Text('Tu espacio académico', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF123B5D))),
            const SizedBox(height: 4),
            const Text('Selecciona una sección para continuar', style: TextStyle(color: Colors.blueGrey)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: modulos.length,
                itemBuilder: (context, index) {
                  final modulo = modulos[index];
                  final bool activo = modulo['activo'];

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      leading: Icon(
                        modulo['icono'],
                        color: activo ? Colors.blue : Colors.grey,
                      ),
                      title: Text(
                        modulo['titulo'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: activo ? Colors.black : Colors.grey,
                        ),
                      ),
                      trailing: activo
                          ? const Icon(Icons.arrow_forward_ios, size: 16)
                          : const Chip(
                              label: Text(
                                'Próximamente',
                                style: TextStyle(fontSize: 12),
                              ),
                              backgroundColor: Colors.amberAccent,
                            ),
                      onTap: activo
                          ? () {
                              Widget pantalla;
                              switch (modulo['titulo']) {
                                case 'Calificaciones':
                                  pantalla = const CalificacionesScreen();
                                  break;
                                case 'Proyectos':
                                  pantalla = const ProjectsScreen();
                                  break;
                                case 'Eventos':
                                  pantalla = const EventosScreen();
                                  break;
                                case 'Permisos':
                                  pantalla = const PermisosScreen();
                                  break;
                                case 'Documentos':
                                  pantalla = const DocumentosScreen();
                                  break;
                                default:
                                  pantalla = const CalificacionesScreen();
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => pantalla),
                              );
                            }
                          : () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'El módulo "${modulo['titulo']}" estará disponible próximamente.',
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

// ==========================================
// MÓDULO DE DOCUMENTOS DEL ESTUDIANTE
// ==========================================
class DocumentoLocal {
  final String nombre;
  final String ruta;
  final int bytes;
  final DateTime fecha;

  const DocumentoLocal({
    required this.nombre,
    required this.ruta,
    required this.bytes,
    required this.fecha,
  });

  String get extension => nombre.contains('.')
      ? nombre.split('.').last.toLowerCase()
      : '';

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'ruta': ruta,
        'bytes': bytes,
        'fecha': fecha.toIso8601String(),
      };

  factory DocumentoLocal.fromMap(Map<String, dynamic> map) => DocumentoLocal(
        nombre: map['nombre'] as String,
        ruta: map['ruta'] as String,
        bytes: int.parse(map['bytes'].toString()),
        fecha: DateTime.parse(map['fecha'] as String),
      );
}

class DocumentosScreen extends StatefulWidget {
  const DocumentosScreen({super.key});

  @override
  State<DocumentosScreen> createState() => _DocumentosScreenState();
}

class _DocumentosScreenState extends State<DocumentosScreen> {
  static const _prefijoDocumentos = 'edunova_documentos_locales';
  final List<DocumentoLocal> _documentos = [];
  bool _cargando = true;
  String? _claveDocumentosActual;

  @override
  void initState() {
    super.initState();
    _cargarDocumentos();
  }

  Future<void> _cargarDocumentos() async {
    final preferencias = await SharedPreferences.getInstance();
    final correo = preferencias.getString('edunova_usuario_actual');
    _claveDocumentosActual = correo == null
        ? _prefijoDocumentos
        : _claveDatosUsuario(_prefijoDocumentos, correo);
    final registros = preferencias.getStringList(_claveDocumentosActual!) ?? [];
    final documentos = <DocumentoLocal>[];
    for (final registro in registros) {
      try {
        documentos.add(DocumentoLocal.fromMap(
          Map<String, dynamic>.from(Uri.splitQueryString(registro)),
        ));
      } catch (_) {
        // Ignorar registros antiguos o dañados sin impedir abrir el módulo.
      }
    }
    if (mounted) {
      setState(() {
        _documentos
          ..clear()
          ..addAll(documentos);
        _cargando = false;
      });
    }
  }

  Future<void> _guardarIndice() async {
    final preferencias = await SharedPreferences.getInstance();
    final clave = _claveDocumentosActual;
    if (clave == null) return;
    final registros = _documentos
        .map((documento) => Uri(queryParameters: {
              'nombre': documento.nombre,
              'ruta': documento.ruta,
              'bytes': documento.bytes.toString(),
              'fecha': documento.fecha.toIso8601String(),
            }).query)
        .toList();
    await preferencias.setStringList(clave, registros);
  }

  Future<void> _agregarDocumento() async {
    final seleccionado = await selectAndSaveDocument();
    if (seleccionado == null) return;

    final documento = DocumentoLocal(
      nombre: seleccionado.name,
      ruta: seleccionado.path,
      bytes: seleccionado.size,
      fecha: DateTime.now(),
    );
    setState(() => _documentos.insert(0, documento));
    await _guardarIndice();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Documento guardado en el celular.')),
      );
    }
  }

  Future<void> _abrirDocumento(DocumentoLocal documento) async {
    final abierto = await openStoredDocument(documento.ruta);
    if (!mounted || abierto) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No se pudo abrir ${documento.nombre}.')),
    );
  }

  Future<void> _eliminarDocumento(int indice) async {
    final documento = _documentos[indice];
    await deleteStoredDocument(documento.ruta);
    setState(() => _documentos.removeAt(indice));
    await _guardarIndice();
  }

  String _tamanio(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis documentos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregarDocumento,
        icon: const Icon(Icons.add),
        label: const Text('Guardar documento'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _documentos.isEmpty
              ? _EstadoVacioDocumentos(onAgregar: _agregarDocumento)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: _documentos.length,
                  itemBuilder: (context, index) {
                    final documento = _documentos[index];
                    final esPdf = documento.extension == 'pdf';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        onTap: () => _abrirDocumento(documento),
                        leading: CircleAvatar(
                          backgroundColor: esPdf ? Colors.red.shade50 : Colors.blue.shade50,
                          child: Icon(esPdf ? Icons.picture_as_pdf : Icons.image,
                              color: esPdf ? Colors.red : Colors.blue),
                        ),
                        title: Text(documento.nombre, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${_tamanio(documento.bytes)} · ${documento.fecha.day.toString().padLeft(2, '0')}/${documento.fecha.month.toString().padLeft(2, '0')}/${documento.fecha.year}'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (opcion) {
                            if (opcion == 'abrir') _abrirDocumento(documento);
                            if (opcion == 'eliminar') _eliminarDocumento(index);
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'abrir', child: Text('Abrir')),
                            PopupMenuItem(value: 'eliminar', child: Text('Eliminar')), 
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _EstadoVacioDocumentos extends StatelessWidget {
  final VoidCallback onAgregar;
  const _EstadoVacioDocumentos({required this.onAgregar});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_copy_outlined, size: 76, color: Colors.blue.shade300),
              const SizedBox(height: 16),
              const Text('Todavía no tienes documentos guardados', textAlign: TextAlign.center, style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Organiza constancias, comprobantes y certificados directamente en tu celular.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              ElevatedButton.icon(onPressed: onAgregar, icon: const Icon(Icons.upload_file), label: const Text('Seleccionar foto o PDF')),
            ],
          ),
        ),
      );
}

// ==========================================
// PERFIL DEL USUARIO CON SESIÓN INICIADA
// ==========================================
class PerfilUsuarioScreen extends StatelessWidget {
  final String nombreEstudiante;
  final String especialidad;
  final String anio;
  final Uint8List? fotoPerfil;

  const PerfilUsuarioScreen({
    super.key,
    required this.nombreEstudiante,
    required this.especialidad,
    required this.anio,
    this.fotoPerfil,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => _cerrarSesion(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: _FotoCircular(bytes: fotoPerfil, radio: 64),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              nombreEstudiante,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.school, color: Colors.blueAccent),
                  title: const Text('Especialidad'),
                  subtitle: Text(especialidad),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.calendar_today, color: Colors.blueAccent),
                  title: const Text('Año de bachillerato'),
                  subtitle: Text(anio),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 3. MÓDULO DE EVENTOS
// ==========================================
class Evento {
  final String titulo;
  final String descripcion;
  final DateTime fecha;
  final String categoria;
  final String? videoUrl;

  const Evento({
    required this.titulo,
    required this.descripcion,
    required this.fecha,
    required this.categoria,
    this.videoUrl,
  });
}

// Datos locales simulando registros leídos desde una base de datos.
final List<Evento> eventosRegistrados = [
  Evento(
    titulo: 'Entrega de notas del segundo periodo',
    descripcion: 'Consulta y entrega de reportes académicos a las familias.',
    fecha: DateTime(2026, 10, 9),
    categoria: 'Académico',
  ),
  Evento(
    titulo: 'Festival cultural del complejo',
    descripcion: 'Presentaciones artísticas, música y actividades culturales.',
    fecha: DateTime(2026, 10, 17),
    categoria: 'Cultural',
    videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
  ),
  Evento(
    titulo: 'Torneo deportivo estudiantil',
    descripcion: 'Jornada de fútbol, voleibol y atletismo.',
    fecha: DateTime(2026, 10, 24),
    categoria: 'Deportivo',
  ),
];

class EventosScreen extends StatelessWidget {
  const EventosScreen({super.key});

  static const double latitudComplejo = 14.6349;
  static const double longitudComplejo = -90.5069;
  static const String nombreComplejo = 'Complejo Educativo EduNova';

  String _fecha(DateTime fecha) {
    const meses = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    return '${fecha.day} de ${meses[fecha.month - 1]} de ${fecha.year}';
  }

  Future<void> _abrirGoogleMaps(BuildContext context) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitudComplejo,$longitudComplejo',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir Google Maps.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventos = [...eventosRegistrados]
      ..sort((a, b) => a.fecha.compareTo(b.fecha));

    return Scaffold(
      appBar: AppBar(title: const Text('Eventos importantes')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Card(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.red.shade600, size: 30),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Ubicación del complejo',
                          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 125,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: const Icon(Icons.map_outlined, size: 70, color: Colors.blueAccent),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Consulta la ubicación y obtén indicaciones para llegar al complejo educativo.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () => _abrirGoogleMaps(context),
                    icon: const Icon(Icons.map),
                    label: const Text('Abrir en Google Maps'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (eventos.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No hay eventos registrados.')))
          else
            ...eventos.map(
              (evento) => Card(
                margin: const EdgeInsets.only(bottom: 14),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.event, color: Colors.blueAccent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              evento.titulo,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(_fecha(evento.fecha), style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Chip(label: Text(evento.categoria)),
                      Text(evento.descripcion),
                      if (evento.videoUrl != null) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse(evento.videoUrl!);
                            if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir el video.')));
                            }
                          },
                          icon: const Icon(Icons.play_circle_outline),
                          label: const Text('Ver video informativo'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ==========================================
// 4. MÓDULO DE PERMISOS
// ==========================================
class SolicitudPermiso {
  final String motivo;
  final String detalle;
  final DateTime fecha;
  String estado;

  SolicitudPermiso({
    required this.motivo,
    required this.detalle,
    required this.fecha,
    this.estado = 'Pendiente',
  });
}

final List<SolicitudPermiso> solicitudesPermiso = [
  SolicitudPermiso(
    motivo: 'Cita médica',
    detalle: 'Consulta programada en horario de clases.',
    fecha: DateTime(2026, 10, 12),
    estado: 'Aprobado',
  ),
];

class PermisosScreen extends StatefulWidget {
  const PermisosScreen({super.key});

  @override
  State<PermisosScreen> createState() => _PermisosScreenState();
}

class _PermisosScreenState extends State<PermisosScreen> {
  final TextEditingController _motivoController = TextEditingController();
  final TextEditingController _detalleController = TextEditingController();
  DateTime? _fechaSeleccionada;

  @override
  void dispose() {
    _motivoController.dispose();
    _detalleController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (fecha != null) setState(() => _fechaSeleccionada = fecha);
  }

  Future<void> _registrarSolicitud() async {
    if (_motivoController.text.trim().isEmpty ||
        _detalleController.text.trim().isEmpty ||
        _fechaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos del permiso.')),
      );
      return;
    }
    setState(() {
      solicitudesPermiso.add(
        SolicitudPermiso(
          motivo: _motivoController.text.trim(),
          detalle: _detalleController.text.trim(),
          fecha: _fechaSeleccionada!,
        ),
      );
      _motivoController.clear();
      _detalleController.clear();
      _fechaSeleccionada = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Solicitud enviada correctamente.')),
    );
  }

  Color _colorEstado(String estado) {
    if (estado == 'Aprobado') return Colors.green;
    if (estado == 'Rechazado') return Colors.red;
    return Colors.orange;
  }

  String _fecha(DateTime fecha) =>
      '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitudes de permisos')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Solicitar un permiso',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _motivoController,
            decoration: const InputDecoration(
              labelText: 'Motivo del permiso',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _detalleController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Detalles de la solicitud',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _seleccionarFecha,
            icon: const Icon(Icons.calendar_month),
            label: Text(
              _fechaSeleccionada == null
                  ? 'Seleccionar fecha'
                  : 'Fecha: ${_fecha(_fechaSeleccionada!)}',
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _registrarSolicitud,
            icon: const Icon(Icons.send),
            label: const Text('Enviar solicitud'),
          ),
          const SizedBox(height: 28),
          const Text(
            'Estado de mis solicitudes',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (solicitudesPermiso.isEmpty)
            const Text('Todavía no tienes solicitudes registradas.')
          else
            ...solicitudesPermiso.reversed.map(
              (solicitud) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(Icons.assignment),
                  title: Text(solicitud.motivo),
                  subtitle: Text(
                    '${solicitud.detalle}\nFecha: ${_fecha(solicitud.fecha)}',
                  ),
                  isThreeLine: true,
                  trailing: Chip(
                    label: Text(solicitud.estado),
                    backgroundColor: _colorEstado(solicitud.estado).withAlpha(45),
                    labelStyle: TextStyle(
                      color: _colorEstado(solicitud.estado),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ==========================================
// 3. MÓDULO DE CALIFICACIONES EDITABLE
// ==========================================
class CalificacionesScreen extends StatefulWidget {
  const CalificacionesScreen({super.key});

  @override
  State<CalificacionesScreen> createState() => _CalificacionesScreenState();
}

class _CalificacionesScreenState extends State<CalificacionesScreen> {
  static const _materias = ['Matemáticas', 'Lenguaje', 'Ciencias', 'Sociales'];
  static const _periodos = ['P1', 'P2', 'P3', 'P4'];
  static const _valoresIniciales = [
    [8.5, 9.0, 8.0, 9.5],
    [7.5, 8.0, 8.5, 9.0],
    [9.0, 9.5, 9.0, 10.0],
    [8.0, 8.5, 8.0, 8.5],
  ];

  late final List<List<TextEditingController>> _controles;
  bool _cargando = true;
  bool _guardando = false;
  String _claveNotasBase = 'edunova_nota';

  @override
  void initState() {
    super.initState();
    _controles = List.generate(
      _materias.length,
      (materia) => List.generate(
        _periodos.length,
        (periodo) => TextEditingController(
          text: _valoresIniciales[materia][periodo].toString(),
        ),
      ),
    );
    _cargarNotas();
  }

  @override
  void dispose() {
    for (final fila in _controles) {
      for (final control in fila) {
        control.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _cargarNotas() async {
    final preferencias = await SharedPreferences.getInstance();
    final correo = preferencias.getString('edunova_usuario_actual');
    if (correo != null && correo.isNotEmpty) {
      _claveNotasBase = _claveDatosUsuario('edunova_nota', correo);
    }
    for (var materia = 0; materia < _materias.length; materia++) {
      for (var periodo = 0; periodo < _periodos.length; periodo++) {
        final clave = '${_claveNotasBase}_${materia}_$periodo';
        final nota = preferencias.getDouble(clave);
        if (nota != null) _controles[materia][periodo].text = _formatoNota(nota);
      }
    }
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _guardarNotas() async {
    setState(() => _guardando = true);
    final preferencias = await SharedPreferences.getInstance();
    for (var materia = 0; materia < _materias.length; materia++) {
      for (var periodo = 0; periodo < _periodos.length; periodo++) {
        final nota = _nota(materia, periodo);
        final clave = '${_claveNotasBase}_${materia}_$periodo';
        if (nota == null) {
          await preferencias.remove(clave);
        } else {
          await preferencias.setDouble(clave, nota);
        }
      }
    }
    if (mounted) {
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notas guardadas correctamente.')));
    }
  }

  double? _nota(int materia, int periodo) {
    final value = double.tryParse(_controles[materia][periodo].text.replaceAll(',', '.'));
    if (value == null || value < 0 || value > 10) return null;
    return value;
  }

  double? _promedioMateria(int materia) {
    final notas = List.generate(_periodos.length, (periodo) => _nota(materia, periodo)).whereType<double>().toList();
    if (notas.isEmpty) return null;
    return notas.reduce((a, b) => a + b) / notas.length;
  }

  double? get _promedioGeneral {
    final promedios = List.generate(_materias.length, _promedioMateria).whereType<double>().toList();
    if (promedios.isEmpty) return null;
    return promedios.reduce((a, b) => a + b) / promedios.length;
  }

  String _formatoNota(double? nota) => nota == null ? '' : nota.toStringAsFixed(nota % 1 == 0 ? 0 : 2);

  @override
  Widget build(BuildContext context) {
    final promedioGeneral = _promedioGeneral;
    return Scaffold(
      appBar: AppBar(title: const Text('Módulo de Calificaciones')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                const Text('Mis notas por periodo', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Edita tus calificaciones de 0 a 10 y observa cómo cambia cada promedio.', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 18),
                for (var materia = 0; materia < _materias.length; materia++)
                  _tarjetaMateria(materia),
                const SizedBox(height: 10),
                Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        const Icon(Icons.insights, color: Colors.green, size: 32),
                        const SizedBox(width: 12),
                        const Expanded(child: Text('Promedio general', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                        Text(promedioGeneral == null ? '--' : promedioGeneral.toStringAsFixed(2), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _guardando ? null : _guardarNotas,
                  icon: _guardando ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
                  label: Text(_guardando ? 'Guardando...' : 'Guardar mis notas'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
                const SizedBox(height: 8),
                const Text('Las notas se guardan localmente en este dispositivo.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
    );
  }

  Widget _tarjetaMateria(int materia) {
    final promedio = _promedioMateria(materia);
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(_materias[materia], style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.blueAccent))),
                Text('Promedio: ${promedio == null ? '--' : promedio.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (var periodo = 0; periodo < _periodos.length; periodo++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: periodo == _periodos.length - 1 ? 0 : 7),
                      child: TextField(
                        controller: _controles[materia][periodo],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.center,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(labelText: _periodos[periodo], border: const OutlineInputBorder(), isDense: true),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
