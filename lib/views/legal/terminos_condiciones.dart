import 'package:flutter/material.dart';
import 'package:biodetect/themes.dart';

class TerminosCondiciones extends StatelessWidget {
  const TerminosCondiciones({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Términos y Condiciones',
          style: TextStyle(color: AppColors.textWhite),
        ),
        backgroundColor: AppColors.slateGreen,
        iconTheme: const IconThemeData(color: AppColors.textWhite),
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: AppColors.backgroundPrimary,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado
              const Text(
                'BIODETECT',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textWhite,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Términos y Condiciones de Uso',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textWhite.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Última actualización: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textWhite.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 24),

              // Contenido de términos
              _buildSection(
                '1. ACEPTACIÓN DE TÉRMINOS',
                'Al registrarte y usar la aplicación BIODETECT, aceptas cumplir con estos términos y condiciones. Si no estás de acuerdo, no uses la aplicación.',
              ),

              _buildSection(
                '2. DESCRIPCIÓN DEL SERVICIO',
                'BIODETECT es una aplicación educativa para la identificación de insectos mediante fotografías e inteligencia artificial. Permite crear bitácoras, participar en foros y acceder a contenido educativo relacionado con entomología.',
              ),

              _buildSection(
                '3. USO RESPONSABLE',
                '''• Proporciona información veraz y precisa
• Respeta a otros usuarios en foros y comunidades
• No subas contenido ofensivo, ilegal o inapropiado
• Usa la app únicamente para fines educativos y científicos
• No intentes dañar o comprometer la seguridad de la aplicación''',
              ),

              _buildSection(
                '4. PRIVACIDAD Y DATOS',
                '''• Recopilamos solo los datos necesarios para el funcionamiento de la app
• Tus fotografías e identificaciones se almacenan de forma segura
• No compartimos información personal con terceros sin tu consentimiento
• Puedes solicitar la eliminación de tu cuenta y datos en cualquier momento''',
              ),

              _buildSection(
                '5. CONTENIDO DE USUARIO',
                '''• Mantienes los derechos sobre las fotografías que subas
• Al publicar contenido, nos otorgas licencia para mostrarlo en la app
• Somos responsables de moderar contenido inapropiado
• Las identificaciones de IA son sugerencias educativas, no diagnósticos científicos definitivos''',
              ),

              _buildSection(
                '6. DISPONIBILIDAD DEL SERVICIO',
                'La aplicación se proporciona "tal como está". Podemos realizar mantenimientos, actualizaciones o interrupciones temporales del servicio.',
              ),

              _buildSection(
                '7. LIMITACIÓN DE RESPONSABILIDAD',
                'BIODETECT es una herramienta educativa. No nos hacemos responsables por decisiones tomadas basándose únicamente en las identificaciones automáticas de la aplicación.',
              ),

              _buildSection(
                '8. MODIFICACIONES',
                'Podemos actualizar estos términos ocasionalmente. Te notificaremos sobre cambios importantes a través de la aplicación.',
              ),

              _buildSection(
                '9. CONTACTO',
                '''Si tienes preguntas sobre estos términos, contáctanos:
• Email: biodetect@cucba.udg.mx
• Centro Universitario de Ciencias Biológicas y Agropecuarias
• Universidad de Guadalajara''',
              ),

              const SizedBox(height: 32),

              // Botón de aceptar
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
                  onPressed: () {
                    Navigator.pop(context, true); // Retorna true indicando aceptación
                  },
                  child: const Text('Acepto los Términos y Condiciones'),
                ),
              ),

              const SizedBox(height: 16),

              // Botón de rechazar
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textWhite,
                    side: const BorderSide(color: AppColors.textWhite),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context, false); // Retorna false indicando rechazo
                  },
                  child: const Text('Cancelar'),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.buttonGreen2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textWhite,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}