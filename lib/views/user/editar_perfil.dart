import 'dart:io';
import 'package:biodetect/themes.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:biodetect/views/user/cambiar_contrasena.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
      final result = await InternetAddress.lookup('example.com');
      final hasInternet = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      if (mounted) {
        setState(() {
          _hasInternet = hasInternet;
        });
        if (!hasInternet) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Se requiere conexión a internet para editar el perfil')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasInternet = false;
        });
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Se requiere conexión a internet para editar el perfil')),
        );
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
                      const SizedBox(width: 44),
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