import 'package:biodetect/themes.dart';
import 'package:biodetect/services/bitacora_service.dart';
import 'package:biodetect/services/pdf_service.dart';
import 'package:biodetect/views/notes/bitacora_map_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

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

  // Verificar si el usuario actual es el propietario de la bitácora
  bool _isCurrentUserOwner() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;
    
    // Verificar por UID del usuario actual vs el authorId de la bitácora
    final authorId = widget.bitacoraData['authorId'];
    if (authorId != null) {
      return currentUser.uid == authorId;
    }
    
    // Verificar por email si no hay authorId
    final authorEmail = widget.bitacoraData['authorEmail'];
    if (authorEmail != null) {
      return currentUser.email == authorEmail;
    }
    
    // Como alternativa, verificar por nombre del autor si coincide con el display name
    if (currentUser.displayName != null && currentUser.displayName!.isNotEmpty) {
      return currentUser.displayName == _authorName;
    }
    
    return false;
  }

  // Verificar si hay registros con ubicación privada
  bool _hasPrivateLocationRegistros() {
    return _registros.any((registro) {
      final locationVisibility = registro['locationVisibility'] ?? 'Privada';
      return locationVisibility == 'Privada';
    });
  }

  // Mostrar diálogo para elegir opciones de PDF
  Future<String?> _showPdfOptionsDialog(String action) async {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.backgroundCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Opciones de ubicación',
            style: const TextStyle(
              color: AppColors.textWhite,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tu bitácora contiene registros con ubicación privada. ¿Cómo deseas ${action.toLowerCase()} el PDF?',
                style: const TextStyle(
                  color: AppColors.textPaleGreen,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              
              // Opción 1: Respetar ajustes
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.buttonGreen2, width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  leading: const Icon(
                    Icons.settings,
                    color: AppColors.buttonGreen2,
                    size: 20,
                  ),
                  title: const Text(
                    'Respetar ajustes de privacidad',
                    style: TextStyle(
                      color: AppColors.textWhite,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'Solo incluir coordenadas de registros públicos',
                    style: TextStyle(
                      color: AppColors.textPaleGreen,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () => Navigator.of(context).pop('respetar'),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Opción 2: Todas las ubicaciones públicas
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.warning, width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  leading: const Icon(
                    Icons.public,
                    color: AppColors.warning,
                    size: 20,
                  ),
                  title: const Text(
                    'Hacer todas las ubicaciones públicas',
                    style: TextStyle(
                      color: AppColors.textWhite,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'Incluir coordenadas de todos los registros',
                    style: TextStyle(
                      color: AppColors.textPaleGreen,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () => Navigator.of(context).pop('publicas'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancelar',
                style: TextStyle(
                  color: AppColors.textPaleGreen,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        );
      },
    );
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

    // Verificar si es el propietario y tiene registros privados
    // Solo mostrar diálogo si es el propietario y hay registros con ubicación privada
    String? opcionSeleccionada;
    if (_isCurrentUserOwner() && _hasPrivateLocationRegistros()) {
      opcionSeleccionada = await _showPdfOptionsDialog('Guardar');
      if (opcionSeleccionada == null) {
        // Usuario canceló el diálogo
        return;
      }
    }

    setState(() => _isGeneratingPdf = true);

    try {
      final titulo = widget.bitacoraData['title'] ?? 'Sin título';
      final fileName = 'BioDetect_${titulo.replaceAll(' ', '_')}';
      
      // Determinar qué registros usar según la opción seleccionada
      List<Map<String, dynamic>> registrosParaPdf;
      if (opcionSeleccionada == 'publicas') {
        // Crear una copia de los registros con todas las ubicaciones como públicas
        registrosParaPdf = _registros.map((registro) {
          final registroCopia = Map<String, dynamic>.from(registro);
          registroCopia['locationVisibility'] = 'Pública';
          return registroCopia;
        }).toList();
      } else {
        // Usar registros originales (respetando ajustes de privacidad)
        registrosParaPdf = _registros;
      }
      
      final pdfBytes = await PdfService.generateBitacoraPdf(
        bitacoraData: widget.bitacoraData,
        registros: registrosParaPdf,
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

    // Verificar si es el propietario y tiene registros privados
    // Solo mostrar diálogo si es el propietario y hay registros con ubicación privada
    String? opcionSeleccionada;
    if (_isCurrentUserOwner() && _hasPrivateLocationRegistros()) {
      opcionSeleccionada = await _showPdfOptionsDialog('Compartir');
      if (opcionSeleccionada == null) {
        // Usuario canceló el diálogo
        return;
      }
    }

    setState(() => _isSharing = true);

    try {
      final titulo = widget.bitacoraData['title'] ?? 'Sin título';
      final fileName = 'Bitacora_${titulo.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}';
      
      // Determinar qué registros usar según la opción seleccionada
      List<Map<String, dynamic>> registrosParaPdf;
      if (opcionSeleccionada == 'publicas') {
        // Crear una copia de los registros con todas las ubicaciones como públicas
        registrosParaPdf = _registros.map((registro) {
          final registroCopia = Map<String, dynamic>.from(registro);
          registroCopia['locationVisibility'] = 'Pública';
          return registroCopia;
        }).toList();
      } else {
        // Usar registros originales (respetando ajustes de privacidad)
        registrosParaPdf = _registros;
      }
      
      final pdfBytes = await PdfService.generateBitacoraPdf(
        bitacoraData: widget.bitacoraData,
        registros: registrosParaPdf,
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

  // Método para obtener registros para el mapa según si es propietario o no
  List<Map<String, dynamic>> _getRegistrosParaMapa() {
    if (_isCurrentUserOwner()) {
      // Si es el propietario, devolver todos los registros con coordenadas válidas
      return _registros.where((registro) {
        if (registro['coords'] == null) return false;
        
        final lat = registro['coords']['x'];
        final lon = registro['coords']['y'];
        
        return lat != null && lon != null && (lat != 0 || lon != 0);
      }).toList();
    } else {
      // Si no es el propietario, solo registros públicos (comportamiento anterior)
      return _getRegistrosConUbicacionPublica();
    }
  }

  // Método para obtener solo los registros con ubicación pública
  List<Map<String, dynamic>> _getRegistrosConUbicacionPublica() {
    return _registros.where((registro) {
      final locationVisibility = registro['locationVisibility'] ?? 'Privada';
      final isPublic = locationVisibility == 'Pública';
      
      // Verificar que además tenga coordenadas válidas
      if (!isPublic) return false;
      
      if (registro['coords'] == null) return false;
      
      final lat = registro['coords']['x'];
      final lon = registro['coords']['y'];
      
      return lat != null && lon != null && (lat != 0 || lon != 0);
    }).toList();
  }

  void _abrirMapaBitacora() {
    final titulo = widget.bitacoraData['title'] ?? 'Sin título';
    final registrosParaMapa = _getRegistrosParaMapa();
    
    // Mostrar mensaje informativo si es bitácora propia
    if (_isCurrentUserOwner()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.textBlack, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bitácora propia: mostrando todas las ubicaciones',
                  style: TextStyle(
                    color: AppColors.textBlack,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.buttonGreen2,
          duration: const Duration(seconds: 2),
        ),
      );
    }
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BitacoraMapScreen(
          registros: registrosParaMapa,
          bitacoraTitle: titulo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titulo = widget.bitacoraData['title'] ?? 'Sin título';
    final descripcion = widget.bitacoraData['description'] ?? 'Sin descripción';
    final fechaCreacion = _formatDate(widget.bitacoraData['createdAt']);
    final isPublic = widget.bitacoraData['isPublic'] ?? false;
    
    // Verificar si mostrar el botón del mapa
    final isOwner = _isCurrentUserOwner();
    final registrosParaMapa = _getRegistrosParaMapa();
    final mostrarBotonMapa = isOwner || registrosParaMapa.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary, // Cambiar de AppColors.deepGreen
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Botón de mapa - mostrar si es propietario O si hay registros públicos
          if (mostrarBotonMapa) ...[
            FloatingActionButton(
              backgroundColor: AppColors.buttonGreen2,
              foregroundColor: AppColors.textBlack,
              heroTag: "map_bitacora",
              onPressed: (_isGeneratingPdf || _isSharing) ? null : _abrirMapaBitacora,
              tooltip: isOwner ? 'Ver en mapa (todas las ubicaciones)' : 'Ver en mapa',
              child: const Icon(Icons.map_outlined),
            ),
            const SizedBox(width: 16),
          ],
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

  Widget _buildCoordsRow() {
    // Verificar la visibilidad de la ubicación - por defecto privada si no existe
    final locationVisibility = registro['locationVisibility'] ?? 'Privada';
    final isPublic = locationVisibility == 'Pública';
    
    String coordsText;
    Color iconColor;
    IconData iconData;
    
    if (!isPublic) {
      coordsText = 'No disponible';
      iconColor = AppColors.warning;
      iconData = Icons.lock;
    } else {
      // Si es pública, verificar si hay coordenadas válidas
      if (registro['coords'] == null) {
        coordsText = 'Sin coordenadas';
        iconColor = AppColors.textPaleGreen;
        iconData = Icons.location_off;
      } else {
        final lat = registro['coords']['x'];
        final lon = registro['coords']['y'];
        
        if (lat == null || lon == null || (lat == 0 && lon == 0)) {
          coordsText = 'Sin coordenadas';
          iconColor = AppColors.textPaleGreen;
          iconData = Icons.location_off;
        } else {
          coordsText = '${lat.toStringAsFixed(6)}°, ${lon.toStringAsFixed(6)}°';
          iconColor = AppColors.buttonGreen2;
          iconData = Icons.public;
        }
      }
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: RichText(
              text: const TextSpan(
                text: 'Coordenadas: ',
                style: TextStyle(
                  color: AppColors.buttonGreen2,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Icon(
                  iconData,
                  size: 16,
                  color: iconColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    coordsText,
                    style: const TextStyle(
                      color: AppColors.textWhite,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
            _buildCoordsRow(), // Usar el método personalizado para coordenadas
            
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

  // Método para descargar la imagen con metadatos usando MediaStore (Android)
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
        
        // Nuevo formato para bitácoras: BioDetect_Bitacora_Orden_photoId
        final fileName = 'BioDetect_Bitacora_${ordenClean}_$photoId';
        
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
              content: Text('✅ Imagen de bitácora: Galería → BioDetect → $claseClean\n'
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
    final metadata = _generateBitacoraMetadataContent(fileName, registro);
    
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

  // Generar contenido de metadatos específico para bitácoras
  String _generateBitacoraMetadataContent(String fileName, Map<String, dynamic> registro) {
    // Formatear coordenadas respetando la visibilidad
    String coordenadas = 'No disponibles';
    final locationVisibility = registro['locationVisibility'] ?? 'Privada';
    
    if (locationVisibility == 'Privada') {
      coordenadas = 'No disponible';
    } else if (registro['coords'] != null) {
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
=== METADATOS DE BITÁCORA BIODETECT ===
Archivo de imagen: $fileName.jpg
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
Visibilidad de ubicación: $locationVisibility
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