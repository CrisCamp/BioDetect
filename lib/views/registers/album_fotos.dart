import 'dart:io';
import 'dart:async';
import 'package:biodetect/themes.dart';
import 'package:biodetect/views/registers/lista_registros.dart';
import 'package:biodetect/views/registers/captura_foto.dart';
import 'package:biodetect/views/registers/fotos_pendientes.dart';
import 'package:biodetect/views/map/mapa.dart';
import 'package:biodetect/services/google_drive_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AlbumFotos extends StatefulWidget {
  const AlbumFotos({super.key});

  @override
  State<AlbumFotos> createState() => _AlbumFotosState();
}

class _AlbumFotosState extends State<AlbumFotos> {
  Map<String, List<Map<String, dynamic>>> _photoGroups = {};
  bool _isLoading = true;
  bool _hasInternet = true;
  Timer? _connectionCheckTimer; // Timer para verificación de conexión automática
  bool _isSyncing = false; // Estado de sincronización con Drive

  @override
  void initState() {
    super.initState();
    _loadPhotos();
    _checkInternetConnection();
    _startPeriodicConnectionCheck(); // Iniciar verificación automática
  }

  @override
  void dispose() {
    _connectionCheckTimer?.cancel(); // Limpiar Timer al destruir el widget
    super.dispose();
  }

