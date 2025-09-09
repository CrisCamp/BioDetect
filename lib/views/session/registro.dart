import 'package:biodetect/themes.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:biodetect/views/legal/terminos_condiciones.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Registro extends StatefulWidget {
  const Registro({super.key});

  @override
  State<Registro> createState() => _RegistroState();
}

class _RegistroState extends State<Registro> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = false;
  bool _aceptaTerminos = false;
  String? _error;
  int _passwordStrength = 0;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  void _checkPasswordStrength(String value) {
    int strength = 0;
    if (value.length >= 8) strength++;
    if (RegExp(r'[A-Z]').hasMatch(value)) strength++;
    if (RegExp(r'[a-z]').hasMatch(value)) strength++;
    if (RegExp(r'[0-9]').hasMatch(value)) strength++;
    if (RegExp(r'[!@#\$&*~]').hasMatch(value)) strength++;
    setState(() {
      _passwordStrength = strength;
    });
  }

  Future<void> _onRegistrar() async {
    if (!_aceptaTerminos) {
      setState(() {
        _error = 'Debes aceptar los términos y condiciones.';
      });
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      setState(() {
        _error = 'Las contraseñas no coinciden.';
      });
      return;
    }
    if (_passwordStrength < 3) {
      setState(() {
        _error = 'La contraseña es demasiado débil.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Crear cuenta
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      
      final user = credential.user;
      if (user != null) {
        // Actualizar displayName
        await user.updateDisplayName(_nombreController.text.trim());
        
        await user.sendEmailVerification();
        
        // Crear documento del usuario en Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email,
          'fullname': _nombreController.text.trim(),
          'profilePicture': '',
          'createdAt': FieldValue.serverTimestamp(),
          'loginAt': FieldValue.serverTimestamp(),
          'badges': [],
        });

        // Crear documento user_activity con estructura completa
        await _createUserActivityDocument(user.uid);

        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        
        await FirebaseAuth.instance.signOut();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Cuenta creada! Verifica tu correo antes de iniciar sesión.'),
              backgroundColor: AppColors.buttonGreen2,
              duration: Duration(seconds: 3),
            ),
          );
          
          Navigator.pop(context);
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'email-already-in-use':
            _error = 'Ya existe una cuenta con este correo.';
            break;
          case 'invalid-email':
            _error = 'El correo no es válido.';
            break;
          case 'weak-password':
            _error = 'La contraseña es demasiado débil.';
            break;
          default:
            _error = 'No se pudo crear la cuenta. Verifica tus datos e inténtalo de nuevo.';
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Error inesperado: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  // Crear documento user_activity con estructura completa según especificaciones
  Future<void> _createUserActivityDocument(String userId) async {
    final activityDoc = FirebaseFirestore.instance.collection('user_activity').doc(userId);
    
    await activityDoc.set({
      'userId': userId,
      'fieldNotesCreated': 0,
      'photosUploaded': 0,
      'lastActivity': FieldValue.serverTimestamp(),
      'speciesIdentified': {
        'byClass': {
          'Arachnida': 0,
          'Insecta': 0,
        },
        'byClassTaxonomy': {
          'Arachnida': 0,
          'Insecta': 0,
        },
        'byTaxon': {
          // Arachnida (5 órdenes)
          'Acari': 0,
          'Amblypygi': 0,
          'Araneae': 0,
          'Scorpiones': 0,
          'Solifugae': 0,
          // Insecta (5 órdenes)
          'Dermaptera': 0,
          'Lepidoptera': 0,
          'Mantodea': 0,
          'Orthoptera': 0,
          'Thysanoptera': 0,
        },
        'totalByClass': 0,
        'totalByTaxon': 0,
      },
    });
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundLightGradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo
                      Image.asset(
                        'assets/ic_logo_biodetect.png',
                        width: 120,
                        height: 120,
                      ),
                      const SizedBox(height: 24),
                      // Campo: Nombre completo
                      TextFormField(
                        controller: _nombreController,
                        decoration: InputDecoration(
                          hintText: 'Nombre completo',
                          filled: true,
                          fillColor: AppColors.slateGreen,
                          hintStyle: const TextStyle(color: AppColors.textWhite),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        style: const TextStyle(color: AppColors.textWhite),
                      ),
                      const SizedBox(height: 16),
                      // Campo: Correo
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'Correo',
                          filled: true,
                          fillColor: AppColors.slateGreen,
                          hintStyle: const TextStyle(color: AppColors.textWhite),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        style: const TextStyle(color: AppColors.textWhite),
                      ),
                      const SizedBox(height: 16),
                      // Campo: Contraseña con ojo dinámico
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        onChanged: _checkPasswordStrength,
                        decoration: InputDecoration(
                          hintText: 'Contraseña',
                          filled: true,
                          fillColor: AppColors.slateGreen,
                          hintStyle: const TextStyle(color: AppColors.textWhite),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: AppColors.textWhite.withValues(alpha: 0.7),
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        style: const TextStyle(color: AppColors.textWhite),
                      ),
                      // Barra de fortaleza de contraseña
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: List.generate(5, (i) {
                            return Expanded(
                              child: Container(
                                height: 4,
                                margin: EdgeInsets.symmetric(horizontal: i == 1 || i == 3 ? 2 : 0),
                                decoration: BoxDecoration(
                                  color: i < _passwordStrength
                                      ? AppColors.mintGreen
                                      : AppColors.slateGrey,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      // Campo: Confirmar contraseña con ojo dinámico
                      TextFormField(
                        controller: _confirmController,
                        obscureText: _obscureConfirm,
                        decoration: InputDecoration(
                          hintText: 'Confirmar contraseña',
                          filled: true,
                          fillColor: AppColors.slateGreen,
                          hintStyle: const TextStyle(color: AppColors.textWhite),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                              color: AppColors.textWhite.withValues(alpha: 0.7),
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirm = !_obscureConfirm;
                              });
                            },
                          ),
                        ),
                        style: const TextStyle(color: AppColors.textWhite),
                      ),
                      const SizedBox(height: 16),
                      // Checkbox Términos y condiciones
                      Row(
                        children: [
                          Checkbox(
                            value: _aceptaTerminos,
                            onChanged: (value) {
                              setState(() {
                                _aceptaTerminos = value ?? false;
                              });
                            },
                            activeColor: AppColors.buttonGreen2,
                          ),
                          const Text(
                            'Acepto los ',
                            style: TextStyle(color: AppColors.textBlack),
                          ),
                          GestureDetector(
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const TerminosCondiciones(),
                                ),
                              );
                              if (result == true) {
                                setState(() {
                                  _aceptaTerminos = true;
                                });
                              }
                            },
                            child: const Text(
                              'términos y condiciones',
                              style: TextStyle(
                                color: AppColors.textBlueNormal,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Mensaje de error
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: AppColors.warning,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      // Botón: Crear cuenta
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.buttonGreen2,
                            foregroundColor: AppColors.textBlack,
                            textStyle: const TextStyle(fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _loading ? null : _onRegistrar,
                          child: _loading
                              ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: AppColors.textBlack,
                              strokeWidth: 2,
                            ),
                          )
                              : const Text('Crear cuenta'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Enlace a Login
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: const Text(
                          '¿Ya tienes cuenta? Inicia sesión',
                          style: TextStyle(
                            color: AppColors.textWhite,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}