import 'dart:io';
import 'package:biodetect/themes.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:biodetect/views/user/cambiar_contrasena.dart';
import 'package:biodetect/views/session/inicio_sesion.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:async';

class EditarPerfil extends StatefulWidget {
  const EditarPerfil({super.key});

  @override
  State<EditarPerfil> createState() => _EditarPerfilState();
}

class _EditarPerfilState extends State<EditarPerfil> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  bool _loading = false;
  String? _profileUrl;
  bool _hasInternet = true;
  Timer? _internetTimer;

  @override
  void initState() {
    super.initState();
    _cargarDatosUsuario();
    _checkInternet();
    _internetTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _checkInternet();
    });
  }

  @override
  void dispose() {
    _internetTimer?.cancel();
    _nombreController.dispose();
    super.dispose();
  }

  Future<void> _checkInternet() async {
    try {
      final result = await InternetAddress.lookup('biodetect.com');
      final hasInternet = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      if (mounted) {
        setState(() {
          _hasInternet = hasInternet;
        });
        if (!hasInternet) {
          // Diferir la navegación hasta después del frame actual
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Se requiere conexión a internet para editar el perfil')),
              );
            }
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasInternet = false;
        });
        // Diferir la navegación hasta después del frame actual
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Se requiere conexión a internet para editar el perfil')),
            );
          }
        });
      }
    }
  }

  Future<void> _cargarDatosUsuario() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data();
    if (data != null) {
      _nombreController.text = data['fullname'] ?? '';
      _profileUrl = data['profilePicture'];
    } else {
      _nombreController.text = user.displayName ?? '';
      _profileUrl = user.photoURL;
    }
    setState(() {});
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      await _uploadProfileImage(picked);
    }
  }

  Future<void> _uploadProfileImage(XFile image) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _loading = true);
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_pictures/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putData(await image.readAsBytes());
      final url = await ref.getDownloadURL();
      
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'profilePicture': url,
      });
      
      setState(() {
        _profileUrl = url;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de perfil actualizada')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir imagen: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final nuevoNombre = _nombreController.text.trim();

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'fullname': nuevoNombre,
      });
      
      await user.updateDisplayName(nuevoNombre);
      await user.reload();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado correctamente')),
        );
        Navigator.pop(context, true);
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Error al actualizar: ${e.message}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error inesperado: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _mostrarDialogoEliminarCuenta() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirmationController = TextEditingController();
    bool isDeleting = false;
    String? errorMessage;
    bool _disposed = false; // Flag para controlar el dispose

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return WillPopScope(
          onWillPop: () async => !isDeleting,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: AppColors.backgroundCard,
                title: const Text(
                  '⚠️ Eliminar cuenta',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Esta acción eliminará permanentemente:\n\n'
                          '• Tu perfil y datos personales\n'
                          '• Todas tus fotos de artrópodos\n'
                          '• Tus bitácoras de campo\n'
                          '• Mensajes del foro\n'
                          '• Estadísticas de actividad\n'
                          '• Archivos en la nube\n\n'
                          'Esta acción NO se puede deshacer.',
                          style: TextStyle(color: AppColors.textWhite, fontSize: 14),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Para confirmar, escribe tu dirección de email actual:',
                          style: TextStyle(
                            color: AppColors.textWhite,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (!_disposed) // Solo mostrar si no está disposed
                          TextFormField(
                            controller: confirmationController,
                            enabled: !isDeleting,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Escribe tu email exacto',
                              labelStyle: const TextStyle(color: AppColors.textWhite),
                              filled: true,
                              fillColor: AppColors.slateGreen,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: errorMessage != null 
                                  ? const BorderSide(color: AppColors.warning, width: 2)
                                  : BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: errorMessage != null 
                                  ? const BorderSide(color: AppColors.warning, width: 2)
                                  : BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: errorMessage != null 
                                  ? const BorderSide(color: AppColors.warning, width: 2)
                                  : const BorderSide(color: AppColors.aquaBlue, width: 2),
                              ),
                              prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textWhite),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            style: const TextStyle(color: AppColors.textWhite),
                            onChanged: (value) {
                              if (errorMessage != null && !_disposed) {
                                setDialogState(() {
                                  errorMessage = null;
                                });
                              }
                            },
                          ),
                        if (errorMessage != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.warning, width: 1),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: AppColors.warning, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    errorMessage!,
                                    style: const TextStyle(
                                      color: AppColors.warning,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: isDeleting ? null : () {
                              if (!_disposed) {
                                _disposed = true;
                                confirmationController.dispose();
                              }
                              Navigator.of(dialogContext).pop();
                            },
                            child: const Text(
                              'Volver',
                              style: TextStyle(color: AppColors.textWhite),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.warning,
                              foregroundColor: AppColors.textWhite,
                              minimumSize: const Size(0, 40),
                            ),
                            onPressed: isDeleting || _disposed ? null : () async {
                              final inputText = confirmationController.text.trim();
                              
                              if (inputText.isEmpty) {
                                setDialogState(() {
                                  errorMessage = 'Por favor introduce tu email';
                                });
                                return;
                              }
                              
                              if (inputText.toLowerCase() != user.email?.toLowerCase()) {
                                setDialogState(() {
                                  errorMessage = 'El email no coincide con tu cuenta actual';
                                });
                                return;
                              }

                              // Marcar como eliminando
                              setDialogState(() {
                                isDeleting = true;
                                errorMessage = null;
                              });

                              try {
                                // Eliminar cuenta
                                await _eliminarCuentaCompleta();
                                
                                // Marcar como disposed y limpiar
                                _disposed = true;
                                confirmationController.dispose();
                                
                                // Cerrar diálogo usando el contexto correcto
                                if (Navigator.of(dialogContext).canPop()) {
                                  Navigator.of(dialogContext).pop();
                                }
                                
                                // Navegar a login
                                if (mounted) {
                                  // Usar pushAndRemoveUntil en lugar de pushNamedAndRemoveUntil
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(builder: (_) => const InicioSesion()),
                                    (route) => false,
                                  );
                                }
                              } catch (e) {
                                print('Error al eliminar cuenta: $e');
                                
                                // Si hubo error, intentar navegar al login de todas formas
                                if (!_disposed) {
                                  _disposed = true;
                                  confirmationController.dispose();
                                }
                                
                                if (Navigator.of(dialogContext).canPop()) {
                                  Navigator.of(dialogContext).pop();
                                }
                                
                                if (mounted) {
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(builder: (_) => const InicioSesion()),
                                    (route) => false,
                                  );
                                }
                              }
                            },
                            child: isDeleting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.textWhite,
                                    ),
                                  )
                                : const Text(
                                    'ELIMINAR',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    
    // Limpiar si aún no se ha hecho
    if (!_disposed && confirmationController.hasListeners) {
      confirmationController.dispose();
    }
  }

  Future<void> _eliminarCuentaCompleta() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('No hay usuario autenticado');

    try {
      print('Iniciando eliminación completa de cuenta...');

      // 1. PRIMERO: Eliminar archivos de Storage (antes de Firestore)
      print('Paso 1: Eliminando archivos de Storage...');
      
      // Eliminar fotos de perfil
      try {
        final profilePicturesRef = FirebaseStorage.instance
            .ref()
            .child('profile_pictures/${user.uid}');
        final profileItems = await profilePicturesRef.listAll();
        for (final item in profileItems.items) {
          await item.delete();
          print('Foto de perfil eliminada: ${item.name}');
        }
      } catch (e) {
        print('Error al eliminar fotos de perfil: $e');
      }

      // Eliminar toda la carpeta del usuario en insect_photos
      try {
        final userInsectRef = FirebaseStorage.instance
            .ref()
            .child('insect_photos/${user.uid}');
        final userInsectItems = await userInsectRef.listAll();
        
        // Eliminar archivos en subcarpetas
        for (final prefix in userInsectItems.prefixes) {
          final items = await prefix.listAll();
          for (final item in items.items) {
            await item.delete();
            print('Archivo eliminado: ${item.fullPath}');
          }
        }
        
        // Eliminar archivos directos
        for (final item in userInsectItems.items) {
          await item.delete();
          print('Archivo directo eliminado: ${item.fullPath}');
        }
      } catch (e) {
        print('Error al eliminar carpeta de insectos: $e');
      }

      // Eliminar archivos de bitácoras si existen
      try {
        final fieldNotesRef = FirebaseStorage.instance
            .ref()
            .child('field_notes/${user.uid}');
        final fieldNotesItems = await fieldNotesRef.listAll();
        for (final item in fieldNotesItems.items) {
          await item.delete();
          print('Archivo de bitácora eliminado: ${item.name}');
        }
      } catch (e) {
        print('Error al eliminar archivos de bitácoras: $e');
      }

      // Eliminar archivos del chat grupal si existen
      try {
        final chatRef = FirebaseStorage.instance
            .ref()
            .child('group_chat/${user.uid}');
        final chatItems = await chatRef.listAll();
        for (final item in chatItems.items) {
          await item.delete();
          print('Archivo de chat eliminado: ${item.name}');
        }
      } catch (e) {
        print('Error al eliminar archivos de chat: $e');
      }

      print('Paso 1 completado: Archivos de Storage eliminados');

      // 2. SEGUNDO: Eliminar documentos de Firestore usando batch
      print('Paso 2: Eliminando documentos de Firestore...');
      final batch = FirebaseFirestore.instance.batch();
      
      // Eliminar fotos de artrópodos identificados
      final insectPhotosQuery = await FirebaseFirestore.instance
          .collection('insect_photos')
          .where('userId', isEqualTo: user.uid)
          .get();
      
      for (final doc in insectPhotosQuery.docs) {
        batch.delete(doc.reference);
      }
      print('Marcadas ${insectPhotosQuery.docs.length} fotos identificadas para eliminar');

      // Eliminar fotos no identificadas
      final unidentifiedQuery = await FirebaseFirestore.instance
          .collection('unidentified')
          .where('userId', isEqualTo: user.uid)
          .get();
      
      for (final doc in unidentifiedQuery.docs) {
        batch.delete(doc.reference);
      }
      print('Marcadas ${unidentifiedQuery.docs.length} fotos no identificadas para eliminar');

      // Eliminar bitácoras
      final fieldNotesQuery = await FirebaseFirestore.instance
          .collection('field_notes')
          .where('userId', isEqualTo: user.uid)
          .get();
      
      for (final doc in fieldNotesQuery.docs) {
        batch.delete(doc.reference);
      }
      print('Marcadas ${fieldNotesQuery.docs.length} bitácoras para eliminar');

      // Eliminar mensajes del foro
      final chatQuery = await FirebaseFirestore.instance
          .collection('group_chat')
          .where('userId', isEqualTo: user.uid)
          .get();
      
      for (final doc in chatQuery.docs) {
        batch.delete(doc.reference);
      }
      print('Marcados ${chatQuery.docs.length} mensajes de chat para eliminar');

      // Eliminar actividad del usuario
      batch.delete(FirebaseFirestore.instance.collection('user_activity').doc(user.uid));

      // Eliminar perfil del usuario
      batch.delete(FirebaseFirestore.instance.collection('users').doc(user.uid));

      // Ejecutar batch
      await batch.commit();
      print('Paso 2 completado: Documentos de Firestore eliminados');

      // 3. TERCERO: Limpiar datos locales
      print('Paso 3: Limpiando datos locales...');
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        print('Preferencias locales limpiadas');
      } catch (e) {
        print('Error al limpiar preferencias: $e');
      }

      // 4. CUARTO: Cerrar sesión de Google si aplica
      print('Paso 4: Cerrando sesión de Google...');
      try {
        await GoogleSignIn().signOut();
        print('Sesión de Google cerrada');
      } catch (e) {
        print('Error al cerrar sesión de Google (puede ser normal si no usó Google): $e');
      }

      // 5. QUINTO: Eliminar cuenta de Firebase Auth (SIEMPRE AL FINAL)
      print('Paso 5: Eliminando cuenta de Firebase Auth...');
      await user.delete();
      print('Cuenta de Firebase Auth eliminada');

      print('Eliminación completa de cuenta exitosa');

    } catch (e) {
      print('Error al eliminar cuenta: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AbsorbPointer(
        absorbing: !_hasInternet,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: AppColors.backgroundPrimary,
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(0),
              children: [
                Container(
                  color: AppColors.slateGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new),
                        color: AppColors.white,
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          'Editar Perfil',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          _mostrarDialogoEliminarCuenta();
                        },
                        child: const Text(
                          'Eliminar cuenta',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_hasInternet)
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: AppColors.warning,
                    child: const Text(
                      'No tienes conexión a internet. No puedes editar tu perfil.',
                      style: TextStyle(color: AppColors.textWhite),
                      textAlign: TextAlign.center,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Center(
                          child: Stack(
                            children: [
                              Card(
                                shape: const CircleBorder(),
                                color: Colors.transparent,
                                elevation: 4,
                                child: CircleAvatar(
                                  radius: 60,
                                  backgroundColor: AppColors.forestGreen,
                                  backgroundImage: (_profileUrl != null && _profileUrl!.isNotEmpty)
                                      ? NetworkImage(_profileUrl!)
                                      : null,
                                  child: (_profileUrl == null || _profileUrl!.isEmpty)
                                      ? const Icon(Icons.person, size: 60, color: AppColors.slateGrey)
                                      : null,
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: FloatingActionButton(
                                  mini: true,
                                  backgroundColor: AppColors.buttonGreen3,
                                  onPressed: _loading ? null : _pickImage,
                                  child: const Icon(Icons.edit, color: AppColors.textWhite),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        TextFormField(
                          controller: _nombreController,
                          decoration: InputDecoration(
                            labelText: 'Nombre completo',
                            labelStyle: const TextStyle(color: AppColors.textWhite),
                            filled: true,
                            fillColor: AppColors.slateGreen,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefixIcon: const Icon(Icons.person_outline, color: AppColors.textWhite),
                          ),
                          style: const TextStyle(color: AppColors.textWhite),
                          validator: (value) =>
                              value == null || value.trim().isEmpty ? 'Ingresa tu nombre' : null,
                        ),
                        const SizedBox(height: 32),
                        
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.buttonBrown2,
                                  foregroundColor: AppColors.textBlack,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  minimumSize: const Size(0, 48),
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.buttonGreen2,
                                  foregroundColor: AppColors.textBlack,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  minimumSize: const Size(0, 48),
                                ),
                                onPressed: _loading ? null : _guardarCambios,
                                child: _loading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Text('Guardar cambios', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 36),
                        
                        Center(
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CambiarContrasenaScreen()),
                              );
                            },
                            child: const Text(
                              'Cambiar contraseña',
                              style: TextStyle(
                                color: AppColors.textWhite,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}