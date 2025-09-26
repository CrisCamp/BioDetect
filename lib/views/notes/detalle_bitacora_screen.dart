import 'dart:io';
import 'package:biodetect/themes.dart';
import 'package:biodetect/services/bitacora_service.dart';
import 'package:biodetect/services/pdf_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class DetalleBitacoraScreen extends StatefulWidget {
  final Map<String, dynamic> bitacoraData;

  const DetalleBitacoraScreen({
    super.key,
    required this.bitacoraData,
  });

  @override
  State<DetalleBitacoraScreen> createState() => _DetalleBitacoraScreenState();
}

class _DetalleBitacoraScreenState extends State<DetalleBitacoraScreen> {
  List<Map<String, dynamic>> _registros = [];
  bool _isLoading = true;
  bool _isGeneratingPdf = false;
  bool _isSharing = false;
  String _authorName = 'Usuario';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Cargar registros
      final selectedPhotos = widget.bitacoraData['selectedPhotos'] as List<dynamic>? ?? [];
      final photoIds = selectedPhotos.cast<String>();
      
      // Obtener el nombre del autor desde los datos de la bitácora
      _authorName = widget.bitacoraData['authorName'] ?? 'Usuario desconocido';
      
      // Cargar registros
      if (photoIds.isNotEmpty) {
        final registros = await BitacoraService.getPhotosByIds(photoIds);
        setState(() {
          _registros = registros;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos: $e'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Sin fecha';
    
    try {
      final dt = date is DateTime ? date : date.toDate();
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (e) {
      return 'Sin fecha';
    }
  }



  Future<void> _generarPdf() async {
    if (_registros.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay registros para generar el PDF'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isGeneratingPdf = true);

    try {
      final titulo = widget.bitacoraData['title'] ?? 'Sin título';
      final fileName = 'Bitacora_${titulo.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}';
      
      final pdfBytes = await PdfService.generateBitacoraPdf(
        bitacoraData: widget.bitacoraData,
        registros: _registros,
        authorName: _authorName,
      );

      // Guardar directamente el PDF en el dispositivo
      final savedPath = await PdfService.saveDirectlyToPdf(pdfBytes, fileName);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF guardado exitosamente en: $savedPath'),
            backgroundColor: AppColors.buttonGreen2,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Entendido',
              textColor: AppColors.textBlack,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar PDF: $e'),
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      setState(() => _isGeneratingPdf = false);
    }
  }

  Future<void> _compartirBitacora() async {
    if (_registros.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay registros para compartir'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSharing = true);

    try {
      final titulo = widget.bitacoraData['title'] ?? 'Sin título';
      final fileName = 'Bitacora_${titulo.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}';
      
      final pdfBytes = await PdfService.generateBitacoraPdf(
        bitacoraData: widget.bitacoraData,
        registros: _registros,
        authorName: _authorName,
      );

      await PdfService.sharePdf(pdfBytes, fileName);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al compartir PDF: $e'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } finally {
      setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titulo = widget.bitacoraData['title'] ?? 'Sin título';
    final descripcion = widget.bitacoraData['description'] ?? 'Sin descripción';
    final fechaCreacion = _formatDate(widget.bitacoraData['createdAt']);
    final isPublic = widget.bitacoraData['isPublic'] ?? false;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary, // Cambiar de AppColors.deepGreen
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Botón de guardar directo
          FloatingActionButton(
            backgroundColor: AppColors.buttonBlue1,
            foregroundColor: AppColors.textWhite,
            heroTag: "save_pdf",
            onPressed: (_isGeneratingPdf || _isSharing) ? null : _generarPdf,
            tooltip: _isGeneratingPdf ? 'Guardando...' : 'Guardar PDF',
            child: _isGeneratingPdf 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: AppColors.textWhite,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.save),
          ),
          const SizedBox(width: 16),
          // Botón de compartir
          FloatingActionButton(
            backgroundColor: AppColors.buttonGreen1,
            foregroundColor: AppColors.textWhite,
            heroTag: "share_pdf",
            onPressed: (_isGeneratingPdf || _isSharing) ? null : _compartirBitacora,
            tooltip: _isSharing ? 'Compartiendo...' : 'Compartir PDF',
            child: _isSharing 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: AppColors.textWhite,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.share),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: AppColors.backgroundPrimary, // Cambiar de decoration con backgroundColor
        child: Stack(
          children: [
            // Contenido principal con padding superior para el header flotante
            Padding(
              padding: const EdgeInsets.only(top: 100), // Espacio para el header flotante
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Información de la bitácora con logo
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.backgroundCard,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Logo de la app centrado
                          Container(
                            width: 80,
                            height: 80,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.buttonGreen2,
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/ic_logo_biodetect.png',
                                width: 60,
                                height: 60,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.menu_book,
                                    size: 40,
                                    color: AppColors.white,
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Título
                          Text(
                            titulo,
                            style: const TextStyle(
                              color: AppColors.textWhite,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          
                          // Autor
                          Text(
                            'Por: $_authorName',
                            style: const TextStyle(
                              color: AppColors.buttonGreen2,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          
                          // Descripción
                          Text(
                            descripcion,
                            style: const TextStyle(
                              color: AppColors.textPaleGreen,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          
                          // Información adicional
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.calendar_today, 
                                   color: AppColors.buttonGreen2, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'Creado: $fechaCreacion',
                                style: const TextStyle(
                                  color: AppColors.textWhite,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.photo_library, 
                                   color: AppColors.buttonGreen2, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                '${_registros.length} registros incluidos',
                                style: const TextStyle(
                                  color: AppColors.textWhite,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Título de registros
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Registros de Identificación',
                        style: TextStyle(
                          color: AppColors.textWhite,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    
                    // Lista de registros
                    if (_isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(
                            color: AppColors.buttonGreen2,
                          ),
                        ),
                      )
                    else if (_registros.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Column(
                            children: [
                              Icon(
                                Icons.photo_library_outlined,
                                size: 64,
                                color: AppColors.textPaleGreen,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No hay registros en esta bitácora',
                                style: TextStyle(
                                  color: AppColors.textPaleGreen,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Column(
                        children: _registros
                            .map((registro) => RegistroDetalleBitacoraCard(registro: registro))
                            .toList(),
                      ),
                  ],
                ),
              ),
            ),
            
            // Header flotante
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.backgroundCard,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top,
                  left: 16,
                  right: 16,
                  bottom: 16,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new),
                      color: AppColors.textWhite,
                      onPressed: (_isGeneratingPdf || _isSharing) ? null : () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Detalles',
                        style: TextStyle(
                          color: AppColors.textWhite,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPublic ? AppColors.buttonGreen2 : AppColors.warning,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPublic ? Icons.public : Icons.lock,
                            size: 14,
                            color: AppColors.textBlack,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isPublic ? 'Pública' : 'Privada',
                            style: const TextStyle(
                              color: AppColors.textBlack,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RegistroDetalleBitacoraCard extends StatelessWidget {
  final Map<String, dynamic> registro;

  const RegistroDetalleBitacoraCard({
    super.key,
    required this.registro,
  });

  // Método para mostrar imagen en pantalla completa
  void _showFullScreenImage(BuildContext context, String imageUrl, Map<String, dynamic> registroData) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenImageViewer(
          imageUrl: imageUrl,
          registroData: registroData,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Sin fecha';
    
    try {
      final dt = date is DateTime ? date : date.toDate();
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (e) {
      return 'Sin fecha';
    }
  }

  String _formatCoords() {
    if (registro['coords'] == null) return 'Sin coordenadas';
    
    final lat = registro['coords']['x'];
    final lon = registro['coords']['y'];
    
    if (lat == null || lon == null || (lat == 0 && lon == 0)) {
      return 'Sin coordenadas';
    }
    
    return '${lat.toStringAsFixed(6)}°, ${lon.toStringAsFixed(6)}°';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.backgroundCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.brownLight2, width: 1),
      ),
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Foto
            GestureDetector(
              onTap: () => _showFullScreenImage(context, registro['imageUrl'] ?? '', registro),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: registro['imageUrl'] ?? '',
                  height: 220, // Agregué la coma que faltaba aquí
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 220,
                    color: AppColors.paleGreen.withValues(alpha: 0.3),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.buttonGreen2,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 220,
                    color: AppColors.paleGreen.withValues(alpha: 0.3),
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
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Información del registro
            _buildInfoRow('Orden:', registro['taxonOrder'] ?? 'No especificado'),
            _buildInfoRow('Clase:', registro['class'] ?? 'No especificada'),
            _buildInfoRow('Hábitat:', registro['habitat'] ?? 'No especificado'),
            _buildInfoRow('Fecha:', _formatDate(registro['lastModifiedAt'])),
            _buildInfoRow('Coordenadas:', _formatCoords()),
            
            if ((registro['details'] ?? '').toString().isNotEmpty) 
              const SizedBox(height: 12),
            if ((registro['details'] ?? '').toString().isNotEmpty) 
              const Text(
                'Detalles:',
                style: TextStyle(
                  color: AppColors.buttonGreen2,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            if ((registro['details'] ?? '').toString().isNotEmpty) 
              const SizedBox(height: 4),
            if ((registro['details'] ?? '').toString().isNotEmpty) 
              Text(
                registro['details'] ?? '',
                style: const TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 14,
                ),
              ),
            
            if ((registro['notes'] ?? '').toString().isNotEmpty) 
              const SizedBox(height: 12),
            if ((registro['notes'] ?? '').toString().isNotEmpty) 
              const Text(
                'Observaciones:',
                style: TextStyle(
                  color: AppColors.buttonGreen2,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            if ((registro['notes'] ?? '').toString().isNotEmpty) 
              const SizedBox(height: 4),
            if ((registro['notes'] ?? '').toString().isNotEmpty) 
              Text(
                registro['notes'] ?? '',
                style: const TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 14,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
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

  // Método para descargar la imagen con metadatos de bitácora
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

      // Solicitar permisos de almacenamiento
      if (await _requestStoragePermission()) {
        
        // Descargar la imagen
        final response = await http.get(Uri.parse(imageUrl));
        if (response.statusCode == 200) {
          
          // Obtener directorio para guardar
          Directory? saveDirectory;
          String displayPath;
          
          if (Platform.isAndroid) {
            // Intentar usar DCIM primero, si falla usar el directorio de la app
            try {
              saveDirectory = Directory('/storage/emulated/0/DCIM/BioDetect_Bitacoras');
              displayPath = 'DCIM/BioDetect_Bitacoras';
            } catch (e) {
              // Si falla, usar directorio de la app
              final appDir = await getExternalStorageDirectory();
              saveDirectory = Directory('${appDir?.path ?? ''}/BioDetect_Bitacoras');
              displayPath = 'BioDetect_Bitacoras';
            }
          } else {
            // En iOS, usar el directorio de documentos de la app
            final appDir = await getApplicationDocumentsDirectory();
            saveDirectory = Directory('${appDir.path}/BioDetect_Bitacoras');
            displayPath = 'BioDetect_Bitacoras';
          }
          
          // Crear el directorio si no existe
          if (!await saveDirectory.exists()) {
            await saveDirectory.create(recursive: true);
          }
          
          // Generar nombre descriptivo con ID de foto
          final photoId = registroData?['photoId'] ?? DateTime.now().millisecondsSinceEpoch.toString();
          
          String fileName = 'bitacora_$photoId';
          
          // Agregar metadatos al nombre del archivo si están disponibles
          if (registroData != null) {
            final clase = registroData!['class'] ?? '';
            final orden = registroData!['taxonOrder'] ?? '';
            
            if (clase.isNotEmpty && orden.isNotEmpty) {
              // Limpiar caracteres especiales para el nombre del archivo
              final claseClean = clase.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
              final ordenClean = orden.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
              fileName = '${claseClean}_${ordenClean}_$fileName';
            }
          }
          
          fileName += '.jpg';
          final filePath = '${saveDirectory.path}/$fileName';
          
          // Guardar la imagen
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);
          
          // Crear archivo de metadatos si hay información disponible
          if (registroData != null) {
            await _createBitacoraMetadataFile(saveDirectory.path, fileName, registroData!);
          }
          
          displayPath = '$displayPath/$fileName';
          
          // Cerrar indicador de descarga
          if (context.mounted) Navigator.of(context).pop();
          
          // Mostrar mensaje de éxito
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Imagen de bitácora y metadatos guardados en: $displayPath'),
                backgroundColor: AppColors.buttonGreen2,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else {
          throw Exception('Error al descargar la imagen');
        }
      } else {
        // Cerrar indicador de descarga
        if (context.mounted) Navigator.of(context).pop();
        
        // Mostrar mensaje de error de permisos
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Se necesitan permisos de almacenamiento para descargar la imagen'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
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

  // Crear archivo de metadatos específico para bitácoras
  Future<void> _createBitacoraMetadataFile(String directoryPath, String imageFileName, Map<String, dynamic> registro) async {
    try {
      final metadataFileName = imageFileName.replaceAll('.jpg', '_metadata.txt');
      final metadataFile = File('$directoryPath/$metadataFileName');
      
      // Formatear coordenadas
      String coordenadas = 'No disponibles';
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
      
      final metadata = '''
=== METADATOS DE BITÁCORA BIODETECT ===
Archivo de imagen: $imageFileName
Fecha de descarga: ${DateTime.now().toString()}
Tipo de documento: Registro de Bitácora

=== INFORMACIÓN TAXONÓMICA ===
Clase: ${registro['class'] ?? 'No especificada'}
Orden: ${registro['taxonOrder'] ?? 'No especificado'}

=== INFORMACIÓN DEL HALLAZGO ===
Hábitat: ${registro['habitat'] ?? 'No especificado'}
Detalles: ${registro['details'] ?? 'Sin detalles'}
Notas: ${registro['notes'] ?? 'Sin notas'}

=== INFORMACIÓN GEOGRÁFICA ===
Coordenadas: $coordenadas

=== FECHAS ===
Fecha de creación: $fechaCreacion${fechaModificacion.isNotEmpty ? '\nÚltima modificación: $fechaModificacion' : ''}

=== SINCRONIZACIÓN ===
Estado: ${registro['syncedAt'] != null ? 'Sincronizado con Google Drive' : 'Sin sincronizar'}
Fecha de sincronización: $fechaSincronizacion

=== INFORMACIÓN DE BITÁCORA ===
Parte de una bitácora de investigación de biodiversidad
Documento científico con fines de estudio y conservación
''';
      
      await metadataFile.writeAsString(metadata);
    } catch (e) {
      print('Error creando archivo de metadatos de bitácora: $e');
    }
  }

  // Solicitar permisos de almacenamiento
  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      // Verificar permisos según la versión de Android
      PermissionStatus status;
      
      // Para Android 11+ (API 30+)
      if (await Permission.manageExternalStorage.isRestricted == false) {
        status = await Permission.manageExternalStorage.status;
        if (!status.isGranted) {
          status = await Permission.manageExternalStorage.request();
        }
      } else {
        // Para Android 10 y versiones anteriores
        status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }
      }
      
      return status.isGranted;
    } else {
      // En iOS, generalmente no necesitamos permisos adicionales para el directorio de la app
      return true;
    }
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
            tooltip: 'Descargar imagen con metadatos de bitácora',
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