import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:biodetect/themes.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

class LocationPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? taxonOrder; // Nuevo parámetro para el orden taxonómico

  const LocationPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.taxonOrder,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  mapbox.MapboxMap? mapboxMap;
  mapbox.PointAnnotationManager? pointAnnotationManager;
  mapbox.PointAnnotation? selectedLocationAnnotation;
  
  double? selectedLatitude;
  double? selectedLongitude;
  bool _isLoading = true;
  bool _hasSelectedLocation = false;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    // Si hay coordenadas iniciales, usarlas
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      selectedLatitude = widget.initialLatitude;
      selectedLongitude = widget.initialLongitude;
      _hasSelectedLocation = true;
    }
  }

  void _onMapCreated(mapbox.MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;
    
    try {
      print('Mapa creado, configurando annotations...');
      
      // Crear el manager de anotaciones
      pointAnnotationManager = await mapboxMap.annotations.createPointAnnotationManager();
      print('PointAnnotationManager creado exitosamente');
      
      // Cargar ícono de marcador personalizado
      await _loadMarkerIcon();
      
      // Si hay coordenadas iniciales, agregar marcador
      if (selectedLatitude != null && selectedLongitude != null) {
        print('Agregando marcador inicial en: $selectedLatitude, $selectedLongitude');
        await _addLocationMarker(selectedLatitude!, selectedLongitude!);
      }
      
      setState(() {
        _isLoading = false;
      });
      
    } catch (e) {
      print('Error configurando mapa: $e');
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

  Future<void> _loadMarkerIcon() async {
    if (mapboxMap == null) return;
    
    try {
      // Determinar el asset path basado en el orden taxonómico
      String assetPath;
      String markerIconId;
      
      if (widget.taxonOrder != null && widget.taxonOrder!.isNotEmpty) {
        // Convertir orden taxonómico a formato de archivo (como en mapa.dart)
        String formattedTaxonOrder = widget.taxonOrder!.toLowerCase().replaceAll(' ', '_');
        assetPath = 'assets/map_markers/$formattedTaxonOrder.png';
        markerIconId = "location_picker_marker_$formattedTaxonOrder";
        print('Cargando marcador para orden taxonómico: $formattedTaxonOrder');
      } else {
        // Usar marcador por defecto si no hay orden taxonómico
        assetPath = 'assets/map_markers/araneae.png';
        markerIconId = "location_picker_marker_default";
        print('Usando marcador por defecto (araneae)');
      }
      
      // Cargar imagen usando la misma función que mapa.dart
      Uint8List? imageBytes = await _loadAssetBytes(assetPath);
      if (imageBytes != null) {
        // Decodificar imagen para obtener dimensiones (igual que mapa.dart)
        img.Image? decodedImage = img.decodeImage(imageBytes);
        if (decodedImage == null) {
          print("Error: No se pudo decodificar la imagen desde los bytes para $assetPath.");
          // Intentar con marcador por defecto si falla
          await _loadDefaultMarkerIcon();
          return;
        }
        
        int imageWidth = decodedImage.width;
        int imageHeight = decodedImage.height;
        
        if (imageWidth == 0 || imageHeight == 0) {
          print("Error: La imagen decodificada $assetPath tiene dimensiones cero.");
          // Intentar con marcador por defecto si falla
          await _loadDefaultMarkerIcon();
          return;
        }
        
        print("Imagen cargada: $assetPath w:$imageWidth, h:$imageHeight");
        
        // Agregar imagen al estilo del mapa (exactamente como mapa.dart)
        await mapboxMap!.style.addStyleImage(
          markerIconId,
          1.0, // scaleFactor
          mapbox.MbxImage(width: imageWidth, height: imageHeight, data: imageBytes),
          false, // sdf
          [], // stretchX
          [], // stretchY  
          null // content
        );
        
        print('Ícono de marcador cargado exitosamente con ID: $markerIconId');
      } else {
        print("Error: No se pudieron cargar los bytes de la imagen $assetPath");
        // Intentar con marcador por defecto si falla
        await _loadDefaultMarkerIcon();
      }
      
    } catch (e) {
      print('Error cargando ícono de marcador: $e');
      // Intentar con marcador por defecto si falla
      await _loadDefaultMarkerIcon();
    }
  }

  Future<void> _loadDefaultMarkerIcon() async {
    if (mapboxMap == null) return;
    
    try {
      const String assetPath = 'assets/map_markers/araneae.png';
      const String markerIconId = "location_picker_marker_default";
      
      Uint8List? imageBytes = await _loadAssetBytes(assetPath);
      if (imageBytes != null) {
        img.Image? decodedImage = img.decodeImage(imageBytes);
        if (decodedImage != null) {
          int imageWidth = decodedImage.width;
          int imageHeight = decodedImage.height;
          
          await mapboxMap!.style.addStyleImage(
            markerIconId,
            1.0,
            mapbox.MbxImage(width: imageWidth, height: imageHeight, data: imageBytes),
            false,
            [],
            [],
            null
          );
          
          print('Marcador por defecto cargado exitosamente');
        }
      }
    } catch (e) {
      print('Error cargando marcador por defecto: $e');
    }
  }

  Future<void> _onMapLongPress(double latitude, double longitude) async {
    print('Usuario tocó en: $latitude, $longitude');
    
    // Actualizar coordenadas seleccionadas
    setState(() {
      selectedLatitude = latitude;
      selectedLongitude = longitude;
      _hasSelectedLocation = true;
    });
    
    // Agregar nuevo marcador (incluye eliminación de anteriores)
    print('Agregando nuevo marcador...');
    await _addLocationMarker(latitude, longitude);
    
    // Mostrar feedback visual
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ubicación seleccionada: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
          ),
          backgroundColor: AppColors.buttonGreen2,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _getMarkerIconId() {
    if (widget.taxonOrder != null && widget.taxonOrder!.isNotEmpty) {
      String formattedTaxonOrder = widget.taxonOrder!.toLowerCase().replaceAll(' ', '_');
      return "location_picker_marker_$formattedTaxonOrder";
    } else {
      return "location_picker_marker_default";
    }
  }

  Future<void> _addLocationMarker(double latitude, double longitude) async {
    if (pointAnnotationManager == null) return;
    
    try {
      // Eliminar marcador anterior si existe
      if (selectedLocationAnnotation != null) {
        await pointAnnotationManager!.delete(selectedLocationAnnotation!);
        selectedLocationAnnotation = null;
        print('Marcador anterior eliminado');
      }
      
      // Obtener el ID del marcador correspondiente al orden taxonómico
      String markerIconId = _getMarkerIconId();
      
      // Crear marcador usando el ícono personalizado cargado (igual que mapa.dart)
      final pointAnnotationOptions = mapbox.PointAnnotationOptions(
        geometry: mapbox.Point(
          coordinates: mapbox.Position.named(
            lng: longitude,
            lat: latitude,
          ),
        ),
        iconImage: markerIconId, // Usar el ícono correspondiente al orden
        iconSize: 0.4, // Mismo tamaño que en mapa.dart
      );
      
      selectedLocationAnnotation = await pointAnnotationManager!.create(pointAnnotationOptions);
      print('Marcador creado exitosamente en: $latitude, $longitude con ícono: $markerIconId');
      
      // Centrar el mapa en la nueva ubicación
      if (mapboxMap != null) {
        await mapboxMap!.setCamera(mapbox.CameraOptions(
          center: mapbox.Point(
            coordinates: mapbox.Position.named(
              lng: longitude,
              lat: latitude,
            ),
          ),
          zoom: 16.0,
        ));
      }
      
    } catch (e) {
      print('Error creando marcador: $e');
      
      // Fallback: crear marcador simple sin ícono
      try {
        final fallbackOptions = mapbox.PointAnnotationOptions(
          geometry: mapbox.Point(
            coordinates: mapbox.Position.named(
              lng: longitude,
              lat: latitude,
            ),
          ),
          iconColor: AppColors.buttonGreen2.value,
          iconSize: 3.0,
        );
        
        selectedLocationAnnotation = await pointAnnotationManager!.create(fallbackOptions);
        print('Marcador fallback creado en: $latitude, $longitude');
        
      } catch (e2) {
        print('Error con marcador fallback: $e2');
      }
    }
  }

  void _confirmSelection() {
    if (_isNavigating) return;
    
    // Verificar que tengamos coordenadas válidas
    final lat = selectedLatitude;
    final lon = selectedLongitude;
    
    if (lat != null && lon != null) {
      setState(() {
        _isNavigating = true;
      });
      
      // Crear el mapa con tipos explícitos
      final Map<String, double> result = {
        'latitude': lat,
        'longitude': lon,
      };
      
      Navigator.of(context).pop(result);
    }
  }

  void _cancelSelection() {
    if (_isNavigating) return;
    
    setState(() {
      _isNavigating = true;
    });
    
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Determinar cámara inicial
    final initialCamera = mapbox.CameraOptions(
      center: mapbox.Point(
        coordinates: mapbox.Position.named(
          lng: selectedLongitude ?? -99.1332,
          lat: selectedLatitude ?? 19.4326,
        ),
      ),
      zoom: selectedLatitude != null && selectedLongitude != null ? 15.0 : 10.0,
      bearing: 0,
      pitch: 0,
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Stack(
          children: [
            // Mapa ocupando toda la pantalla
            mapbox.MapWidget(
              key: const ValueKey("location_picker_map"),
              cameraOptions: initialCamera,
              onMapCreated: _onMapCreated,
              styleUri: mapbox.MapboxStyles.OUTDOORS,
              onTapListener: (context) async {
                // Obtener las coordenadas del punto tocado
                final point = context.point;
                final latitude = point.coordinates.lat.toDouble();
                final longitude = point.coordinates.lng.toDouble();
                await _onMapLongPress(latitude, longitude);
              },
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
            
            // Botón de regresar (esquina superior izquierda)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.backgroundCard,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new),
                  color: AppColors.textWhite,
                  onPressed: _isNavigating ? null : _cancelSelection,
                  iconSize: 24,
                ),
              ),
            ),
            
            // Instrucciones (parte superior)
            Positioned(
              top: 80,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.backgroundCard.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  'Toca en el mapa para seleccionar una ubicación',
                  style: const TextStyle(
                    color: AppColors.textWhite,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            
            // Información de coordenadas (si hay una ubicación seleccionada)
            // if (_hasSelectedLocation && selectedLatitude != null && selectedLongitude != null)
            //   Positioned(
            //     top: 140,
            //     left: 16,
            //     right: 16,
            //     child: Container(
            //       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            //       decoration: BoxDecoration(
            //         color: AppColors.buttonGreen2.withValues(alpha: 0.9),
            //         borderRadius: BorderRadius.circular(8),
            //       ),
            //       child: Text(
            //         'Coordenadas: ${selectedLatitude!.toStringAsFixed(6)}°, ${selectedLongitude!.toStringAsFixed(6)}°',
            //         style: const TextStyle(
            //           color: AppColors.textBlack,
            //           fontSize: 12,
            //           fontWeight: FontWeight.bold,
            //         ),
            //         textAlign: TextAlign.center,
            //       ),
            //     ),
            //   ),
            
            // Botón de guardar (parte inferior, solo si hay ubicación seleccionada)
            if (_hasSelectedLocation)
              Positioned(
                bottom: 30,
                left: 20,
                right: 20,
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.location_on, size: 24),
                    label: const Text(
                      'Guardar Ubicación',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.buttonGreen2,
                      foregroundColor: AppColors.textBlack,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _isNavigating ? null : _confirmSelection,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}