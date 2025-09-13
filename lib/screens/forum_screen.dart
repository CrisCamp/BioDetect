import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:biodetect/themes.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

// Modal para mostrar el perfil del usuario
class UserProfileModal extends StatelessWidget {
  final String userId;
  final String userName;
  final String? profilePictureUrl;
  final bool esPropio;

  const UserProfileModal({
    super.key,
    required this.userId,
    required this.userName,
    this.profilePictureUrl,
    required this.esPropio,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 350),
        decoration: BoxDecoration(
          color: AppColors.darkTeal,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.seaGreen, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Foto de perfil grande
              CircleAvatar(
                backgroundColor: AppColors.seaGreen,
                radius: 50,
                backgroundImage: profilePictureUrl != null && profilePictureUrl!.isNotEmpty
                    ? NetworkImage(profilePictureUrl!)
                    : null,
                child: profilePictureUrl == null || profilePictureUrl!.isEmpty
                    ? const Icon(Icons.person, color: Colors.white, size: 60)
                    : null,
              ),
              const SizedBox(height: 16),
              
              // Nombre del usuario
              Text(
                esPropio ? '$userName (Tú)' : userName,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              
              // Sección de insignias
              FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance.collection('badges').get(),
                builder: (context, badgesSnapshot) {
                  if (!badgesSnapshot.hasData) {
                    return const CircularProgressIndicator(color: AppColors.seaGreen);
                  }
                  
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                    builder: (context, userSnapshot) {
                      if (!userSnapshot.hasData) {
                        return const CircularProgressIndicator(color: AppColors.seaGreen);
                      }
                      
                      final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                      final userBadges = userData?['badges'] as List<dynamic>? ?? [];
                      final allBadges = badgesSnapshot.data!.docs;
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Insignias (${userBadges.length}/${allBadges.length})',
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          // Grid de insignias con centrado automático
                          SizedBox(
                            height: 280,
                            child: SingleChildScrollView(
                              child: Builder(
                                builder: (context) {
                                  // Ordenamos las insignias por el campo "order"
                                  final sortedBadges = List<QueryDocumentSnapshot>.from(allBadges);
                                  sortedBadges.sort((a, b) {
                                    final dataA = a.data() as Map<String, dynamic>;
                                    final dataB = b.data() as Map<String, dynamic>;
                                    final orderA = dataA['order'] as int? ?? 999;
                                    final orderB = dataB['order'] as int? ?? 999;
                                    return orderA.compareTo(orderB);
                                  });
                                  
                                  return Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: sortedBadges.map((badge) {
                                      final badgeData = badge.data() as Map<String, dynamic>;
                                      final badgeOrder = badgeData['order'] as int?;
                                      
                                      // Convertir userBadges a List<int> para comparación con el campo "order"
                                      final userBadgeOrders = userBadges.map((e) {
                                        if (e is int) return e;
                                        if (e is String) return int.tryParse(e) ?? -1;
                                        return -1;
                                      }).toList();
                                      
                                      final hasBadge = badgeOrder != null && userBadgeOrders.contains(badgeOrder);
                                      final badgeIconName = badgeData['iconName'] as String?; // Nombre del archivo de la imagen
                                      
                                      return SizedBox(
                                        width: 70, // Ancho fijo para mantener 3 por fila aproximadamente
                                        height: 100,
                                        child: Opacity(
                                          opacity: hasBadge ? 1.0 : 0.4, // Insignias no conseguidas más opacas
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: hasBadge ? AppColors.seaGreen.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: hasBadge ? AppColors.seaGreen : Colors.grey,
                                                width: 2,
                                              ),
                                              boxShadow: hasBadge ? [
                                                BoxShadow(
                                                  color: AppColors.seaGreen.withOpacity(0.3),
                                                  blurRadius: 8,
                                                  spreadRadius: 1,
                                                ),
                                              ] : null,
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(8),
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  // Imagen de la insignia o ícono por defecto
                                                  Container(
                                                    width: 38,
                                                    height: 38,
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: badgeIconName != null && badgeIconName.isNotEmpty
                                                        ? ClipRRect(
                                                            borderRadius: BorderRadius.circular(8),
                                                            child: Image.asset(
                                                              'assets/badge_icons/$badgeIconName.png',
                                                              width: 32,
                                                              height: 32,
                                                              fit: BoxFit.cover,
                                                              errorBuilder: (context, error, stackTrace) {
                                                                // Si la imagen no se puede cargar, mostramos ícono por defecto
                                                                return Icon(
                                                                  Icons.star,
                                                                  color: hasBadge ? Colors.amber : Colors.grey,
                                                                  size: 28,
                                                                );
                                                              },
                                                            ),
                                                          )
                                                        : Icon(
                                                            Icons.star,
                                                            color: hasBadge ? Colors.amber : Colors.grey,
                                                            size: 28,
                                                          ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    badgeData['name'] ?? 'Insignia',
                                                    style: TextStyle(
                                                      color: hasBadge ? AppColors.white : Colors.grey,
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                }).toList(),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              
              const SizedBox(height: 20),
              
              // Botón cerrar
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.seaGreen,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Modelo simple para el mensaje
class Message {
  final String id;
  final String userId;
  final String userName;
  final String content;
  final bool includeImage;
  final String? imageUrl; // Será nulo si includeImage es false
  final String? profilePictureUrl; // URL de la foto de perfil del usuario
  final String badgeProgress; // Progreso de insignias en formato "X/13"
  final Timestamp createdAt;
  final bool esPropio; // Para determinar si el mensaje es del usuario actual
  final bool isPending; // Para indicar si el mensaje está pendiente de envío

  Message({
    required this.id,
    required this.userId,
    required this.userName,
    required this.content,
    required this.includeImage,
    this.imageUrl,
    this.profilePictureUrl,
    this.badgeProgress = "0/13", // Valor por defecto
    required this.createdAt,
    required this.esPropio,
    this.isPending = false, // Por defecto no está pendiente
  });

  factory Message.fromFirestore(DocumentSnapshot doc, String currentUserId) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['user_name'] ?? 'Usuario Desconocido',
      content: data['content'] ?? '',
      includeImage: data['includeImage'] ?? false,
      imageUrl: data['imageUrl'],
      profilePictureUrl: null, // Se cargará después con el método loadProfilePicture
      createdAt: data['createdAt'] ?? Timestamp.now(),
      esPropio: data['userId'] == currentUserId,
    );
  }

  // Método estático para cargar la foto de perfil del usuario
  static Future<String?> loadProfilePicture(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return userData['profilePicture'] as String?;
      }
    } catch (e) {
      print('Error al cargar foto de perfil para $userId: $e');
    }
    return null;
  }

  // Método estático para cargar datos del perfil del usuario (foto y progreso de insignias)
  static Future<Message> loadUserProfileData(Message message) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(message.userId)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final badges = userData['badges'] as List<dynamic>? ?? [];
        final badgeCount = badges.length;
        const totalBadges = 13; // Total de insignias disponibles
        
        final profilePictureUrl = userData['profilePicture'] as String?;
        final badgeProgress = '$badgeCount/$totalBadges';
        
        return message.copyWithProfileData(profilePictureUrl, badgeProgress);
      }
    } catch (e) {
      print('Error al cargar datos del perfil para ${message.userId}: $e');
    }
    return message.copyWithProfileData(null, '0/13');
  }

  // Método para crear una copia del mensaje con los datos del perfil
  Message copyWithProfileData(String? profilePictureUrl, String badgeProgress) {
    return Message(
      id: id,
      userId: userId,
      userName: userName,
      content: content,
      includeImage: includeImage,
      imageUrl: imageUrl,
      profilePictureUrl: profilePictureUrl,
      badgeProgress: badgeProgress,
      createdAt: createdAt,
      esPropio: esPropio,
      isPending: isPending, // Mantener el estado de pendiente
    );
  }

  // Método para formatear la hora
  String get formattedTime {
    final dateTime = createdAt.toDate();
    return "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
  }

  // Convertir mensaje a JSON para persistencia
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'content': content,
      'includeImage': includeImage,
      'imageUrl': imageUrl,
      'profilePictureUrl': profilePictureUrl,
      'badgeProgress': badgeProgress,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'esPropio': esPropio,
      'isPending': isPending,
    };
  }

  // Crear mensaje desde JSON para persistencia
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? 'Usuario Desconocido',
      content: json['content'] ?? '',
      includeImage: json['includeImage'] ?? false,
      imageUrl: json['imageUrl'],
      profilePictureUrl: json['profilePictureUrl'],
      badgeProgress: json['badgeProgress'] ?? '0/13',
      createdAt: Timestamp.fromMillisecondsSinceEpoch(json['createdAt'] ?? 0),
      esPropio: json['esPropio'] ?? false,
      isPending: json['isPending'] ?? false,
    );
  }
}

class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  File? _image;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _currentUserId; // <--- Para obtener el ID del usuario actual
  String? _currentUserName; // <--- Para obtener el nombre del usuario actual

  // --- Lógica para enviar mensajes ---
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;

  // --- Nuevas variables para optimización ---
  List<Message> _messages = []; // Cache local de mensajes
  StreamSubscription<QuerySnapshot>? _messageSubscription;
  Timestamp? _lastMessageTimestamp; // Para cargar solo mensajes nuevos
  bool _isLoadingHistory = false;
  static const int _messageLimit = 150; // Límite de mensajes

  // --- Variables para gestión de conectividad ---
  bool _hasInternet = true;
  List<Message> _pendingMessages = []; // Mensajes pendientes de envío
  bool _isSendingPendingMessages = false; // Estado de envío de mensajes pendientes
  Timer? _connectionCheckTimer;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Cargar mensajes pendientes del caché primero
    await _loadPendingMessages();
    
    // Obtener usuario actual
    _getCurrentUser();
    
    // Verificar conexión a internet
    await _checkInternetConnection();
    
    // Iniciar el chequeo periódico de conexión
    _startPeriodicConnectionCheck();
    
    // Esperar un momento para que todo se inicialice y luego verificar mensajes pendientes
    Timer(const Duration(seconds: 3), () {
      _checkAndSendPendingMessagesOnStartup();
    });
  }

  void _getCurrentUser() {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _currentUserId = user.uid;
        _currentUserName = user.displayName ?? "Usuario Desconocido";
      });
      _initializeMessageStream(); // Inicializar el stream después de obtener el usuario
      _addPendingMessagesToUI(); // Agregar mensajes pendientes a la UI
    } else {
      if (kDebugMode) {
        print("Usuario no autenticado. El foro podría no funcionar completamente.");
      }
      // Aqui probablemente redirija al login
    }
  }

  // Verificar conexión a internet
  Future<void> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      bool hasConnection = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      
      bool wasOffline = !_hasInternet;
      
      setState(() {
        _hasInternet = hasConnection;
      });
      
      // Si recuperamos la conexión, enviar mensajes pendientes y reactivar listener
      if (wasOffline && hasConnection && _pendingMessages.isNotEmpty) {
        if (kDebugMode) {
          print('Conexión recuperada. Enviando ${_pendingMessages.length} mensajes pendientes...');
          // Ejecutar prueba de conectividad antes de intentar enviar mensajes
          _testFirestoreConnection();
        }
        _sendPendingMessages();
        _setupNewMessageListener(); // Reactivar listener
      } else if (hasConnection && _messageSubscription == null) {
        // Si hay conexión pero no hay listener activo, reactivarlo
        _setupNewMessageListener();
      } else if (!hasConnection && _messageSubscription != null) {
        // Si se pierde la conexión, cancelar el listener para ahorrar recursos
        _messageSubscription?.cancel();
        _messageSubscription = null;
      }
    } catch (_) {
      setState(() {
        _hasInternet = false;
      });
    }
  }

  // Verificación periódica de conexión
  void _startPeriodicConnectionCheck() {
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkInternetConnection();
    });
  }

  // Verificar y enviar mensajes pendientes al iniciar la app
  Future<void> _checkAndSendPendingMessagesOnStartup() async {
    if (kDebugMode) {
      print('🔄 Verificando mensajes pendientes al iniciar la app...');
      print('   - Mensajes pendientes: ${_pendingMessages.length}');
      print('   - Internet disponible: $_hasInternet');
      print('   - Usuario actual: $_currentUserId');
    }

    // Si hay mensajes pendientes, verificar conexión más profunda
    if (_pendingMessages.isNotEmpty) {
      if (kDebugMode) {
        print('📤 Hay mensajes pendientes, verificando conexión a Firestore...');
      }
      
      // Probar conexión a Firestore
      bool firestoreConnected = await _testFirestoreConnection();
      
      if (firestoreConnected && _currentUserId != null) {
        if (kDebugMode) {
          print('✅ Conexión a Firestore confirmada, enviando mensajes...');
        }
        await _sendPendingMessages();
      } else {
        if (kDebugMode) {
          if (!firestoreConnected) {
            print('⚠️ Firestore no está disponible');
          } else if (_currentUserId == null) {
            print('⚠️ Usuario no identificado');
          }
        }
      }
    } else {
      if (kDebugMode) {
        print('ℹ️ No hay mensajes pendientes para enviar');
      }
    }
  }

  // Enviar mensajes pendientes cuando se recupere la conexión
  Future<void> _sendPendingMessages() async {
    if (_pendingMessages.isEmpty || !_hasInternet || _isSendingPendingMessages) return;

    if (kDebugMode) {
      print('🚀 Iniciando envío de ${_pendingMessages.length} mensajes pendientes...');
      print('   - Usuario actual: $_currentUserId');
      print('   - Nombre usuario: $_currentUserName');
      print('   - Internet disponible: $_hasInternet');
    }

    // Verificar autenticación
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      if (kDebugMode) {
        print('❌ Usuario no autenticado, cancelando envío de mensajes pendientes');
      }
      return;
    }

    // Verificar conexión a Firestore
    try {
      await _firestore.collection('group_chat').limit(1).get();
      if (kDebugMode) {
        print('✅ Conexión a Firestore verificada');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error de conexión a Firestore: $e');
      }
      setState(() {
        _isSendingPendingMessages = false;
      });
      return;
    }

    setState(() {
      _isSendingPendingMessages = true;
    });

    final messagesToSend = List<Message>.from(_pendingMessages);
    final sentMessageIds = <String>{};

    int sentCount = 0;
    int failedCount = 0;
    
    for (final message in messagesToSend) {
      if (kDebugMode) {
        print('📤 Procesando mensaje: ${message.content.substring(0, message.content.length > 20 ? 20 : message.content.length)}...');
        print('   - ID: ${message.id}');
        print('   - Include Image: ${message.includeImage}');
        print('   - Is Pending: ${message.isPending}');
        print('   - User ID: ${message.userId}');
        print('   - User Name: ${message.userName}');
      }
      
      // Validar que el mensaje tenga datos válidos
      if (message.content.trim().isEmpty) {
        if (kDebugMode) {
          print('   - ⚠️ Saltando mensaje vacío');
        }
        continue;
      }
      
      if (message.userId.isEmpty || message.userName.isEmpty) {
        if (kDebugMode) {
          print('   - ⚠️ Saltando mensaje con datos de usuario incompletos');
        }
        failedCount++;
        _pendingMessages.add(message);
        continue;
      }
      
      try {
        // Solo enviar mensajes de texto (sin imágenes)
        if (!message.includeImage) {
          if (kDebugMode) {
            print('   - Enviando mensaje de texto...');
          }
          
          // Agregar timeout de 10 segundos para el envío
          await _sendMessageToFirestore(message).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('Timeout enviando mensaje a Firestore', const Duration(seconds: 10));
            },
          );
          
          sentCount++;
          sentMessageIds.add(message.id);
          if (kDebugMode) {
            print('   - ✅ Mensaje enviado exitosamente');
          }
        } else {
          // Si tiene imagen, mantener en pendientes
          failedCount++;
          if (kDebugMode) {
            print('   - ❌ Mensaje con imagen no enviado (sin conexión para imágenes)');
          }
        }
      } catch (e) {
        // Si falla, mantener en pendientes
        failedCount++;
        if (kDebugMode) {
          print('   - ❌ Error enviando mensaje: $e');
        }
      }
    }

    // Actualizar pendientes: mantener solo los que fallaron
    setState(() {
      _pendingMessages.removeWhere((msg) => sentMessageIds.contains(msg.id));
      // Remover también de la UI los mensajes que se enviaron exitosamente
      _messages.removeWhere((msg) => msg.isPending && sentMessageIds.contains(msg.id));
    });

    // Actualizar caché
    await _savePendingMessages();

    if (kDebugMode) {
      print('🧹 Limpieza completada:');
      print('   - Mensajes enviados: ${sentMessageIds.length}');
      print('   - Mensajes pendientes restantes: ${_pendingMessages.length}');
      print('   - Mensajes en UI: ${_messages.length}');
    }

    setState(() {
      _isSendingPendingMessages = false;
    });

    if (mounted) {
      if (sentCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$sentCount mensaje(s) enviado(s)'),
            backgroundColor: AppColors.buttonGreen2,
            duration: const Duration(seconds: 2),
          ),
        );
        
        // Si todos los mensajes se enviaron exitosamente, ocultar la barra después de un momento
        if (_pendingMessages.isEmpty) {
          // Actualizar el timestamp del último mensaje para el listener
          if (_messages.isNotEmpty) {
            _lastMessageTimestamp = _messages.first.createdAt;
          }
          
          Timer(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {}); // Forzar rebuild para ocultar la barra
            }
          });
        }
      }
      
      if (failedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$failedCount mensaje(s) fallaron. Se reintentará automáticamente.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }

    if (kDebugMode) {
      print('Envío completado: $sentCount exitosos, $failedCount fallidos');
    }
  }

  // Método de prueba para verificar conexión a Firestore
  Future<bool> _testFirestoreConnection() async {
    if (kDebugMode) {
      print('🧪 Probando conexión a Firestore...');
    }
    
    try {
      final testDoc = await _firestore.collection('group_chat').add({
        'test': true,
        'createdAt': Timestamp.now(),
        'userId': _currentUserId ?? 'test',
      }).timeout(const Duration(seconds: 10));
      
      if (kDebugMode) {
        print('✅ Prueba exitosa, documento creado con ID: ${testDoc.id}');
      }
      
      // Eliminar el documento de prueba
      await testDoc.delete();
      
      if (kDebugMode) {
        print('🗑️ Documento de prueba eliminado exitosamente');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error probando conexión a Firestore: $e');
      }
      return false;
    }
  }

  // Enviar mensaje a Firestore
  Future<void> _sendMessageToFirestore(Message message) async {
    if (kDebugMode) {
      print('🔄 Intentando enviar mensaje a Firestore...');
      print('   - Usuario: ${message.userId}');
      print('   - Nombre: ${message.userName}');
      print('   - Contenido: ${message.content}');
      print('   - Timestamp: ${message.createdAt}');
      print('   - IncludeImage: ${message.includeImage}');
      print('   - ImageUrl: ${message.imageUrl}');
    }

    try {
      final docRef = await _firestore.collection('group_chat').add({
        'userId': message.userId,
        'user_name': message.userName,
        'content': message.content,
        'createdAt': Timestamp.now(), // Usar timestamp actual en lugar del mensaje
        'includeImage': message.includeImage,
        'imageUrl': message.imageUrl,
      });
      
      if (kDebugMode) {
        print('✅ Mensaje enviado exitosamente con ID: ${docRef.id}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error enviando mensaje a Firestore: $e');
        print('   - Stack trace: ${e.toString()}');
      }
      rethrow; // Re-lanzar el error para que sea manejado por el caller
    }
  }

  // Cargar mensajes pendientes desde SharedPreferences
  Future<void> _loadPendingMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingMessagesJson = prefs.getStringList('pending_messages') ?? [];
      
      if (kDebugMode) {
        print('📱 Cargando mensajes pendientes desde SharedPreferences...');
        print('   - Mensajes en caché: ${pendingMessagesJson.length}');
      }
      
      _pendingMessages = pendingMessagesJson
          .map((jsonString) => Message.fromJson(jsonDecode(jsonString)))
          .toList();
      
      if (kDebugMode) {
        print('✅ Cargados ${_pendingMessages.length} mensajes pendientes');
        for (int i = 0; i < _pendingMessages.length; i++) {
          final msg = _pendingMessages[i];
          print('   Mensaje $i: "${msg.content}" - Creado: ${msg.createdAt}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error cargando mensajes pendientes: $e');
      }
      _pendingMessages = [];
    }
  }

  // Guardar mensajes pendientes en SharedPreferences
  Future<void> _savePendingMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingMessagesJson = _pendingMessages
          .map((message) => jsonEncode(message.toJson()))
          .toList();
      
      await prefs.setStringList('pending_messages', pendingMessagesJson);
      
      if (kDebugMode) {
        print('Guardados ${_pendingMessages.length} mensajes pendientes en caché');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error guardando mensajes pendientes: $e');
      }
    }
  }

  // Agregar mensajes pendientes a la UI
  void _addPendingMessagesToUI() {
    if (_pendingMessages.isNotEmpty && _currentUserId != null) {
      // Filtrar solo mensajes del usuario actual
      final userPendingMessages = _pendingMessages
          .where((msg) => msg.userId == _currentUserId)
          .toList();
      
      setState(() {
        // Evitar duplicados - solo agregar mensajes que no estén ya en la UI
        for (final pendingMsg in userPendingMessages) {
          final existsInUI = _messages.any((msg) => msg.id == pendingMsg.id);
          if (!existsInUI) {
            _messages.insert(0, pendingMsg);
          }
        }
        
        // Ordenar mensajes por timestamp (más recientes primero)
        _messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      });
      
      if (kDebugMode) {
        print('Agregados ${userPendingMessages.length} mensajes pendientes a la UI');
      }
    }
  }

  // Inicializar el stream de mensajes optimizado
  void _initializeMessageStream() {
    if (!_hasInternet) {
      // Sin internet, solo mostrar mensajes del cache local
      if (kDebugMode) {
        print('Sin conexión: usando mensajes del cache local');
      }
      return;
    }
    
    _loadInitialMessages();
    _setupNewMessageListener();
  }

  // Cargar mensajes iniciales (últimos 150)
  Future<void> _loadInitialMessages() async {
    if (_currentUserId == null || !_hasInternet) return;
    
    setState(() => _isLoadingHistory = true);
    
    try {
      final querySnapshot = await _firestore
          .collection('group_chat')
          .orderBy('createdAt', descending: true)
          .limit(_messageLimit)
          .get();

      final messages = querySnapshot.docs
          .map((doc) => Message.fromFirestore(doc, _currentUserId!))
          .toList();

      // Cargar datos de perfil para todos los mensajes
      final messagesWithProfile = <Message>[];
      for (final message in messages) {
        final messageWithProfile = await Message.loadUserProfileData(message);
        messagesWithProfile.add(messageWithProfile);
      }

      setState(() {
        _messages = messagesWithProfile;
        _lastMessageTimestamp = messages.isNotEmpty ? messages.first.createdAt : null;
        _isLoadingHistory = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error cargando mensajes iniciales: $e');
      }
      setState(() => _isLoadingHistory = false);
    }
  }

  // Configurar listener solo para mensajes nuevos
  void _setupNewMessageListener() {
    if (_currentUserId == null || !_hasInternet) return;

    _messageSubscription = _firestore
        .collection('group_chat')
        .orderBy('createdAt', descending: false)
        .where('createdAt', isGreaterThan: _lastMessageTimestamp ?? Timestamp.now())
        .snapshots()
        .listen((snapshot) async {
      
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final message = Message.fromFirestore(change.doc, _currentUserId!);
          
          // Validar que el mensaje tenga contenido válido
          if (message.content.trim().isEmpty) {
            if (kDebugMode) {
              print('⚠️ Mensaje vacío ignorado del stream');
            }
            continue;
          }
          
          // Verificar duplicados
          bool shouldAdd = true;
          
          // Para evitar duplicados, verificar si ya existe un mensaje con el mismo ID o 
          // mismo userId, contenido y timestamp muy cercano
          final isDuplicate = _messages.any((existingMsg) {
            // Mismo ID
            if (existingMsg.id == message.id) return true;
            
            // Mismo contenido, usuario y timestamp muy cercano (máximo 30 segundos de diferencia)
            // Esto evita duplicados cuando un mensaje pendiente se envía y vuelve desde Firestore
            if (existingMsg.userId == message.userId && 
                existingMsg.content.trim() == message.content.trim() &&
                (existingMsg.createdAt.seconds - message.createdAt.seconds).abs() <= 30) {
              
              if (kDebugMode) {
                print('🔍 Posible duplicado detectado:');
                print('   - Contenido: "${message.content}"');
                print('   - Existente isPending: ${existingMsg.isPending}');
                print('   - Nuevo es de Firestore: ${!message.isPending}');
                print('   - Diferencia tiempo: ${(existingMsg.createdAt.seconds - message.createdAt.seconds).abs()} segundos');
              }
              
              // Si el mensaje existente es pendiente y el nuevo viene de Firestore,
              // actualizar el existente en lugar de crear uno nuevo
              if (existingMsg.isPending && !message.isPending) {
                // Actualizar el mensaje existente con los datos de Firestore
                setState(() {
                  final index = _messages.indexOf(existingMsg);
                  if (index != -1) {
                    _messages[index] = Message(
                      id: message.id,
                      userId: message.userId,
                      userName: message.userName,
                      content: message.content,
                      includeImage: message.includeImage,
                      imageUrl: message.imageUrl,
                      profilePictureUrl: existingMsg.profilePictureUrl,
                      badgeProgress: existingMsg.badgeProgress,
                      createdAt: message.createdAt,
                      esPropio: message.esPropio,
                      isPending: false,
                    );
                    
                    if (kDebugMode) {
                      print('✅ Mensaje pendiente actualizado con datos de Firestore');
                    }
                  }
                });
              }
              
              return true;
            }
            
            return false;
          });
          
          shouldAdd = !isDuplicate;
          
          if (shouldAdd) {
            if (kDebugMode) {
              print('📥 Nuevo mensaje del stream: ${message.content.substring(0, message.content.length > 20 ? 20 : message.content.length)}...');
              print('   - ID: ${message.id}');
              print('   - Usuario: ${message.userName}');
              print('   - UserID: ${message.userId}');
              print('   - Es propio: ${message.esPropio}');
              print('   - Contenido completo: "${message.content}"');
              
              if (message.userName == "Usuario Desconocido") {
                print('⚠️ ADVERTENCIA: Mensaje con "Usuario Desconocido" detectado');
              }
            }
            
            final messageWithProfile = await Message.loadUserProfileData(message);
            
            setState(() {
              _messages.insert(0, messageWithProfile); // Insertar al principio
              _lastMessageTimestamp = message.createdAt;
              
              // Mantener solo los últimos mensajes para evitar memoria excesiva
              if (_messages.length > _messageLimit * 2) {
                _messages = _messages.take(_messageLimit).toList();
              }
            });
          } else {
            if (kDebugMode) {
              print('🔄 Mensaje duplicado ignorado: ${message.content.substring(0, message.content.length > 10 ? 10 : message.content.length)}...');
            }
          }
        }
      }
    }, onError: (error) {
      if (kDebugMode) {
        print('Error en stream de mensajes: $error');
      }
      // Si hay error de conexión, verificar estado de internet
      _checkInternetConnection();
    });
  }

  void _sendMessage() async {
    // Si no hay texto y no hay imagen, no envía nada
    if (_messageController.text.trim().isEmpty && _image == null) {
      return;
    }

    if (_currentUserId == null || _currentUserName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se puede enviar el mensaje. Usuario no identificado.')),
      );
      return;
    }

    // Verificar conexión antes de enviar
    await _checkInternetConnection();

    // Si no hay conexión y hay imagen, mostrar error y cancelar
    if (!_hasInternet && _image != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sin conexión. Las imágenes solo se pueden enviar con conexión a internet.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    final messageContent = _messageController.text.trim();
    final tempImage = _image; // Capturar imagen temporal
    
    // OPTIMISTIC UPDATE: Agregar el mensaje inmediatamente a la UI
    final tempMessage = Message(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}', // ID temporal
      userId: _currentUserId!,
      userName: _currentUserName!,
      content: messageContent,
      includeImage: tempImage != null,
      imageUrl: null, // Se actualizará cuando se suba la imagen
      profilePictureUrl: null, // Se cargará después
      badgeProgress: "0/13", // Se cargará después
      createdAt: Timestamp.now(),
      esPropio: true,
      isPending: !_hasInternet, // Marcar como pendiente si no hay conexión
    );

    // Cargar datos de perfil
    final tempMessageWithProfile = await Message.loadUserProfileData(tempMessage);
    
    setState(() {
      _messages.insert(0, tempMessageWithProfile); // Agregar inmediatamente a la UI
      _messageController.clear();
      _image = null; // Limpiar imagen inmediatamente
      _isSending = false; // Quitar indicador de envío inmediatamente
    });

    if (!_hasInternet) {
      // Sin conexión: agregar a mensajes pendientes
      _pendingMessages.add(tempMessageWithProfile);
      await _savePendingMessages(); // Guardar en caché
      
      // if (mounted) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     const SnackBar(
      //       content: Text('Sin conexión. El mensaje se enviará cuando se recupere la conexión.'),
      //       backgroundColor: Colors.orange,
      //       duration: Duration(seconds: 3),
      //     ),
      //   );
      // }
      return;
    }

    try {
      String? imageUrl; // Puede ser nulo si no hay imagen
      bool hasImage = false;
      if (tempImage != null) {
        final photoId = FirebaseFirestore.instance.collection('group_chat').doc().id;
        final ref = FirebaseStorage.instance.ref().child('group_chat/$_currentUserId/$photoId.jpg');
        await ref.putFile(tempImage);
        imageUrl = await ref.getDownloadURL();
        hasImage = true;
        
        // Actualizar el mensaje temporal con la URL de la imagen
        final updatedMessage = tempMessageWithProfile.copyWithProfileData(
          tempMessageWithProfile.profilePictureUrl,
          tempMessageWithProfile.badgeProgress,
        );
        
        setState(() {
          final index = _messages.indexWhere((m) => m.id == tempMessage.id);
          if (index != -1) {
            _messages[index] = Message(
              id: updatedMessage.id,
              userId: updatedMessage.userId,
              userName: updatedMessage.userName,
              content: updatedMessage.content,
              includeImage: hasImage,
              imageUrl: imageUrl,
              profilePictureUrl: updatedMessage.profilePictureUrl,
              badgeProgress: updatedMessage.badgeProgress,
              createdAt: updatedMessage.createdAt,
              esPropio: updatedMessage.esPropio,
            );
          }
        });
      }

      // Enviar a Firestore usando el método helper
      final finalMessage = Message(
        id: tempMessage.id,
        userId: _currentUserId!,
        userName: _currentUserName!,
        content: messageContent,
        includeImage: hasImage,
        imageUrl: imageUrl,
        profilePictureUrl: tempMessageWithProfile.profilePictureUrl,
        badgeProgress: tempMessageWithProfile.badgeProgress,
        createdAt: Timestamp.now(),
        esPropio: true,
      );

      await _sendMessageToFirestore(finalMessage);
      

    } catch (e) {
      // Si hay error, remover el mensaje temporal y mostrar error
      setState(() {
        _messages.removeWhere((m) => m.id == tempMessage.id);
        _messageController.text = messageContent; // Restaurar texto
        _image = tempImage; // Restaurar imagen
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar mensaje: $e')),
        );
      }
    }
  }
  // --- Fin de lógica para enviar mensajes ---

  Future<void> _seleccionarGaleria() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }
  void _quitarImagenSeleccionada() {
    setState(() {
      _image = null;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Foro de la Comunidad',
          style: TextStyle(color: AppColors.textWhite),
        ),
        backgroundColor: AppColors.backgroundNavBarsLigth,
        iconTheme: const IconThemeData(color: AppColors.textWhite),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundLightGradient,
        ),
        child: Column(
          children: [
            // Indicador de estado de conexión
            if (!_hasInternet || _pendingMessages.isNotEmpty || _isSendingPendingMessages)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: !_hasInternet 
                    ? Colors.red 
                    : (_isSendingPendingMessages || _pendingMessages.isNotEmpty) 
                        ? Colors.orange 
                        : AppColors.buttonGreen2,
                child: Row(
                  children: [
                    Icon(
                      !_hasInternet 
                          ? Icons.cloud_off 
                          : (_isSendingPendingMessages || _pendingMessages.isNotEmpty) 
                              ? Icons.cloud_upload 
                              : Icons.cloud_done,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        !_hasInternet
                            ? 'Sin conexión. Los mensajes se enviarán cuando se recupere la conexión.'
                            : _isSendingPendingMessages
                                ? 'Enviando mensajes pendientes...'
                                : _pendingMessages.isNotEmpty
                                    ? 'Preparando ${_pendingMessages.length} mensaje(s) para envío...'
                                    : 'Conexión restablecida',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Lista de mensajes
            Expanded(
              child: _isLoadingHistory
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.textWhite),
                    )
                  : _messages.isEmpty
                      ? const Center(
                          child: Text(
                            'No hay mensajes aún. ¡Sé el primero!',
                            style: TextStyle(
                              color: AppColors.textWhite,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ListView.builder(
                          reverse: true, // Para que el chat se muestre desde abajo
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            
                            return ForoMensajeCard(
                              esPropio: message.esPropio,
                              usuario: message.userName,
                              userId: message.userId,
                              hora: message.formattedTime,
                              texto: message.content,
                              imagen: message.includeImage ? message.imageUrl : null,
                              profilePictureUrl: message.profilePictureUrl,
                              badgeProgress: message.badgeProgress,
                              isPending: message.isPending,
                            );
                          },
                        ),
            ),

            if (_image != null) // Muestra esta sección solo si hay una imagen seleccionada
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                color: AppColors.slateGreen.withOpacity(0.5), // Un color de fondo sutil
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Image.file(
                        _image!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Imagen seleccionada', // O el nombre del archivo si lo tienes
                        style: TextStyle(color: AppColors.textWhite.withOpacity(0.8)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textWhite),
                      onPressed: _quitarImagenSeleccionada,
                      tooltip: 'Quitar imagen',
                    ),
                  ],
                ),
              ),

            // Campo de entrada
            Container(
              color: AppColors.slateGreen,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_a_photo),
                    // ignore: deprecated_member_use
                    color: _hasInternet ? AppColors.white : AppColors.white.withOpacity(0.5),
                    tooltip: _hasInternet 
                        ? 'Adjuntar imagen' 
                        : 'Sin conexión - Solo mensajes de texto',
                    onPressed: (_isSending || !_hasInternet) ? null : _seleccionarGaleria,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: AppColors.white),
                      decoration: InputDecoration(
                        hintText: 'Escribe un mensaje...',
                        hintStyle: const TextStyle(color: AppColors.white),
                        filled: true,
                        fillColor: Colors.transparent,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      onSubmitted: (_) => (_isSending || (_messageController.text.trim().isEmpty && _image == null)) ? null : _sendMessage(),
                      minLines: 1,
                      maxLines: 5,
                    ),
                  ),
                  IconButton(
                    icon: _isSending
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
                        : const Icon(Icons.send),
                    color: AppColors.white,
                    onPressed: _isSending ? null : _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageSubscription?.cancel(); // Cancelar el stream
    _connectionCheckTimer?.cancel(); // Cancelar el timer de verificación de conexión
    
    super.dispose();
  }
}

