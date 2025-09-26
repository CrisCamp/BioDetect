import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:biodetect/themes.dart';
import 'package:biodetect/views/badges/notificacion_logro.dart';

class GaleriaInsigniasScreen extends StatefulWidget {
  const GaleriaInsigniasScreen({super.key});

  @override
  State<GaleriaInsigniasScreen> createState() => _GaleriaInsigniasScreenState();

  // Método estático para navegar desde otros archivos y mostrar notificaciones
  static Future<bool> navigateAndShowBadges(BuildContext context) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const GaleriaInsigniasScreen(),
      ),
    );
    return result ?? false; // Retorna true si hubo cambios en las insignias
  }

  // Método estático para verificar y mostrar notificaciones sin navegar a la galería
  static Future<void> checkAndShowNotifications(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Cargar todas las insignias disponibles
      final badgesSnapshot = await FirebaseFirestore.instance
          .collection('badges')
          .orderBy('order')
          .get();

      // Cargar datos del usuario para ver qué insignias tiene
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      // Cargar actividad del usuario para calcular progreso
      final activityDoc = await FirebaseFirestore.instance
          .collection('user_activity')
          .doc(user.uid)
          .get();

      final userData = userDoc.data() as Map<String, dynamic>? ?? {};
      final activityData = activityDoc.data() as Map<String, dynamic>? ?? {};
      final userBadges = List<String>.from(userData['badges'] ?? []);

      // Verificar nuevas insignias
      final newBadgeDetails = await _staticCheckAndUpdateCompletedBadges(
        badgesSnapshot.docs, 
        userBadges, 
        activityData, 
        user.uid
      );

      // Mostrar notificaciones si hay nuevas insignias
      if (newBadgeDetails.isNotEmpty) {
        // ignore: use_build_context_synchronously
        await _staticShowNewBadgeNotifications(context, newBadgeDetails);
      }
    } catch (e) {
      // print('Error al verificar insignias: $e');
    }
  }

  // Función estática auxiliar para verificar insignias completadas
  static Future<List<Map<String, dynamic>>> _staticCheckAndUpdateCompletedBadges(
    List<QueryDocumentSnapshot> badgesDocs,
    List<String> currentUserBadges,
    Map<String, dynamic> userActivity,
    String userId,
  ) async {
    List<String> newBadges = [];
    List<Map<String, dynamic>> newBadgeDetails = [];

    for (final badgeDoc in badgesDocs) {
      final badgeData = badgeDoc.data() as Map<String, dynamic>;
      final badgeOrder = badgeData['order'] as int;
      final badgeOrderString = badgeOrder.toString();

      // Si ya tiene esta insignia, continúa con la siguiente
      if (currentUserBadges.contains(badgeOrderString)) {
        continue;
      }

      // Calcular si ha completado esta insignia
      final criteria = badgeData['criteria'] as Map<String, dynamic>;
      final type = criteria['type'] as String;
      final threshold = criteria['threshold'] as int;
      final taxonOrder = criteria['taxonOrder'] as String?;
      final className = criteria['class'] as String?;

      int currentProgress = 0;

      if (type == 'species_identified') {
        if (className != null && className.isNotEmpty) {
          final speciesIdentified = userActivity['speciesIdentified'] as Map<String, dynamic>?;
          final byClass = speciesIdentified?['byClass'] as Map<String, dynamic>?;
          currentProgress = byClass?[className] ?? 0;
        } else if (taxonOrder != null && taxonOrder.isNotEmpty) {
          final speciesIdentified = userActivity['speciesIdentified'] as Map<String, dynamic>?;
          final byTaxon = speciesIdentified?['byTaxon'] as Map<String, dynamic>?;
          currentProgress = byTaxon?[taxonOrder] ?? 0;
        } else {
          currentProgress = userActivity['photosUploaded'] ?? 0;
        }
      } else if (type == 'unique_orders') {
        final speciesIdentified = userActivity['speciesIdentified'] as Map<String, dynamic>?;
        final byTaxon = speciesIdentified?['byTaxon'] as Map<String, dynamic>?;
        currentProgress = byTaxon?.keys.where((key) => (byTaxon[key] ?? 0) > 0).length ?? 0;
      } else if (type == 'diversity') {
        final speciesIdentified = userActivity['speciesIdentified'] as Map<String, dynamic>?;
        final byTaxon = speciesIdentified?['byTaxon'] as Map<String, dynamic>?;
        if (byTaxon != null) {
          // ignore: avoid_types_as_parameter_names
          currentProgress = byTaxon.values.where((count) => count >= threshold).length;
        }
      } else if (type == 'field_notes_created') {
        currentProgress = userActivity['fieldNotesCreated'] ?? 0;
      } else if (type == 'all_badges') {
        currentProgress = currentUserBadges.length;
      }

      // Si completó la insignia, agregarla a la lista de nuevas insignias
      if (currentProgress >= threshold) {
        newBadges.add(badgeOrderString);
        newBadgeDetails.add({
          'name': badgeData['name'],
          'description': badgeData['description'],
          'iconName': badgeData['iconName'],
          'order': badgeOrderString,
        });
      }
    }

    // Si hay nuevas insignias, actualizar el documento del usuario
    if (newBadges.isNotEmpty) {
      final updatedBadges = [...currentUserBadges, ...newBadges];
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'badges': updatedBadges,
      });
    }

    return newBadgeDetails;
  }

  // Función estática auxiliar para mostrar notificaciones
  static Future<void> _staticShowNewBadgeNotifications(BuildContext context, List<Map<String, dynamic>> newBadges) async {
    if (newBadges.isEmpty) return;

    // Ordenar por order para mostrar en el orden correcto
    newBadges.sort((a, b) => int.parse(a['order']).compareTo(int.parse(b['order'])));

    for (int i = 0; i < newBadges.length; i++) {
      final badge = newBadges[i];
      final isLast = i == newBadges.length - 1;
      
      // ignore: use_build_context_synchronously
      await Navigator.of(context).push(
        PageRouteBuilder(
          opaque: false,
          barrierDismissible: false,
          pageBuilder: (context, animation, secondaryAnimation) {
            return NotificacionLogroScreen(
              titulo: newBadges.length > 1 
                  ? '¡Insignia Desbloqueada! ${i + 1}/${newBadges.length}' 
                  : '¡Insignia Desbloqueada!',
              nombreInsignia: badge['name'] ?? 'Insignia',
              descripcion: badge['description'] ?? 'Has completado una insignia.',
              imagenInsignia: badge['iconName'] != null 
                  ? 'assets/badge_icons/${badge['iconName']}.png' 
                  : null,
              showContinueButton: !isLast,
              onOk: () {
                Navigator.of(context).pop();
              },
            );
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                ),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );

      // Pequeña pausa entre notificaciones
      if (!isLast) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
  }
}

class _GaleriaInsigniasScreenState extends State<GaleriaInsigniasScreen> {
  late Future<Map<String, dynamic>> _badgesDataFuture;
  bool _hasShownNotifications = false; // Para evitar mostrar notificaciones múltiples veces
  bool _hadNewBadges = false; // Para rastrear si se obtuvieron nuevas insignias

  @override
  void initState() {
    super.initState();
    _badgesDataFuture = _loadBadgesData();
  }

  Future<Map<String, dynamic>> _loadBadgesData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('No hay usuario autenticado');

    // Cargar todas las insignias disponibles
    final badgesSnapshot = await FirebaseFirestore.instance
        .collection('badges')
        .orderBy('order')
        .get();

    // Cargar datos del usuario para ver qué insignias tiene
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    // Cargar actividad del usuario para calcular progreso
    final activityDoc = await FirebaseFirestore.instance
        .collection('user_activity')
        .doc(user.uid)
        .get();

    final userData = userDoc.data() as Map<String, dynamic>? ?? {};
    final activityData = activityDoc.data() as Map<String, dynamic>? ?? {};
    final userBadges = List<String>.from(userData['badges'] ?? []);

    // Verificar y actualizar insignias completadas
    final newBadgeDetails = await _checkAndUpdateCompletedBadges(badgesSnapshot.docs, userBadges, activityData, user.uid);
    
    // Marcar si hubo nuevas insignias para informar al perfil
    if (newBadgeDetails.isNotEmpty) {
      _hadNewBadges = true;
    }

    // Recargar los datos del usuario después de la actualización
    final updatedUserDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final updatedUserData = updatedUserDoc.data() as Map<String, dynamic>? ?? {};
    final updatedUserBadges = List<String>.from(updatedUserData['badges'] ?? []);

    return {
      'badges': badgesSnapshot.docs,
      'userBadges': updatedUserBadges,
      'activity': activityData,
      'newBadges': newBadgeDetails, // Incluir nuevas insignias
    };
  }

  Future<List<Map<String, dynamic>>> _checkAndUpdateCompletedBadges(
    List<QueryDocumentSnapshot> badgesDocs,
    List<String> currentUserBadges, // Cambiar a List<String>
    Map<String, dynamic> userActivity,
    String userId,
  ) async {
    List<String> newBadges = []; // Cambiar a List<String>
    List<Map<String, dynamic>> newBadgeDetails = []; // Para retornar detalles de nuevas insignias

    for (final badgeDoc in badgesDocs) {
      final badgeData = badgeDoc.data() as Map<String, dynamic>;
      final badgeOrder = badgeData['order'] as int;
      final badgeOrderString = badgeOrder.toString(); // Convertir a string

      // Si ya tiene esta insignia, continúa con la siguiente
      if (currentUserBadges.contains(badgeOrderString)) { // Usar string
        continue;
      }

      // Calcular si ha completado esta insignia
      final criteria = badgeData['criteria'] as Map<String, dynamic>;
      final type = criteria['type'] as String;
      final threshold = criteria['threshold'] as int;
      final taxonOrder = criteria['taxonOrder'] as String?;
      final className = criteria['class'] as String?;

      int currentProgress = 0;

      if (type == 'species_identified') {
        // Para insignias específicas de clase o orden
        if (className != null && className.isNotEmpty) {
          final speciesIdentified = userActivity['speciesIdentified'] as Map<String, dynamic>?;
          final byClass = speciesIdentified?['byClass'] as Map<String, dynamic>?;
          currentProgress = byClass?[className] ?? 0;
        } else if (taxonOrder != null && taxonOrder.isNotEmpty) {
          final speciesIdentified = userActivity['speciesIdentified'] as Map<String, dynamic>?;
          final byTaxon = speciesIdentified?['byTaxon'] as Map<String, dynamic>?;
          currentProgress = byTaxon?[taxonOrder] ?? 0;
        } else {
          // Para insignias generales como "Primeros Pasos" y "Taxónomo Novato"
          // usar directamente photosUploaded que cuenta todas las identificaciones
          currentProgress = userActivity['photosUploaded'] ?? 0;
        }
      } else if (type == 'unique_orders') {
        // Contar órdenes únicos identificados
        final speciesIdentified = userActivity['speciesIdentified'] as Map<String, dynamic>?;
        final byTaxon = speciesIdentified?['byTaxon'] as Map<String, dynamic>?;
        currentProgress = byTaxon?.keys.where((key) => (byTaxon[key] ?? 0) > 0).length ?? 0;
      } else if (type == 'diversity') {
        // Identificar especímenes de diferentes órdenes (mínimo X especímenes de Y órdenes)
        final speciesIdentified = userActivity['speciesIdentified'] as Map<String, dynamic>?;
        final byTaxon = speciesIdentified?['byTaxon'] as Map<String, dynamic>?;
        if (byTaxon != null) {
          // ignore: avoid_types_as_parameter_names
          currentProgress = byTaxon.values.where((count) => count >= threshold).length;
        }
      } else if (type == 'field_notes_created') {
        // Contar bitácoras creadas
        currentProgress = userActivity['fieldNotesCreated'] ?? 0;
      } else if (type == 'all_badges') {
        // Meta-insignia: tener todas las demás insignias
        currentProgress = currentUserBadges.length;
      }

      // Si completó la insignia, agregarla a la lista de nuevas insignias
      if (currentProgress >= threshold) {
        newBadges.add(badgeOrderString); // Agregar como string
        newBadgeDetails.add({
          'name': badgeData['name'],
          'description': badgeData['description'],
          'iconName': badgeData['iconName'],
          'order': badgeOrderString,
        });
        // print('🏆 Nueva insignia completada: ${badgeData['name']} (order: "$badgeOrderString")');
      }
    }

    // Si hay nuevas insignias, actualizar el documento del usuario
    if (newBadges.isNotEmpty) {
      final updatedBadges = [...currentUserBadges, ...newBadges];
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'badges': updatedBadges,
      });

      // print('✅ Insignias actualizadas en Firestore: $updatedBadges');
    }

    return newBadgeDetails; // Retornar detalles de nuevas insignias
  }

  // Función para mostrar notificaciones de nuevas insignias de manera secuencial
  Future<void> _showNewBadgeNotifications(List<Map<String, dynamic>> newBadges) async {
    if (newBadges.isEmpty) return;

    // Ordenar por order para mostrar en el orden correcto
    newBadges.sort((a, b) => int.parse(a['order']).compareTo(int.parse(b['order'])));

    for (int i = 0; i < newBadges.length; i++) {
      final badge = newBadges[i];
      final isLast = i == newBadges.length - 1;
      
      // ignore: use_build_context_synchronously
      await Navigator.of(context).push(
        PageRouteBuilder(
          opaque: false, // Permite transparencia
          barrierDismissible: false,
          pageBuilder: (context, animation, secondaryAnimation) {
            return NotificacionLogroScreen(
              titulo: newBadges.length > 1 
                  ? '¡Insignia Desbloqueada! ${i + 1}/${newBadges.length}' 
                  : '¡Insignia Desbloqueada!',
              nombreInsignia: badge['name'] ?? 'Insignia',
              descripcion: badge['description'] ?? 'Has completado una insignia.',
              imagenInsignia: badge['iconName'] != null 
                  ? 'assets/badge_icons/${badge['iconName']}.png' 
                  : null,
              showContinueButton: !isLast, // Mostrar "Continuar" si no es la última
              onOk: () {
                Navigator.of(context).pop();
              },
            );
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                ),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );

      // Pequeña pausa entre notificaciones para evitar superposición
      if (!isLast) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_hadNewBadges);
        return false; // Prevenimos el pop automático
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          color: AppColors.backgroundPrimary, // Cambiar de gradiente a color sólido
          child: SafeArea(
            child: Column(
              children: [
              // Header
              Container(
                color: AppColors.backgroundCard,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new),
                      color: AppColors.textWhite,
                      onPressed: () => Navigator.pop(context, _hadNewBadges),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Galería de Insignias',
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Grid de insignias
              Expanded(
                child: FutureBuilder<Map<String, dynamic>>(
                  future: _badgesDataFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppColors.mintGreen),
                      );
                    }
                    
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Error al cargar insignias: ${snapshot.error}',
                              style: const TextStyle(color: AppColors.warning),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _hasShownNotifications = false;
                                  _badgesDataFuture = _loadBadgesData();
                                });
                              },
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      );
                    }

                    final badgesDocs = snapshot.data!['badges'] as List<QueryDocumentSnapshot>;
                    final userBadges = snapshot.data!['userBadges'] as List<String>;
                    final activity = snapshot.data!['activity'] as Map<String, dynamic>;
                    final newBadges = snapshot.data!['newBadges'] as List<Map<String, dynamic>>;

                    // Mostrar notificaciones de nuevas insignias después de construir la interfaz
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (newBadges.isNotEmpty && !_hasShownNotifications) {
                        _hasShownNotifications = true;
                        _showNewBadgeNotifications(newBadges);
                      }
                    });

                    if (badgesDocs.isEmpty) {
                      return const Center(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 64, horizontal: 24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.emoji_events_outlined, color: AppColors.textPaleGreen, size: 64),
                                SizedBox(height: 24),
                                Text(
                                  'No hay insignias disponibles en este momento.',
                                  style: TextStyle(
                                    color: AppColors.textPaleGreen,
                                    fontSize: 18,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: badgesDocs.length,
                      itemBuilder: (context, index) {
                        final badgeDoc = badgesDocs[index];
                        final badgeData = badgeDoc.data() as Map<String, dynamic>;
                        final badgeOrder = badgeData['order'] as int;
                        final badgeOrderString = badgeOrder.toString();
                        
                        final isInUserBadges = userBadges.contains(badgeOrderString);

                        return InsigniaCard(
                          badgeData: badgeData,
                          isEarned: isInUserBadges,
                          userActivity: activity,
                          userBadges: userBadges,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ), // Cierre del Column
        ), // Cierre del SafeArea
      ), // Cierre del Container
    ), // Cierre del body/Scaffold
  ); // Cierre del WillPopScope
  }
}

