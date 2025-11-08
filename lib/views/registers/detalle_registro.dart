import 'dart:io';
import 'dart:async';
import 'package:biodetect/themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'datos.dart';

class DetalleRegistro extends StatefulWidget {
  final Map<String, dynamic> registro;

  const DetalleRegistro({super.key, required this.registro});

  @override
  State<DetalleRegistro> createState() => _DetalleRegistroState();
}

class _DetalleRegistroState extends State<DetalleRegistro> {
  late Map<String, dynamic> _registro;
  bool _isDeleting = false;
  bool _hasInternet = true;
  Timer? _internetCheckTimer;

  @override
  void initState() {
    super.initState();
    _registro = Map<String, dynamic>.from(widget.registro);
    _checkInternetConnection();
    _startInternetMonitoring();
  }

  @override
  void dispose() {
    _internetCheckTimer?.cancel();
    super.dispose();
  }

  void _startInternetMonitoring() {
    // Verificar conexión cada 3 segundos
    _internetCheckTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        _checkInternetConnection();
      }
    });
  }

  Future<void> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      final hasConnection = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      
      if (mounted && _hasInternet != hasConnection) {
        setState(() {
          _hasInternet = hasConnection;
        });
        
        // Mostrar notificación cuando cambie el estado
        if (hasConnection) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Conexión a internet restaurada'),
              backgroundColor: AppColors.buttonGreen2,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sin conexión a internet'),
              backgroundColor: AppColors.warning,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else if (mounted && _hasInternet != hasConnection) {
        setState(() {
          _hasInternet = hasConnection;
        });
      }
    } catch (_) {
      if (mounted && _hasInternet) {
        setState(() {
          _hasInternet = false;
        });
      }
    }
  }

  Future<void> _refrescarRegistro() async {
    if (!_hasInternet) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Se requiere conexión a internet para refrescar'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    try {
      // Solo refrescar registros online desde Firestore
      final doc = await FirebaseFirestore.instance
          .collection('insect_photos')
          .doc(_registro['photoId'])
          .get(const GetOptions(source: Source.serverAndCache));
      
      if (doc.exists) {
        setState(() {
          _registro = {...doc.data()!, 'photoId': doc.id};
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registro actualizado'),
            backgroundColor: AppColors.buttonGreen2,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('Error al refrescar registro: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al refrescar: $e'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    }
  }

  String _formatCoords(Map<String, dynamic> registro) {
    double? lat, lon;
    
    if (registro['coords'] != null) {
      lat = registro['coords']['x'];
      lon = registro['coords']['y'];
    }
    
    // Verificar la visibilidad de la ubicación
    final locationVisibility = registro['locationVisibility'] ?? 'Privada';
    final isPublic = locationVisibility == 'Pública';
    
    String coordsText;
    if (lat == null || lon == null || (lat == 0 && lon == 0)) {
      coordsText = 'No disponibles';
    } else {
      coordsText = '${lat.toStringAsFixed(6)}°, ${lon.toStringAsFixed(6)}°';
    }
    
    // Agregar información de visibilidad
    final visibilityText = isPublic ? 'Pública' : 'Privada';
    final visibilityIcon = isPublic ? '🌍' : '🔒';
    
    return 'Coordenadas: $coordsText\nVisibilidad: $visibilityIcon $visibilityText';
  }

  String _formatDate(Map<String, dynamic> registro) {
    try {
      String result = '';
      
      // Fecha de creación
      if (registro['uploadedAt'] != null) {
        final date = registro['uploadedAt'];
        final dt = date is DateTime ? date : date.toDate();
        result = 'Creado: ${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      }
      
      // Fecha de modificación (solo si es diferente a la creación)
      if (registro['lastModifiedAt'] != null && registro['uploadedAt'] != null) {
        final modDate = registro['lastModifiedAt'];
        final modDt = modDate is DateTime ? modDate : modDate.toDate();
        
        final createDate = registro['uploadedAt'];
        final createDt = createDate is DateTime ? createDate : createDate.toDate();
        
        // Si la diferencia es mayor a 1 minuto, consideramos que fue editado
        if (modDt.difference(createDt).inMinutes > 1) {
          result += '\nModificado: ${modDt.day.toString().padLeft(2, '0')}/${modDt.month.toString().padLeft(2, '0')}/${modDt.year}';
        }
      } else if (registro['lastModifiedAt'] != null && registro['uploadedAt'] == null) {
        // Fallback si no hay uploadedAt
        final date = registro['lastModifiedAt'];
        final dt = date is DateTime ? date : date.toDate();
        result = 'Fecha: ${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      }
      
      return result.isNotEmpty ? result : 'Fecha: No disponible';
    } catch (_) {
      return 'Fecha: No disponible';
    }
  }

  Future<void> _actualizarActividadUsuario(String userId, String className, String taxonOrder) async {
    if (!_hasInternet) return;

    try {
      final activityRef = FirebaseFirestore.instance.collection('user_activity').doc(userId);

      // Primero obtenemos el documento actual para verificar los conteos
      final docSnapshot = await activityRef.get();

      if (!docSnapshot.exists) {
        print('⚠️ User activity document does not exist for user $userId');
        return;
      }

      final currentData = docSnapshot.data() as Map<String, dynamic>;

      // Obtener conteos actuales
      final currentByTaxon = currentData['speciesIdentified']?['byTaxon'] as Map<String, dynamic>?;
      final currentByClass = currentData['speciesIdentified']?['byClass'] as Map<String, dynamic>?;

      final currentTaxonCount = currentByTaxon?[taxonOrder] ?? 0;
      final currentClassCount = currentByClass?[className] ?? 0;

      // Preparar datos de actualización
      Map<String, dynamic> updateData = {
        'photosUploaded': FieldValue.increment(-1),
        'speciesIdentified.byTaxon.$taxonOrder': FieldValue.increment(-1),
        'speciesIdentified.byClass.$className': FieldValue.increment(-1),
        'lastActivity': FieldValue.serverTimestamp(),
      };

      // Si el conteo del orden llegará a 0, decrementar totalByTaxon
      if (currentTaxonCount <= 1) {
        updateData['speciesIdentified.totalByTaxon'] = FieldValue.increment(-1);
        print('📉 Removing taxon: $taxonOrder (last occurrence)');
      }

      // Si el conteo de la clase llegará a 0, decrementar totalByClass
      if (currentClassCount <= 1) {
        updateData['speciesIdentified.totalByClass'] = FieldValue.increment(-1);
        print('📉 Removing class: $className (last occurrence)');
      }

      // Si este orden llegará a 0, decrementar el contador de taxonomías por clase
      if (currentTaxonCount <= 1) {
        updateData['speciesIdentified.byClassTaxonomy.$className'] = FieldValue.increment(-1);
        print('📉 Removing taxonomy $taxonOrder from class $className');
      }

      await activityRef.update(updateData);

      print('✅ User activity decremented successfully for user $userId');
      print('📊 Decremented - Order: $taxonOrder, Class: $className');

    } catch (error) {
      print('❌ Error decrementing user activity: $error');
      // Aquí puedes manejar el error como prefieras
    }
  }

  Future<void> _eliminarRegistro(BuildContext context) async {
    if (_isDeleting) return;

    setState(() => _isDeleting = true);

    try {
      final photoId = _registro['photoId'];
      final userId = _registro['userId'];
      final taxonOrder = _registro['taxonOrder'] ?? '';
      final classArtropodo = _registro['class'] ?? '';

      if (!_hasInternet) {
        throw Exception('Se requiere conexión a internet para eliminar registros');
      }

      // Eliminar imagen de Storage
      final imageUrl = _registro['imageUrl'];
      if (imageUrl != null && imageUrl.toString().isNotEmpty) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(imageUrl);
          await ref.delete();
        } catch (e) {
          print('Error al eliminar imagen de Storage: $e');
        }
      }

      // Eliminar documento de Firestore
      await FirebaseFirestore.instance.collection('insect_photos').doc(photoId).delete();

      // Actualizar actividad del usuario
      if (userId != null && taxonOrder.isNotEmpty) {
        await _actualizarActividadUsuario(userId, classArtropodo, taxonOrder);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registro eliminado correctamente'),
            backgroundColor: AppColors.buttonGreen2,
          ),
        );
        Navigator.of(context).pop(true);
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  // Método para mostrar imagen en pantalla completa
  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenImageViewer(
          imageUrl: imageUrl,
          registroData: _registro,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  Widget _buildImageWidget() {
    final imageSource = _registro['imageUrl'];

    return CachedNetworkImage(
      imageUrl: imageSource,
      height: 200,
      width: double.infinity,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        height: 200,
        color: AppColors.paleGreen.withValues(alpha: 0.2),
        child: const Center(
          child: CircularProgressIndicator(
            color: AppColors.buttonGreen2,
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.paleGreen.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: AppColors.warning, size: 50),
            SizedBox(height: 8),
            Text(
              'Error al cargar imagen',
              style: TextStyle(color: AppColors.textPaleGreen),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: AppColors.backgroundPrimary,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                color: AppColors.backgroundCard,
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new),
                            color: AppColors.textWhite,
                            onPressed: _isDeleting ? null : () => Navigator.pop(context),
                            iconSize: 28,
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                const Text(
                                  'Detalles del Hallazgo',
                                  style: TextStyle(
                                    color: AppColors.textWhite,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _hasInternet ? AppColors.buttonGreen2 : AppColors.warning,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _hasInternet ? 'En línea' : 'Sin conexión',
                                    style: const TextStyle(
                                      color: AppColors.textBlack,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            color: _hasInternet ? AppColors.textWhite : AppColors.textWhite.withValues(alpha: 0.5),
                            onPressed: (_isDeleting || !_hasInternet) ? null : _refrescarRegistro,
                            iconSize: 24,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      // Imagen
                      GestureDetector(
                        onTap: () => _showFullScreenImage(context, _registro['imageUrl']),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _buildImageWidget(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Detalles
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.paleGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.paleGreen.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow('Clase:', _registro['class'] ?? 'No especificada'),
                            _buildDetailRow('Orden:', _registro['taxonOrder'] ?? 'No especificado'),
                            _buildDetailRow('Hábitat:', _registro['habitat'] ?? 'No especificado'),
                            _buildDetailRow('Detalles:', _registro['details'] ?? 'Sin detalles'),
                            _buildDetailRow('Notas:', _registro['notes'] ?? 'Sin notas'),
                            _buildDetailRow('', _formatCoords(_registro)),
                            _buildDetailRow('', _formatDate(_registro)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Botones de acción
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.edit),
                              label: const Text('Editar'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: (_isDeleting || !_hasInternet) 
                                    ? AppColors.buttonBlue2.withValues(alpha: 0.5) 
                                    : AppColors.buttonBlue2,
                                foregroundColor: (_isDeleting || !_hasInternet) 
                                    ? AppColors.textBlack.withValues(alpha: 0.5) 
                                    : AppColors.textBlack,
                                minimumSize: const Size(0, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: (_isDeleting || !_hasInternet) ? null : () async {
                                Map<String, dynamic> datosParaEdicion = {
                                  'taxonOrder': _registro['taxonOrder'] ?? '',
                                  'class': _registro['class'] ?? '',
                                  'habitat': _registro['habitat'] ?? '',
                                  'details': _registro['details'] ?? '',
                                  'notes': _registro['notes'] ?? '',
                                  'coords': _registro['coords'],
                                };

                                final result = await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => RegDatos(
                                      photoId: _registro['photoId'],
                                      imageUrl: _registro['imageUrl'],
                                      claseArtropodo: _registro['class'] ?? '',
                                      ordenTaxonomico: _registro['taxonOrder'] ?? '',
                                      datosIniciales: datosParaEdicion,
                                    ),
                                  ),
                                );
                                
                                if (result == true) {
                                  await _refrescarRegistro();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: _isDeleting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: AppColors.textBlack,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Icon(Icons.delete),
                              label: Text(_isDeleting ? 'Eliminando...' : 'Eliminar'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: (_isDeleting || !_hasInternet) 
                                    ? AppColors.warning.withValues(alpha: 0.5) 
                                    : AppColors.warning,
                                foregroundColor: (_isDeleting || !_hasInternet) 
                                    ? AppColors.textBlack.withValues(alpha: 0.5) 
                                    : AppColors.textBlack,
                                minimumSize: const Size(0, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: (_isDeleting || !_hasInternet) ? null : () async {
                                final confirmacion = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: AppColors.backgroundCard,
                                    title: const Text(
                                      'Confirmar eliminación',
                                      style: TextStyle(color: AppColors.textWhite),
                                    ),
                                    content: const Text(
                                      '¿Estás seguro de que quieres eliminar este registro?',
                                      style: TextStyle(color: AppColors.textWhite),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(false),
                                        child: const Text(
                                          'Cancelar',
                                          style: TextStyle(color: AppColors.textPaleGreen),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(true),
                                        child: const Text(
                                          'Eliminar',
                                          style: TextStyle(color: AppColors.warning),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                
                                if (confirmacion == true) {
                                  await _eliminarRegistro(context);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      // Mensaje de estado de conexión
                      if (!_hasInternet) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.warning),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.wifi_off, color: AppColors.warning),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Sin conexión a internet. Las funciones de edición y eliminación están deshabilitadas.',
                                  style: TextStyle(
                                    color: AppColors.textWhite,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    if (label.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          value,
          style: const TextStyle(
            color: AppColors.textPaleGreen,
            fontSize: 14,
          ),
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(
                color: AppColors.buttonGreen2,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: AppColors.textWhite,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget para mostrar imagen en pantalla completa
class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final Map<String, dynamic>? registroData;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    this.registroData,
  });

  // Método para descargar la imagen con metadatos usando MediaStore
  Future<void> _downloadImageWithMetadata(BuildContext context) async {
    try {
      // Mostrar indicador de descarga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );

      // Descargar la imagen
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        
        // Generar nombre y estructura de carpetas
        final photoId = registroData?['photoId'] ?? DateTime.now().millisecondsSinceEpoch.toString();
        
        // Obtener datos taxonómicos
        final clase = registroData?['class'] ?? 'Sin_Clasificar';
        final orden = registroData?['taxonOrder'] ?? 'Sin_Orden';
        
        // Limpiar caracteres especiales para nombres de archivo y carpeta
        final claseClean = clase.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
        final ordenClean = orden.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
        
        // Nuevo formato: BioDetect_Orden_photoId
        final fileName = 'BioDetect_${ordenClean}_$photoId';
        
        // Usar MediaStore para guardar imagen y metadatos
        await _saveImageToMediaStore(response.bodyBytes, fileName, claseClean);
        
        // Crear archivo de metadatos si hay información disponible
        if (registroData != null) {
          await _saveMetadataToMediaStore(fileName, registroData!, claseClean);
        }
        
        // Cerrar indicador
        if (context.mounted) Navigator.of(context).pop();
        
        // Mostrar mensaje de éxito
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Imagen: Galería → BioDetect → $claseClean\n'
                          '📄 Metadatos: Documentos → BioDetect → $claseClean'),
              backgroundColor: AppColors.buttonGreen2,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else {
        throw Exception('Error al descargar la imagen (${response.statusCode})');
      }
    } catch (e) {
      // Cerrar indicador de descarga
      if (context.mounted) Navigator.of(context).pop();
      
      // Mostrar mensaje de error
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al descargar la imagen: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Guardar imagen en MediaStore (Android)
  Future<void> _saveImageToMediaStore(Uint8List imageBytes, String fileName, String clase) async {
    const platform = MethodChannel('biodetect/mediastore');
    
    try {
      await platform.invokeMethod('saveImage', {
        'bytes': imageBytes,
        'fileName': '$fileName.jpg',
        'mimeType': 'image/jpeg',
        'collection': 'DCIM/BioDetect/$clase', // Organizado por clase taxonómica
      });
    } catch (e) {
      throw Exception('Error guardando imagen en MediaStore: $e');
    }
  }

  // Guardar metadatos como documento (Android)
  Future<void> _saveMetadataToMediaStore(String fileName, Map<String, dynamic> registro, String clase) async {
    const platform = MethodChannel('biodetect/mediastore');
    
    // Generar contenido de metadatos
    final metadata = _generateMetadataContent(fileName, registro);
    
    try {
      await platform.invokeMethod('saveDocument', {
        'content': metadata,
        'fileName': '${fileName}_metadata.txt',
        'mimeType': 'text/plain',
        'collection': 'Documents/BioDetect/$clase', // Organizado por clase taxonómica
      });
    } catch (e) {
      print('Error guardando metadatos en MediaStore: $e');
      // No lanzar excepción para que la imagen se guarde aunque fallen los metadatos
    }
  }



  // Generar contenido de metadatos
  String _generateMetadataContent(String fileName, Map<String, dynamic> registro) {
    // Formatear coordenadas
    String coordenadas = 'No disponibles';
    final locationVisibility = registro['locationVisibility'] ?? 'Privada';
    
    if (registro['coords'] != null) {
      final lat = registro['coords']['x'];
      final lon = registro['coords']['y'];
      if (lat != null && lon != null && (lat != 0 || lon != 0)) {
        coordenadas = '${lat.toStringAsFixed(6)}°, ${lon.toStringAsFixed(6)}°';
      }
    }
    
    // Formatear fecha de creación
    String fechaCreacion = 'No disponible';
    try {
      if (registro['uploadedAt'] != null) {
        final date = registro['uploadedAt'];
        final dt = date is DateTime ? date : date.toDate();
        fechaCreacion = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    } catch (_) {}
    
    // Formatear fecha de modificación
    String fechaModificacion = '';
    try {
      if (registro['lastModifiedAt'] != null) {
        final date = registro['lastModifiedAt'];
        final dt = date is DateTime ? date : date.toDate();
        fechaModificacion = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    } catch (_) {}
    
    // Formatear fecha de sincronización
    String fechaSincronizacion = 'No sincronizado';
    try {
      if (registro['syncedAt'] != null) {
        final date = registro['syncedAt'];
        final dt = date is DateTime ? date : date.toDate();
        fechaSincronizacion = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    } catch (_) {}
    
    return '''
=== METADATOS DEL REGISTRO BIODETECT ===
Archivo de imagen: $fileName.jpg
Fecha de descarga: ${DateTime.now().toString()}

=== INFORMACIÓN TAXONÓMICA ===
Clase: ${registro['class'] ?? 'No especificada'}
Orden: ${registro['taxonOrder'] ?? 'No especificado'}

=== INFORMACIÓN DEL HALLAZGO ===
Hábitat: ${registro['habitat'] ?? 'No especificado'}
Detalles: ${registro['details'] ?? 'Sin detalles'}
Notas: ${registro['notes'] ?? 'Sin notas'}

=== INFORMACIÓN GEOGRÁFICA ===
Visibilidad de ubicación: $locationVisibility
Coordenadas: $coordenadas

=== FECHAS ===
Fecha de creación: $fechaCreacion${fechaModificacion.isNotEmpty ? '\nÚltima modificación: $fechaModificacion' : ''}

=== SINCRONIZACIÓN ===
Estado: ${registro['syncedAt'] != null ? 'Sincronizado con Google Drive' : 'Sin sincronizar'}
Fecha de sincronización: $fechaSincronizacion
''';
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: () => _downloadImageWithMetadata(context),
            tooltip: 'Descargar imagen con metadatos',
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          scaleEnabled: true,
          minScale: 0.5,
          maxScale: 4.0,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            ),
            errorWidget: (context, url, error) => const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 64,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Error al cargar la imagen',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}