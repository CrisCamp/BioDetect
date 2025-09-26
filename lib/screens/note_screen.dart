import 'package:biodetect/views/notes/crear_editar_bitacora_screen.dart';
import 'package:biodetect/views/notes/explorar_bitacoras_publicas_screen.dart';
import 'package:flutter/material.dart';
import 'package:biodetect/themes.dart';

class BinnacleScreen extends StatelessWidget {
  const BinnacleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bitácora',
            style: TextStyle(color: AppColors.textWhite)),
        backgroundColor: AppColors.backgroundNavBarsLigth,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: AppColors.backgroundPrimary,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                _MenuButton(
                  icon: Icons.add_circle_outline,
                  label: 'Crear nueva bitácora',
                  color: AppColors.buttonBlue2,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CrearEditarBitacoraScreen()),
                    );
                  },
                ),
                const SizedBox(height: 18),
                _MenuButton(
                  icon: Icons.public,
                  label: 'Explorar bitácoras públicas',
                  color: AppColors.buttonBrown2,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ExplorarBitacorasPublicasScreen()),
                    );
                  },
                ),
                const Spacer(),
                // Puedes agregar más accesos aquí si lo necesitas
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: Icon(icon, color: AppColors.textWhite, size: 28),
      label: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.textWhite,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 6,
        alignment: Alignment.centerLeft,
      ),
      onPressed: onTap,
    );
  }
}