class InsigniaCard extends StatelessWidget {
  final Map<String, dynamic> badgeData;
  final bool isEarned;
  final Map<String, dynamic> userActivity;
  final List<String> userBadges;

  const InsigniaCard({
    super.key,
    required this.badgeData,
    required this.isEarned,
    required this.userActivity,
    required this.userBadges,
  });

  Map<String, dynamic> _calculateProgress() {
    final criteria = badgeData['criteria'] as Map<String, dynamic>;
    final type = criteria['type'] as String;
    final threshold = criteria['threshold'] as int;
    final taxonOrder = criteria['taxonOrder'] as String?;
    final className = criteria['class'] as String?;
    
    int currentProgress = 0;
    
    if (type == 'species_identified') {
      final speciesIdentified = userActivity['speciesIdentified'] as Map<String, dynamic>?;
      
      if (className != null && className.isNotEmpty) {
        final byClass = speciesIdentified?['byClass'] as Map<String, dynamic>?;
        currentProgress = byClass?[className] ?? 0;
      } else if (taxonOrder != null && taxonOrder.isNotEmpty) {
        final byTaxon = speciesIdentified?['byTaxon'] as Map<String, dynamic>?;
        currentProgress = byTaxon?[taxonOrder] ?? 0;
      } else {
        currentProgress = userActivity['photosUploaded'] ?? 0;
      }
    } else if (type == 'unique_orders') {
      final speciesIdentified = userActivity['speciesIdentified'] as Map<String, dynamic>?;
      final byTaxon = speciesIdentified?['byTaxon'] as Map<String, dynamic>?;
      currentProgress = byTaxon?.keys.where((key) => (byTaxon[key] ?? 0) > 0).length ?? 0;
    } else if (type == 'diversity') {
      final speciesIdentified = userActivity['speciesIdentified'] as Map<String, dynamic>?;
      final byTaxon = speciesIdentified?['byTaxon'] as Map<String, dynamic>?;
      if (byTaxon != null) {
        // ignore: avoid_types_as_parameter_names
        currentProgress = byTaxon.values.where((count) => count >= threshold).length;
      }
    } else if (type == 'field_notes_created') {
      currentProgress = userActivity['fieldNotesCreated'] ?? 0;
    } else if (type == 'all_badges') {
      final currentBadgeOrder = badgeData['order']?.toString();
      final otherBadges = userBadges.where((badge) => badge != currentBadgeOrder).toList();
      currentProgress = otherBadges.length;
    }
    
    final progress = currentProgress / threshold;
    final progressClamped = progress > 1.0 ? 1.0 : progress;
    
    String progressText;
    if (currentProgress >= threshold) {
      progressText = '✓';
    } else {
      // Simplificar todos los textos a formato numérico básico para mantener consistencia
      progressText = '$currentProgress/$threshold';
    }
    
    return {
      'current': currentProgress,
      'target': threshold,
      'progress': progressClamped,
      'progressText': progressText,
    };
  }

