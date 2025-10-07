import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:biodetect/themes.dart';
import 'package:biodetect/views/registers/detalle_registro.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

class BitacoraMapScreen extends StatefulWidget {
  final List<Map<String, dynamic>> registros;
  final String bitacoraTitle;

  const BitacoraMapScreen({
    super.key,
    required this.registros,
    required this.bitacoraTitle,
  });

  @override
  State<BitacoraMapScreen> createState() => _BitacoraMapScreenState();
}

class _BitacoraMapScreenState extends State<BitacoraMapScreen> {
  mapbox.MapboxMap? mapboxMap;
  mapbox.PointAnnotationManager? pointAnnotationManager;
  bool _isLoading = true;
  final List<mapbox.PointAnnotation> _createdAnnotations = [];
  final Map<String, String> _loadedMarkerImageIds = {};
  final Map<mapbox.PointAnnotation, Map<String, dynamic>> _annotationToRegistro = {};

  @override
  void initState() {
    super.initState();
  }

  void _onMapCreated(mapbox.MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;
    
    try {
      print('Mapa de bitácora creado, configurando annotations...');
      
      pointAnnotationManager = await mapboxMap.annotations.createPointAnnotationManager();
      print('PointAnnotationManager creado exitosamente');
      
      // Configurar listener para taps en marcadores
      // ignore: deprecated_member_use
      pointAnnotationManager!.addOnPointAnnotationClickListener(_BitacoraAnnotationClickListener(this));
      
      // Agregar marcadores de todos los registros
      await _addRegistroMarkers();
      
      // Centrar el mapa para mostrar todos los puntos
      await _centerMapToShowAllPoints();
      
      setState(() {
        _isLoading = false;
      });
      
    } catch (e) {
      print('Error configurando mapa de bitácora: $e');
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

  Future<void> _addRegistroMarkers() async {
    if (pointAnnotationManager == null || mapboxMap == null) return;

    try {
      // Limpiar marcadores anteriores
      if (_createdAnnotations.isNotEmpty) {
        await pointAnnotationManager!.deleteAll();
        _createdAnnotations.clear();
        _annotationToRegistro.clear();
      }

      List<mapbox.PointAnnotationOptions> annotationOptionsList = [];

      for (int i = 0; i < widget.registros.length; i++) {
        final registro = widget.registros[i];
        
        // Verificar que tenga coordenadas válidas
        if (registro['coords'] == null) continue;
        
        final lat = registro['coords']['x'];
        final lon = registro['coords']['y'];
        
        if (lat == null || lon == null || (lat == 0 && lon == 0)) continue;

        String? taxonOrder = registro['taxonOrder']?.toString().toLowerCase().replaceAll(' ', '_');
        String markerIconId;

        if (taxonOrder != null && taxonOrder.isNotEmpty) {
          final String assetPath = 'assets/map_markers/$taxonOrder.png';

          if (_loadedMarkerImageIds.containsKey(assetPath)) {
            markerIconId = _loadedMarkerImageIds[assetPath]!;
            print("Usando imagen de marcador cacheada para $taxonOrder con ID: $markerIconId");
          } else {
            Uint8List? imageBytes = await _loadAssetBytes(assetPath);
            if (imageBytes != null) {
              // Decodificar imagen para obtener dimensiones
              img.Image? decodedImage = img.decodeImage(imageBytes);
              if (decodedImage == null) {
                print("Error: No se pudo decodificar la imagen desde los bytes para $assetPath.");
                // Fallback si la decodificación falla
                annotationOptionsList.add(
                  mapbox.PointAnnotationOptions(
                    geometry: mapbox.Point(coordinates: mapbox.Position.named(lng: lon, lat: lat)),
                    iconColor: Colors.red.toARGB32(),
                    iconSize: 1.0,
                  )
                );
                continue;
              }
              
              int imageWidth = decodedImage.width;
              int imageHeight = decodedImage.height;

              if (imageWidth == 0 || imageHeight == 0) {
                print("Error: La imagen decodificada $assetPath tiene dimensiones cero.");
                // Fallback si las dimensiones son cero
                annotationOptionsList.add(
                  mapbox.PointAnnotationOptions(
                    geometry: mapbox.Point(coordinates: mapbox.Position.named(lng: lon, lat: lat)),
                    iconColor: Colors.orange.toARGB32(),
                    iconSize: 1.0,
                  )
                );
                continue;
              }

              final String styleImageId = "bitacora_marker_icon_$taxonOrder";

              await mapboxMap!.style.addStyleImage(
                styleImageId,
                1.0, // scaleFactor
                mapbox.MbxImage(width: imageWidth, height: imageHeight, data: imageBytes),
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
                  geometry: mapbox.Point(coordinates: mapbox.Position.named(lng: lon, lat: lat)),
                  iconColor: AppColors.warning.toARGB32(),
                  iconSize: 1.0,
                )
              );
              continue;
            }
          }

          annotationOptionsList.add(
            mapbox.PointAnnotationOptions(
              geometry: mapbox.Point(coordinates: mapbox.Position.named(lng: lon, lat: lat)),
              iconImage: markerIconId,
              iconSize: 0.4,
            )
          );

        } else {
          print("No hay taxonOrder para registro. Usando marcador de texto por defecto.");
          annotationOptionsList.add(
            mapbox.PointAnnotationOptions(
              geometry: mapbox.Point(coordinates: mapbox.Position.named(lng: lon, lat: lat)),
              iconColor: AppColors.buttonGreen2.toARGB32(),
              iconSize: 1.0,
            )
          );
        }
      }

      if (annotationOptionsList.isNotEmpty) {
        final annotations = await pointAnnotationManager!.createMulti(annotationOptionsList);
        final validAnnotations = annotations.whereType<mapbox.PointAnnotation>().toList();
        _createdAnnotations.addAll(validAnnotations);
        
        // Mapear cada anotación con su registro correspondiente
        int annotationIndex = 0;
        for (int i = 0; i < widget.registros.length; i++) {
          final registro = widget.registros[i];
          
          // Verificar que tenga coordenadas válidas (misma lógica que arriba)
          if (registro['coords'] == null) continue;
          final lat = registro['coords']['x'];
          final lon = registro['coords']['y'];
          if (lat == null || lon == null || (lat == 0 && lon == 0)) continue;
          
          // Mapear la anotación con el registro
          if (annotationIndex < validAnnotations.length) {
            _annotationToRegistro[validAnnotations[annotationIndex]] = registro;
            annotationIndex++;
          }
        }
        
        print('Se agregaron ${validAnnotations.length} marcadores al mapa de bitácora');
      }

    } catch (e) {
      print('Error agregando marcadores de bitácora: $e');
    }
  }

  Future<void> _centerMapToShowAllPoints() async {
    if (mapboxMap == null || widget.registros.isEmpty) return;

    try {
      // Filtrar registros con coordenadas válidas
      final registrosConCoords = widget.registros.where((registro) {
        if (registro['coords'] == null) return false;
        final lat = registro['coords']['x'];
        final lon = registro['coords']['y'];
        return lat != null && lon != null && !(lat == 0 && lon == 0);
      }).toList();

      if (registrosConCoords.isEmpty) return;

      if (registrosConCoords.length == 1) {
        // Si solo hay un punto, centrar en él
        final registro = registrosConCoords.first;
        final lat = registro['coords']['x'];
        final lon = registro['coords']['y'];
        
        await mapboxMap!.setCamera(mapbox.CameraOptions(
          center: mapbox.Point(
            coordinates: mapbox.Position.named(lng: lon, lat: lat),
          ),
          zoom: 16.0,
        ));
      } else {
        // Si hay múltiples puntos, calcular los límites
        double minLat = registrosConCoords.first['coords']['x'];
        double maxLat = registrosConCoords.first['coords']['x'];
        double minLon = registrosConCoords.first['coords']['y'];
        double maxLon = registrosConCoords.first['coords']['y'];

        for (final registro in registrosConCoords) {
          final lat = registro['coords']['x'];
          final lon = registro['coords']['y'];
          
          if (lat < minLat) minLat = lat;
          if (lat > maxLat) maxLat = lat;
          if (lon < minLon) minLon = lon;
          if (lon > maxLon) maxLon = lon;
        }

        // Calcular el centro y el zoom apropiado
        final centerLat = (minLat + maxLat) / 2;
        final centerLon = (minLon + maxLon) / 2;
        
        // Calcular zoom basado en la distancia
        final latDiff = maxLat - minLat;
        final lonDiff = maxLon - minLon;
        final maxDiff = latDiff > lonDiff ? latDiff : lonDiff;
        
        double zoom = 10.0;
        if (maxDiff < 0.01) {
          zoom = 14.0;
        } else if (maxDiff < 0.1) {
          zoom = 10.0;
        } else if (maxDiff < 1.0) {
          zoom = 6.0;
        } else {
          zoom = 4.0;
        }

        await mapboxMap!.setCamera(mapbox.CameraOptions(
          center: mapbox.Point(
            coordinates: mapbox.Position.named(lng: centerLon, lat: centerLat),
          ),
          zoom: zoom,
        ));
      }

    } catch (e) {
      print('Error centrando mapa: $e');
    }
  }

  void _onAnnotationTapped(mapbox.PointAnnotation annotation) {
    try {
      // Buscar el registro correspondiente en el mapeo
      final registro = _annotationToRegistro[annotation];
      
      if (registro != null) {
        // Navegar al detalle del registro
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => DetalleRegistro(registro: registro),
          ),
        );
      } else {
        print('No se encontró registro para la anotación');
      }
    } catch (e) {
      print('Error al manejar tap en marcador de bitácora: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Contar registros con coordenadas válidas
    final registrosConCoords = widget.registros.where((registro) {
      if (registro['coords'] == null) return false;
      final lat = registro['coords']['x'];
      final lon = registro['coords']['y'];
      return lat != null && lon != null && !(lat == 0 && lon == 0);
    }).length;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Stack(
          children: [
            // Mapa ocupando toda la pantalla
            mapbox.MapWidget(
              key: const ValueKey("bitacora_map"),
              cameraOptions: mapbox.CameraOptions(
                center: mapbox.Point(
                  coordinates: mapbox.Position.named(lng: -99.1332, lat: 19.4326),
                ),
                zoom: 10.0,
              ),
              onMapCreated: _onMapCreated,
              styleUri: mapbox.MapboxStyles.OUTDOORS,
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
            
            // Header flotante
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.backgroundCard.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.backgroundPrimary,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new),
                        color: AppColors.textWhite,
                        onPressed: () => Navigator.of(context).pop(),
                        iconSize: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.bitacoraTitle,
                            style: const TextStyle(
                              color: AppColors.textWhite,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$registrosConCoords ubicaciones en el mapa',
                            style: const TextStyle(
                              color: AppColors.textPaleGreen,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Información en la parte inferior
            if (!_isLoading && registrosConCoords == 0)
              Positioned(
                bottom: 30,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundCard.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_off,
                        color: AppColors.textPaleGreen,
                        size: 48,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Sin ubicaciones disponibles',
                        style: TextStyle(
                          color: AppColors.textWhite,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Los registros de esta bitácora no tienen coordenadas GPS',
                        style: TextStyle(
                          color: AppColors.textPaleGreen,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
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

  @override
  void dispose() {
    super.dispose();
  }
}

// Clase listener para manejar clicks en marcadores
// ignore: deprecated_member_use
class _BitacoraAnnotationClickListener extends mapbox.OnPointAnnotationClickListener {
  final _BitacoraMapScreenState mapState;

  _BitacoraAnnotationClickListener(this.mapState);

  @override
  void onPointAnnotationClick(mapbox.PointAnnotation annotation) {
    mapState._onAnnotationTapped(annotation);
  }
}