class ForoMensajeCard extends StatelessWidget {
  final bool esPropio;
  final String usuario;
  final String userId; // ID del usuario para el modal
  final String hora;
  final String texto;
  final String? imagen;
  final String? profilePictureUrl;
  final String? badgeProgress; // Progreso de insignias
  final bool isPending; // Indica si el mensaje está pendiente

  const ForoMensajeCard({
    super.key,
    required this.esPropio,
    required this.usuario,
    required this.userId,
    required this.hora,
    required this.texto,
    this.imagen,
    this.profilePictureUrl,
    this.badgeProgress,
    this.isPending = false, // Por defecto no está pendiente
  });

  // Método para mostrar imagen en pantalla completa
  static void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenImageViewer(imageUrl: imageUrl),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: esPropio ? Alignment.centerRight : Alignment.centerLeft,
      child: Card(
        color: esPropio ? AppColors.mintGreen : AppColors.slateGreen,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        elevation: 6,
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Usuario y hora (tocable para mostrar perfil)
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => UserProfileModal(
                      userId: userId,
                      userName: usuario,
                      profilePictureUrl: profilePictureUrl,
                      esPropio: esPropio,
                    ),
                  );
                },
                child: Row(
                  children: [
                    // Foto de perfil del usuario
                    CircleAvatar(
                      backgroundColor: AppColors.seaGreen,
                      radius: 16,
                      backgroundImage: profilePictureUrl != null && profilePictureUrl!.isNotEmpty
                          ? NetworkImage(profilePictureUrl!)
                          : null,
                      child: profilePictureUrl == null || profilePictureUrl!.isEmpty
                          ? const Icon(Icons.person, color: Colors.white, size: 18)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  esPropio ? '$usuario (Tú)' : usuario,
                                  style: const TextStyle(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              if (badgeProgress != null) ...[
                                const SizedBox(width: 6),
                                // Progreso de insignias
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.amber.shade300, width: 0.5),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.star,
                                        size: 12,
                                        color: Colors.amber.shade700,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        badgeProgress!,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.amber.shade700,
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
                    const SizedBox(width: 8),
                    Text(
                      hora,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 13,
                      ),
                    ),
                    if (isPending) ...[
                      const SizedBox(width: 8),
                      // Indicador de mensaje pendiente
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange, width: 1),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 12,
                              color: Colors.orange,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Pendiente',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (texto.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    texto,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 15,
                    ),
                  ),
                ),
              if (imagen != null && imagen!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: GestureDetector(
                    onTap: () => _showFullScreenImage(context, imagen!),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imagen!,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        // Mostrar un indicador de carga mientras la imagen se descarga
                        loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                          if (loadingProgress == null) return child; // Imagen cargada
                          return Container(
                            height: 160,
                            width: double.infinity,
                            color: Colors.grey[300], // Un color de fondo mientras carga
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                    : null,
                                color: AppColors.textWhite,
                              ),
                            ),
                          );
                        },
                        // Mostrar un widget de error si la imagen no se puede cargar
                        errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
                          return Container(
                            height: 160,
                            width: double.infinity,
                            color: Colors.grey[300],
                            child: const Center(
                              child: Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 40,
                              ),
                            ),
                          );
                        },
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

