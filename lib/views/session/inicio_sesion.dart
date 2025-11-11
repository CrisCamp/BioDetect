import 'package:biodetect/themes.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:biodetect/views/user/recuperar_contrasena.dart';
import 'package:biodetect/views/session/registro.dart';
import 'package:biodetect/menu.dart';

class InicioSesion extends StatefulWidget {
  const InicioSesion({super.key});

  @override
  State<InicioSesion> createState() => _InicioSesionState();
}

class _InicioSesionState extends State<InicioSesion> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _remember = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadRememberPreference();
    _checkAutoLogin();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadRememberPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email') ?? '';
    final rememberMe = prefs.getBool('remember_me') ?? false;

    setState(() {
      _remember = rememberMe;
      if (rememberMe && savedEmail.isNotEmpty) {
        _emailController.text = savedEmail;
      }
    });
  }

  Future<void> _checkAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final autoLogin = prefs.getBool('auto_login') ?? false;
    final user = FirebaseAuth.instance.currentUser;

    if (user != null && autoLogin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainMenu()),
          );
        }
      });
    }
  }

  Future<void> _saveRememberPreference(String email, bool remember) async {
    final prefs = await SharedPreferences.getInstance();

    if (remember) {
      await prefs.setString('saved_email', email);
      await prefs.setBool('remember_me', true);
      await prefs.setBool('auto_login', true);
    } else {
      await prefs.remove('saved_email');
      await prefs.setBool('remember_me', false);
      await prefs.setBool('auto_login', false);
    }
  }

  Future<void> _onLogin() async {
    if (!mounted) return;

    setState(() {
      _error = null;
    });

    
    if (_emailController.text.trim().isEmpty) {
      setState(() {
        _error = 'Por favor ingresa tu correo electrónico.';
      });
      return;
    }

    if (_passwordController.text.isEmpty) {
      setState(() {
        _error = 'Por favor ingresa tu contraseña.';
      });
      return;
    }

    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(_emailController.text.trim())) {
      setState(() {
        _error = 'Por favor ingresa un correo electrónico válido.';
      });
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = credential.user;
      if (user != null) {
        if (!user.emailVerified) {
          await user.sendEmailVerification();

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('auto_login', false);

          setState(() {
            _error = 'Debes verificar tu correo antes de continuar. Te hemos reenviado el enlace de verificación.';
          });

          await FirebaseAuth.instance.signOut();
          return;
        }

        final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
        final docSnapshot = await userDoc.get();

        if (docSnapshot.exists) {
          final data = docSnapshot.data();
          if (data != null && data['email'] != user.email) {
            await userDoc.update({'email': user.email});
          }
          await userDoc.update({
            'loginAt': FieldValue.serverTimestamp(),
          });
        } else {
          await userDoc.set({
            'uid': user.uid,
            'email': user.email,
            'fullname': user.displayName ?? '',
            'profilePicture': user.photoURL ?? '',
            'createdAt': FieldValue.serverTimestamp(),
            'loginAt': FieldValue.serverTimestamp(),
            'badges': [],
          });
          await _createUserActivityDocument(user.uid);
        }
        await _saveRememberPreference(_emailController.text.trim(), _remember);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainMenu()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_login', false);

      setState(() {
        switch (e.code) {
          case 'user-not-found':
            _error = 'No existe una cuenta registrada con este correo electrónico.';
            break;
          case 'wrong-password':
            _error = 'La contraseña es incorrecta. Verifica e intenta de nuevo.';
            break;
          case 'invalid-email':
            _error = 'El formato del correo electrónico no es válido.';
            break;
          case 'invalid-credential':
            _error = 'Correo o contraseña incorrectos. Verifica tus datos.';
            break;
          case 'too-many-requests':
            _error = 'Demasiados intentos fallidos. Espera unos minutos antes de intentar de nuevo.';
            break;
          case 'network-request-failed':
            _error = 'Error de conexión. Verifica tu internet e intenta de nuevo.';
            break;
          case 'user-disabled':
            _error = 'Esta cuenta ha sido deshabilitada. Contacta al soporte.';
            break;
          default:
            _error = 'No se pudo iniciar sesión. Verifica tus datos e inténtalo de nuevo.';
        }
      });
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_login', false);

      setState(() {
        _error = 'Error inesperado. Por favor intenta de nuevo más tarde.';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _onGoogleSignIn() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await GoogleSignIn().signOut();

      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        if (mounted) {
          setState(() {
            _loading = false;
          });
        }
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
        final docSnapshot = await userDoc.get();

        if (!docSnapshot.exists) {
          await userDoc.set({
            'uid': user.uid,
            'email': user.email,
            'fullname': user.displayName ?? '',
            'profilePicture': user.photoURL ?? '',
            'createdAt': FieldValue.serverTimestamp(),
            'loginAt': FieldValue.serverTimestamp(),
            'badges': [],
          });

          await _createUserActivityDocument(user.uid);
        } else {
          await userDoc.update({
            'loginAt': FieldValue.serverTimestamp(),
          });
        }
        await _saveRememberPreference(user.email ?? '', _remember);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainMenu()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_login', false);

      if (mounted) {
        setState(() {
          switch (e.code) {
            case 'account-exists-with-different-credential':
              _error = 'Ya existe una cuenta con este correo usando otro método de inicio de sesión.';
              break;
            case 'invalid-credential':
              _error = 'Error con las credenciales de Google. Intenta de nuevo.';
              break;
            case 'operation-not-allowed':
              _error = 'El inicio de sesión con Google no está disponible en este momento.';
              break;
            case 'network-request-failed':
              _error = 'Para iniciar sesión con Google necesitas conexión a internet. Puedes mantener la sesión activa seleccionando "Recordar sesión".';
              break;
            default:
              _error = 'Error al iniciar sesión con Google.';
          }
        });
      }
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_login', false);

      if (mounted) {
        setState(() {
          String errorMessage = e.toString().toLowerCase();
          
          if (errorMessage.contains('network') || 
              errorMessage.contains('connection') || 
              errorMessage.contains('internet') ||
              errorMessage.contains('apiexception: 7')) {
            _error = 'Para iniciar sesión con Google necesitas una conexión estable a internet. Puedes mantener tu sesión activa seleccionando "Recordar sesión".';
          } else if (errorMessage.contains('cancelled') || errorMessage.contains('user_cancelled')) {
            _error = 'Inicio de sesión cancelado. Intenta de nuevo si lo deseas.';
          } else {
            _error = 'Error al conectar con Google. Verifica tu conexión a internet e intenta de nuevo.';
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
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
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
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
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Checkbox(
                            value: _remember,
                            onChanged: (value) {
                              setState(() {
                                _remember = value ?? false;
                              });
                            },
                            activeColor: AppColors.buttonGreen1,
                            checkColor: AppColors.textWhite,
                            side: BorderSide(color: AppColors.inputBorder),
                          ),
                          const Text(
                            'Recordar sesión',
                            style: TextStyle(color: AppColors.textWhite),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const RecuperarContrasena()),
                              );
                            },
                            child: const Text(
                              '¿Olvidaste tu contraseña?',
                              style: TextStyle(
                                color: AppColors.textBlueNormal,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
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
                      const SizedBox(height: 16),
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
                          onPressed: _loading ? null : _onLogin,
                          child: const Text(
                            'Iniciar Sesión',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 1,
                              color: AppColors.borderColor.withOpacity(0.3),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'O',
                              style: TextStyle(
                                color: AppColors.textPaleGreen,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 1,
                              color: AppColors.borderColor.withOpacity(0.3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.backgroundCardLight,
                            foregroundColor: AppColors.textWhite,
                            textStyle: const TextStyle(fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: AppColors.inputBorder),
                            ),
                            elevation: 2,
                          ),
                          icon: Image.asset(
                            'assets/ic_google.png',
                            height: 24,
                          ),
                          label: const Text(
                            'Continuar con Google',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          onPressed: _loading ? null : _onGoogleSignIn,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const Registro()),
                          );
                        },
                        child: const Text(
                          '¿No tienes cuenta? Regístrate',
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