import 'dart:io';
import 'dart:async';
import 'package:biodetect/themes.dart';
import 'package:biodetect/views/registers/datos.dart';
import 'package:biodetect/views/registers/fotos_pendientes.dart';
import 'package:biodetect/services/pending_photos_service.dart';
import 'package:biodetect/services/ai_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:crop_your_image/crop_your_image.dart';

class CapturaFoto extends StatefulWidget {
  const CapturaFoto({super.key});

  @override
  State<CapturaFoto> createState() => _CapturaFotoState();
}

class _CapturaFotoState extends State<CapturaFoto> {
  final CropController _cropController = CropController();
  bool _showCropper = false;
  Uint8List? _imageBytes;

  Future<void> _recortarImagen() async {
    if (_image == null) return;
    final bytes = await _image!.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _showCropper = true;
    });
  }

  Future<File> _saveCroppedBytesToFile(Uint8List croppedBytes) async {
    final tempDir = Directory.systemTemp;
    final tempFile = await File('${tempDir.path}/biodetect_cropped_${DateTime.now().millisecondsSinceEpoch}.jpg').create();
    await tempFile.writeAsBytes(croppedBytes);
    return tempFile;
  }
  File? _image;
  bool _isProcessing = false;
  bool _hasInternet = true;
  Position? _currentPosition;
  Timer? _connectionCheckTimer; // Timer para verificación de conexión automática
  int _pendingCount = 0; // Contador de fotos pendientes

  @override
  void initState() {
    super.initState();
    _checkInternetConnection();
    _startPeriodicConnectionCheck(); // Iniciar verificación de conexión automática
    _loadPendingCount(); // Cargar conteo de fotos pendientes
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
      _checkInternetConnection();
    });
  }

  // Cargar conteo de fotos pendientes
  Future<void> _loadPendingCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final count = await PendingPhotosService.getPendingCount(user.uid);
      setState(() {
        _pendingCount = count;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || 
          permission == LocationPermission.always) {
        final Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        setState(() {
          _currentPosition = position;
        });
      }
    } catch (e) {
      // Cambiar print por debugPrint
      if (kDebugMode) {
        debugPrint('Error obteniendo ubicación: $e');
      }
    }
  }

  Future<bool> _validateImageSize(File imageFile) async {
    try {
      final fileSizeInBytes = await imageFile.length();
      const maxSizeInBytes = 20 * 1024 * 1024; // 20 MB en bytes
      const warningThreshold = 8 * 1024 * 1024; // 8 MB en bytes
      
      if (kDebugMode) {
        final fileSizeInMB = (fileSizeInBytes / (1024 * 1024)).toStringAsFixed(2);
        debugPrint('📷 Imagen seleccionada:');
        debugPrint('   - Tamaño: ${fileSizeInMB}MB');
        debugPrint('   - Límite máximo: 20MB');
        debugPrint('   - Umbral de advertencia: 8MB');
        debugPrint('   - Válida: ${fileSizeInBytes <= maxSizeInBytes}');
      }
      
      if (fileSizeInBytes > maxSizeInBytes) {
        // Imagen muy grande (>20MB)
        final fileSizeInMB = (fileSizeInBytes / (1024 * 1024)).toStringAsFixed(1);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'La imagen es muy grande (${fileSizeInMB}MB).\n'
                'El tamaño máximo permitido es 20MB.\n'
                'Por favor, selecciona una imagen más pequeña.',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return false;
      } else if (fileSizeInBytes >= warningThreshold) {
        // Imagen grande (8MB-20MB) - mostrar advertencia
        final fileSizeInMB = (fileSizeInBytes / (1024 * 1024)).toStringAsFixed(1);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Imagen de ${fileSizeInMB}MB.\n'
                'El análisis podría demorar un poco más de lo habitual.',
              ),
              backgroundColor: AppColors.warning,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return true;
      } else {
        // Imagen pequeña (<8MB) - sin mensaje, continuar normalmente
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error verificando tamaño de imagen: $e');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al validar la imagen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  Future<void> _tomarFoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      
      // Validar tamaño de imagen
      final isValid = await _validateImageSize(file);
      if (isValid) {
        setState(() {
          _image = file;
        });
        _getCurrentLocation();
      }
    }
  }

  Future<void> _seleccionarGaleria() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      
      // Validar tamaño de imagen
      final isValid = await _validateImageSize(file);
      if (isValid) {
        setState(() {
          _image = file;
        });
        _getCurrentLocation();
      }
    }
  }

  Future<void> _analizarFoto() async {
    if (_isProcessing) return;
    if (!mounted) return; // Verificar mounted antes de setState
    
    setState(() => _isProcessing = true);

    if (_image == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Primero selecciona una foto.')),
        );
        setState(() => _isProcessing = false);
      }
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isProcessing = false);
      return;
    }

    await _checkInternetConnection();

    if (!_hasInternet) {
      await _guardarPendiente();
      return;
    }

    try {
      // Verificación adicional de conexión justo antes del procesamiento
      await _checkInternetConnection();
      
      // Si perdimos la conexión después de la verificación inicial
      if (!_hasInternet) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Se perdió la conexión a internet. La foto se guardará como pendiente.'),
            backgroundColor: AppColors.warning,
            duration: Duration(seconds: 4),
          ),
        );
        await _guardarPendiente();
        return;
      }

      final Map<String, dynamic> response = await AIService.analyzeImage(_image!);

      final String clasificacion = response['predicted_class'];
      final double confianza = response['confidence'];

      final List<String> taxonomia = clasificacion.split('-');
      final String claseArtropodo = taxonomia[0];
      final String ordenTaxonomico = taxonomia[1];

      if (mounted) {
        if (confianza >= 0.75) {
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Clase: $claseArtropodo. Orden: $ordenTaxonomico.\nConfianza: (${(confianza * 100).toStringAsFixed(2)}%)'),
              backgroundColor: AppColors.buttonGreen2,
            ),
          );

          await Future.delayed(const Duration(milliseconds: 1000));

          if (mounted) {
            final dynamic result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RegDatos(
                  imageFile: _image!,
                  claseArtropodo: claseArtropodo,
                  ordenTaxonomico: ordenTaxonomico,
                  coordenadas: _currentPosition != null ? {'x': _currentPosition!.latitude, 'y': _currentPosition!.longitude} : null,
                ),
              ),
            );

            if (result == 'saved' && mounted) {
              setState(() {
                _image = null;
              });
            }
          }
        } else {
          await _mostrarOpcionesBajaConfianza(claseArtropodo, ordenTaxonomico, confianza);
        }
      }
    } catch (e) {
      if (mounted) {
        // Verificar si es un error de conexión
        if (_isConnectionError(e)) {
          // Es un error de conexión - actualizar estado y guardar como pendiente
          await _checkInternetConnection(); // Actualizar estado de conexión
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error de conexión. La foto se guardará como pendiente para analizarla más tarde.'),
              backgroundColor: AppColors.warning,
              duration: Duration(seconds: 4),
            ),
          );
          // Guardar como pendiente automáticamente
          await _guardarPendiente();
        } else {
          // Otro tipo de error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al procesar la foto: ${e.toString()}'),
              backgroundColor: AppColors.warning,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }

    if (mounted) setState(() => _isProcessing = false);
  }

  Future<void> _guardarPendiente() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isProcessing = false);
        return;
      }
      final String userId = user.uid;
      await PendingPhotosService.savePendingPhoto(
        userId: userId,
        imageFile: _image!,
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto guardada como pendiente. Podrás analizarla más tarde.'),
            backgroundColor: AppColors.buttonGreen2,
            duration: Duration(seconds: 3),
          ),
        );
        
        setState(() {
          _image = null;
        });
        
        // Actualizar conteo de fotos pendientes
        _loadPendingCount();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar la foto como pendiente: $e'),
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }

    if (mounted) setState(() => _isProcessing = false);
  }

  Future<void> _mostrarOpcionesBajaConfianza(
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
                _procederConClasificacion(claseArtropodo, ordenTaxonomico);
              },
            ),
            TextButton(
              child: const Text(
                'Enviar para revisión',
                style: TextStyle(color: AppColors.darkTeal),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _enviarRevision();
              },
            ),
            TextButton(
              child: const Text(
                'Eliminar foto',
                style: TextStyle(color: AppColors.warningDark),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                setState(() {
                  _image = null;
                  _isProcessing = false;
                });
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

  Future<void> _procederConClasificacion(String claseArtropodo, String ordenTaxonomico) async {
    try {
      if (_image == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: No hay imagen para registrar manualmente.')),
          );
        }
        return;
      }

      final dynamic result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RegDatos(
            imageFile: _image!,
            claseArtropodo: claseArtropodo,
            ordenTaxonomico: ordenTaxonomico,
            coordenadas: _currentPosition != null ? {'x': _currentPosition!.latitude, 'y': _currentPosition!.longitude} : null,
          ),
        ),
      );

      if (result == 'saved' && mounted) {
        setState(() {
          _image = null;
          _isProcessing = false;
        });
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

  Future<void> _enviarRevision() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      setState(() => _isProcessing = true);

      final photoId = FirebaseFirestore.instance.collection('unidentified').doc().id;

      final ref = FirebaseStorage.instance.ref().child('unidentified/${user.uid}/$photoId.jpg');
      await ref.putFile(_image!);
      final imageUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('unidentified').doc(photoId).set({
        'userId': user.uid,
        'imageUrl': imageUrl,
        'uploadedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'coords': {'x': _currentPosition?.latitude, 'y': _currentPosition?.longitude}
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto enviada para revisión. Gracias por su apoyo.'),
            backgroundColor: AppColors.buttonGreen2,
          ),
        );
        
        setState(() {
          _image = null;
        });
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
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            color: AppColors.backgroundPrimary,
            child: SafeArea(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height -
                        MediaQuery.of(context).padding.top -
                        MediaQuery.of(context).padding.bottom,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new),
                              color: AppColors.white,
                              onPressed: () => Navigator.pop(context),
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  const Text(
                                    'Nueva Fotografía',
                                    style: TextStyle(
                                      color: AppColors.white,
                                      fontSize: 24,
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
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.schedule_outlined),
                                  color: AppColors.white,
                                  tooltip: 'Ver fotos pendientes',
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const FotosPendientes(),
                                      ),
                                    ).then((_) {
                                      _loadPendingCount();
                                    });
                                  },
                                ),
                                if (_pendingCount > 0)
                                  Positioned(
                                    right: 8,
                                    top: 8,
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        minWidth: 18,
                                        minHeight: 18,
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFFF6B6B),
                                            Color(0xFFEE5A24),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFFF6B6B).withOpacity(0.4),
                                            spreadRadius: 1,
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        _pendingCount.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // ...
                        Container(
                          height: 440,
                          decoration: BoxDecoration(
                            color: AppColors.backgroundCard,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.buttonGreen2,
                              width: 2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: _image == null
                              ? const Text(
                                  'Aquí se mostrará la foto',
                                  style: TextStyle(
                                    color: AppColors.textPaleGreen,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                )
                              : Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(18),
                                      child: Image.file(
                                        _image!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: 440,
                                      ),
                                    ),
                                    Positioned(
                                      top: 12,
                                      right: 12,
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(24),
                                          onTap: _isProcessing ? null : _recortarImagen,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: AppColors.buttonGreen2.withOpacity(0.85),
                                              borderRadius: BorderRadius.circular(24),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.15),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            padding: const EdgeInsets.all(8),
                                            child: const Icon(
                                              Icons.crop,
                                              color: AppColors.textBlack,
                                              size: 28,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 16),
                        if (_image == null) ...[
                          Card(
                            color: AppColors.backgroundCard,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!_hasInternet) ...[
                                    Row(
                                      children: const [
                                        Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          'Sin conexión',
                                          style: TextStyle(
                                            color: AppColors.warning,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Podrás guardar las fotos como pendientes y analizarlas cuando recuperes la conexión.',
                                      style: TextStyle(
                                        color: AppColors.textWhite,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  const Text(
                                    'Asegúrate de:',
                                    style: TextStyle(
                                      color: AppColors.buttonGreen2,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    '• Enfocar bien el artrópodo',
                                    style: TextStyle(
                                      color: AppColors.textWhite,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const Text(
                                    '• Tener buena iluminación',
                                    style: TextStyle(
                                      color: AppColors.textWhite,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const Text(
                                    '• Sin objetos distractores',
                                    style: TextStyle(
                                      color: AppColors.textWhite,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.buttonGreen2,
                                  foregroundColor: AppColors.textBlack,
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  minimumSize: const Size(0, 48),
                                ),
                                onPressed: _tomarFoto,
                                child: const Text(
                                  'Capturar',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.buttonBrown3,
                                  foregroundColor: AppColors.textBlack,
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  minimumSize: const Size(0, 48),
                                ),
                                onPressed: _seleccionarGaleria,
                                child: const Text(
                                  'Galería',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_image != null) ...[
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              if (_hasInternet)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: IconButton(
                                    icon: const Icon(Icons.save_as_outlined),
                                    color: AppColors.textWhite,
                                    style: IconButton.styleFrom(
                                      backgroundColor: AppColors.buttonBrown3,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.all(12),
                                    ),
                                    tooltip: 'Guardar como pendiente',
                                    onPressed: _isProcessing ? null : _guardarPendiente,
                                  ),
                                ),
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: _isProcessing
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            color: AppColors.textWhite,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : Icon(
                                          _hasInternet ? Icons.psychology : Icons.save,
                                          color: AppColors.textWhite,
                                        ),
                                  label: Text(
                                    _isProcessing
                                        ? (_hasInternet ? 'Analizando...' : 'Guardando...')
                                        : (_hasInternet ? 'Analizar' : 'Guardar como pendiente'),
                                    style: const TextStyle(
                                      color: AppColors.textWhite,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  style: ButtonStyle(
                                    backgroundColor: WidgetStateProperty.all(
                                        _hasInternet ? AppColors.buttonBlue2 : AppColors.buttonBrown3),
                                    shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                                      RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    minimumSize: WidgetStateProperty.all(const Size(0, 48)),
                                    elevation: WidgetStateProperty.all(_isProcessing ? 0 : 4),
                                  ),
                                  onPressed: _isProcessing ? null : _analizarFoto,
                                ),
                              ),
                            ],
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
        if (_showCropper && _imageBytes != null)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundCard,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 320,
                          height: 320,
                          child: Crop(
                            controller: _cropController,
                            image: _imageBytes!,
                            onCropped: (croppedData) async {
                              final croppedFile = await _saveCroppedBytesToFile(croppedData);
                              setState(() {
                                _image = croppedFile;
                                _showCropper = false;
                              });
                            },
                            initialSize: 0.8,
                            baseColor: Colors.black,
                            maskColor: Colors.black.withOpacity(0.4),
                            cornerDotBuilder: (size, edgeAlignment) => const DotControl(color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () => _cropController.crop(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.buttonGreen2,
                                foregroundColor: AppColors.textBlack,
                              ),
                              child: const Text('Recortar'),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              onPressed: () => setState(() => _showCropper = false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.warning,
                                foregroundColor: AppColors.textBlack,
                              ),
                              child: const Text('Cancelar'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _connectionCheckTimer?.cancel(); // Cancelar el timer de verificación de conexión
    super.dispose();
  }
}