// Widget para mostrar imagen en pantalla completa
class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
  });

  // Método para descargar la imagen
  Future<void> _downloadImage(BuildContext context) async {
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
              saveDirectory = Directory('/storage/emulated/0/DCIM/BioDetect_Chat');
              displayPath = 'DCIM/BioDetect_Chat';
            } catch (e) {
              // Si falla, usar directorio de la app
              final appDir = await getExternalStorageDirectory();
              saveDirectory = Directory('${appDir?.path ?? ''}/BioDetect_Chat');
              displayPath = 'BioDetect_Chat';
            }
          } else {
            // En iOS, usar el directorio de documentos de la app
            final appDir = await getApplicationDocumentsDirectory();
            saveDirectory = Directory('${appDir.path}/BioDetect_Chat');
            displayPath = 'BioDetect_Chat';
          }
          
          // Crear el directorio si no existe
          if (!await saveDirectory.exists()) {
            await saveDirectory.create(recursive: true);
          }
          
          // Generar nombre único para el archivo
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final dateTime = DateTime.now();
          final fileName = 'chat_${dateTime.year}${dateTime.month.toString().padLeft(2, '0')}${dateTime.day.toString().padLeft(2, '0')}_$timestamp.jpg';
          final filePath = '${saveDirectory.path}/$fileName';
          
          // Guardar la imagen
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);
          
          displayPath = '$displayPath/$fileName';
          
          // Cerrar indicador de descarga
          if (context.mounted) Navigator.of(context).pop();
          
          // Mostrar mensaje de éxito
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Imagen guardada en: $displayPath'),
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
            onPressed: () => _downloadImage(context),
            tooltip: 'Descargar imagen',
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          scaleEnabled: true,
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                  color: Colors.white,
                ),
              );
            },
            errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
              return const Center(
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
              );
            },
          ),
        ),
      ),
    );
  }
}