import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'profile_notifier.dart';

class BitacoraService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Crear nueva bitácora con verificación robusta de conexión
  static Future<String> createBitacora({
    required String title,
    required String description,
    required List<String> selectedPhotoIds,
    required bool isPublic,
  }) async {
    try {
      print('🔄 BitacoraService: Iniciando creación de nueva bitácora "$title"');
      
      // Verificar autenticación
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ BitacoraService: Usuario no autenticado');
        throw Exception('Usuario no autenticado. Inicia sesión e inténtalo de nuevo.');
      }

      // Verificar conectividad con timeout
      print('🔍 BitacoraService: Verificando conectividad...');
      await Future.any([
        _firestore.collection('field_notes').limit(1).get(const GetOptions(source: Source.server)),
        Future.delayed(const Duration(seconds: 10), () => throw Exception('timeout'))
      ]);
      print('✅ BitacoraService: Conectividad confirmada');

      // Validar datos de entrada
      if (title.trim().isEmpty) {
        print('❌ BitacoraService: Título vacío');
        throw Exception('El título de la bitácora no puede estar vacío.');
      }
      
      if (selectedPhotoIds.isEmpty) {
        print('❌ BitacoraService: Sin fotos seleccionadas');
        throw Exception('Debes seleccionar al menos un registro para la bitácora.');
      }

      print('📋 BitacoraService: Validación completada - ${selectedPhotoIds.length} registros seleccionados');

      // Obtener nombre del usuario con manejo robusto de errores
      String authorName = 'Usuario';
      try {
        print('👤 BitacoraService: Obteniendo información del usuario...');
        final userDoc = await _firestore.collection('users').doc(user.uid).get(
          const GetOptions(source: Source.server)
        );
        if (userDoc.exists) {
          authorName = userDoc.data()?['fullname'] ?? user.displayName ?? 'Usuario';
          print('✅ BitacoraService: Nombre de usuario obtenido: $authorName');
        } else {
          authorName = user.displayName ?? 'Usuario';
          print('⚠️ BitacoraService: Documento de usuario no encontrado, usando: $authorName');
        }
      } catch (e) {
        authorName = user.displayName ?? 'Usuario';
        print('⚠️ BitacoraService: Error obteniendo usuario, usando fallback: $authorName - $e');
      }

      // Usar batch para operaciones atómicas
      final batch = _firestore.batch();
      final docRef = _firestore.collection('field_notes').doc();
      
      print('📝 BitacoraService: Preparando datos de la bitácora...');
      
      // 1. Crear documento de bitácora
      batch.set(docRef, {
        'userId': user.uid,
        'authorName': authorName,
        'title': title.trim(),
        'description': description.trim(),
        'selectedPhotos': selectedPhotoIds,
        'isPublic': isPublic,
        'createdAt': FieldValue.serverTimestamp(),
        'pdfUrl': null,
      });

      // 2. Actualizar actividad del usuario
      final userActivityRef = _firestore.collection('user_activity').doc(user.uid);
      batch.set(userActivityRef, {
        'userId': user.uid,
        'fieldNotesCreated': FieldValue.increment(1),
        'lastActivity': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3. Verificación adicional de conexión justo antes de la operación crítica
      print('🔍 BitacoraService: Verificación final de conectividad antes de crear...');
      try {
        // Usar lookup DNS para verificación más robusta de conectividad
        final result = await InternetAddress.lookup('dns.google').timeout(const Duration(seconds: 10));
        if (result.isEmpty || result[0].rawAddress.isEmpty) {
          throw Exception('No internet connection');
        }
        print('✅ BitacoraService: Conectividad final confirmada con DNS lookup');
      } catch (e) {
        print('❌ BitacoraService: Fallo en verificación final - cancelando creación');
        throw Exception('Se perdió la conexión a internet durante el proceso. La creación ha sido cancelada por seguridad.');
      }

      // 4. Ejecutar batch (operaciones Firestore atómicas)
      print('💾 BitacoraService: Ejecutando creación atómica...');
      await batch.commit();
      print('✅ BitacoraService: Creación atómica completada exitosamente');

      // 5. Notificar al ProfileScreen
      ProfileNotifier().notifyBitacoraCreada();
      print('🔔 BitacoraService: Notificado creación de bitácora "$title" con ID: ${docRef.id}');

      return docRef.id;
      
    } catch (e) {
      final errorString = e.toString().toLowerCase();
      print('❌ BitacoraService: Error en creación - $e');
      
      // Detectar errores específicos de Firebase y proporcionar mensajes amigables
      if (errorString.contains('unavailable') || 
          errorString.contains('timeout') || 
          errorString.contains('network') || 
          errorString.contains('connection')) {
        throw Exception('El servidor no está disponible temporalmente. Verifica tu conexión a internet e inténtalo de nuevo en unos momentos.');
      } else if (errorString.contains('permission-denied') || 
                 errorString.contains('unauthorized')) {
        throw Exception('No tienes permisos para crear bitácoras. Verifica tu cuenta.');
      } else if (errorString.contains('unauthenticated') ||
                 (errorString.contains('user') && errorString.contains('auth'))) {
        throw Exception('Tu sesión ha expirado. Inicia sesión nuevamente e inténtalo de nuevo.');
      } else if (errorString.contains('quota-exceeded') ||
                 errorString.contains('resource-exhausted')) {
        throw Exception('Se ha superado la cuota de uso. Inténtalo más tarde.');
      } else if (errorString.contains('deadline-exceeded') ||
                 errorString.contains('cancelled')) {
        throw Exception('La operación tardó demasiado tiempo. Verifica tu conexión e inténtalo de nuevo.');
      } else if (errorString.contains('título') && errorString.contains('vacío')) {
        throw Exception('El título de la bitácora no puede estar vacío.');
      } else if (errorString.contains('seleccionar') && errorString.contains('registro')) {
        throw Exception('Debes seleccionar al menos un registro para la bitácora.');
      } else {
        // Para cualquier otro error, usar un mensaje genérico y amigable
        throw Exception('No se pudo crear la bitácora. Verifica tu conexión a internet e inténtalo de nuevo.');
      }
    }
  }

  /// Obtener nombre del usuario actual
  static Future<String> getCurrentUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Usuario';

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        return userDoc.data()?['fullname'] ?? user.displayName ?? 'Usuario';
      }
      return user.displayName ?? 'Usuario';
    } catch (e) {
      return user.displayName ?? 'Usuario';
    }
  }

  /// Obtener mis fotos disponibles para bitácoras (por orden taxonómico)
  static Future<Map<String, List<Map<String, dynamic>>>> getAvailablePhotosByTaxon(String userId) async {
    try {
      final query = await _firestore
          .collection('insect_photos')
          .where('userId', isEqualTo: userId)
          .orderBy('lastModifiedAt', descending: true)
          .get(const GetOptions(source: Source.serverAndCache));

      final Map<String, List<Map<String, dynamic>>> photoGroups = {};
      for (final doc in query.docs) {
        final data = doc.data();
        final taxonOrder = data['taxonOrder'] as String? ?? 'Sin clasificar';
        
        photoGroups.putIfAbsent(taxonOrder, () => []);
        photoGroups[taxonOrder]!.add({
          ...data,
          'photoId': doc.id,
          'imageUrl': data['imageUrl'] ?? '',
          'taxonOrder': taxonOrder,
          'habitat': data['habitat'] ?? 'No especificado',
          'details': data['details'] ?? 'Sin detalles',
          'notes': data['notes'] ?? 'Sin notas',
          'class': data['class'] ?? 'Sin clasificar',
        });
      }

      return photoGroups;
    } catch (e) {
      throw Exception('Error al cargar fotos: $e');
    }
  }

  /// Obtener mis bitácoras
  static Future<List<Map<String, dynamic>>> getMyBitacoras(String userId) async {
    try {
      final query = await _firestore
          .collection('field_notes')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get(const GetOptions(source: Source.serverAndCache));

      return query.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      throw Exception('Error al cargar bitácoras: $e');
    }
  }

  /// Obtener bitácoras públicas
  static Future<List<Map<String, dynamic>>> getPublicBitacoras() async {
    try {
      final query = await _firestore
          .collection('field_notes')
          .where('isPublic', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get(const GetOptions(source: Source.serverAndCache));

      return query.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      throw Exception('Error al cargar bitácoras públicas: $e');
    }
  }

  /// Obtener fotos específicas por IDs
  static Future<List<Map<String, dynamic>>> getPhotosByIds(List<String> photoIds) async {
    if (photoIds.isEmpty) return [];
    
    try {
      List<Map<String, dynamic>> allPhotos = [];
      
      for (int i = 0; i < photoIds.length; i += 10) {
        final batch = photoIds.skip(i).take(10).toList();
        final query = await _firestore
            .collection('insect_photos')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        final batchPhotos = query.docs.map((doc) => {
          'photoId': doc.id,
          ...doc.data(),
        }).toList();
        
        allPhotos.addAll(batchPhotos);
      }

      return allPhotos;
    } catch (e) {
      throw Exception('Error al cargar fotos seleccionadas: $e');
    }
  }

  /// Eliminar bitácora con verificación robusta de conexión
  static Future<void> deleteBitacora(String bitacoraId) async {
    try {
      print('🔄 BitacoraService: Iniciando eliminación de bitácora $bitacoraId');
      
      // Verificar autenticación
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ BitacoraService: Usuario no autenticado');
        throw Exception('Usuario no autenticado. Inicia sesión e inténtalo de nuevo.');
      }

      // Verificar conectividad con DNS lookup más robusto
      print('🔍 BitacoraService: Verificando conectividad...');
      try {
        // Usar lookup DNS para verificación más robusta de conectividad
        final result = await InternetAddress.lookup('dns.google').timeout(const Duration(seconds: 10));
        if (result.isEmpty || result[0].rawAddress.isEmpty) {
          throw Exception('No internet connection');
        }
        print('✅ BitacoraService: Conectividad confirmada con DNS lookup');
      } catch (e) {
        print('❌ BitacoraService: No hay conexión a internet');
        throw Exception('No hay conexión a internet. Por favor, verifica tu conectividad e intenta nuevamente.');
      }

      // Obtener documento con verificación de permisos
      print('📄 BitacoraService: Obteniendo datos de la bitácora...');
      final doc = await _firestore.collection('field_notes').doc(bitacoraId).get(
        const GetOptions(source: Source.server)
      );
      
      if (!doc.exists) {
        print('❌ BitacoraService: Bitácora no encontrada');
        throw Exception('La bitácora no existe o ya fue eliminada por otro usuario.');
      }

      final bitacoraData = doc.data();
      if (bitacoraData?['userId'] != user.uid) {
        print('❌ BitacoraService: Sin permisos para eliminar');
        throw Exception('No tienes permisos para eliminar esta bitácora.');
      }

      final bitacoraTitle = bitacoraData?['title'] ?? 'Sin título';
      print('📝 BitacoraService: Procesando eliminación de "$bitacoraTitle"');

      // Usar batch para operaciones Firestore atómicas
      final batch = _firestore.batch();

      // 1. Eliminar documento de bitácora
      batch.delete(doc.reference);

      // 2. Actualizar actividad del usuario
      final userActivityRef = _firestore.collection('user_activity').doc(user.uid);
      batch.update(userActivityRef, {
        'fieldNotesCreated': FieldValue.increment(-1),
        'lastActivity': FieldValue.serverTimestamp(),
      });

      // 3. Eliminar PDF de Storage (fuera del batch)
      final pdfUrl = bitacoraData?['pdfUrl'];
      if (pdfUrl != null && pdfUrl.toString().isNotEmpty) {
        try {
          print('📄 BitacoraService: Eliminando PDF asociado...');
          final ref = _storage.refFromURL(pdfUrl);
          await ref.delete();
          print('✅ BitacoraService: PDF eliminado exitosamente');
        } catch (e) {
          print('⚠️ BitacoraService: Error al eliminar PDF: $e');
          // Continuar con el proceso - Storage no es crítico para la integridad de datos
        }
      }

      // 4. Ejecutar batch (operaciones Firestore atómicas)
      print('💾 BitacoraService: Ejecutando eliminación atómica...');
      await batch.commit();
      print('✅ BitacoraService: Eliminación atómica completada exitosamente');

      // 5. Notificar al ProfileScreen
      ProfileNotifier().notifyBitacorasEliminadas();
      print('🔔 BitacoraService: Notificado eliminación de bitácora "$bitacoraTitle"');

    } catch (e) {
      final errorString = e.toString().toLowerCase();
      print('❌ BitacoraService: Error en eliminación - $e');
      
      // Detectar errores específicos de Firebase y proporcionar mensajes amigables
      if (errorString.contains('unavailable') || 
          errorString.contains('timeout') || 
          errorString.contains('network') || 
          errorString.contains('connection')) {
        throw Exception('El servidor no está disponible temporalmente. Verifica tu conexión a internet e inténtalo de nuevo en unos momentos.');
      } else if (errorString.contains('permission-denied') || 
                 errorString.contains('unauthorized') ||
                 errorString.contains('permisos')) {
        throw Exception('No tienes permisos para eliminar esta bitácora.');
      } else if (errorString.contains('not-found') || 
                 errorString.contains('not found') ||
                 errorString.contains('no existe')) {
        throw Exception('La bitácora ya no existe o fue eliminada por otro usuario.');
      } else if (errorString.contains('unauthenticated') ||
                 (errorString.contains('user') && errorString.contains('auth'))) {
        throw Exception('Tu sesión ha expirado. Inicia sesión nuevamente e inténtalo de nuevo.');
      } else if (errorString.contains('quota-exceeded') ||
                 errorString.contains('resource-exhausted')) {
        throw Exception('Se ha superado la cuota de uso. Inténtalo más tarde.');
      } else if (errorString.contains('deadline-exceeded') ||
                 errorString.contains('cancelled')) {
        throw Exception('La operación tardó demasiado tiempo. Verifica tu conexión e inténtalo de nuevo.');
      } else {
        // Para cualquier otro error, usar un mensaje genérico y amigable
        throw Exception('No se pudo eliminar la bitácora. Verifica tu conexión a internet e inténtalo de nuevo.');
      }
    }
  }

  /// Actualizar bitácora con verificación robusta de conexión
  static Future<void> updateBitacora({
    required String bitacoraId,
    required String title,
    required String description,
    required List<String> selectedPhotoIds,
    required bool isPublic,
  }) async {
    try {
      print('🔄 BitacoraService: Iniciando actualización de bitácora $bitacoraId');
      
      // Verificar autenticación
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ BitacoraService: Usuario no autenticado');
        throw Exception('Usuario no autenticado. Inicia sesión e inténtalo de nuevo.');
      }

      // Verificar conectividad con DNS lookup más robusto
      print('🔍 BitacoraService: Verificando conectividad...');
      try {
        // Usar lookup DNS para verificación más robusta de conectividad
        final result = await InternetAddress.lookup('dns.google').timeout(const Duration(seconds: 10));
        if (result.isEmpty || result[0].rawAddress.isEmpty) {
          throw Exception('No internet connection');
        }
        print('✅ BitacoraService: Conectividad confirmada con DNS lookup');
      } catch (e) {
        print('❌ BitacoraService: No hay conexión a internet');
        throw Exception('No hay conexión a internet. Por favor, verifica tu conectividad e intenta nuevamente.');
      }

      // Validar datos de entrada
      if (title.trim().isEmpty) {
        print('❌ BitacoraService: Título vacío');
        throw Exception('El título de la bitácora no puede estar vacío.');
      }
      
      if (selectedPhotoIds.isEmpty) {
        print('❌ BitacoraService: Sin fotos seleccionadas');
        throw Exception('Debes seleccionar al menos un registro para la bitácora.');
      }

      // Obtener documento con verificación de permisos
      print('📄 BitacoraService: Obteniendo datos de la bitácora...');
      final doc = await _firestore.collection('field_notes').doc(bitacoraId).get(
        const GetOptions(source: Source.server)
      );
      
      if (!doc.exists) {
        print('❌ BitacoraService: Bitácora no encontrada');
        throw Exception('La bitácora no existe o ya fue eliminada por otro usuario.');
      }

      final bitacoraData = doc.data();
      if (bitacoraData?['userId'] != user.uid) {
        print('❌ BitacoraService: Sin permisos para actualizar');
        throw Exception('No tienes permisos para editar esta bitácora.');
      }

      print('📝 BitacoraService: Procesando actualización de "${bitacoraData?['title']}" -> "$title"');

      // Usar batch para operaciones atómicas
      final batch = _firestore.batch();

      // 1. Actualizar documento de bitácora
      batch.update(doc.reference, {
        'title': title.trim(),
        'description': description.trim(),
        'selectedPhotos': selectedPhotoIds,
        'isPublic': isPublic,
        'lastModifiedAt': FieldValue.serverTimestamp(),
      });

      // 2. Actualizar actividad del usuario
      final userActivityRef = _firestore.collection('user_activity').doc(user.uid);
      batch.update(userActivityRef, {
        'lastActivity': FieldValue.serverTimestamp(),
      });

      // 3. Verificación adicional de conexión justo antes de la operación crítica
      print('🔍 BitacoraService: Verificación final de conectividad antes de actualizar...');
      try {
        // Usar lookup DNS para verificación más robusta de conectividad
        final result = await InternetAddress.lookup('dns.google').timeout(const Duration(seconds: 10));
        if (result.isEmpty || result[0].rawAddress.isEmpty) {
          throw Exception('No internet connection');
        }
        print('✅ BitacoraService: Conectividad final confirmada con DNS lookup');
      } catch (e) {
        print('❌ BitacoraService: Fallo en verificación final - cancelando actualización');
        throw Exception('Se perdió la conexión a internet durante el proceso. La actualización ha sido cancelada por seguridad.');
      }

      // 4. Ejecutar batch (operaciones Firestore atómicas)
      print('💾 BitacoraService: Ejecutando actualización atómica...');
      await batch.commit();
      print('✅ BitacoraService: Actualización atómica completada exitosamente');

      // 5. Notificar al ProfileScreen
      ProfileNotifier().notifyProfileChanged();
      print('🔔 BitacoraService: Notificado actualización de bitácora "$title"');

    } catch (e) {
      final errorString = e.toString().toLowerCase();
      print('❌ BitacoraService: Error en actualización - $e');
      
      // Detectar errores específicos de Firebase y proporcionar mensajes amigables
      if (errorString.contains('unavailable') || 
          errorString.contains('timeout') || 
          errorString.contains('network') || 
          errorString.contains('connection')) {
        throw Exception('El servidor no está disponible temporalmente. Verifica tu conexión a internet e inténtalo de nuevo en unos momentos.');
      } else if (errorString.contains('permission-denied') || 
                 errorString.contains('unauthorized') ||
                 errorString.contains('permisos')) {
        throw Exception('No tienes permisos para editar esta bitácora.');
      } else if (errorString.contains('not-found') || 
                 errorString.contains('not found') ||
                 errorString.contains('no existe')) {
        throw Exception('La bitácora ya no existe o fue eliminada por otro usuario.');
      } else if (errorString.contains('unauthenticated') ||
                 (errorString.contains('user') && errorString.contains('auth'))) {
        throw Exception('Tu sesión ha expirado. Inicia sesión nuevamente e inténtalo de nuevo.');
      } else if (errorString.contains('quota-exceeded') ||
                 errorString.contains('resource-exhausted')) {
        throw Exception('Se ha superado la cuota de uso. Inténtalo más tarde.');
      } else if (errorString.contains('deadline-exceeded') ||
                 errorString.contains('cancelled')) {
        throw Exception('La operación tardó demasiado tiempo. Verifica tu conexión e inténtalo de nuevo.');
      } else if (errorString.contains('título') && errorString.contains('vacío')) {
        throw Exception('El título de la bitácora no puede estar vacío.');
      } else if (errorString.contains('seleccionar') && errorString.contains('registro')) {
        throw Exception('Debes seleccionar al menos un registro para la bitácora.');
      } else {
        // Para cualquier otro error, usar un mensaje genérico y amigable
        throw Exception('No se pudo actualizar la bitácora. Verifica tu conexión a internet e inténtalo de nuevo.');
      }
    }
  }

}