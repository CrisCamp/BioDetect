import 'dart:io';
import 'dart:async';
import 'package:biodetect/themes.dart';
import 'package:biodetect/services/pending_photos_service.dart';
import 'package:biodetect/services/ai_service.dart';
import 'package:biodetect/views/registers/datos.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FotosPendientes extends StatefulWidget {
  const FotosPendientes({super.key});

  @override
  State<FotosPendientes> createState() => _FotosPendientesState();
}

class _FotosPendientesState extends State<FotosPendientes> {
  List<Map<String, dynamic>> _pendingPhotos = [];
  bool _isLoading = true;
  bool _hasInternet = false;
  final Set<String> _processingPhotos = {};
  Timer? _connectionCheckTimer; // Timer para verificación de conexión automática

  @override
  void initState() {
    super.initState();
    _loadPendingPhotos();
    _checkInternetConnection();
    _startPeriodicConnectionCheck(); // Iniciar verificación de conexión automática
  }

  // Reemplazar la función de SyncService por una local
  Future<void> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('dns.google');
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
      _checkInternetConnection();
    });
  }

  Future<void> _loadPendingPhotos() async {
    setState(() => _isLoading = true);
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final photos = await PendingPhotosService.getPendingPhotos(user.uid);
      setState(() {
        _pendingPhotos = photos;
      });
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _clasificarFoto(Map<String, dynamic> photo) async {
    // Verificación inicial de conexión
    if (!_hasInternet) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Se requiere conexión a internet para analizar la foto.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final photoId = photo['id'] as String;
    if (_processingPhotos.contains(photoId)) return;

    setState(() {
      _processingPhotos.add(photoId);
    });

    try {
      // Verificación adicional de conexión justo antes del procesamiento
      await _checkInternetConnection();
      
      // Si perdimos la conexión después de la verificación inicial
      if (!_hasInternet) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Se perdió la conexión a internet. Inténtalo de nuevo cuando tengas conexión.'),
            backgroundColor: AppColors.warning,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      final imageFile = File(photo['localImagePath']);
      if (!await imageFile.exists()) {
        throw Exception('Archivo de imagen no encontrado');
      }

      final response = await AIService.analyzeImage(imageFile);
      
      final String clasificacion = response['predicted_class'];
      final double confianza = response['confidence'];

      final List<String> taxonomia = clasificacion.split('-');
      final claseArtropodo = taxonomia[0];
      final ordenTaxonomico = taxonomia[1];

      if (mounted) {
        if (confianza >= 0.75) {

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Clasificación: $claseArtropodo - $ordenTaxonomico\nConfianza: ${(confianza * 100).toStringAsFixed(2)}%'),
              backgroundColor: AppColors.buttonGreen2,
              duration: const Duration(seconds: 2),
            ),
          );

          await Future.delayed(const Duration(milliseconds: 500));

          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RegDatos(
                imageFile: imageFile,
                claseArtropodo: claseArtropodo,
                ordenTaxonomico: ordenTaxonomico,
                coordenadas: photo['latitude'] != null && photo['longitude'] != null
                    ? {'x': photo['latitude'], 'y': photo['longitude']}
                    : null,
              ),
            ),
          );

          if (result == 'saved') {
            await PendingPhotosService.markAsClassified(photoId);
            await _loadPendingPhotos();
          }
        } else {
          await _mostrarOpcionesBajaConfianza(photo, claseArtropodo, ordenTaxonomico, confianza);
        }
      }
    } catch (e) {
      if (mounted) {
        // Verificar si es un error de conexión
        String errorMessage;
        
        if (_isConnectionError(e)) {
          // Es un error de conexión
          await _checkInternetConnection(); // Actualizar estado de conexión
          errorMessage = 'Error de conexión. Verifica tu conexión a internet e inténtalo de nuevo.';
        } else {
          errorMessage = 'Error al analizar: $e';
        }
        
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingPhotos.remove(photoId);
        });
      }
    }
  }

  Future<void> _mostrarOpcionesBajaConfianza(
    Map<String, dynamic> photo, 
    String claseArtropodo,
    String ordenTaxonomico,
    double confianza
  ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.textPaleGreen,
          title: const Text(
            'Confianza Insuficiente',
            style: TextStyle(color: AppColors.black),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'El nivel de confianza es insuficiente para una clasificación automática.',
                style: TextStyle(color: AppColors.textGraphite),
              ),
              const SizedBox(height: 5),
              RichText(
                text: TextSpan(
                  style: const TextStyle(color: AppColors.textGraphite),
                  children: [
                    const TextSpan(
                      text: 'Clase: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: claseArtropodo,
                    ),
                    const TextSpan(
                      text: '\nOrden: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: ordenTaxonomico,
                    ),
                    const TextSpan(
                      text: '\nConfianza: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: '${(confianza * 100).toStringAsFixed(2)}%',
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'Ingresar manualmente',
                style: TextStyle(color: AppColors.blueDark),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _procederConClasificacion(photo, claseArtropodo, ordenTaxonomico);
              },
            ),
            TextButton(
              child: const Text(
                'Enviar para revisión',
                style: TextStyle(color: AppColors.darkTeal),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _enviarRevision(photo);
              },
            ),
            TextButton(
              child: const Text(
                'Eliminar foto',
                style: TextStyle(color: AppColors.warningDark),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _eliminarFoto(photo);
              },
            ),
            TextButton(
              child: const Text(
                'Cancelar',
                style: TextStyle(color: AppColors.black),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _procederConClasificacion(Map<String, dynamic> photo, String claseArtropodo, String ordenTaxonomico) async {
    try {
      final imageFile = File(photo['localImagePath']);
      
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RegDatos(
            imageFile: imageFile,
            claseArtropodo: claseArtropodo,
            ordenTaxonomico: ordenTaxonomico,
            coordenadas: photo['latitude'] != null && photo['longitude'] != null
                ? {'x': photo['latitude'], 'y': photo['longitude']}
                : null,
          ),
        ),
      );

      if (result == 'saved') {
        await PendingPhotosService.markAsClassified(photo['id']);
        await _loadPendingPhotos();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    }
  }

  Future<void> _enviarRevision(Map<String, dynamic> photo) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final imageFile = File(photo['localImagePath']);

    try {
      //setState(() => _isProcessing = true);

      final photoId = FirebaseFirestore.instance.collection('unidentified').doc().id;

      final ref = FirebaseStorage.instance.ref().child('unidentified/${user.uid}/$photoId.jpg');
      await ref.putFile(imageFile);
      final imageUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('unidentified').doc(photoId).set({
        'userId': user.uid,
        'imageUrl': imageUrl,
        'uploadedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'coords': {'x': photo['latitude'], 'y': photo['longitude']}
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto enviada para revisión. Gracias por su apoyo.'),
            backgroundColor: AppColors.buttonGreen2,
          ),
        );

        await PendingPhotosService.markAsClassified(photo['id']);
        await _loadPendingPhotos();

        //setState(() {
        //  _image = null;
        //});
      }
    } catch (e) {
      if (mounted) {
        // Verificar si es un error de conexión
        String errorMessage;
        
        if (_isConnectionError(e)) {
          // Es un error de conexión
          await _checkInternetConnection(); // Actualizar estado de conexión
          errorMessage = 'Error de conexión. Verifica tu conexión a internet e inténtalo de nuevo.';
        } else {
          errorMessage = 'Error al enviar: $e';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _eliminarFoto(Map<String, dynamic> photo) async {
    try {
      await PendingPhotosService.deletePendingPhoto(photo['id']);
      await _loadPendingPhotos();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto eliminada'),
            backgroundColor: AppColors.buttonGreen2,
          ),
        );
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
    }
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  String _formatCoordinates(double? lat, double? lon) {
    if (lat == null || lon == null) return 'Sin ubicación';
    return '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: AppColors.backgroundPrimary,
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new),
                      color: AppColors.textWhite,
                      onPressed: () => Navigator.pop(context),
                      iconSize: 28,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            'Fotos Pendientes',
                            style: TextStyle(
                              color: AppColors.textWhite,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          // Indicador de conexión
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _hasInternet ? AppColors.buttonGreen2 : AppColors.warning,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _hasInternet ? Icons.wifi : Icons.wifi_off,
                                  color: AppColors.textBlack,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _hasInternet ? 'En línea' : 'Sin conexión',
                                  style: const TextStyle(
                                    color: AppColors.textBlack,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Mensaje de información
              if (!_hasInternet)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning, width: 1),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.wifi_off, color: AppColors.warning, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Necesitas conexión a internet para analizar las fotos.',
                          style: TextStyle(
                            color: AppColors.textWhite,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              // Lista de fotos pendientes
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.buttonGreen2,
                        ),
                      )
                    : _pendingPhotos.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.photo_library_outlined,
                                  size: 64,
                                  color: AppColors.textPaleGreen,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No hay fotos pendientes',
                                  style: TextStyle(
                                    color: AppColors.textPaleGreen,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Las fotos capturadas sin conexión aparecerán aquí',
                                  style: TextStyle(
                                    color: AppColors.textPaleGreen,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _pendingPhotos.length,
                            itemBuilder: (context, index) {
                              final photo = _pendingPhotos[index];
                              final photoId = photo['id'] as String;
                              final isProcessing = _processingPhotos.contains(photoId);
                              
                              return Card(
                                color: AppColors.backgroundCard,
                                elevation: 4,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      // Imagen en miniatura
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          File(photo['localImagePath']),
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              width: 80,
                                              height: 80,
                                              color: AppColors.paleGreen.withValues(alpha: 0.2),
                                              child: const Icon(
                                                Icons.image_not_supported,
                                                color: AppColors.textPaleGreen,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Información
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _formatDate(photo['createdAt']),
                                              style: const TextStyle(
                                                color: AppColors.textWhite,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _formatCoordinates(
                                                photo['latitude']?.toDouble(),
                                                photo['longitude']?.toDouble(),
                                              ),
                                              style: const TextStyle(
                                                color: AppColors.textPaleGreen,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Botones de acción
                                      Column(
                                        children: [
                                          // Botón analizar
                                          ElevatedButton.icon(
                                            icon: isProcessing
                                                ? const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child: CircularProgressIndicator(
                                                      color: AppColors.textBlack,
                                                      strokeWidth: 2,
                                                    ),
                                                  )
                                                : const Icon(Icons.psychology, size: 16),
                                            label: Text(
                                              isProcessing ? 'Procesando...' : 'Analizar',
                                              style: const TextStyle(fontSize: 11),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: _hasInternet 
                                                  ? AppColors.buttonGreen2 
                                                  : AppColors.textPaleGreen,
                                              foregroundColor: AppColors.textBlack,
                                              minimumSize: const Size(90, 32),
                                              padding: const EdgeInsets.symmetric(horizontal: 8),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                            ),
                                            onPressed: (_hasInternet && !isProcessing) 
                                                ? () => _clasificarFoto(photo)
                                                : null,
                                          ),
                                          const SizedBox(height: 4),
                                          // Botón eliminar
                                          ElevatedButton.icon(
                                            icon: const Icon(Icons.delete, size: 16),
                                            label: const Text(
                                              'Eliminar',
                                              style: TextStyle(fontSize: 11),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.warning,
                                              foregroundColor: AppColors.textBlack,
                                              minimumSize: const Size(90, 32),
                                              padding: const EdgeInsets.symmetric(horizontal: 8),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                            ),
                                            onPressed: isProcessing 
                                                ? null 
                                                : () => _eliminarFoto(photo),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _connectionCheckTimer?.cancel(); // Cancelar el timer de verificación de conexión
    super.dispose();
  }
}