  Future<void> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      setState(() {
        _hasInternet = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      });
    } catch (_) {
      setState(() {
        _hasInternet = false;
      });
    }
  }

  // Verificar si el error es relacionado con la conexión
  bool _isConnectionError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('network') || 
           errorString.contains('connection') || 
           errorString.contains('internet') ||
           errorString.contains('timeout') ||
           errorString.contains('failed host lookup') ||
           errorString.contains('socketexception') ||
           errorString.contains('httpexception') ||
           errorString.contains('clientexception') ||
           errorString.contains('no address associated with hostname') ||
           errorString.contains('unreachable');
  }

  // Verificación periódica de conexión (cada 10 segundos)
  void _startPeriodicConnectionCheck() {
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _checkInternetConnection();
      } else {
        timer.cancel(); // Cancelar si el widget ya no está montado
      }
    });
  }

  Future<void> _loadPhotos() async {
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Usar cache de Firestore (igual que ProfileScreen)
      final query = await FirebaseFirestore.instance
          .collection('insect_photos')
          .where('userId', isEqualTo: user.uid)
          .get(const GetOptions(source: Source.serverAndCache));

      // Agrupar por taxonOrder
      final Map<String, List<Map<String, dynamic>>> photoGroups = {};
      for (final doc in query.docs) {
        final data = doc.data();
        final taxonOrder = data['taxonOrder'] as String? ?? 'Sin clasificar'; // Proteger contra null
        
        photoGroups.putIfAbsent(taxonOrder, () => []);
        photoGroups[taxonOrder]!.add({
          ...data,
          'photoId': doc.id,
          // Asegurar que todos los campos necesarios existan
          'imageUrl': data['imageUrl'] ?? '',
          'taxonOrder': taxonOrder,
          'habitat': data['habitat'] ?? 'No especificado',
          'details': data['details'] ?? 'Sin detalles',
          'notes': data['notes'] ?? 'Sin notas',
          'class': data['class'] ?? 'Sin clasificar',
        });
      }
      
      setState(() {
        _photoGroups = photoGroups;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        // Verificar si es un error de conexión
        String errorMessage;
        
        if (_isConnectionError(e)) {
          // Es un error de conexión
          await _checkInternetConnection(); // Actualizar estado de conexión
          errorMessage = 'Error de conexión. Mostrando datos en caché si están disponibles.';
        } else {
          errorMessage = 'Error al cargar fotos: $e';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: _isConnectionError(e) ? AppColors.warning : AppColors.warning,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Método para sincronizar con Google Drive
  Future<void> _syncWithGoogleDrive() async {
    if (!_hasInternet) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Se requiere conexión a internet para sincronizar con Google Drive'),
          backgroundColor: AppColors.warning,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_photoGroups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay fotos para sincronizar'),
          backgroundColor: AppColors.warning,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Analizar estado de sincronización
    final syncAnalysis = _analyzeSyncStatus();
    
    // Si no hay registros sincronizados, sincronizar todo directamente
    if (syncAnalysis['syncedCount'] == 0) {
      await _performFullSync();
      return;
    }

    // Mostrar opciones de sincronización
    await _showSyncOptionsDialog(syncAnalysis);
  }

  // Método para analizar el estado de sincronización
  Map<String, int> _analyzeSyncStatus() {
    int totalPhotos = 0;
    int syncedPhotos = 0;
    int unsyncedPhotos = 0;
    int outdatedPhotos = 0;

    for (final photos in _photoGroups.values) {
      for (final photo in photos) {
        totalPhotos++;
        final syncedAt = photo['syncedAt'];
        final lastModifiedAt = photo['lastModifiedAt'];

        if (syncedAt == null) {
          unsyncedPhotos++;
        } else {
          syncedPhotos++;
          
          // Verificar si fue editado después de la sincronización
          if (lastModifiedAt != null) {
            final syncDate = (syncedAt as Timestamp).toDate();
            final modDate = (lastModifiedAt as Timestamp).toDate();
            
            if (modDate.isAfter(syncDate)) {
              outdatedPhotos++;
            }
          }
        }
      }
    }

    return {
      'totalCount': totalPhotos,
      'syncedCount': syncedPhotos,
      'unsyncedCount': unsyncedPhotos,
      'outdatedCount': outdatedPhotos,
    };
  }

  // Método para mostrar opciones de sincronización
  Future<void> _showSyncOptionsDialog(Map<String, int> syncAnalysis) async {
    final totalPhotos = syncAnalysis['totalCount']!;
    final syncedPhotos = syncAnalysis['syncedCount']!;
    final unsyncedPhotos = syncAnalysis['unsyncedCount']!;
    final outdatedPhotos = syncAnalysis['outdatedCount']!;

    final syncOption = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        title: const Text(
          'Opciones de Sincronización',
          style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estado actual:',
              style: const TextStyle(color: AppColors.buttonGreen2, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '• Total de registros: $totalPhotos',
              style: const TextStyle(color: AppColors.textWhite),
            ),
            Text(
              '• Ya sincronizados: $syncedPhotos',
              style: const TextStyle(color: AppColors.buttonGreen2),
            ),
            Text(
              '• Sin sincronizar: $unsyncedPhotos',
              style: const TextStyle(color: AppColors.warning),
            ),
            if (outdatedPhotos > 0)
              Text(
                '• Editados después de sync: $outdatedPhotos',
                style: const TextStyle(color: AppColors.warning),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textPaleGreen),
            ),
          ),
          if (unsyncedPhotos > 0)
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop('new_only'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.buttonGreen2,
                foregroundColor: AppColors.textBlack,
              ),
              child: Text('Solo nuevos ($unsyncedPhotos)'),
            ),
          if (outdatedPhotos > 0)
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop('new_and_updated'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.paleGreen,
                foregroundColor: AppColors.textBlack,
              ),
              child: Text('Nuevos + Editados (${unsyncedPhotos + outdatedPhotos})'),
            ),
        ],
      ),
    );

    if (syncOption == null) return;

    // Ejecutar sincronización según la opción seleccionada
    if (syncOption == 'new_only') {
      await _performSelectiveSync(false); // Solo nuevos
    } else if (syncOption == 'new_and_updated') {
      await _performSelectiveSync(true); // Nuevos y editados
    }
  }

  // Método para sincronización completa (cuando no hay registros previos)
  Future<void> _performFullSync() async {
    // Contar total de fotos
    int totalPhotos = 0;
    for (final photos in _photoGroups.values) {
      totalPhotos += photos.length;
    }

    // Mostrar diálogo de confirmación
    final shouldSync = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        title: const Text(
          'Sincronizar con Google Drive',
          style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Se van a sincronizar $totalPhotos fotos con sus metadatos a Google Drive.',
              style: const TextStyle(color: AppColors.textWhite),
            ),
            const SizedBox(height: 12),
            const Text(
              'Estructura que se creará:',
              style: TextStyle(color: AppColors.buttonGreen2, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '📁 BioDetect/\n  📁 Insecta/\n    📁 [Órdenes encontrados]\n  📁 Arachnida/\n    📁 [Órdenes encontrados]',
              style: TextStyle(
                color: AppColors.textPaleGreen,
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '⚠️ Este proceso puede tardar varios minutos dependiendo de la cantidad de fotos.',
              style: TextStyle(color: AppColors.warning, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textPaleGreen),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.buttonGreen2,
              foregroundColor: AppColors.textBlack,
            ),
            child: const Text('Sincronizar'),
          ),
        ],
      ),
    );

    if (shouldSync != true) return;

    await _executeSync(null); // null significa sincronizar todo
  }

  // Método para sincronización selectiva
  Future<void> _performSelectiveSync(bool includeUpdated) async {
    final syncAnalysis = _analyzeSyncStatus();
    final unsyncedPhotos = syncAnalysis['unsyncedCount']!;
    final outdatedPhotos = syncAnalysis['outdatedCount']!;
    final totalToSync = includeUpdated ? (unsyncedPhotos + outdatedPhotos) : unsyncedPhotos;

    final shouldSync = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        title: Text(
          includeUpdated ? 'Sincronizar Nuevos y Editados' : 'Sincronizar Solo Nuevos',
          style: const TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Se van a sincronizar $totalToSync registros:',
              style: const TextStyle(color: AppColors.textWhite),
            ),
            const SizedBox(height: 8),
            if (unsyncedPhotos > 0)
              Text(
                '• $unsyncedPhotos registros nuevos',
                style: const TextStyle(color: AppColors.buttonGreen2),
              ),
            if (includeUpdated && outdatedPhotos > 0)
              Text(
                '• $outdatedPhotos registros editados',
                style: const TextStyle(color: AppColors.warning),
              ),
            const SizedBox(height: 12),
            const Text(
              '⚠️ Los registros editados reemplazarán los archivos existentes en Google Drive.',
              style: TextStyle(color: AppColors.warning, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textPaleGreen),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.buttonGreen2,
              foregroundColor: AppColors.textBlack,
            ),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    if (shouldSync != true) return;

    await _executeSync(includeUpdated ? 'new_and_updated' : 'new_only');
  }

  // Método para ejecutar la sincronización con diálogo cancelable
  Future<void> _executeSync(String? syncMode) async {
    setState(() => _isSyncing = true);

    bool syncCancelled = false;

    // Variables para el progreso que se actualizarán
    ValueNotifier<int> currentProgress = ValueNotifier(0);
    ValueNotifier<int> totalProgress = ValueNotifier(0);
    ValueNotifier<String> currentFileName = ValueNotifier('Iniciando...');

    try {
      // Calcular total según el modo
      if (syncMode == null) {
        // Sincronizar todo
        int total = 0;
        for (final photos in _photoGroups.values) {
          total += photos.length;
        }
        totalProgress.value = total;
      } else {
        final syncAnalysis = _analyzeSyncStatus();
        if (syncMode == 'new_only') {
          totalProgress.value = syncAnalysis['unsyncedCount']!;
        } else if (syncMode == 'new_and_updated') {
          totalProgress.value = syncAnalysis['unsyncedCount']! + syncAnalysis['outdatedCount']!;
        }
      }

      // Mostrar diálogo de progreso cancelable
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: AppColors.backgroundCard,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<int>(
                  valueListenable: currentProgress,
                  builder: (context, current, _) => ValueListenableBuilder<int>(
                    valueListenable: totalProgress,
                    builder: (context, total, _) => CircularProgressIndicator(
                      color: AppColors.buttonGreen2,
                      value: total > 0 ? current / total : null,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sincronizando con Google Drive...',
                  style: TextStyle(color: AppColors.textWhite, fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ValueListenableBuilder<int>(
                  valueListenable: currentProgress,
                  builder: (context, current, _) => ValueListenableBuilder<int>(
                    valueListenable: totalProgress,
                    builder: (context, total, _) => Text(
                      '$current de $total fotos',
                      style: const TextStyle(
                        color: AppColors.buttonGreen2,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<String>(
                  valueListenable: currentFileName,
                  builder: (context, fileName, _) => Text(
                    fileName,
                    style: const TextStyle(
                      color: AppColors.textPaleGreen,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Cancelar a través del servicio
                    GoogleDriveService.cancelSync();
                    syncCancelled = true;
                    
                    // Cerrar diálogo inmediatamente
                    Navigator.of(context).pop();
                    
                    // Mostrar mensaje inmediatamente
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Sincronización cancelada por el usuario'),
                          backgroundColor: AppColors.warning,
                          duration: Duration(seconds: 3),
                        ),
                      );
                      
                      // Resetear estado inmediatamente
                      setState(() => _isSyncing = false);
                      
                      // Asegurar que se resetee después de un pequeño delay
                      Future.delayed(const Duration(milliseconds: 500), () {
                        if (mounted) {
                          setState(() => _isSyncing = false);
                        }
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: AppColors.textBlack,
                  ),
                  child: const Text('Cancelar Sincronización'),
                ),
              ],
            ),
          ),
        ),
      );

      // Ejecutar sincronización
      Map<String, dynamic>? result;
      
      try {
        if (syncMode == null) {
          // Sincronización completa
          result = await GoogleDriveService.syncAllPhotos(
            onProgress: (current, total, fileName) {
              if (syncCancelled) return;
              currentProgress.value = current;
              totalProgress.value = total;
              currentFileName.value = fileName;
            },
          ).timeout(
            const Duration(minutes: 30),
            onTimeout: () {
              GoogleDriveService.cancelSync();
              return {
                'success': false,
                'errors': ['Timeout: La sincronización excedió el tiempo límite'],
                'syncedPhotos': 0,
                'totalPhotos': 0,
                'skippedPhotos': 0,
              };
            },
          );
        } else {
          // Sincronización selectiva
          result = await GoogleDriveService.syncSelectivePhotos(
            syncMode: syncMode,
            onProgress: (current, total, fileName) {
              if (syncCancelled) return;
              currentProgress.value = current;
              totalProgress.value = total;
              currentFileName.value = fileName;
            },
          ).timeout(
            const Duration(minutes: 30),
            onTimeout: () {
              GoogleDriveService.cancelSync();
              return {
                'success': false,
                'errors': ['Timeout: La sincronización excedió el tiempo límite'],
                'syncedPhotos': 0,
                'totalPhotos': 0,
                'skippedPhotos': 0,
              };
            },
          );
        }
      } catch (e) {
        // Si hay error, cerrar diálogo si está abierto
        if (mounted) {
          try {
            Navigator.of(context, rootNavigator: true).pop();
          } catch (_) {}
        }
        rethrow;
      }

      // Manejo del resultado después de la sincronización
      if (mounted && !syncCancelled) {
        // Cerrar diálogo de progreso
        try {
          Navigator.of(context).pop();
        } catch (_) {
          // El diálogo ya fue cerrado
        }
        
        // Verificar si la sincronización fue cancelada desde el backend
        if (result['errors'] != null && 
            (result['errors'] as List).any((error) => error.contains('cancelada por el usuario'))) {
          // Fue cancelada desde el backend
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sincronización cancelada'),
                backgroundColor: AppColors.warning,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          // Fue exitosa
          _showSyncResult(result);
        }
      }
    } catch (e) {
      // Cerrar diálogo de progreso si está abierto
      if (mounted) {
        try {
          Navigator.of(context).pop();
        } catch (_) {}
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error inesperado: $e'),
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      // Asegurar que cualquier diálogo modal esté cerrado
      if (mounted) {
        try {
          // Solo cerrar si hay un diálogo modal activo
          if (ModalRoute.of(context)?.isCurrent == false) {
            Navigator.of(context).pop();
          }
        } catch (_) {
          // No hay diálogos que cerrar
        }
      }
      
      // Limpiar recursos
      try {
        currentProgress.dispose();
        totalProgress.dispose();
        currentFileName.dispose();
      } catch (_) {
        // Los ValueNotifiers ya fueron disposed
      }
      
      // Resetear estado de sincronización
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  // Método para mostrar el resultado de la sincronización
  void _showSyncResult(Map<String, dynamic> result) {
    if (result['success'] == true) {
      final syncedPhotos = result['syncedPhotos'] ?? 0;
      final skippedPhotos = result['skippedPhotos'] ?? 0;
      final totalPhotos = result['totalPhotos'] ?? 0;
      
      String message = 'Sincronización completada: $syncedPhotos de $totalPhotos fotos procesadas';
      // if (skippedPhotos > 0) {
      //   message += ' ($skippedPhotos ya existían)';
      // }
      
      // Recargar los datos para actualizar los indicadores de sync
      _loadPhotos();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.buttonGreen2,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Ver estructura',
            textColor: AppColors.textWhite,
            onPressed: () {
              _showSyncStructureDialog();
            },
          ),
        ),
      );
    } else {
      final errors = result['errors'] as List<String>? ?? [];
      final errorMessage = errors.isNotEmpty 
          ? errors.first 
          : 'Error desconocido al sincronizar';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error en sincronización: $errorMessage'),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // Mostrar diálogo con la estructura de Drive
  void _showSyncStructureDialog() {
    final classes = <String>{};
    final orders = <String, Set<String>>{};

    // Analizar estructura de datos
    for (final photos in _photoGroups.values) {
      for (final photo in photos) {
        final clase = photo['class'] ?? 'Sin clasificar';
        final orden = photo['taxonOrder'] ?? 'Sin clasificar';
        
        classes.add(clase);
        orders.putIfAbsent(clase, () => <String>{});
        orders[clase]!.add(orden);
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        title: const Text(
          'Estructura en Google Drive',
          style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BioDetect/',
                style: TextStyle(
                  color: AppColors.buttonGreen2,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              ...classes.map((clase) => Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '├── $clase/',
                      style: TextStyle(
                        color: AppColors.buttonBlue2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    ...orders[clase]!.map((orden) => Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: Text(
                        '├── $orden/',
                        style: TextStyle(color: AppColors.textPaleGreen),
                      ),
                    )),
                  ],
                ),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cerrar',
              style: TextStyle(color: AppColors.buttonGreen2),
            ),
          ),
        ],
      ),
    );
  }

  // Método para construir el indicador de sincronización
  Widget _buildSyncIndicator(List<Map<String, dynamic>> photos) {
    // Verificar el estado de sincronización del grupo
    final syncedCount = photos.where((photo) => photo['syncedAt'] != null).length;
    final totalCount = photos.length;
    
    if (syncedCount == totalCount) {
      // Todas las fotos están sincronizadas
      return Column(
        children: [
          const Icon(
            Icons.cloud_done,
            color: AppColors.buttonGreen2,
            size: 20,
          ),
          const SizedBox(height: 2),
          Text(
            'Sync',
            style: const TextStyle(
              color: AppColors.buttonGreen2,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    } else if (syncedCount > 0) {
      // Algunas fotos están sincronizadas
      return Column(
        children: [
          const Icon(
            Icons.cloud_sync,
            color: AppColors.warning,
            size: 20,
          ),
          const SizedBox(height: 2),
          Text(
            '$syncedCount/$totalCount',
            style: const TextStyle(
              color: AppColors.warning,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    } else {
      // Ninguna foto está sincronizada
      return Column(
        children: [
          const Icon(
            Icons.cloud_off,
            color: AppColors.textPaleGreen,
            size: 20,
          ),
          const SizedBox(height: 2),
          Text(
            'No sync',
            style: const TextStyle(
              color: AppColors.textPaleGreen,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }
  }

  Widget _buildPhotoTile(String taxonOrder, List<Map<String, dynamic>> photos) {
    final firstPhoto = photos.first;
    final imageSource = firstPhoto['imageUrl'] ?? '';

    return Card(
      color: AppColors.backgroundCard,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ListaRegistros(
                taxonOrder: taxonOrder,
                registros: photos,
              ),
            ),
          ).then((_) => _loadPhotos());
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Imagen de vista previa
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: imageSource.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageSource,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: AppColors.paleGreen.withValues(alpha: 0.3),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.buttonGreen2,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: AppColors.paleGreen.withValues(alpha: 0.3),
                            child: const Icon(
                              Icons.error_outline,
                              color: AppColors.warning,
                              size: 30,
                            ),
                          ),
                        )
                      : Container(
                          color: AppColors.paleGreen.withValues(alpha: 0.3),
                          child: const Icon(
                            Icons.image_not_supported,
                            color: AppColors.textPaleGreen,
                            size: 30,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              // Información del taxon
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      taxonOrder,
                      style: const TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${photos.length} ${photos.length == 1 ? 'registro' : 'registros'}',
                      style: const TextStyle(
                        color: AppColors.textPaleGreen,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              // Indicador de sincronización
              _buildSyncIndicator(photos),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios,
                color: AppColors.textPaleGreen,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: AppColors.backgroundPrimary, // Cambiar de gradiente a color sólido
        child: SafeArea(
          child: Column(
            children: [
              // Header con indicador de conexión
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Mis hallazgos', // EL TEXTO ORIGINAL NO CAMBIA
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    
                    // Indicador de conexión y accesos rápidos
                    Row(
                      children: [
                        // Indicador de conexión
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _hasInternet ? AppColors.buttonGreen2 : AppColors.warning,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _hasInternet ? Icons.wifi : Icons.wifi_off,
                                size: 16,
                                color: AppColors.textBlack,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _hasInternet ? 'Conectado' : 'Sin conexión',
                                style: const TextStyle(
                                  color: AppColors.textBlack,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        
                        // Botón de sincronización con Google Drive
                        IconButton(
                          icon: _isSyncing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: AppColors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.cloud_sync),
                          color: AppColors.white,
                          tooltip: 'Sincronizar con Google Drive\n(Organiza por clase y orden taxonómico)',
                          onPressed: _isSyncing ? null : _syncWithGoogleDrive,
                        ),
                        
                        // Botones de acceso rápido
                        IconButton(
                          icon: const Icon(Icons.camera_alt_outlined),
                          color: AppColors.white,
                          tooltip: 'Capturar Foto',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const CapturaFoto()),
                            ).then((_) {
                              _loadPhotos();
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.location_on_outlined),
                          color: AppColors.white,
                          tooltip: 'Ver mapa',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const MapaIterativoScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Lista de taxones
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.buttonGreen2,
                        ),
                      )
                    : _photoGroups.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: AppColors.buttonGreen2.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_outlined,
                                      size: 80,
                                      color: AppColors.buttonGreen2,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  const Text(
                                    '¡Bienvenido a BioDetect!',
                                    style: TextStyle(
                                      color: AppColors.textWhite,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Comienza tu aventura capturando tu primera fotografía de un artrópodo',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.textPaleGreen,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppColors.backgroundCard.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Column(
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.camera_alt, color: AppColors.buttonGreen2, size: 20),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Toca el botón "Capturar" para empezar',
                                                style: TextStyle(color: AppColors.textWhite, fontSize: 14),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.psychology, color: AppColors.buttonBlue2, size: 20),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Nuestra IA identificará automáticamente la clase y el orden taxonómico',
                                                style: TextStyle(color: AppColors.textWhite, fontSize: 14),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.collections, color: AppColors.buttonBrown1, size: 20),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Construye tu colección personal de descubrimientos',
                                                style: TextStyle(color: AppColors.textWhite, fontSize: 14),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _photoGroups.length,
                            itemBuilder: (context, index) {
                              final entry = _photoGroups.entries.toList()[index];
                              return _buildPhotoTile(entry.key, entry.value);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}