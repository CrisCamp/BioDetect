import 'dart:io';
import 'package:biodetect/themes.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:biodetect/views/badges/galeria_insignias.dart';
import 'package:biodetect/services/google_drive_service.dart';

class RegDatos extends StatefulWidget {
  final File? imageFile;
  final String? photoId;
  final String? imageUrl;
  final String claseArtropodo;
  final String ordenTaxonomico;
  final Map<String, dynamic>? datosIniciales;
  final Map<String, double>? coordenadas;

  const RegDatos({
    super.key,
    this.imageFile,
    this.photoId,
    this.imageUrl,
    required this.claseArtropodo,
    required this.ordenTaxonomico,
    this.datosIniciales,
    this.coordenadas,
  });

  @override
  State<RegDatos> createState() => _RegDatosState();
}

class _RegDatosState extends State<RegDatos> {
  // Variables auxiliares para sincronización inmediata
  String? _originalClass;
  String? _originalOrder;
  String? _originalPhotoId;
  final _formKey = GlobalKey<FormState>();
  final _latitudController = TextEditingController();
  final _longitudController = TextEditingController();
  
  String taxonOrder = '';
  String className = '';
  String habitat = '';
  String details = '';
  String notes = '';
  double lat = 0;
  double lon = 0;
  String? currentImageUrl;
  bool _isEditing = false;
  bool _isProcessing = false;
  bool _hasInternet = true;
  bool _isGettingLocation = false;
  Map<String, double> _coords = {};

  // Expresiones regulares separadas para latitud y longitud
  final RegExp _latitudRegExp = RegExp(r'^-?([0-8]?[0-9](\.[0-9]+)?|90(\.0+)?)$');
  final RegExp _longitudRegExp = RegExp(r'^-?(1[0-7][0-9](\.[0-9]+)?|[0-9]?[0-9](\.[0-9]+)?|180(\.0+)?)$');

  @override
  void initState() {
    super.initState();
    
    _isEditing = widget.photoId != null;

    // Guardar valores originales para sincronización inmediata
    if (_isEditing) {
      _originalPhotoId = widget.photoId;
    }

    if (widget.coordenadas != null) {
      _coords = widget.coordenadas!;
      lat = _coords['x'] ?? 0;
      lon = _coords['y'] ?? 0;
      _latitudController.text = lat != 0 ? lat.toString() : '';
      _longitudController.text = lon != 0 ? lon.toString() : '';
    } else {
      if (!_isEditing) {
        _getCurrentLocation();
      }
    }
    
    className = widget.claseArtropodo;
    taxonOrder = widget.ordenTaxonomico;
    currentImageUrl = widget.imageUrl;

    _checkInternetConnection();

    if (widget.datosIniciales != null) {
      _loadDatosFromParam();
    } else if (_isEditing) {
      _loadPhotoData();
    }
  }