  void _showBadgeDetails(BuildContext context) {
    final progressData = _calculateProgress();
    final int currentProgress = progressData['current'];
    final int target = progressData['target'];
    final bool hasCompletedProgress = currentProgress >= target;
    final bool isActuallyEarned = isEarned && hasCompletedProgress;
    
    showDialog(
      context: context,
      builder: (context) => BadgeDetailModal(
        badgeData: badgeData,
        isEarned: isActuallyEarned,
        userActivity: userActivity,
        userBadges: userBadges,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progressData = _calculateProgress();
    final iconName = badgeData['iconName'] as String? ?? 'first_steps';
    final name = badgeData['name'] as String? ?? 'Insignia';
    
    final int currentProgress = progressData['current'];
    final int target = progressData['target'];
    final bool hasCompletedProgress = currentProgress >= target;
    final bool isActuallyEarned = isEarned && hasCompletedProgress;
    
    final Color nameColor = isActuallyEarned ? AppColors.mintGreen : AppColors.textPaleGreen;

    return GestureDetector(
      onTap: () => _showBadgeDetails(context),
      child: Card(
        color: AppColors.backgroundCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 8,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  // ignore: deprecated_member_use
                  color: AppColors.slateGreen.withOpacity(0.3),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Opacity(
                    opacity: isActuallyEarned ? 1.0 : 0.4,
                    child: Image.asset(
                      'assets/badge_icons/$iconName.png',
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(Icons.emoji_events, size: 40, color: nameColor);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                name,
                style: TextStyle(
                  color: nameColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                '${progressData['current']}/${progressData['target']}',
                style: TextStyle(
                  color: nameColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BadgeDetailModal extends StatelessWidget {
  final Map<String, dynamic> badgeData;
  final bool isEarned;
  final Map<String, dynamic> userActivity;
  final List<String> userBadges;

  const BadgeDetailModal({
    super.key,
    required this.badgeData,
    required this.isEarned,
    required this.userActivity,
    required this.userBadges,
  });

  Map<String, dynamic> _calculateProgress() {
    final criteria = badgeData['criteria'] as Map<String, dynamic>;
    final type = criteria['type'] as String;
    final threshold = criteria['threshold'] as int;
    final taxonOrder = criteria['taxonOrder'] as String?;
    final className = criteria['class'] as String?;
    
    int currentProgress = 0;
    
    if (type == 'species_identified') {
      final speciesIdentified = userActivity['speciesIdentified'] as Map<String, dynamic>?;
      
      if (className != null && className.isNotEmpty) {
        final byClass = speciesIdentified?['byClass'] as Map<String, dynamic>?;
        currentProgress = byClass?[className] ?? 0;
      } else if (taxonOrder != null && taxonOrder.isNotEmpty) {
        final byTaxon = speciesIdentified?['byTaxon'] as Map<String, dynamic>?;
        currentProgress = byTaxon?[taxonOrder] ?? 0;
      } else {
        currentProgress = userActivity['photosUploaded'] ?? 0;
      }
    } else if (type == 'unique_orders') {
      final speciesIdentified = userActivity['speciesIdentified'] as Map<String, dynamic>?;
      final byTaxon = speciesIdentified?['byTaxon'] as Map<String, dynamic>?;
      currentProgress = byTaxon?.keys.where((key) => (byTaxon[key] ?? 0) > 0).length ?? 0;
    } else if (type == 'diversity') {
      final speciesIdentified = userActivity['speciesIdentified'] as Map<String, dynamic>?;
      final byTaxon = speciesIdentified?['byTaxon'] as Map<String, dynamic>?;
      if (byTaxon != null) {
        // ignore: avoid_types_as_parameter_names
        currentProgress = byTaxon.values.where((count) => count >= threshold).length;
      }
    } else if (type == 'field_notes_created') {
      currentProgress = userActivity['fieldNotesCreated'] ?? 0;
    } else if (type == 'all_badges') {
      final currentBadgeOrder = badgeData['order']?.toString();
      final otherBadges = userBadges.where((badge) => badge != currentBadgeOrder).toList();
      currentProgress = otherBadges.length;
    }
    
    final progress = currentProgress / threshold;
    final progressClamped = progress > 1.0 ? 1.0 : progress;
    
    String progressText;
    if (currentProgress >= threshold) {
      progressText = '✓';
    } else {
      // Simplificar todos los textos a formato numérico básico para evitar desbordamiento
      progressText = '$currentProgress/$threshold';
    }
    
    return {
      'current': currentProgress,
      'target': threshold,
      'progress': progressClamped,
      'progressText': progressText,
    };
  }

  String _getProgressTypeText(Map<String, dynamic> badgeData, Map<String, dynamic> progressData) {
    final criteria = badgeData['criteria'] as Map<String, dynamic>;
    final type = criteria['type'] as String;
    final current = progressData['current'] as int;
    final target = progressData['target'] as int;
    
    if (current >= target) {
      return '¡Insignia completada!';
    }
    
    switch (type) {
      case 'unique_orders':
        return 'Órdenes únicos identificados';
      case 'diversity':
        return 'Órdenes con suficientes especímenes';
      case 'field_notes_created':
        return 'Bitácoras de campo creadas';
      case 'all_badges':
        return 'Total de insignias obtenidas';
      case 'species_identified':
        final className = criteria['class'] as String?;
        final taxonOrder = criteria['taxonOrder'] as String?;
        if (className != null && className.isNotEmpty) {
          return 'Especímenes de $className identificados';
        } else if (taxonOrder != null && taxonOrder.isNotEmpty) {
          return 'Especímenes de $taxonOrder identificados';
        } else {
          return 'Especímenes identificados';
        }
      default:
        return 'Progreso actual';
    }
  }

  @override
  Widget build(BuildContext context) {
    final progressData = _calculateProgress();
    final iconName = badgeData['iconName'] as String? ?? 'first_steps';
    final name = badgeData['name'] as String? ?? 'Insignia';
    final description = badgeData['description'] as String? ?? '';
    
    final Color nameColor = isEarned ? AppColors.mintGreen : AppColors.textPaleGreen;
    final Color progressColor = isEarned ? AppColors.mintGreen : AppColors.aquaBlue;
    final String motivationText = isEarned ? '¡Completado!' : '¡Sigue así!';

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                // ignore: deprecated_member_use
                color: AppColors.slateGreen.withOpacity(0.3),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Opacity(
                  opacity: isEarned ? 1.0 : 0.4,
                  child: Image.asset(
                    'assets/badge_icons/$iconName.png',
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.emoji_events, size: 60, color: nameColor);
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              name,
              style: TextStyle(
                color: nameColor,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: progressData['progress'],
                    backgroundColor: AppColors.slateGreen,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    strokeWidth: 8,
                  ),
                ),
                Text(
                  progressData['progressText'],
                  style: const TextStyle(
                    color: AppColors.textWhite,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Texto descriptivo del tipo de progreso
            Text(
              _getProgressTypeText(badgeData, progressData),
              style: const TextStyle(
                color: AppColors.textPaleGreen,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              description,
              style: const TextStyle(
                color: AppColors.textWhite,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              motivationText,
              style: TextStyle(
                color: isEarned ? AppColors.mintGreen : AppColors.textPaleGreen,
                fontStyle: FontStyle.italic,
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mintGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text(
                'Cerrar',
                style: TextStyle(
                  color: AppColors.textWhite,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}