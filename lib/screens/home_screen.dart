import 'package:biodetect/views/map/mapa.dart';
import 'package:biodetect/views/registers/album_fotos.dart';
import 'package:biodetect/views/registers/captura_foto.dart';
import 'package:biodetect/views/registers/fotos_pendientes.dart';
import 'package:biodetect/services/pending_photos_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:biodetect/themes.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPendingCount();
  }

  Future<void> _loadPendingCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final count = await PendingPhotosService.getPendingCount(user.uid);
      setState(() {
        _pendingCount = count;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio', style: TextStyle(color: AppColors.textWhite)),
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
                  icon: Icons.photo_library_outlined,
                  label: 'Álbum de Fotos',
                  color: AppColors.buttonBlue2,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AlbumFotos()),
                  ).then((_) => _loadPendingCount()),
                ),
                const SizedBox(height: 18),
                _MenuButton(
                  icon: Icons.camera_alt_outlined,
                  label: 'Capturar Foto',
                  color: AppColors.buttonGreen2,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CapturaFoto()),
                  ).then((_) => _loadPendingCount()),
                ),
                const SizedBox(height: 18),
                _MenuButtonWithBadge(
                  icon: Icons.schedule_outlined,
                  label: 'Fotos Pendientes',
                  color: AppColors.buttonBrown3,
                  badgeCount: _pendingCount,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const FotosPendientes()),
                  ).then((_) => _loadPendingCount()),
                ),
                const SizedBox(height: 18),
                _MenuButton(
                  icon: Icons.map_outlined,
                  label: 'Mapa Interactivo',
                  color: AppColors.buttonBlue1,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MapaIterativoScreen()),
                  ),
                ),
                const Spacer(),
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

class _MenuButtonWithBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final int badgeCount;
  final VoidCallback onTap;

  const _MenuButtonWithBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
              border: badgeCount > 0 
                  ? Border.all(color: AppColors.warning.withValues(alpha: 0.3), width: 2)
                  : null,
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(icon, color: AppColors.textWhite, size: 28),
                    if (badgeCount > 0)
                      Positioned(
                        right: -8,
                        top: -8,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFF6B6B),
                                Color(0xFFEE5A24),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF6B6B).withValues(alpha: 0.4),
                                spreadRadius: 1,
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            border: Border.all(
                              color: AppColors.textWhite,
                              width: 2,
                            ),
                          ),
                          child: Text(
                            badgeCount > 99 ? '99+' : badgeCount.toString(),
                            style: const TextStyle(
                              color: AppColors.textWhite,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              height: 1,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
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