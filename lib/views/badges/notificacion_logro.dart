import 'package:biodetect/themes.dart';
import 'package:flutter/material.dart';

class NotificacionLogroScreen extends StatelessWidget {
  final String titulo;
  final String nombreInsignia;
  final String descripcion;
  final String? lottieAsset; // Ejemplo: 'assets/badge_unlocked_anim.json'
  final String? imagenInsignia; // Ejemplo: 'assets/ic_badge_expert.png'
  final VoidCallback? onOk;
  final bool showContinueButton; // Para mostrar "Continuar" en lugar de "OK" cuando hay más insignias

  const NotificacionLogroScreen({
    super.key,
    this.titulo = '¡Insignia Desbloqueada!',
    this.nombreInsignia = 'Identificador Experto',
    this.descripcion = '¡Has identificado 50 especies y alcanzado el nivel Experto!',
    this.lottieAsset,
    this.imagenInsignia,
    this.onOk,
    this.showContinueButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animación Lottie (opcional)
              // Si tienes el paquete lottie y el asset, descomenta lo siguiente:
              // if (lottieAsset != null)
              //   Lottie.asset(
              //     lottieAsset!,
              //     width: 200,
              //     height: 200,
              //     repeat: false,
              //   ),
              const SizedBox(height: 16),
              // Card de notificación
              Card(
                color: AppColors.backgroundCard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 8,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(
                          color: AppColors.aquaBlue,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      // Imagen de la insignia
                      Container(
                        width: 100,
                        height: 100,
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          // ignore: deprecated_member_use
                          color: AppColors.slateGreen.withOpacity(0.3),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: imagenInsignia != null
                              ? Image.asset(
                                  imagenInsignia!,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.emoji_events,
                                      color: AppColors.textWhite,
                                      size: 50,
                                    );
                                  },
                                )
                              : const Icon(
                                  Icons.emoji_events,
                                  color: AppColors.textWhite,
                                  size: 50,
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        nombreInsignia,
                        style: const TextStyle(
                          color: AppColors.textWhite,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        descripcion,
                        style: const TextStyle(
                          color: AppColors.textSand,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.buttonBlue1,
                          foregroundColor: AppColors.textWhite,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        onPressed: onOk ?? () => Navigator.pop(context),
                        child: Text(showContinueButton ? 'Continuar' : 'OK'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}