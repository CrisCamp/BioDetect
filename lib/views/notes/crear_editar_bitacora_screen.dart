import 'dart:io';
import 'dart:async';
import 'package:biodetect/themes.dart';
import 'package:biodetect/services/bitacora_service.dart';
import 'package:biodetect/views/notes/seleccionar_registros_screen.dart';
import 'package:flutter/material.dart';

class CrearEditarBitacoraScreen extends StatefulWidget {
  final String? bitacoraId; // null = crear nueva, no-null = editar
  final Map<String, dynamic>? bitacoraData; // datos existentes para editar

  const CrearEditarBitacoraScreen({
    super.key,
    this.bitacoraId,
    this.bitacoraData,
  });

  @override
  State<CrearEditarBitacoraScreen> createState() => _CrearEditarBitacoraScreenState();
}

class _CrearEditarBitacoraScreenState extends State<CrearEditarBitacoraScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  List<String> _selectedPhotoIds = [];
  List<Map<String, dynamic>> _selectedPhotos = [];
  bool _isPublic = false;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _hasInternet = true;
  Timer? _connectionCheckTimer;
  
  // Contador de caracteres para el título
  int _titleCharCount = 0;
  static const int _maxTitleCharacters = 30;
  
  // Contador de caracteres para la descripción
  int _descriptionCharCount = 0;
  static const int _maxDescriptionCharacters = 255;

  bool get _isEditing => widget.bitacoraId != null;

  @override
  void initState() {
    super.initState();
    _checkInternetConnection();
    _startPeriodicConnectionCheck();
    
    // Inicializar contadores de caracteres
    _titleCharCount = _titleController.text.length;
    _descriptionCharCount = _descriptionController.text.length;
    
    if (_isEditing && widget.bitacoraData != null) {
      _loadExistingData();
    }
  }

  @override
  void dispose() {
    _connectionCheckTimer?.cancel();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('dns.google');
      final hasConnection = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      
      if (mounted && _hasInternet != hasConnection) {
        setState(() {
          _hasInternet = hasConnection;
        });
        
        // Mostrar notificación solo cuando cambie el estado
        if (hasConnection) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.wifi, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Conexión a internet restablecida',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
              backgroundColor: AppColors.buttonGreen2,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.wifi_off, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Se perdió la conexión a internet',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
              backgroundColor: AppColors.warning,
              duration: Duration(seconds: 3),
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

  void _startPeriodicConnectionCheck() {
    // Verificar conexión cada 5 segundos para mayor responsividad
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        _checkInternetConnection();
      } else {
        timer.cancel();
      }
    });
  }

  void _loadExistingData() {
    final data = widget.bitacoraData!;
    final title = (data['title'] ?? '').toString().toUpperCase(); // Convertir a mayúsculas al cargar
    _titleController.text = title;
    _descriptionController.text = data['description'] ?? '';
    _isPublic = data['isPublic'] ?? false;
    _selectedPhotoIds = List<String>.from(data['selectedPhotos'] ?? []);
    
    // Actualizar contadores de caracteres
    _titleCharCount = title.length;
    _descriptionCharCount = _descriptionController.text.length;
    
    // Cargar fotos seleccionadas
    _loadSelectedPhotos();
  }

  Future<void> _loadSelectedPhotos() async {
    if (_selectedPhotoIds.isEmpty) return;
    
    setState(() => _isLoading = true);
    
    try {
      final photos = await BitacoraService.getPhotosByIds(_selectedPhotoIds);
      setState(() {
        _selectedPhotos = photos;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar fotos: $e'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateToSelectPhotos() async {
    final result = await Navigator.push<List<Map<String, dynamic>>>(
      context,
      MaterialPageRoute(
        builder: (context) => SeleccionarRegistrosScreen(
          selectedPhotoIds: _selectedPhotoIds,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedPhotos = result;
        _selectedPhotoIds = result.map((photo) => photo['photoId'] as String).toList();
      });
    }
  }

  /// SISTEMA DE VERIFICACIONES DE CONEXIÓN PARA CREACIÓN/ACTUALIZACIÓN DE BITÁCORAS:
  /// 
  /// Este método implementa múltiples verificaciones de conexión a internet durante todo el proceso
  /// para garantizar la integridad de los datos y evitar estados inconsistentes:
  /// 
  /// VERIFICACIONES IMPLEMENTADAS:
  /// 1. Verificación inicial antes de mostrar el indicador de progreso
  /// 2. Verificación final antes de la operación crítica principal
  /// 3. Verificaciones adicionales usando el patrón atómico del BitacoraService
  /// 
  /// RESULTADO: Si se pierde la conexión en cualquier punto crítico, todo el proceso
  /// se cancela para evitar bitácoras incompletas o actividades de usuario desincronizadas.

  /// Método principal que implementa el patrón híbrido:
  /// - Batch para operaciones Firestore (atómicas) en BitacoraService
  /// - Verificaciones múltiples de conexión
  Future<void> _guardarBitacoraAtomico() async {
    print('🔄 Iniciando ${_isEditing ? 'actualización' : 'creación'} atómica de bitácora');

    // VERIFICACIÓN 1: Conexión inicial antes de iniciar proceso
    print('🔍 Verificando conexión inicial antes de ${_isEditing ? 'actualizar' : 'crear'} bitácora...');
    await _checkInternetConnection();
    if (!_hasInternet) {
      print('❌ Sin conexión - cancelando ${_isEditing ? 'actualización' : 'creación'} de bitácora');
      throw Exception('Se requiere conexión a internet para ${_isEditing ? 'actualizar' : 'crear'} la bitácora');
    }

    // VERIFICACIÓN 2: Conexión justo antes de la operación crítica
    print('🔍 Verificación final de conectividad antes de operación atómica...');
    try {
      await InternetAddress.lookup('dns.google').timeout(const Duration(seconds: 10));
      print('✅ Conectividad final confirmada para operación atómica');
    } catch (e) {
      print('❌ Fallo en verificación final - cancelando operación atómica');
      throw Exception('Se perdió la conexión a internet durante el proceso. La ${_isEditing ? 'actualización' : 'creación'} ha sido cancelada por seguridad.');
    }

    // FASE: Ejecutar operación atómica usando BitacoraService
    if (_isEditing) {
      await BitacoraService.updateBitacora(
        bitacoraId: widget.bitacoraId!,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        selectedPhotoIds: _selectedPhotoIds,
        isPublic: _isPublic,
      );
      print('✅ Bitácora actualizada exitosamente usando patrón atómico');
    } else {
      await BitacoraService.createBitacora(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        selectedPhotoIds: _selectedPhotoIds,
        isPublic: _isPublic,
      );
      print('✅ Bitácora creada exitosamente usando patrón atómico');
    }

    // VERIFICACIÓN FINAL: Confirmar que todo el proceso se completó exitosamente
    print('✅ Proceso completo exitoso - Bitácora ${_isEditing ? 'actualizada' : 'creada'} y actividad actualizada');
  }

  Future<void> _guardarBitacora() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedPhotoIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.photo_library_outlined, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Debes seleccionar al menos un registro para crear la bitácora.',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.warning,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // VERIFICACIÓN 1: Conexión inicial antes de mostrar proceso
    print('🔍 Verificando conexión inicial antes de guardar...');
    await _checkInternetConnection();
    if (!_hasInternet) {
      String mensaje = _isEditing 
        ? 'Se requiere conexión a internet para actualizar la bitácora. Verifica tu conexión e inténtalo de nuevo.'
        : 'Se requiere conexión a internet para crear la bitácora. Verifica tu conexión e inténtalo de nuevo.';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.wifi_off, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mensaje,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    // Mostrar indicador de progreso
    final operacionTexto = _isEditing ? 'Actualizando' : 'Creando';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$operacionTexto bitácora... No cierres la aplicación.',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        backgroundColor: AppColors.slateGreen,
        duration: const Duration(seconds: 30), // Duración larga para cubrir el proceso
      ),
    );

    try {
      // VERIFICACIÓN 2: Conexión justo antes de la operación crítica
      print('🔍 Verificación final de conexión antes de ${_isEditing ? 'actualizar' : 'crear'}...');
      await _checkInternetConnection();
      if (!_hasInternet) {
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.wifi_off, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Se perdió la conexión a internet. ${_isEditing ? 'La actualización' : 'La creación'} ha sido cancelada por seguridad.',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.warning,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      print('🔄 Iniciando ${_isEditing ? 'actualización' : 'creación'} de bitácora...');
      
      // Usar patrón atómico para crear/actualizar bitácora
      await _guardarBitacoraAtomico();

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  _isEditing ? 'Bitácora actualizada correctamente' : 'Bitácora creada exitosamente',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            backgroundColor: AppColors.buttonGreen2,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop(true); // Indica que se guardó correctamente
      }
    } catch (e) {
      print('❌ Error al ${_isEditing ? 'actualizar' : 'crear'} bitácora: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        
        // Extraer mensaje limpio del error
        String errorMessage = 'No se pudo ${_isEditing ? 'actualizar' : 'crear'} la bitácora. Inténtalo de nuevo.';
        IconData errorIcon = Icons.error_outline;
        
        String cleanErrorMessage = e.toString();
        if (cleanErrorMessage.startsWith('Exception: ')) {
          cleanErrorMessage = cleanErrorMessage.substring(11);
        }
        
        final errorString = cleanErrorMessage.toLowerCase();
        
        if (errorString.contains('servidor no está disponible') ||
            errorString.contains('unavailable') ||
            errorString.contains('network') || 
            errorString.contains('internet') || 
            errorString.contains('connection') ||
            errorString.contains('timeout') ||
            errorString.contains('cancelado por seguridad') ||
            errorString.contains('cancelada por seguridad') ||
            errorString.contains('actividad del usuario') ||
            errorString.contains('se perdió la conexión')) {
          errorMessage = 'Problema de conexión. Verifica tu internet e inténtalo de nuevo.';
          errorIcon = Icons.wifi_off;
        } else if (errorString.contains('permisos') ||
                   errorString.contains('permission') || 
                   errorString.contains('unauthorized')) {
          errorMessage = 'No tienes permisos para realizar esta operación.';
          errorIcon = Icons.lock;
        } else if (errorString.contains('sesión ha expirado') ||
                   errorString.contains('inicia sesión')) {
          errorMessage = 'Tu sesión ha expirado. Inicia sesión nuevamente.';
          errorIcon = Icons.account_circle_outlined;
        } else if (errorString.contains('cuota') ||
                   errorString.contains('quota')) {
          errorMessage = 'Se ha superado el límite de uso. Inténtalo más tarde.';
          errorIcon = Icons.hourglass_empty;
        } else if (errorString.length > 10 && errorString.length < 80) {
          errorMessage = cleanErrorMessage;
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(errorIcon, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    errorMessage,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Reintentar',
              textColor: Colors.white,
              onPressed: () => _guardarBitacora(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _selectedPhotos.removeAt(index);
      _selectedPhotoIds.removeAt(index);
    });
  }

  // Función para manejar cambios en el título con conversión a mayúsculas y contador
  void _onTitleChanged(String value) {
    // Convertir a mayúsculas
    final upperCaseValue = value.toUpperCase();
    
    // Si el texto fue convertido, actualizar el controller
    if (upperCaseValue != value) {
      _titleController.value = _titleController.value.copyWith(
        text: upperCaseValue,
        selection: TextSelection.collapsed(offset: upperCaseValue.length),
      );
    }
    
    // Actualizar contador de caracteres
    setState(() {
      _titleCharCount = upperCaseValue.length;
    });
  }

  // Función helper para limitar saltos de línea
  String _limitLineBreaks(String text, int maxLines) {
    // Contar los saltos de línea en el texto
    final lineBreaks = '\n'.allMatches(text).length;
    
    if (lineBreaks <= maxLines - 1) {
      return text; // Permitir el texto si no excede el límite (maxLines - 1 porque la primera línea no necesita \n)
    }
    
    // Si excede el límite, recortar el texto hasta el último salto de línea permitido
    final lines = text.split('\n');
    if (lines.length > maxLines) {
      return lines.take(maxLines).join('\n');
    }
    
    return text;
  }

  // Función para manejar cambios en la descripción con validación de saltos de línea y contador
  void _onDescriptionChanged(String value) {
    final limitedText = _limitLineBreaks(value, 3);
    if (limitedText != value) {
      // Si el texto fue limitado, actualizar el controller sin triggear onChanged
      _descriptionController.value = _descriptionController.value.copyWith(
        text: limitedText,
        selection: TextSelection.collapsed(offset: limitedText.length),
      );
    }
    
    // Actualizar contador de caracteres
    setState(() {
      _descriptionCharCount = limitedText.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: _hasInternet ? AppColors.buttonGreen2 : AppColors.buttonGreen2.withOpacity(0.5),
        foregroundColor: AppColors.white,
        onPressed: _isSaving ? null : _guardarBitacora,
        tooltip: _hasInternet ? 'Guardar bitácora' : 'Sin conexión - No se puede guardar',
        child: const Icon(Icons.save),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: AppColors.backgroundPrimary,
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                color: AppColors.slateGreen,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new),
                      color: AppColors.white,
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            widget.bitacoraData != null ? 'Editar Bitácora' : 'Nueva Bitácora',
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
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
              ),
              // Formulario
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Título de la Bitácora con contador
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Título de la bitácora:',
                                  style: TextStyle(
                                    color: AppColors.inputHint,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '$_titleCharCount/$_maxTitleCharacters',
                                  style: TextStyle(
                                    color: _titleCharCount > _maxTitleCharacters 
                                        ? AppColors.warning 
                                        : AppColors.inputHint,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _titleController,
                              enabled: !_isSaving,
                              maxLength: _maxTitleCharacters,
                              onChanged: _onTitleChanged,
                              decoration: InputDecoration(
                                hintText: 'Ej: REGISTRO DE INSECTOS ABRIL',
                                hintStyle: const TextStyle(color: AppColors.inputHint),
                                filled: true,
                                fillColor: AppColors.inputBackground,
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: AppColors.inputBorder, width: 1.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: AppColors.inputBorderFocused, width: 2.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(color: AppColors.warning, width: 1.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(color: AppColors.warning, width: 2.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                errorStyle: const TextStyle(
                                  color: AppColors.warning,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                counterText: '', // Ocultar el contador por defecto
                              ),
                              style: const TextStyle(fontSize: 18, color: AppColors.textWhite),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'El título es obligatorio';
                                }
                                if (value.length > _maxTitleCharacters) {
                                  return 'El título no puede exceder $_maxTitleCharacters caracteres';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Descripción con contador
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Descripción:',
                                  style: TextStyle(
                                    color: AppColors.inputHint,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '$_descriptionCharCount/$_maxDescriptionCharacters',
                                  style: TextStyle(
                                    color: _descriptionCharCount > _maxDescriptionCharacters 
                                        ? AppColors.warning 
                                        : AppColors.inputHint,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _descriptionController,
                              enabled: !_isSaving,
                              maxLength: _maxDescriptionCharacters,
                              maxLines: 3,
                              onChanged: _onDescriptionChanged,
                              decoration: InputDecoration(
                                hintText: 'Describe el propósito y contenido de esta bitácora...',
                                hintStyle: const TextStyle(color: AppColors.inputHint),
                                filled: true,
                                fillColor: AppColors.inputBackground,
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: AppColors.inputBorder, width: 1.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: AppColors.inputBorderFocused, width: 2.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(color: AppColors.warning, width: 1.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(color: AppColors.warning, width: 2.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                errorStyle: const TextStyle(
                                  color: AppColors.warning,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                counterText: '', // Ocultar el contador por defecto
                              ),
                              style: const TextStyle(color: AppColors.textWhite),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'La descripción es obligatoria';
                                }
                                if (value.length > _maxDescriptionCharacters) {
                                  return 'La descripción no puede exceder $_maxDescriptionCharacters caracteres';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Switch para hacer pública
                        Row(
                          children: [
                            Switch(
                              value: _isPublic,
                              onChanged: _isSaving ? null : (value) {
                                setState(() {
                                  _isPublic = value;
                                });
                              },
                              activeColor: AppColors.inputBorderFocused, // Color más brillante
                              activeTrackColor: AppColors.inputBorder.withOpacity(0.6), // Track más visible
                              inactiveThumbColor: AppColors.inputHint,
                              inactiveTrackColor: AppColors.inputBackground.withOpacity(0.7),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Hacer pública la bitácora',
                                style: TextStyle(
                                  color: AppColors.textWhite,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Título de registros con botón mejorado
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Registros seleccionados (${_selectedPhotos.length}):',
                              style: const TextStyle(
                                color: AppColors.textWhite,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.buttonSelect.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.buttonSelect, width: 1.5),
                              ),
                              child: InkWell(
                                onTap: _isSaving ? null : _navigateToSelectPhotos,
                                borderRadius: BorderRadius.circular(8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.add_photo_alternate,
                                      color: AppColors.buttonSelect,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Seleccionar',
                                      style: TextStyle(
                                        color: AppColors.buttonSelect,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Lista de registros seleccionados
                        _isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.buttonGreen2,
                                ),
                              )
                            : _selectedPhotos.isEmpty
                                ? Container(
                                    height: 100,
                                    decoration: BoxDecoration(
                                      color: AppColors.textWhite.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppColors.textPaleGreen.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      'No hay registros seleccionados.\nToca "Seleccionar" para añadir registros.',
                                      style: TextStyle(color: AppColors.textPaleGreen),
                                      textAlign: TextAlign.center,
                                    ),
                                  )
                                : Container(
                                    constraints: const BoxConstraints(maxHeight: 300),
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: _selectedPhotos.length,
                                      itemBuilder: (context, index) {
                                        final photo = _selectedPhotos[index];
                                        return Card(
                                          color: AppColors.backgroundCard,
                                          margin: const EdgeInsets.only(bottom: 8),
                                          child: ListTile(
                                            leading: ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: Image.network(
                                                photo['imageUrl'] ?? '',
                                                width: 50,
                                                height: 50,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Container(
                                                    width: 50,
                                                    height: 50,
                                                    color: AppColors.paleGreen.withValues(alpha: 0.3),
                                                    child: const Icon(
                                                      Icons.image_not_supported,
                                                      color: AppColors.textPaleGreen,
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                            title: Text(
                                              photo['taxonOrder'] ?? 'Sin clasificar',
                                              style: const TextStyle(
                                                color: AppColors.textWhite,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            subtitle: Text(
                                              'Hábitat: ${photo['habitat'] ?? 'No especificado'}',
                                              style: const TextStyle(
                                                color: AppColors.textPaleGreen,
                                              ),
                                            ),
                                            trailing: IconButton(
                                              icon: const Icon(Icons.remove_circle, color: AppColors.warning),
                                              onPressed: _isSaving ? null : () => _removePhoto(index),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}