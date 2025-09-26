import 'package:biodetect/themes.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CambiarContrasenaScreen extends StatefulWidget {
  const CambiarContrasenaScreen({super.key});

  @override
  State<CambiarContrasenaScreen> createState() => _CambiarContrasenaScreenState();
}

class _CambiarContrasenaScreenState extends State<CambiarContrasenaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = false;
  String? _error;
  int _passwordStrength = 0;

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

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

  Future<void> _onGuardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final user = FirebaseAuth.instance.currentUser;
    final currentPassword = _currentController.text.trim();
    final newPassword = _newController.text.trim();
    final confirmPassword = _confirmController.text.trim();

    if (newPassword != confirmPassword) {
      setState(() {
        _loading = false;
        _error = 'Las contraseñas nuevas no coinciden.';
      });
      return;
    }

    try {
      final cred = EmailAuthProvider.credential(
        email: user!.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(cred);

      await user.updatePassword(newPassword);

      setState(() {
        _loading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contraseña actualizada correctamente')),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _loading = false;
        if (e.code == 'wrong-password') {
          _error = 'La contraseña actual es incorrecta.';
        } else if (e.code == 'weak-password') {
          _error = 'La nueva contraseña es demasiado débil.';
        } else if (e.code == 'requires-recent-login') {
          _error = 'Por seguridad, vuelve a iniciar sesión e inténtalo de nuevo.';
        } else {
          _error = 'Error: ${e.message}';
        }
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Error inesperado: $e';
      });
    }
  }

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: AppColors.backgroundPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Cambiar Contraseña',
                        style: TextStyle(
                          color: AppColors.textBlack,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _currentController,
                        obscureText: !_showCurrent,
                        decoration: InputDecoration(
                          hintText: 'Contraseña actual',
                          filled: true,
                          fillColor: AppColors.paleGreen,
                          hintStyle: const TextStyle(color: AppColors.textBlack),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showCurrent ? Icons.visibility : Icons.visibility_off,
                              color: AppColors.slateGrey,
                            ),
                            onPressed: () {
                              setState(() {
                                _showCurrent = !_showCurrent;
                              });
                            },
                          ),
                        ),
                        style: const TextStyle(color: AppColors.textBlack),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _newController,
                        obscureText: !_showNew,
                        onChanged: _checkPasswordStrength,
                        decoration: InputDecoration(
                          hintText: 'Nueva contraseña',
                          filled: true,
                          fillColor: AppColors.paleGreen,
                          hintStyle: const TextStyle(color: AppColors.textBlack),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showNew ? Icons.visibility : Icons.visibility_off,
                              color: AppColors.slateGrey,
                            ),
                            onPressed: () {
                              setState(() {
                                _showNew = !_showNew;
                              });
                            },
                          ),
                        ),
                        style: const TextStyle(color: AppColors.textBlack),
                      ),
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
                      TextFormField(
                        controller: _confirmController,
                        obscureText: !_showConfirm,
                        decoration: InputDecoration(
                          hintText: 'Confirmar nueva contraseña',
                          filled: true,
                          fillColor: AppColors.paleGreen,
                          hintStyle: const TextStyle(color: AppColors.textBlack),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showConfirm ? Icons.visibility : Icons.visibility_off,
                              color: AppColors.slateGrey,
                            ),
                            onPressed: () {
                              setState(() {
                                _showConfirm = !_showConfirm;
                              });
                            },
                          ),
                        ),
                        style: const TextStyle(color: AppColors.textBlack),
                      ),
                      const SizedBox(height: 28),
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
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.buttonBrown2,
                                foregroundColor: AppColors.textBlack,
                                minimumSize: const Size(0, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              onPressed: _loading
                                  ? null
                                  : () {
                                Navigator.pop(context);
                              },
                              child: const Text(
                                'Cancelar',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.buttonGreen2,
                                foregroundColor: AppColors.textBlack,
                                minimumSize: const Size(0, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              onPressed: _loading ? null : _onGuardar,
                              child: _loading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text(
                                      'Guardar cambios',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                            ),
                          ),
                        ],
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
                    color: AppColors.mintGreen,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}