import 'dart:typed_data';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class GoogleDriveService {
  // Scopes necesarios para Drive
  static final List<String> _scopes = [
    drive.DriveApi.driveFileScope,
  ];
  static drive.DriveApi? _driveApi;
  static String? _rootFolderId;

  /// Elimina archivos viejos y sube los nuevos tras cambio de clase/orden taxonómico
  static Future<void> resyncPhotoWithNewClassOrder({
    required String photoId,
    required String prevClass,
    required String prevOrder,
    required String newClass,
    required String newOrder,
    required Map<String, dynamic> photoData,
  }) async {
    // Inicializar conexión si es necesario
    if (!await initialize()) throw Exception('No se pudo conectar a Google Drive');

    // Obtener estructura de carpetas
    final rootFolderId = await _createFolderStructure();
    if (rootFolderId == null) throw Exception('No se pudo obtener la carpeta raíz');

    // Carpeta y nombres viejos
    final prevClassFolder = await _getOrCreateFolder(_normalizeClassName(prevClass), rootFolderId);
    final prevOrderFolder = await _getOrCreateFolder(_normalizeOrderName(prevOrder), prevClassFolder);
    final oldBaseName = _generateFileName({
      ...photoData,
      'class': prevClass,
      'taxonOrder': prevOrder,
      'photoId': photoId,
    });
    final oldImage = '$oldBaseName.jpg';
    final oldMeta = '${oldBaseName}_metadata.txt';

    // Eliminar archivos viejos
    await _deleteFileIfExists(oldImage, prevOrderFolder!);
    await _deleteFileIfExists(oldMeta, prevOrderFolder);

    // Carpeta y nombres nuevos
    final newClassFolder = await _getOrCreateFolder(_normalizeClassName(newClass), rootFolderId);
    final newOrderFolder = await _getOrCreateFolder(_normalizeOrderName(newOrder), newClassFolder);
    final newBaseName = _generateFileName({
      ...photoData,
      'class': newClass,
      'taxonOrder': newOrder,
      'photoId': photoId,
    });

    // Descargar imagen
    final imageUrl = photoData['imageUrl'] ?? '';
    if (imageUrl.isEmpty) throw Exception('No se encontró la URL de la imagen');
    final response = await http.get(Uri.parse(imageUrl));
    if (response.statusCode != 200) throw Exception('No se pudo descargar la imagen');

    // Subir imagen y metadatos nuevos
    final imageOk = await _uploadFileIfNotExists('$newBaseName.jpg', response.bodyBytes, newOrderFolder);
    final metadataContent = _createMetadataContent({...photoData, 'class': newClass, 'taxonOrder': newOrder});
    final metadataBytes = Uint8List.fromList(metadataContent.codeUnits);
    final metaOk = await _uploadFileIfNotExists('${newBaseName}_metadata.txt', metadataBytes, newOrderFolder);

    // Actualizar syncedAt si ambos archivos se subieron
    if (imageOk && metaOk) {
      await _updateSyncedAt(photoId);
    } else {
      throw Exception('No se pudo subir los archivos nuevos a Drive');
    }
  }

  // Inicializar la conexión con Google Drive
  static Future<bool> initialize() async {
    try {
      final googleSignIn = GoogleSignIn(scopes: _scopes);
      
      // Verificar si ya hay una sesión activa
      GoogleSignInAccount? account = googleSignIn.currentUser;
      
      account ??= await googleSignIn.signIn();
      
      if (account == null) {
        return false; // Usuario canceló la autenticación
      }

      // Obtener las credenciales de autenticación
      final googleAuth = await account.authentication;
      final accessCredentials = AccessCredentials(
        AccessToken('Bearer', googleAuth.accessToken!, DateTime.now().toUtc().add(const Duration(hours: 1))),
        googleAuth.idToken,
        _scopes,
      );

      // Crear cliente autenticado
      final authClient = authenticatedClient(http.Client(), accessCredentials);
      _driveApi = drive.DriveApi(authClient);

      return true;
    } catch (e) {
      print('Error inicializando Google Drive: $e');
      return false;
    }
  }

  // Crear o obtener estructura de carpetas en Drive
  static Future<String?> _createFolderStructure() async {
    if (_driveApi == null) return null;

    try {
      // Primero buscar si ya existe una carpeta BioDetect
      final query = "name='BioDetect' and mimeType='application/vnd.google-apps.folder' and trashed=false";
      final searchResult = await _driveApi!.files.list(q: query);
      
      if (searchResult.files != null && searchResult.files!.isNotEmpty) {
        // Ya existe una carpeta BioDetect, usar la primera encontrada
        _rootFolderId = searchResult.files!.first.id;
        print('Usando carpeta BioDetect existente: $_rootFolderId');
        return _rootFolderId;
      }

      // No existe, crear nueva carpeta raíz BioDetect
      final rootFolder = drive.File()
        ..name = 'BioDetect'
        ..mimeType = 'application/vnd.google-apps.folder';

      final createdRoot = await _driveApi!.files.create(rootFolder);
      _rootFolderId = createdRoot.id;
      print('Creada nueva carpeta BioDetect: $_rootFolderId');

      return _rootFolderId;
    } catch (e) {
      print('Error creando/obteniendo estructura de carpetas: $e');
      return null;
    }
  }

  // Obtener o crear carpeta por nombre
  static Future<String?> _getOrCreateFolder(String folderName, String? parentId) async {
    if (_driveApi == null) return null;

    try {
      // Buscar si la carpeta ya existe
      String query = "name='$folderName' and mimeType='application/vnd.google-apps.folder' and trashed=false";
      if (parentId != null) {
        query += " and '$parentId' in parents";
      }

      final searchResult = await _driveApi!.files.list(q: query);
      
      if (searchResult.files != null && searchResult.files!.isNotEmpty) {
        return searchResult.files!.first.id;
      }

      // Si no existe, crearla
      final folder = drive.File()
        ..name = folderName
        ..mimeType = 'application/vnd.google-apps.folder';
      
      if (parentId != null) {
        folder.parents = [parentId];
      }

      final createdFolder = await _driveApi!.files.create(folder);
      return createdFolder.id;
    } catch (e) {
      print('Error obteniendo/creando carpeta $folderName: $e');
      return null;
    }
  }

  // Verificar si un archivo ya existe en Drive
  static Future<bool> _fileExists(String fileName, String parentFolderId) async {
    if (_driveApi == null) return false;

    try {
      final query = "name='$fileName' and '$parentFolderId' in parents and trashed=false";
      final searchResult = await _driveApi!.files.list(q: query);
      return searchResult.files != null && searchResult.files!.isNotEmpty;
    } catch (e) {
      print('Error verificando archivo $fileName: $e');
      return false;
    }
  }

  // Subir archivo a Drive solo si no existe
  static Future<bool> _uploadFileIfNotExists(String fileName, Uint8List fileData, String? parentFolderId) async {
    if (_driveApi == null || parentFolderId == null) return false;

    try {
      // Verificar si el archivo ya existe
      if (await _fileExists(fileName, parentFolderId)) {
        print('Archivo $fileName ya existe, omitiendo...');
        return true; // Consideramos exitoso porque el archivo ya está
      }

      final driveFile = drive.File()
        ..name = fileName
        ..parents = [parentFolderId];

      final media = drive.Media(Stream.fromIterable([fileData]), fileData.length);
      await _driveApi!.files.create(driveFile, uploadMedia: media);
      
      return true;
    } catch (e) {
      print('Error subiendo archivo $fileName: $e');
      return false;
    }
  }

  // Variable estática para controlar la cancelación
  static bool _isCancelled = false;

  // Método para cancelar la sincronización
  static void cancelSync() {
    _isCancelled = true;
  }

  // Método para resetear el estado de cancelación
  static void _resetCancellation() {
    _isCancelled = false;
  }

  // Sincronizar todas las fotos del usuario con Drive
  static Future<Map<String, dynamic>> syncAllPhotos({
    Function(int current, int total, String fileName)? onProgress,
  }) async {
    // Resetear cancelación al inicio
    _resetCancellation();
    final Map<String, dynamic> result = {
      'success': false,
      'syncedPhotos': 0,
      'totalPhotos': 0,
      'skippedPhotos': 0,
      'errors': <String>[],
    };

    try {
      // Inicializar conexión con Drive
      if (!await initialize()) {
        (result['errors'] as List<String>).add('No se pudo conectar con Google Drive');
        return result;
      }

      // Crear estructura de carpetas
      final rootFolderId = await _createFolderStructure();
      if (rootFolderId == null) {
        (result['errors'] as List<String>).add('No se pudo crear la carpeta raíz en Drive');
        return result;
      }

      // Obtener todas las fotos del usuario
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        (result['errors'] as List<String>).add('Usuario no autenticado');
        return result;
      }

      final query = await FirebaseFirestore.instance
          .collection('insect_photos')
          .where('userId', isEqualTo: user.uid)
          .get();

      result['totalPhotos'] = query.docs.length;

      // Crear mapa para organizar por clase y orden
      final Map<String, Map<String, List<Map<String, dynamic>>>> organized = {};

      for (final doc in query.docs) {
        final data = doc.data();
        final clase = _normalizeClassName(data['class'] ?? 'Sin_clasificar');
        final orden = _normalizeOrderName(data['taxonOrder'] ?? 'Sin_clasificar');

        organized.putIfAbsent(clase, () => {});
        organized[clase]!.putIfAbsent(orden, () => []);
        organized[clase]![orden]!.add({
          ...data,
          'photoId': doc.id,
        });
      }

      // Sincronizar cada clase y orden
      int syncedCount = 0;
      int skippedCount = 0;
      int currentPhoto = 0;
      
      for (final claseEntry in organized.entries) {
        // Verificar cancelación antes de procesar cada clase
        if (_isCancelled) {
          result['success'] = false;
          result['syncedPhotos'] = syncedCount;
          result['skippedPhotos'] = skippedCount;
          (result['errors'] as List<String>).add('Sincronización cancelada por el usuario');
          return result;
        }

        final clase = claseEntry.key;
        final ordenes = claseEntry.value;

        // Crear carpeta de clase
        final claseFolderId = await _getOrCreateFolder(clase, rootFolderId);
        if (claseFolderId == null) {
          (result['errors'] as List<String>).add('Error creando carpeta para clase: $clase');
          continue;
        }

        for (final ordenEntry in ordenes.entries) {
          final orden = ordenEntry.key;
          final photos = ordenEntry.value;

          // Crear carpeta de orden
          final ordenFolderId = await _getOrCreateFolder(orden, claseFolderId);
          if (ordenFolderId == null) {
            (result['errors'] as List<String>).add('Error creando carpeta para orden: $orden');
            continue;
          }

          // Subir fotos y metadatos de este orden
          for (final photo in photos) {
            // Verificar cancelación antes de procesar cada foto
            if (_isCancelled) {
              result['success'] = false;
              result['syncedPhotos'] = syncedCount;
              result['skippedPhotos'] = skippedCount;
              (result['errors'] as List<String>).add('Sincronización cancelada por el usuario');
              return result;
            }

            currentPhoto++;
            final photoId = photo['photoId'] ?? 'desconocido';
            
            try {
              // Reportar progreso
              onProgress?.call(currentPhoto, result['totalPhotos'] as int, 'Procesando $clase - $orden ($photoId)');
              
              final syncResult = await _syncSinglePhoto(photo, ordenFolderId);
              
              // Contar según el resultado
              if (syncResult['image'] == true && syncResult['metadata'] == true) {
                syncedCount++; // Se procesó exitosamente (nuevo o existente)
              } else {
                skippedCount++; // Hubo algún error
              }
            } catch (e) {
              (result['errors'] as List<String>).add('Error sincronizando foto $photoId: $e');
            }
          }
        }
      }

      result['success'] = true;
      result['syncedPhotos'] = syncedCount;
      result['skippedPhotos'] = skippedCount;

      result['success'] = true;
      result['syncedPhotos'] = syncedCount;
    } catch (e) {
      (result['errors'] as List<String>).add('Error general: $e');
    }

    return result;
  }

  // Sincronizar fotos de manera selectiva (solo nuevas o nuevas + editadas)
  static Future<Map<String, dynamic>> syncSelectivePhotos({
    required String syncMode, // 'new_only' o 'new_and_updated'
    Function(int current, int total, String fileName)? onProgress,
  }) async {
    // Resetear cancelación al inicio
    _resetCancellation();
    final Map<String, dynamic> result = {
      'success': false,
      'syncedPhotos': 0,
      'totalPhotos': 0,
      'skippedPhotos': 0,
      'errors': <String>[],
    };

    try {
      // Inicializar conexión con Drive
      if (!await initialize()) {
        (result['errors'] as List<String>).add('No se pudo conectar con Google Drive');
        return result;
      }

      // Crear estructura de carpetas
      final rootFolderId = await _createFolderStructure();
      if (rootFolderId == null) {
        (result['errors'] as List<String>).add('No se pudo crear la carpeta raíz en Drive');
        return result;
      }

      // Obtener fotos del usuario según el modo de sincronización
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        (result['errors'] as List<String>).add('Usuario no autenticado');
        return result;
      }

      // Filtrar fotos según el modo
      List<QueryDocumentSnapshot> photosToSync = [];
      
      if (syncMode == 'new_only') {
        // Solo fotos no sincronizadas
        final query = await FirebaseFirestore.instance
            .collection('insect_photos')
            .where('userId', isEqualTo: user.uid)
            .where('syncedAt', isNull: true)
            .get();
        photosToSync = query.docs;
      } else if (syncMode == 'new_and_updated') {
        // Fotos no sincronizadas y fotos editadas después de sincronización
        final allQuery = await FirebaseFirestore.instance
            .collection('insect_photos')
            .where('userId', isEqualTo: user.uid)
            .get();
        
        for (final doc in allQuery.docs) {
          final data = doc.data();
          final syncedAt = data['syncedAt'];
          final lastModifiedAt = data['lastModifiedAt'];
          
          if (syncedAt == null) {
            // Foto no sincronizada
            photosToSync.add(doc);
          } else if (lastModifiedAt != null) {
            // Verificar si fue editada después de la sincronización
            final syncDate = (syncedAt as Timestamp).toDate();
            final modDate = (lastModifiedAt as Timestamp).toDate();
            
            if (modDate.isAfter(syncDate)) {
              // Foto editada después de la sincronización
              photosToSync.add(doc);
            }
          }
        }
      }

      result['totalPhotos'] = photosToSync.length;

      if (photosToSync.isEmpty) {
        result['success'] = true;
        return result;
      }

      // Crear mapa para organizar por clase y orden
      final Map<String, Map<String, List<Map<String, dynamic>>>> organized = {};

      for (final doc in photosToSync) {
        final data = doc.data() as Map<String, dynamic>;
        final clase = _normalizeClassName(data['class'] ?? 'Sin_clasificar');
        final orden = _normalizeOrderName(data['taxonOrder'] ?? 'Sin_clasificar');

        organized.putIfAbsent(clase, () => {});
        organized[clase]!.putIfAbsent(orden, () => []);
        organized[clase]![orden]!.add({
          ...data,
          'photoId': doc.id,
        });
      }

      // Sincronizar cada clase y orden
      int currentPhoto = 0;
      int syncedCount = 0;
      int skippedCount = 0;

      for (final claseEntry in organized.entries) {
        final clase = claseEntry.key;
        final ordenes = claseEntry.value;

        // Crear carpeta de clase
        final claseFolderId = await _getOrCreateFolder(clase, rootFolderId);
        if (claseFolderId == null) {
          (result['errors'] as List<String>).add('Error creando carpeta para clase: $clase');
          continue;
        }

        for (final ordenEntry in ordenes.entries) {
          final orden = ordenEntry.key;
          final photos = ordenEntry.value;

          // Crear carpeta de orden
          final ordenFolderId = await _getOrCreateFolder(orden, claseFolderId);
          if (ordenFolderId == null) {
            (result['errors'] as List<String>).add('Error creando carpeta para orden: $orden');
            continue;
          }

          // Sincronizar cada foto del orden
          for (final photo in photos) {
            // Verificar cancelación antes de procesar cada foto
            if (_isCancelled) {
              result['success'] = false;
              result['syncedPhotos'] = syncedCount;
              result['skippedPhotos'] = skippedCount;
              (result['errors'] as List<String>).add('Sincronización cancelada por el usuario');
              return result;
            }

            currentPhoto++;
            final photoId = photo['photoId'] ?? 'desconocido';
            
            try {
              // Reportar progreso
              onProgress?.call(currentPhoto, result['totalPhotos'] as int, 'Procesando $clase - $orden ($photoId)');
              
              final syncResult = await _syncSinglePhoto(photo, ordenFolderId);
              
              // Contar según el resultado
              if (syncResult['image'] == true && syncResult['metadata'] == true) {
                syncedCount++; // Se procesó exitosamente (nuevo o existente)
              } else {
                skippedCount++; // Hubo algún error
              }
            } catch (e) {
              (result['errors'] as List<String>).add('Error sincronizando foto $photoId: $e');
            }
          }
        }
      }

      result['success'] = true;
      result['syncedPhotos'] = syncedCount;
      result['skippedPhotos'] = skippedCount;

    } catch (e) {
      (result['errors'] as List<String>).add('Error general: $e');
    }

    return result;
  }

  // Actualizar el campo syncedAt en Firestore cuando se sincroniza exitosamente
  static Future<void> _updateSyncedAt(String photoId) async {
    try {
      await FirebaseFirestore.instance
          .collection('insect_photos')
          .doc(photoId)
          .update({'syncedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      print('Error actualizando syncedAt para foto $photoId: $e');
    }
  }

  // Sincronizar una sola foto con sus metadatos
  static Future<Map<String, bool>> _syncSinglePhoto(Map<String, dynamic> photo, String folderId) async {
    final result = {'image': false, 'metadata': false};

    // Descargar imagen
    final imageUrl = photo['imageUrl'] ?? '';
    if (imageUrl.isEmpty) return result;

    final response = await http.get(Uri.parse(imageUrl));
    if (response.statusCode != 200) return result;

    // Generar nombres de archivo
    final baseFileName = _generateFileName(photo);
    final imageFileName = '$baseFileName.jpg';
    final metadataFileName = '${baseFileName}_metadata.txt';

    // Verificar si el registro fue editado después de sincronizado
    bool editedAfterSync = false;
    try {
      final syncedAt = photo['syncedAt'];
      final lastModifiedAt = photo['lastModifiedAt'];
      if (syncedAt != null && lastModifiedAt != null) {
        final syncDate = (syncedAt is DateTime) ? syncedAt : syncedAt.toDate();
        final modDate = (lastModifiedAt is DateTime) ? lastModifiedAt : lastModifiedAt.toDate();
        if (modDate.isAfter(syncDate)) {
          editedAfterSync = true;
        }
      }
    } catch (_) {}

    // Si fue editado después de sincronizado, eliminar archivos viejos antes de subir
    if (editedAfterSync) {
      await GoogleDriveService._deleteFileIfExists(imageFileName, folderId);
      await GoogleDriveService._deleteFileIfExists(metadataFileName, folderId);
    }

    // Subir imagen (si no existe o ya fue eliminada)
    result['image'] = await _uploadFileIfNotExists(imageFileName, response.bodyBytes, folderId);

    // Crear y subir metadatos (si no existen o ya fueron eliminados)
    final metadataContent = _createMetadataContent(photo);
    final metadataBytes = Uint8List.fromList(metadataContent.codeUnits);
    result['metadata'] = await _uploadFileIfNotExists(metadataFileName, metadataBytes, folderId);

    // Si ambos archivos se sincronizaron exitosamente, actualizar el campo syncedAt
    if (result['image'] == true && result['metadata'] == true) {
      final photoId = photo['photoId'];
      if (photoId != null) {
        await _updateSyncedAt(photoId);
      }
    }

    return result;
  }

  // Crear contenido de metadatos
  static String _createMetadataContent(Map<String, dynamic> photo) {
    // Formatear coordenadas
    String coordenadas = 'No disponibles';
    if (photo['coords'] != null) {
      final lat = photo['coords']['x'];
      final lon = photo['coords']['y'];
      if (lat != null && lon != null && (lat != 0 || lon != 0)) {
        coordenadas = '${lat.toStringAsFixed(6)}°, ${lon.toStringAsFixed(6)}°';
      }
    }
    
    // Formatear fecha de creación
    String fechaCreacion = 'No disponible';
    try {
      if (photo['uploadedAt'] != null) {
        final date = photo['uploadedAt'];
        final dt = date is DateTime ? date : date.toDate();
        fechaCreacion = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    } catch (_) {}
    
    // Formatear fecha de modificación
    String fechaModificacion = '';
    try {
      if (photo['lastModifiedAt'] != null) {
        final date = photo['lastModifiedAt'];
        final dt = date is DateTime ? date : date.toDate();
        fechaModificacion = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    } catch (_) {}

    return '''
=== METADATOS BIODETECT - GOOGLE DRIVE SYNC ===
Archivo de imagen: ${photo['photoId'] ?? 'No disponible'}.jpg
Fecha de sincronización: ${DateTime.now().toString()}
Tipo de documento: Registro de Identificación

=== INFORMACIÓN TAXONÓMICA ===
Clase: ${photo['class'] ?? 'No especificada'}
Orden: ${photo['taxonOrder'] ?? 'No especificado'}

=== INFORMACIÓN DEL HALLAZGO ===
Hábitat: ${photo['habitat'] ?? 'No especificado'}
Detalles: ${photo['details'] ?? 'Sin detalles'}
Notas: ${photo['notes'] ?? 'Sin notas'}

=== INFORMACIÓN GEOGRÁFICA ===
Coordenadas: $coordenadas

=== FECHAS ===
Fecha de creación: $fechaCreacion${fechaModificacion.isNotEmpty ? '\nÚltima modificación: $fechaModificacion' : ''}

=== INFORMACIÓN DE SINCRONIZACIÓN ===
Sincronizado con Google Drive el: ${DateTime.now().toString()}
Estructura: BioDetect/${_normalizeClassName(photo['class'] ?? 'Sin_clasificar')}/${_normalizeOrderName(photo['taxonOrder'] ?? 'Sin_clasificar')}
''';
  }

  // Normalizar nombre de clase para carpetas
  static String _normalizeClassName(String className) {
    return className
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(' ', '_')
        .replaceAll('-', '_');
  }

  // Normalizar nombre de orden para carpetas
  static String _normalizeOrderName(String orderName) {
    return orderName
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(' ', '_')
        .replaceAll('-', '_');
  }

  // Generar nombre base de archivo para una foto
  static String _generateFileName(Map<String, dynamic> photo) {
    final photoId = photo['photoId'] ?? DateTime.now().millisecondsSinceEpoch.toString();
    final clase = _normalizeClassName(photo['class'] ?? '');
    final orden = _normalizeOrderName(photo['taxonOrder'] ?? '');
    
    if (clase.isNotEmpty && orden.isNotEmpty) {
      return '${clase}_${orden}_$photoId';
    } else {
      return 'registro_$photoId';
    }
  }

  // Eliminar archivo por nombre en una carpeta de Drive
  static Future<void> _deleteFileIfExists(String fileName, String parentFolderId) async {
    if (_driveApi == null) return;
    try {
      final query = "name='$fileName' and '$parentFolderId' in parents and trashed=false";
      final searchResult = await _driveApi!.files.list(q: query);
      if (searchResult.files != null && searchResult.files!.isNotEmpty) {
        for (final file in searchResult.files!) {
          if (file.id != null) {
            await _driveApi!.files.delete(file.id!);
          }
        }
      }
    } catch (e) {
      print('Error eliminando archivo $fileName: $e');
    }
  }

  // Limpiar recursos
  static void dispose() {
    _driveApi = null;
    _rootFolderId = null;
  }
}
