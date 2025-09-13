import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class BitacoraService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Crear nueva bitácora
  static Future<String> createBitacora({
    required String title,
    required String description,
    required List<String> selectedPhotoIds,
    required bool isPublic,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    try {
      // Obtener nombre del usuario
      String authorName = 'Usuario';
      try {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          authorName = userDoc.data()?['fullname'] ?? user.displayName ?? 'Usuario';
        }
      } catch (e) {
        authorName = user.displayName ?? 'Usuario';
      }

      // Crear documento en Firestore
      final docRef = _firestore.collection('field_notes').doc();
      
      await docRef.set({
        'userId': user.uid,
        'authorName': authorName, // ← Agregar nombre del autor
        'title': title,
        'description': description,
        'selectedPhotos': selectedPhotoIds,
        'isPublic': isPublic,
        'createdAt': FieldValue.serverTimestamp(),
        'pdfUrl': null,
      });

      // Actualizar actividad del usuario
      await _updateUserActivity(user.uid);

      return docRef.id;
    } catch (e) {
      throw Exception('Error al crear bitácora: $e');
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

  /// Eliminar bitácora
  static Future<void> deleteBitacora(String bitacoraId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final doc = await _firestore.collection('field_notes').doc(bitacoraId).get();
      if (!doc.exists || doc.data()?['userId'] != user.uid) {
        throw Exception('No tienes permisos para eliminar esta bitácora');
      }

      final pdfUrl = doc.data()?['pdfUrl'];
      if (pdfUrl != null && pdfUrl.toString().isNotEmpty) {
        try {
          final ref = _storage.refFromURL(pdfUrl);
          await ref.delete();
        } catch (e) {
          print('Error al eliminar PDF: $e');
        }
      }

      await _firestore.collection('field_notes').doc(bitacoraId).delete();

      await _firestore.collection('user_activity').doc(user.uid).update({
        'fieldNotesCreated': FieldValue.increment(-1),
        'lastActivity': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error al eliminar bitácora: $e');
    }
  }

  /// Actualizar bitácora
  static Future<void> updateBitacora({
    required String bitacoraId,
    required String title,
    required String description,
    required List<String> selectedPhotoIds,
    required bool isPublic,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final doc = await _firestore.collection('field_notes').doc(bitacoraId).get();
      if (!doc.exists || doc.data()?['userId'] != user.uid) {
        throw Exception('No tienes permisos para editar esta bitácora');
      }

      await _firestore.collection('field_notes').doc(bitacoraId).update({
        'title': title,
        'description': description,
        'selectedPhotos': selectedPhotoIds,
        'isPublic': isPublic,
      });
    } catch (e) {
      throw Exception('Error al actualizar bitácora: $e');
    }
  }

  /// Actualizar actividad del usuario
  static Future<void> _updateUserActivity(String userId) async {
    await _firestore.collection('user_activity').doc(userId).set({
      'userId': userId,
      'fieldNotesCreated': FieldValue.increment(1),
      'lastActivity': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}