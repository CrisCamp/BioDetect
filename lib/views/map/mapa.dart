import 'package:biodetect/themes.dart';
import 'package:biodetect/views/registers/detalle_registro.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle, PlatformException;
import 'package:image/image.dart' as img;

class MapaIterativoScreen extends StatefulWidget {
  const MapaIterativoScreen({super.key});

  @override
  State<MapaIterativoScreen> createState() => _MapaIterativoScreenState();
}

class _MapaIterativoScreenState extends State<MapaIterativoScreen> {
  mapbox.MapboxMap? mapboxMap;
  mapbox.PointAnnotationManager? pointAnnotationManager;
  geolocator.Position? _currentPosition;
  List<Map<String, dynamic>> _userPhotos = [];
  List<mapbox.PointAnnotation> _createdAnnotations = [];
  bool _isLoading = true;
  bool _hasLocationPermission = false;
  String? _mapError;
  mapbox.PointAnnotation? _currentLocationAnnotation; // Referencia al marcador de ubicación

  final Map<String, String> _loadedMarkerImageIds = {};

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    await _requestLocationPermission();
    await _loadUserPhotos();
    print('Mapbox token configurado en main.dart');
  }

  Future<void> _requestLocationPermission() async {
    try {
      PermissionStatus permission = await Permission.locationWhenInUse.request();
      
      if (permission.isGranted) {
        setState(() {
          _hasLocationPermission = true;
        });
        await _getCurrentLocation();
      } else {
        setState(() {
          _hasLocationPermission = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permisos de ubicación necesarios para el mapa'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      }
    } catch (e) {
      print('Error solicitando permisos: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      if (!_hasLocationPermission) return;
      
      geolocator.Position position = await geolocator.Geolocator.getCurrentPosition(
        desiredAccuracy: geolocator.LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      setState(() {
        _currentPosition = position;
      });
      
      print('Ubicación obtenida: ${position.latitude}, ${position.longitude}');
      
      // Si el mapa ya está creado, agregar marcador y centrar en la ubicación actual
      if (mapboxMap != null) {
        await _addCurrentLocationMarker();
        await _centerOnCurrentLocation();
      }
    } catch (e) {
      print('Error obteniendo ubicación: $e');
      // Usar ubicación por defecto si no se puede obtener la actual
      setState(() {
        _currentPosition = geolocator.Position(
          latitude: 19.4326,
          longitude: -99.1332,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
      });
    }
  }

  Future<void> _loadUserPhotos() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Consultar directamente desde Firestore con cache
      final query = await FirebaseFirestore.instance
          .collection('insect_photos')
          .where('userId', isEqualTo: user.uid)
          .get(const GetOptions(source: Source.serverAndCache));

      List<Map<String, dynamic>> photosWithCoords = [];

      for (final doc in query.docs) {
        final data = doc.data();
        double? lat, lon;
        
        if (data['coords'] != null && data['coords']['x'] != null && data['coords']['y'] != null) {
          lat = data['coords']['x'];
          lon = data['coords']['y'];
          
          if (lat != null && lon != null && lat != 0 && lon != 0) {
            photosWithCoords.add({
              ...data,
              'lat': lat,
              'lon': lon,
              'taxonOrder': data['taxonOrder'],
              'photoId': doc.id,
            });
          }
        }
      }

      setState(() {
        _userPhotos = photosWithCoords;
        _isLoading = false;
      });

      if (pointAnnotationManager != null) {
        await _addPhotoMarkers();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Uint8List?> _loadAssetBytes(String assetPath) async {
    try {
      final ByteData byteData = await rootBundle.load(assetPath);
      return byteData.buffer.asUint8List();
    } catch (e) {
      print('Error cargando asset $assetPath: $e');
      return null;
    }
  }

  Future<void> _addPhotoMarkers() async {
    if (pointAnnotationManager == null || mapboxMap == null || !_userPhotos.isNotEmpty) {
      print("No se pueden agregar marcadores: pointAnnotationManager, mapboxMap o _userPhotos no están listos.");
      return;
    }

    try {
      if (_createdAnnotations.isNotEmpty) {
        await pointAnnotationManager!.deleteAll();
        _createdAnnotations.clear();
      }

      List<mapbox.PointAnnotationOptions> annotationOptionsList = [];

      for (int i = 0; i < _userPhotos.length; i++) {
        final photo = _userPhotos[i];
        String? taxonOrder = photo['taxonOrder']?.toString().toLowerCase().replaceAll(' ', '_');
        String markerIconId;

        if (taxonOrder != null && taxonOrder.isNotEmpty) {
          final String assetPath = 'assets/map_markers/$taxonOrder.png';

          if (_loadedMarkerImageIds.containsKey(assetPath)) {
            markerIconId = _loadedMarkerImageIds[assetPath]!;
            print("Usando imagen de marcador cacheada para $taxonOrder con ID: $markerIconId");
          } else {
            Uint8List? imageBytes = await _loadAssetBytes(assetPath);
            if (imageBytes != null) {
              // ***** DECODIFICAR IMAGEN PARA OBTENER DIMENSIONES *****
              img.Image? decodedImage = img.decodeImage(imageBytes);
              if (decodedImage == null) {
                print("Error: No se pudo decodificar la imagen desde los bytes para $assetPath.");
                // Fallback si la decodificación falla
                annotationOptionsList.add(
                    mapbox.PointAnnotationOptions(
                      geometry: mapbox.Point(coordinates: mapbox.Position.named(lng: photo['lon'], lat: photo['lat'])),
                      iconColor: Colors.red.toARGB32(), // Color de error
                      iconSize: 1.0,
                      textField: "Error img",
                    )
                );
                continue; // Pasa a la siguiente foto
              }
              int imageWidth = decodedImage.width;
              int imageHeight = decodedImage.height;
              // ***** FIN DE DECODIFICACIÓN *****

              if (imageWidth == 0 || imageHeight == 0) {
                print("Error: La imagen decodificada $assetPath tiene dimensiones cero.");
                // Fallback si las dimensiones son cero
                annotationOptionsList.add(
                    mapbox.PointAnnotationOptions(
                      geometry: mapbox.Point(coordinates: mapbox.Position.named(lng: photo['lon'], lat: photo['lat'])),
                      iconColor: Colors.orange.toARGB32(), // Color de advertencia
                      iconSize: 1.0,
                      textField: "Dim Zero",
                    )
                );
                continue; // Pasa a la siguiente foto
              }


              final String styleImageId = "marker_icon_$taxonOrder";

              await mapboxMap!.style.addStyleImage(
                  styleImageId,
                  1.0, // scaleFactor
                  mapbox.MbxImage(width: imageWidth, height: imageHeight, data: imageBytes), // Usa dimensiones decodificadas
                  false, // sdf
                  [],
                  [],
                  null
              );

              _loadedMarkerImageIds[assetPath] = styleImageId;
              markerIconId = styleImageId;
              print("Imagen $assetPath (w:$imageWidth, h:$imageHeight) cargada y añadida al estilo con ID: $markerIconId");
            } else {
              print("Fallback: No se pudo cargar la imagen $assetPath. Usando marcador por defecto.");
              annotationOptionsList.add(
                  mapbox.PointAnnotationOptions(
                    geometry: mapbox.Point(coordinates: mapbox.Position.named(lng: photo['lon'], lat: photo['lat'])),
                    iconColor: AppColors.warning.toARGB32(),
                    iconSize: 1.0,
                  )
              );
              continue;
            }
          }

          annotationOptionsList.add(
              mapbox.PointAnnotationOptions(
                geometry: mapbox.Point(coordinates: mapbox.Position.named(lng: photo['lon'], lat: photo['lat'])),
                iconImage: markerIconId,
                iconSize: 0.4,
              )
          );

        } else {
          print("No hay taxonOrder para photoId: ${photo['photoId']}. Usando marcador de texto por defecto.");
          annotationOptionsList.add(
              mapbox.PointAnnotationOptions(
                geometry: mapbox.Point(coordinates: mapbox.Position.named(lng: photo['lon'], lat: photo['lat'])),
                textField: 'Registro',
                textSize: 10.0,
                textColor: Colors.black.toARGB32(),
                iconColor: AppColors.buttonGreen2.toARGB32(),
                iconSize: 1.0,
              )
          );
        }
      }

      if (annotationOptionsList.isNotEmpty) {
        final createdAnnotationsResult = await pointAnnotationManager!.createMulti(annotationOptionsList);
        _createdAnnotations = createdAnnotationsResult
            .where((annotation) => annotation != null)
            .map((annotation) => annotation!)
            .toList();
        print('Marcadores con imágenes de assets agregados: ${_createdAnnotations.length}');
        if (_createdAnnotations.isEmpty && annotationOptionsList.isNotEmpty) {
          print("ALERTA: Se crearon opciones de anotación pero no se generaron anotaciones en el mapa.");
        }
      } else if (_userPhotos.isNotEmpty) {
        print("ALERTA: Había fotos de usuario pero no se generaron opciones de anotación.");
      }


    } catch (e) {
      print('Error agregando marcadores con imágenes de assets: $e');
      if (e is PlatformException) {
        print('Error de plataforma específico: Código: ${e.code}, Mensaje: ${e.message}, Detalles: ${e.details}');
      }
    }
  }

  void _onAnnotationTapped(mapbox.PointAnnotation annotation) {
    try {
      // Encontrar la foto correspondiente por índice
      final annotationIndex = _createdAnnotations.indexOf(annotation);
      
      if (annotationIndex >= 0 && annotationIndex < _userPhotos.length) {
        final photo = _userPhotos[annotationIndex];
        
        // Navegar al detalle del registro
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => DetalleRegistro(registro: photo),
          ),
        ).then((result) {
          // Si se modificó o eliminó el registro, recargar los datos
          if (result == true) {
            _loadUserPhotos();
          }
        });
      }
    } catch (e) {
      print('Error al manejar tap en marcador: $e');
    }
  }

  void _onMapCreated(mapbox.MapboxMap mapboxMap) async {
    print('Mapa creado, configurando...');
    this.mapboxMap = mapboxMap;
    
    try {
      // Crear el manager de anotaciones
      pointAnnotationManager = await mapboxMap.annotations.createPointAnnotationManager();
      print('PointAnnotationManager creado');
      
      // Configurar listener para taps en marcadores usando la API que funciona
      pointAnnotationManager!.addOnPointAnnotationClickListener(_AnnotationClickListener(this));
      
      // Habilitar componente de ubicación
      if (_hasLocationPermission) {
        await mapboxMap.location.updateSettings(
          mapbox.LocationComponentSettings(
            enabled: true,
            puckBearingEnabled: true,
            pulsingEnabled: true, // Añadir pulsación para mejor visibilidad
            locationPuck: mapbox.LocationPuck(
              locationPuck2D: mapbox.LocationPuck2D(
                bearingImage: null,
                shadowImage: null,
                topImage: null,
                // El puck por defecto será más visible
              ),
            ),
          ),
        );
        print('Componente de ubicación habilitado');
      }
      
      // Agregar marcadores si ya están cargados
      if (_userPhotos.isNotEmpty) {
        await _addPhotoMarkers();
      }
      
      // Agregar marcador de ubicación actual si está disponible
      if (_currentPosition != null) {
        await _addCurrentLocationMarker();
      }
      
      // Centrar en ubicación actual si está disponible
      if (_currentPosition != null) {
        await _centerOnCurrentLocation();
      }
      
      print('Mapa completamente configurado');
      
    } catch (e) {
      print('Error configurando mapa: $e');
      setState(() {
        _mapError = e.toString();
      });
    }
  }

  Future<void> _addCurrentLocationMarker() async {
    if (_currentPosition == null || pointAnnotationManager == null || mapboxMap == null) return;
    
    try {
      // Eliminar marcador anterior si existe
      if (_currentLocationAnnotation != null) {
        await pointAnnotationManager!.delete(_currentLocationAnnotation!);
        _currentLocationAnnotation = null;
      }
      
      // Crear un marcador distintivo para la ubicación actual
      final pointAnnotationOptions = mapbox.PointAnnotationOptions(
        geometry: mapbox.Point(
          coordinates: mapbox.Position.named(
            lng: _currentPosition!.longitude,
            lat: _currentPosition!.latitude,
          ),
        ),
        iconColor: const Color.fromARGB(255, 19, 21, 173).value,
        iconSize: 5.0,
      );
      
      _currentLocationAnnotation = await pointAnnotationManager!.create(pointAnnotationOptions);
      print('Marcador de ubicación actual agregado/actualizado');
    } catch (e) {
      print('Error agregando marcador de ubicación actual: $e');
    }
  }

  Future<void> _centerOnCurrentLocation() async {
    if (_currentPosition != null && mapboxMap != null) {
      try {
        final cameraOptions = mapbox.CameraOptions(
          center: mapbox.Point(
            coordinates: mapbox.Position.named(
              lng: _currentPosition!.longitude,
              lat: _currentPosition!.latitude,
            ),
          ),
          zoom: 15.0,
          bearing: 0,
          pitch: 0,
        );
        
        await mapboxMap!.flyTo(cameraOptions, mapbox.MapAnimationOptions(duration: 2000));
        print('Cámara centrada en ubicación actual');
      } catch (e) {
        print('Error centrando cámara: $e');
      }
    } else if (!_hasLocationPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permisos de ubicación no concedidos'),
          backgroundColor: AppColors.warning,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ubicación no disponible'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cámara inicial basada ÚNICAMENTE en ubicación actual del usuario
    mapbox.CameraOptions initialCamera = mapbox.CameraOptions(
      center: _currentPosition != null
          ? mapbox.Point(
              coordinates: mapbox.Position.named(
                lng: _currentPosition!.longitude,
                lat: _currentPosition!.latitude,
              ),
            )
          : mapbox.Point(
              coordinates: mapbox.Position.named(lng: 0, lat: 0), // Ubicación temporal hasta obtener la real
            ),
      zoom: _currentPosition != null ? 15.0 : 2.0, // Zoom bajo si no hay ubicación
      bearing: 0,
      pitch: 0,
    );

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: AppColors.backgroundPrimary,
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
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new),
                      color: AppColors.textWhite,
                    ),
                    Expanded(
                      child: Text(
                        'Mapa Interactivo',
                        style: const TextStyle(
                          color: AppColors.textWhite,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      color: AppColors.textWhite,
                      onPressed: _isLoading ? null : () async {
                        setState(() => _isLoading = true);
                        await _loadUserPhotos();
                      },
                    ),
                  ],
                ),
              ),
              // Mapa
              Expanded(
                child: Stack(
                  children: [
                    // Widget del mapa
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      child: mapbox.MapWidget(
                        key: const ValueKey("mapbox_map"),
                        cameraOptions: initialCamera,
                        onMapCreated: _onMapCreated,
                        styleUri: mapbox.MapboxStyles.OUTDOORS,
                      ),
                    ),
                    
                    // Indicador de error del mapa
                    if (_mapError != null)
                      Container(
                        color: Colors.red.withValues(alpha: 0.8),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.white, size: 50),
                              const SizedBox(height: 16),
                              Text(
                                'Error del mapa: $_mapError',
                                style: const TextStyle(color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    // Indicador de carga
                    if (_isLoading)
                      Container(
                        color: Colors.black26,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.buttonGreen2,
                          ),
                        ),
                      ),
                    
                    // Botón de ubicación
                    Positioned(
                      bottom: 24,
                      right: 24,
                      child: FloatingActionButton(
                        backgroundColor: AppColors.buttonGreen2,
                        onPressed: () async {
                          // Obtener ubicación actualizada y centrar
                          await _getCurrentLocation();
                        },
                        child: Icon(_hasLocationPermission ? Icons.my_location : Icons.location_disabled),
                      ),
                    ),
                  ],
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
    // No necesitamos limpiar listeners con esta API
    super.dispose();
  }
}

// Añadir la clase listener al final del archivo
class _AnnotationClickListener extends mapbox.OnPointAnnotationClickListener {
  final _MapaIterativoScreenState mapState;

  _AnnotationClickListener(this.mapState);

  @override
  void onPointAnnotationClick(mapbox.PointAnnotation annotation) {
    mapState._onAnnotationTapped(annotation);
  }
}