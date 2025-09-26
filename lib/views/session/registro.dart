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
    setState(() {
      _error = null;
    });

    if (_nombreController.text.trim().isEmpty) {
      setState(() {
        _error = 'Por favor ingresa tu nombre completo.';
      });
      return;
    }
    
    if (_emailController.text.trim().isEmpty) {
      setState(() {
        _error = 'Por favor ingresa tu correo electrónico.';
      });
      return;
    }
    
    if (_passwordController.text.isEmpty) {
      setState(() {
        _error = 'Por favor ingresa una contraseña.';
      });
      return;
    }
    
    if (_confirmController.text.isEmpty) {
      setState(() {
        _error = 'Por favor confirma tu contraseña.';
      });
      return;
    }

    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(_emailController.text.trim())) {
      setState(() {
        _error = 'Por favor ingresa un correo electrónico válido.';
      });
      return;
    }

    if (_passwordStrength < 3) {
      setState(() {
        _error = 'La contraseña debe tener al menos 8 caracteres, incluir mayúsculas, minúsculas y números.';
      });
      return;
    }

    if (_passwordController.text != _confirmController.text) {
      setState(() {
        _error = 'Las contraseñas no coinciden.';
      });
      return;
    }

    if (!_aceptaTerminos) {
      setState(() {
        _error = 'Debes aceptar los términos y condiciones para continuar.';
      });
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      
      final user = credential.user;
      if (user != null) {
        await user.updateDisplayName(_nombreController.text.trim());
        
        await user.sendEmailVerification();
        
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email,
          'fullname': _nombreController.text.trim(),
          'profilePicture': '',
          'createdAt': FieldValue.serverTimestamp(),
          'loginAt': FieldValue.serverTimestamp(),
          'badges': [],
        });

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
            _error = 'Ya existe una cuenta con este correo electrónico.';
            break;
          case 'invalid-email':
            _error = 'El formato del correo electrónico no es válido.';
            break;
          case 'weak-password':
            _error = 'La contraseña es demasiado débil. Debe tener al menos 8 caracteres.';
            break;
          case 'network-request-failed':
            _error = 'Error de conexión. Verifica tu internet e intenta de nuevo.';
            break;
          default:
            _error = 'No se pudo crear la cuenta. Verifica tus datos e inténtalo de nuevo.';
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Error inesperado. Por favor intenta de nuevo más tarde.';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

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
          'Acari': 0,
          'Amblypygi': 0,
          'Araneae': 0,
          'Scorpiones': 0,
          'Solifugae': 0,
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
      backgroundColor: AppColors.backgroundPrimary,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: AppColors.backgroundPrimary,
        padding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/ic_logo_biodetect.png',
                        width: 120,
                        height: 120,
                      ),
                      const SizedBox(height: 24),
                      // Campo Nombre - ACTUALIZADO con nuevos colores
                      TextFormField(
                        controller: _nombreController,
                        decoration: InputDecoration(
                          hintText: 'Nombre completo',
                          filled: true,
                          fillColor: AppColors.inputBackground,
                          hintStyle: const TextStyle(color: AppColors.inputHint),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.inputBorder, width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.inputBorder, width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.inputBorderFocused, width: 2.5),
                          ),
                        ),
                        style: const TextStyle(color: AppColors.textWhite),
                      ),
                      const SizedBox(height: 16),
                      // Campo Email - ACTUALIZADO con nuevos colores
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'Correo',
                          filled: true,
                          fillColor: AppColors.inputBackground,
                          hintStyle: const TextStyle(color: AppColors.inputHint),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.inputBorder, width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.inputBorder, width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.inputBorderFocused, width: 2.5),
                          ),
                        ),
                        style: const TextStyle(color: AppColors.textWhite),
                      ),
                      const SizedBox(height: 16),
                      // Campo Contraseña - ACTUALIZADO con nuevos colores
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        onChanged: _checkPasswordStrength,
                        decoration: InputDecoration(
                          hintText: 'Contraseña',
                          filled: true,
                          fillColor: AppColors.inputBackground,
                          hintStyle: const TextStyle(color: AppColors.inputHint),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.inputBorder, width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.inputBorder, width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.inputBorderFocused, width: 2.5),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: AppColors.inputHint,
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
                      // Indicador de fortaleza de contraseña - COLORES ACTUALIZADOS
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
                                      ? AppColors.inputBorderFocused
                                      : AppColors.slateGrey,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      // Campo Confirmar Contraseña - ACTUALIZADO con nuevos colores
                      TextFormField(
                        controller: _confirmController,
                        obscureText: _obscureConfirm,
                        decoration: InputDecoration(
                          hintText: 'Confirmar contraseña',
                          filled: true,
                          fillColor: AppColors.inputBackground,
                          hintStyle: const TextStyle(color: AppColors.inputHint),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.inputBorder, width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.inputBorder, width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.inputBorderFocused, width: 2.5),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                              color: AppColors.inputHint,
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
                      // Checkbox de términos - COLORES ACTUALIZADOS
                      Row(
                        children: [
                          Checkbox(
                            value: _aceptaTerminos,
                            onChanged: (value) {
                              setState(() {
                                _aceptaTerminos = value ?? false;
                              });
                            },
                            activeColor: AppColors.buttonGreen1,
                            checkColor: AppColors.textWhite,
                            side: BorderSide(color: AppColors.inputBorder),
                          ),
                          const Text(
                            'Acepto los ',
                            style: TextStyle(color: AppColors.textWhite),
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
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Mensaje de error
                      if (_error != null)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.warning, width: 1),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: AppColors.warning, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: AppColors.textWhite,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Botón Crear cuenta - COLORES ACTUALIZADOS
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.buttonGreen1,
                            foregroundColor: AppColors.textWhite,
                            textStyle: const TextStyle(fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 4,
                          ),
                          onPressed: _loading ? null : _onRegistrar,
                          child: _loading
                              ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: AppColors.textWhite,
                              strokeWidth: 2,
                            ),
                          )
                              : const Text(
                                  'Crear cuenta',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Enlace de regreso - COLOR ACTUALIZADO
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: const Text(
                          '¿Ya tienes cuenta? Inicia sesión',
                          style: TextStyle(
                            color: AppColors.textBlueNormal,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Loading overlay
            if (_loading)
              Container(
                color: Colors.black26,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.buttonGreen1,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}