  @override
  void dispose() {
    _latitudController.dispose();
    _longitudController.dispose();
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

  void _loadDatosFromParam() {
    final data = widget.datosIniciales!;
    setState(() {
      taxonOrder = data['taxonOrder'] ?? '';
      className = data['class'] ?? '';
      // Guardar valores originales si no se han guardado
      _originalOrder ??= taxonOrder;
      _originalClass ??= className;
      habitat = data['habitat'] ?? '';
      details = data['details'] ?? '';
      notes = data['notes'] ?? '';
      if (data['coords'] != null) {
        lat = data['coords']['x'] ?? 0;
        lon = data['coords']['y'] ?? 0;
        _latitudController.text = lat != 0 ? lat.toString() : '';
        _longitudController.text = lon != 0 ? lon.toString() : '';
      }
    });
  }

  Future<void> _loadPhotoData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('insect_photos')
          .doc(widget.photoId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          taxonOrder = data['taxonOrder'] ?? '';
          className = data['class'] ?? '';
          // Guardar valores originales si no se han guardado
          _originalOrder ??= taxonOrder;
          _originalClass ??= className;
          habitat = data['habitat'] ?? '';
          details = data['details'] ?? '';
          notes = data['notes'] ?? '';
          if (data['coords'] != null) {
            lat = data['coords']['x'] ?? 0;
            lon = data['coords']['y'] ?? 0;
            _latitudController.text = lat != 0 ? lat.toString() : '';
            _longitudController.text = lon != 0 ? lon.toString() : '';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e')),
        );
      }
    }
  }

  Future<void> _actualizarActividadUsuario(String userId, {bool isIncrement = true}) async {
    if (!_hasInternet) return;

    try {
      final activityRef = FirebaseFirestore.instance.collection('user_activity').doc(userId);
      final increment = isIncrement ? 1 : -1;

      // Primero obtenemos el documento actual para verificar si son orden/clase nuevos
      final docSnapshot = await activityRef.get();

      Map<String, dynamic> updateData = {
        'userId': userId,
        'photosUploaded': FieldValue.increment(increment),
        'speciesIdentified.byTaxon.$taxonOrder': FieldValue.increment(increment),
        'speciesIdentified.byClass.$className': FieldValue.increment(increment),
        'lastActivity': FieldValue.serverTimestamp(),
      };

      if (docSnapshot.exists) {
        // El documento existe, verificar si son orden y clase nuevos
        final currentData = docSnapshot.data() as Map<String, dynamic>;

        // Verificar si es un orden nuevo
        final currentByTaxon = currentData['speciesIdentified']?['byTaxon'] as Map<String, dynamic>?;
        final isNewOrder = currentByTaxon == null || !currentByTaxon.containsKey(taxonOrder);

        // Verificar si es una clase nueva
        final currentByClass = currentData['speciesIdentified']?['byClass'] as Map<String, dynamic>?;
        final isNewClass = currentByClass == null || !currentByClass.containsKey(className);

        // Verificar si es un nuevo orden para esta clase específica
        final isNewOrderForClass = isNewOrder; // Si el orden es nuevo globalmente, también es nuevo para la clase

        // Solo incrementar totales si son orden/clase nuevos
        if (isNewOrder && isIncrement) {
          updateData['speciesIdentified.totalByTaxon'] = FieldValue.increment(1);
        } else if (!isIncrement && !isNewOrder) {
          // Al decrementar, verificar si queda en 0 para decrementar el total
          final currentOrderCount = currentByTaxon[taxonOrder] ?? 0;
          if (currentOrderCount <= 1) {
            updateData['speciesIdentified.totalByTaxon'] = FieldValue.increment(-1);
          }
        }

        if (isNewClass && isIncrement) {
          updateData['speciesIdentified.totalByClass'] = FieldValue.increment(1);
        } else if (!isIncrement && !isNewClass) {
          // Al decrementar, verificar si queda en 0 para decrementar el total
          final currentClassCount = currentByClass[className] ?? 0;
          if (currentClassCount <= 1) {
            updateData['speciesIdentified.totalByClass'] = FieldValue.increment(-1);
          }
        }

        // Manejar el contador de taxonomías por clase
        if (isNewOrderForClass && isIncrement) {
          updateData['speciesIdentified.byClassTaxonomy.$className'] = FieldValue.increment(1);
          // print('🆕 New taxonomy for class $className: $taxonOrder');
        } else if (!isIncrement && !isNewOrderForClass) {
          // Al decrementar, verificar si queda en 0 para decrementar el total de taxonomías de la clase
          final currentOrderCount = currentByTaxon[taxonOrder] ?? 0;
          if (currentOrderCount <= 1) {
            updateData['speciesIdentified.byClassTaxonomy.$className'] = FieldValue.increment(-1);
          }
        }

        await activityRef.update(updateData);

      } else {
        // El documento no existe, crear uno nuevo
        await activityRef.set({
          'userId': userId,
          'fieldNotesCreated': 0,
          'photosUploaded': isIncrement ? 1 : 0,
          'speciesIdentified': {
            'byTaxon': {
              taxonOrder: isIncrement ? 1 : 0,
            },
            'byClass': {
              className: isIncrement ? 1 : 0,
            },
            'byClassTaxonomy': {
              className: isIncrement ? 1 : 0,  // Primera taxonomía para esta clase
            },
            'totalByTaxon': isIncrement ? 1 : 0,
            'totalByClass': isIncrement ? 1 : 0,
          },
          'lastActivity': FieldValue.serverTimestamp(),
        });
      }

      // print('✅ User activity updated successfully for user $userId');
      // print('📊 Order: $taxonOrder, Class: $className');

    } catch (error) {
      // print('❌ Error updating user activity: $error');
    }
  }

  // void _updateCoordinatesFromFields() {
  //   // Actualizar las coordenadas desde los campos de texto
  //   final latText = _latitudController.text.trim();
  //   final lonText = _longitudController.text.trim();
    
  //   if (latText.isNotEmpty && _latitudRegExp.hasMatch(latText)) {
  //     final parsedLat = double.tryParse(latText);
  //     if (parsedLat != null && parsedLat >= -90 && parsedLat <= 90) {
  //       lat = parsedLat;
  //     }
  //   }
    
  //   if (lonText.isNotEmpty && _longitudRegExp.hasMatch(lonText)) {
  //     final parsedLon = double.tryParse(lonText);
  //     if (parsedLon != null && parsedLon >= -180 && parsedLon <= 180) {
  //       lon = parsedLon;
  //     }
  //   }
  // }

  Future<void> _guardarDatos() async {
    if (_isProcessing) return;

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor corrige los errores en el formulario'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (!_hasInternet) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Se requiere conexión a internet para guardar registros'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      if (_isEditing) {
        // Obtener datos actuales para comparar clase/orden y estado de sincronización
        final docRef = FirebaseFirestore.instance.collection('insect_photos').doc(widget.photoId);
        final docSnap = await docRef.get();
        final prevData = docSnap.data();
        final prevClass = prevData?['class'] ?? '';
        final prevOrder = prevData?['taxonOrder'] ?? '';
        final prevSyncedAt = prevData?['syncedAt'];

        final classChanged = prevClass != className;
        final orderChanged = prevOrder != taxonOrder;
        final wasSynced = prevSyncedAt != null;

        // Si cambió clase/orden y estaba sincronizado, preguntar al usuario
        if (wasSynced && (classChanged || orderChanged)) {
          final shouldSync = await showDialog<bool>(
            // ignore: use_build_context_synchronously
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppColors.backgroundCard,
              title: const Text('¿Sincronizar cambios en Google Drive?', style: TextStyle(color: AppColors.textWhite)),
              content: const Text(
                'Has cambiado la clase y/o el orden taxonómico de un registro ya sincronizado.\n\n¿Deseas sincronizar el registro editado en Google Drive? (Esto eliminará los archivos anteriores y subirá los nuevos en la carpeta correspondiente).',
                style: TextStyle(color: AppColors.textWhite),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('No', style: TextStyle(color: AppColors.warning)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.buttonGreen2),
                  child: const Text('Sí, sincronizar'),
                ),
              ],
            ),
          );

          if (shouldSync == true) {
            // 1. Eliminar archivos viejos de Drive y subir los nuevos usando los valores originales
            try {
              // Actualizar Firestore primero (para que los datos estén correctos en metadatos)
              await docRef.update({
                'taxonOrder': taxonOrder,
                'class': className,
                'habitat': habitat,
                'details': details,
                'notes': notes,
                'coords': {'x': lat, 'y': lon},
                'lastModifiedAt': FieldValue.serverTimestamp(),
              });
              // Obtener datos actualizados para metadatos
              final updatedSnap = await docRef.get();
              final updatedData = updatedSnap.data()!;
              // Llamar al servicio de Drive usando los valores originales
              await GoogleDriveService.resyncPhotoWithNewClassOrder(
                photoId: _originalPhotoId!,
                prevClass: _originalClass!,
                prevOrder: _originalOrder!,
                newClass: className,
                newOrder: taxonOrder,
                photoData: updatedData,
              );
              // Mostramos por consola los valores de las clases, ordenes e ID tanto viejos como nuevos
              print('🔄 Resyncing photo ${_originalPhotoId!} from Class $_originalClass, Order $_originalOrder to Class $className, Order $taxonOrder');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Datos y archivos sincronizados correctamente en Drive.'),
                    duration: Duration(seconds: 3),
                  ),
                );
                Navigator.of(context).pop(true);
              }
              return;
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al sincronizar con Drive: $e')),
                );
              }
              return;
            }
          } else {
            // Usuario NO quiere sincronizar, solo actualizar y poner syncedAt en null
            await docRef.update({
              'taxonOrder': taxonOrder,
              'class': className,
              'habitat': habitat,
              'details': details,
              'notes': notes,
              'coords': {'x': lat, 'y': lon},
              'lastModifiedAt': FieldValue.serverTimestamp(),
              'syncedAt': null, // Marcar como pendiente de sincronización
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Datos actualizados. El registro se marcará como pendiente de sincronización.'),
                  duration: Duration(seconds: 3),
                ),
              );
              Navigator.of(context).pop(true);
            }
            return;
          }
        }

        // Edición normal (sin cambio de clase/orden o no estaba sincronizado)
        await docRef.update({
          'taxonOrder': taxonOrder,
          'class': className,
          'habitat': habitat,
          'details': details,
          'notes': notes,
          'coords': {'x': lat, 'y': lon},
          'lastModifiedAt': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Datos actualizados correctamente'),
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        // Modo nuevo: crear nuevo registro
        await _guardarNuevoRegistro(user.uid);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _guardarNuevoRegistro(String userId) async {
    final photoId = FirebaseFirestore.instance.collection('insect_photos').doc().id;
    
    // Subir imagen a Storage
    final ref = FirebaseStorage.instance
        .ref()
        .child('insect_photos/$userId/original/$photoId.jpg');
    await ref.putFile(widget.imageFile!);
    final imageUrl = await ref.getDownloadURL();
    
    // Crear documento en Firestore
    await FirebaseFirestore.instance.collection('insect_photos').doc(photoId).set({
      'userId': userId,
      'imageUrl': imageUrl,
      'uploadedAt': FieldValue.serverTimestamp(),
      'lastModifiedAt': FieldValue.serverTimestamp(),
      'syncedAt': null, // Sin sincronizar inicialmente
      'taxonOrder': taxonOrder,
      'class': className,
      'habitat': habitat,
      'details': details,
      'notes': notes,
      'coords': {'x': lat, 'y': lon},
    });
    
    // Actualizar actividad del usuario
    await _actualizarActividadUsuario(userId, isIncrement: true);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Datos guardados correctamente'),
          backgroundColor: AppColors.buttonGreen2,
          duration: Duration(seconds: 2),
        ),
      );
      
      // Pequeña pausa para que se vea el SnackBar antes de las notificaciones
      await Future.delayed(const Duration(milliseconds: 1000));
      
      // Verificar y mostrar notificaciones de nuevas insignias
      // Solo se hace aquí porque es cuando se actualiza la actividad del usuario con un nuevo registro
      try {
        // ignore: use_build_context_synchronously
        await GaleriaInsigniasScreen.checkAndShowNotifications(context);
      } catch (e) {
        // print('Error al verificar insignias: $e');
        // No mostrar error al usuario, ya que el guardado fue exitoso
      }
      
      if (mounted) {
        Navigator.of(context).pop('saved');
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    if (_isGettingLocation) return;
    
    setState(() => _isGettingLocation = true);
    
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permiso de ubicación denegado')),
          );
          setState(() => _isGettingLocation = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permiso de ubicación denegado permanentemente')),
        );
        setState(() => _isGettingLocation = false);
        return;
      }
      
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      
      setState(() {
        lat = position.latitude;
        lon = position.longitude;
        _latitudController.text = lat.toStringAsFixed(6);
        _longitudController.text = lon.toStringAsFixed(6);
        _isGettingLocation = false;
      });
      
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ubicación obtenida correctamente'),
          backgroundColor: AppColors.buttonGreen2,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() => _isGettingLocation = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al obtener ubicación: $e')),
        );
      }
    }
  }

  String? _validateLatitud(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'La latitud es requerida';
    }
    
    if (!_latitudRegExp.hasMatch(value.trim())) {
      return 'Formato de latitud inválido';
    }
    
    final lat = double.tryParse(value.trim());
    if (lat == null || lat < -90 || lat > 90) {
      return 'La latitud debe estar entre -90 y 90';
    }
    
    return null;
  }

  String? _validateLongitud(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'La longitud es requerida';
    }
    
    if (!_longitudRegExp.hasMatch(value.trim())) {
      return 'Formato de longitud inválido';
    }
    
    final lon = double.tryParse(value.trim());
    if (lon == null || lon < -180 || lon > 180) {
      return 'La longitud debe estar entre -180 y 180';
    }
    
    return null;
  }

  List<DropdownMenuItem<String>> _getClassesArthropods() {
    return [
      'Insecta',
      'Arachnida'
    ].map((String value) {
      return DropdownMenuItem<String>(
        value: value,
        child: Text(value),
      );
    }).toList();
  }

  List<DropdownMenuItem<String>> _getTaxonOrder() {
    return [
      'Acari', // Arachnida
      'Amblypygi', // Arachnida
      'Araneae', // Arachnida
      'Scorpiones', // Arachnida
      'Solifugae', // Arachnida
      'Dermaptera', // Insecta
      'Lepidoptera', // Insecta
      'Mantodea', // Insecta
      'Orthoptera', // Insecta
      'Thysanoptera', // Insecta
    ].map((String value) {
      return DropdownMenuItem<String>(
        value: value,
        child: Text(value),
      );
    }).toList();
  }

  List<DropdownMenuItem<String>> _getFilteredTaxonOrder() {
    // Definir qué órdenes pertenecen a cada clase con tipado explícito
    final Map<String, List<String>> classToOrders = {
      'Arachnida': ['Acari', 'Amblypygi', 'Araneae', 'Scorpiones', 'Solifugae'],
      'Insecta': ['Dermaptera', 'Lepidoptera', 'Mantodea', 'Orthoptera', 'Thysanoptera'],
    };

    // Obtener los órdenes para la clase seleccionada, o lista vacía si no hay clase
    final List<String> orders = className.isNotEmpty
        ? classToOrders[className] ?? <String>[]
        : <String>[];

    return orders.map<DropdownMenuItem<String>>((String value) {
      return DropdownMenuItem<String>(
        value: value,
        child: Text(value),
      );
    }).toList();
  }

  String? _getValidClassesValue() {
    if (className.isNotEmpty && _getClassesArthropods().any((item) => item.value == className)) {
      return className;
    }
    return null;
  }
  String? _getValidTaxonValue() {
    if (taxonOrder.isNotEmpty && _getTaxonOrder().any((item) => item.value == taxonOrder)) {
      return taxonOrder;
    }
    return null;
  }

  List<DropdownMenuItem<String>> _getHabitatItems() {
    return [
      'Jardín urbano',
      'Parque',
      'Bosque',
      'Campo abierto',
      'Zona húmeda',
      'Interior de casa',
      'Cultivo',
      'Otro'
    ].map((String value) {
      return DropdownMenuItem<String>(
        value: value,
        child: Text(value),
      );
    }).toList();
  }

  String? _getValidHabitatValue() {
    if (habitat.isNotEmpty && _getHabitatItems().any((item) => item.value == habitat)) {
      return habitat;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: AppColors.backgroundPrimary, // Cambiar de gradiente a color sólido
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 0),
              child: Column(
                children: [
                  Card(
                    color: AppColors.backgroundCard,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: const BorderSide(color: AppColors.white, width: 2),
                    ),
                    elevation: 12,
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Header con indicador de conexión
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back_ios_new),
                                  color: AppColors.white,
                                  onPressed: _isProcessing ? null : () => Navigator.pop(context),
                                  iconSize: 28,
                                ),
                                Expanded(
                                  child: Column(
                                    children: [
                                      Text(
                                        _isEditing ? 'Editar Registro' : 'Datos del Registro',
                                        style: const TextStyle(
                                          color: AppColors.white,
                                          fontSize: 22,
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
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.refresh),
                                  color: AppColors.white,
                                  onPressed: _isProcessing ? null : _checkInternetConnection,
                                  iconSize: 24,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Imagen
                            Card(
                              color: AppColors.backgroundCard,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(color: AppColors.white, width: 1),
                              ),
                              elevation: 4,
                              margin: EdgeInsets.zero,
                              child: SizedBox(
                                height: 180,
                                width: double.infinity,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: _isEditing && currentImageUrl != null
                                      ? Image.network(currentImageUrl!, fit: BoxFit.cover)
                                      : (widget.imageFile != null 
                                          ? Image.file(widget.imageFile!, fit: BoxFit.cover)
                                          : Container(
                                              color: AppColors.paleGreen.withValues(alpha: 0.2),
                                              child: const Icon(Icons.image_outlined, color: AppColors.textPaleGreen, size: 80),
                                            )),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Formulario
                            Column(
                              children: [
                                // Clase - Convertido a Dropdown
                                IgnorePointer(
                                  ignoring: _isProcessing,
                                  child: DropdownButtonFormField<String>(
                                    value: _getValidClassesValue(),
                                    decoration: InputDecoration(
                                      labelText: 'Clase',
                                      labelStyle: const TextStyle(color: AppColors.textWhite),
                                      filled: true,
                                      fillColor: _isProcessing
                                          ? AppColors.paleGreen.withValues(alpha: 0.5)
                                          : AppColors.paleGreen,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    dropdownColor: AppColors.paleGreen,
                                    style: TextStyle(
                                      color: _isProcessing
                                          ? AppColors.textBlack.withValues(alpha: 0.5)
                                          : AppColors.textBlack,
                                    ),
                                    items: _getClassesArthropods(),
                                    onChanged: _isProcessing
                                        ? null
                                        : (value) {
                                      setState(() {
                                        className = value ?? '';
                                        // Reset taxonOrder cuando cambia la clase
                                        taxonOrder = '';
                                      });
                                    },
                                    validator: (value) => value?.trim().isEmpty ?? true
                                        ? 'La clase es requerida' : null,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Orden taxonómico - Convertido a Dropdown dependiente
                                IgnorePointer(
                                  ignoring: _isProcessing || className.isEmpty,
                                  child: DropdownButtonFormField<String>(
                                    value: _getValidTaxonValue(),
                                    decoration: InputDecoration(
                                      labelText: 'Orden Taxonómico',
                                      labelStyle: const TextStyle(color: AppColors.textWhite),
                                      filled: true,
                                      fillColor: _isProcessing || className.isEmpty
                                          ? AppColors.slateGrey.withValues(alpha: 0.3)
                                          : AppColors.paleGreen,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide.none,
                                      ),
                                      suffixIcon: className.isEmpty
                                          ? const Icon(Icons.lock, color: AppColors.textPaleGreen)
                                          : null,
                                    ),
                                    dropdownColor: AppColors.paleGreen,
                                    style: TextStyle(
                                      color: _isProcessing || className.isEmpty
                                          ? AppColors.textBlack.withValues(alpha: 0.5)
                                          : AppColors.textBlack,
                                    ),
                                    items: _getFilteredTaxonOrder(),
                                    onChanged: _isProcessing || className.isEmpty
                                        ? null
                                        : (value) => setState(() => taxonOrder = value ?? ''),
                                    validator: (value) => value?.trim().isEmpty ?? true
                                        ? 'El orden taxonómico es requerido' : null,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Coordenadas mejoradas
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.slateGreen.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.buttonGreen2.withValues(alpha: 0.5)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on, color: AppColors.buttonGreen2),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Coordenadas GPS',
                                            style: TextStyle(
                                              color: AppColors.textWhite,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const Spacer(),
                                          // Botón de ubicación solo con icono
                                          Container(
                                            decoration: BoxDecoration(
                                              color: AppColors.buttonGreen2,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: IconButton(
                                              icon: _isGettingLocation
                                                  ? const SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child: CircularProgressIndicator(
                                                        color: AppColors.textBlack,
                                                        strokeWidth: 2,
                                                      ),
                                                    )
                                                  : const Icon(Icons.my_location, color: AppColors.textBlack),
                                              onPressed: (_isProcessing || _isGettingLocation) ? null : _getCurrentLocation,
                                              tooltip: 'Obtener ubicación actual',
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      // Campo Latitud
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Latitud:',
                                            style: TextStyle(
                                              color: AppColors.textWhite,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          TextFormField(
                                            controller: _latitudController,
                                            enabled: !_isProcessing,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                            decoration: InputDecoration(
                                              hintText: 'Ej: 19.432608',
                                              hintStyle: const TextStyle(color: AppColors.textBlack),
                                              filled: true,
                                              fillColor: AppColors.paleGreen,
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: BorderSide.none,
                                              ),
                                              errorBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: const BorderSide(color: AppColors.warning, width: 2),
                                              ),
                                              prefixIcon: const Icon(Icons.arrow_upward, color: AppColors.textBlack),
                                            ),
                                            style: const TextStyle(color: AppColors.textBlack),
                                            validator: _validateLatitud,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      // Campo Longitud
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Longitud:',
                                            style: TextStyle(
                                              color: AppColors.textWhite,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          TextFormField(
                                            controller: _longitudController,
                                            enabled: !_isProcessing,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                            decoration: InputDecoration(
                                              hintText: 'Ej: -99.133209',
                                              hintStyle: const TextStyle(color: AppColors.textBlack),
                                              filled: true,
                                              fillColor: AppColors.paleGreen,
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: BorderSide.none,
                                              ),
                                              errorBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: const BorderSide(color: AppColors.warning, width: 2),
                                              ),
                                              prefixIcon: const Icon(Icons.arrow_forward, color: AppColors.textBlack),
                                            ),
                                            style: const TextStyle(color: AppColors.textBlack),
                                            validator: _validateLongitud,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Hábitat - CORREGIDO
                                IgnorePointer(
                                  ignoring: _isProcessing,
                                  child: DropdownButtonFormField<String>(
                                    value: _getValidHabitatValue(),
                                    decoration: InputDecoration(
                                      labelText: 'Hábitat',
                                      labelStyle: const TextStyle(color: AppColors.textWhite),
                                      filled: true,
                                      fillColor: _isProcessing 
                                          ? AppColors.paleGreen.withValues(alpha: 0.5) 
                                          : AppColors.paleGreen,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    dropdownColor: AppColors.paleGreen,
                                    style: TextStyle(
                                      color: _isProcessing 
                                          ? AppColors.textBlack.withValues(alpha: 0.5) 
                                          : AppColors.textBlack,
                                    ),
                                    items: _getHabitatItems(),
                                    onChanged: _isProcessing 
                                        ? null 
                                        : (value) => setState(() => habitat = value ?? ''),
                                    validator: (value) => value?.trim().isEmpty ?? true 
                                        ? 'El hábitat es requerido' : null,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Detalles
                                TextFormField(
                                  initialValue: details,
                                  enabled: !_isProcessing,
                                  onChanged: (v) => details = v,
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    labelText: 'Detalles adicionales',
                                    labelStyle: const TextStyle(color: AppColors.textWhite),
                                    filled: true,
                                    fillColor: AppColors.paleGreen,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  style: const TextStyle(color: AppColors.textBlack),
                                ),
                                const SizedBox(height: 16),
                                // Notas
                                TextFormField(
                                  initialValue: notes,
                                  enabled: !_isProcessing,
                                  onChanged: (v) => notes = v,
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    labelText: 'Notas personales',
                                    labelStyle: const TextStyle(color: AppColors.textWhite),
                                    filled: true,
                                    fillColor: AppColors.paleGreen,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  style: const TextStyle(color: AppColors.textBlack),
                                ),
                                const SizedBox(height: 24),
                                // Botón guardar/actualizar
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.buttonBrown2,
                                          foregroundColor: AppColors.textBlack,
                                          minimumSize: const Size(0, 48),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        onPressed: _isProcessing ? null : () => Navigator.pop(context),
                                        child: const Text(
                                          'Cancelar',
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        icon: _isProcessing
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  color: AppColors.textBlack,
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : Icon(_isEditing ? Icons.update : Icons.save),
                                        label: Text(
                                          _isProcessing
                                              ? (_isEditing ? 'Actualizando...' : 'Guardando...')
                                              : (_isEditing ? 'Actualizar' : 'Guardar'),
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.buttonGreen2,
                                          foregroundColor: AppColors.textBlack,
                                          minimumSize: const Size(0, 48),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        onPressed: _isProcessing ? null : _guardarDatos,
                                      ),
                                    ),
                                  ],
                                ),
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
                                        Icon(Icons.warning, color: AppColors.warning),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Sin conexión a internet. No se pueden guardar los datos.',
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
                          ],
                        ),
                      ),
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