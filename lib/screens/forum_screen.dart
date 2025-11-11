import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:biodetect/themes.dart';
import 'package:biodetect/services/banner_ad_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';

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
                backgroundImage:
                    profilePictureUrl != null && profilePictureUrl!.isNotEmpty
                        ? CachedNetworkImageProvider(profilePictureUrl!)
                        : null,
                child: profilePictureUrl == null || profilePictureUrl!.isEmpty
                    ? const Icon(Icons.person, color: Colors.white, size: 60)
                    : null,
              ),
              const SizedBox(height: 16),

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

              FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance.collection('badges').get(),
                builder: (context, badgesSnapshot) {
                  if (!badgesSnapshot.hasData) {
                    return const CircularProgressIndicator(
                        color: AppColors.seaGreen);
                  }

                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .get(),
                    builder: (context, userSnapshot) {
                      if (!userSnapshot.hasData) {
                        return const CircularProgressIndicator(
                            color: AppColors.seaGreen);
                      }

                      final userData =
                          userSnapshot.data!.data() as Map<String, dynamic>?;
                      final userBadges =
                          userData?['badges'] as List<dynamic>? ?? [];
                      final allBadges = badgesSnapshot.data!.docs;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.star,
                                  color: Colors.amber, size: 20),
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
                                  final sortedBadges =
                                      List<QueryDocumentSnapshot>.from(
                                          allBadges);
                                  sortedBadges.sort((a, b) {
                                    final dataA =
                                        a.data() as Map<String, dynamic>;
                                    final dataB =
                                        b.data() as Map<String, dynamic>;
                                    final orderA =
                                        dataA['order'] as int? ?? 999;
                                    final orderB =
                                        dataB['order'] as int? ?? 999;
                                    return orderA.compareTo(orderB);
                                  });

                                  return Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: sortedBadges.map((badge) {
                                      final badgeData =
                                          badge.data() as Map<String, dynamic>;
                                      final badgeOrder =
                                          badgeData['order'] as int?;

                                      // Convertir userBadges a List<int> para comparación con el campo "order"
                                      final userBadgeOrders =
                                          userBadges.map((e) {
                                        if (e is int) return e;
                                        if (e is String)
                                          return int.tryParse(e) ?? -1;
                                        return -1;
                                      }).toList();

                                      final hasBadge = badgeOrder != null &&
                                          userBadgeOrders.contains(badgeOrder);
                                      final badgeIconName = badgeData[
                                              'iconName']
                                          as String?; // Nombre del archivo de la imagen

                                      return SizedBox(
                                        width:
                                            70, // Ancho fijo para mantener 3 por fila aproximadamente
                                        height: 100,
                                        child: Opacity(
                                          opacity: hasBadge
                                              ? 1.0
                                              : 0.4, // Insignias no conseguidas más opacas
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: hasBadge
                                                  ? AppColors.seaGreen
                                                      .withOpacity(0.3)
                                                  : Colors.grey
                                                      .withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: hasBadge
                                                    ? AppColors.seaGreen
                                                    : Colors.grey,
                                                width: 2,
                                              ),
                                              boxShadow: hasBadge
                                                  ? [
                                                      BoxShadow(
                                                        color: AppColors
                                                            .seaGreen
                                                            .withOpacity(0.3),
                                                        blurRadius: 8,
                                                        spreadRadius: 1,
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(8),
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  // Imagen de la insignia o ícono por defecto
                                                  Container(
                                                    width: 38,
                                                    height: 38,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child: badgeIconName !=
                                                                null &&
                                                            badgeIconName
                                                                .isNotEmpty
                                                        ? ClipRRect(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8),
                                                            child: Image.asset(
                                                              'assets/badge_icons/$badgeIconName.png',
                                                              width: 32,
                                                              height: 32,
                                                              fit: BoxFit.cover,
                                                              errorBuilder:
                                                                  (context,
                                                                      error,
                                                                      stackTrace) {
                                                                // Si la imagen no se puede cargar, mostramos ícono por defecto
                                                                return Icon(
                                                                  Icons.star,
                                                                  color: hasBadge
                                                                      ? Colors
                                                                          .amber
                                                                      : Colors
                                                                          .grey,
                                                                  size: 28,
                                                                );
                                                              },
                                                            ),
                                                          )
                                                        : Icon(
                                                            Icons.star,
                                                            color: hasBadge
                                                                ? Colors.amber
                                                                : Colors.grey,
                                                            size: 28,
                                                          ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    badgeData['name'] ??
                                                        'Insignia',
                                                    style: TextStyle(
                                                      color: hasBadge
                                                          ? AppColors.white
                                                          : Colors.grey,
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
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

              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.seaGreen,
                  foregroundColor: AppColors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

class Message {
  final String id;
  final String userId;
  final String userName;
  final String content;
  final bool includeImage;
  final String? imageUrl;
  final String? profilePictureUrl;
  final String badgeProgress;
  final Timestamp createdAt;
  final bool esPropio;
  final bool isPending;

  Message({
    required this.id,
    required this.userId,
    required this.userName,
    required this.content,
    required this.includeImage,
    this.imageUrl,
    this.profilePictureUrl,
    this.badgeProgress = "0/13",
    required this.createdAt,
    required this.esPropio,
    this.isPending = false,
  });

  factory Message.fromFirestore(DocumentSnapshot doc, String currentUserId) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    if (data.containsKey('test') && data['test'] == true) {
      throw Exception('Documento de prueba detectado - no crear mensaje');
    }
    
    final content = data['content'] ?? '';
    if (content.trim().isEmpty) {
      throw Exception('Mensaje con contenido vacío - no crear mensaje');
    }
    
    final userId = data['userId'] ?? '';
    if (userId.isEmpty) {
      throw Exception('Mensaje sin userId válido - no crear mensaje');
    }
    
    return Message(
      id: doc.id,
      userId: userId,
      userName: data['user_name'] ?? 'Usuario Desconocido',
      content: content,
      includeImage: data['includeImage'] ?? false,
      imageUrl: data['imageUrl'],
      profilePictureUrl: null,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      esPropio: userId == currentUserId,
    );
  }

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
        const totalBadges = 13;

        final profilePictureUrl = userData['profilePicture'] as String?;
        final badgeProgress = '$badgeCount/$totalBadges';

        return message.copyWithProfileData(profilePictureUrl, badgeProgress);
      }
    } catch (e) {
      print('Error al cargar datos del perfil para ${message.userId}: $e');
    }
    return message.copyWithProfileData(null, '0/13');
  }

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
      isPending: isPending,
    );
  }

  String get formattedTime {
    final dateTime = createdAt.toDate();
    return "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
  }

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

class _ForumScreenState extends State<ForumScreen> with WidgetsBindingObserver, BannerAdMixin {
  File? _image;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _currentUserId;
  String? _currentUserName;

  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;

  List<Message> _messages = [];
  StreamSubscription<QuerySnapshot>? _messageSubscription;
  Timestamp? _lastMessageTimestamp;
  bool _isLoadingHistory = false;
  bool _isLoadingMore = false;
  static const int _messageLimit = 50;
  static const int _loadMoreLimit = 10;
  DocumentSnapshot? _lastDocument;
  bool _hasMoreMessages = true;
  final ScrollController _scrollController = ScrollController();

  bool _hasInternet = true;
  bool _isSendingPendingMessages = false;
  Timer? _connectionCheckTimer;
  int _characterCount = 0;
  static const int _maxCharacters = 255;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _configureCacheSettings();
    initializeBanner();
    _setupScrollListener();
    _initializeApp();
    
    // Inicializar contador de caracteres
    _characterCount = _messageController.text.length;
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (!_isLoadingMore && _hasMoreMessages && _hasInternet) {
          _loadMoreMessages();
        }
      }
    });
  }

  void _configureCacheSettings() {
  }

  bool _hasPendingMessages() {
    return _messages.any((msg) => msg.isPending);
  }

  int _getPendingMessagesCount() {
    return _messages.where((msg) => msg.isPending).length;
  }

  List<Message> _getPendingMessages() {
    return _messages.where((msg) => msg.isPending).toList();
  }

  Future<void> _initializeApp() async {
    await _loadPendingMessages();
    await _cleanupPendingMessages();
    _getCurrentUser();
    await _checkInternetConnection();
    _startPeriodicConnectionCheck();

    Timer(const Duration(seconds: 3), () {
      _checkAndSendPendingMessagesOnStartup();
    });
  }

  void _getCurrentUser() {
    final user = _auth.currentUser;
    if (user != null) {
      String userName = user.displayName ?? '';
      
      if (userName.isEmpty && user.email != null) {
        userName = user.email!.split('@').first;
      }
      
      if (userName.isEmpty) {
        userName = "Usuario";
      }
      
      setState(() {
        _currentUserId = user.uid;
        _currentUserName = userName;
      });
      
      if (kDebugMode) {
        print('✅ Usuario autenticado:');
        print('   - ID: ${user.uid}');
        print('   - Nombre: $userName');
        print('   - Email: ${user.email}');
        print('   - DisplayName: ${user.displayName}');
      }
      
      _initializeMessageStream();
      _addPendingMessagesToUI();
    } else {
      if (kDebugMode) {
        print(
            "Usuario no autenticado. El foro podría no funcionar completamente.");
      }
    }
  }

  Future<void> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('dns.google');
      bool hasConnection = result.isNotEmpty && result[0].rawAddress.isNotEmpty;

      bool wasOffline = !_hasInternet;

      setState(() {
        _hasInternet = hasConnection;
      });

      if (kDebugMode) {
        print('🌐 Estado de conexión:');
        print('   - Anteriormente offline: $wasOffline');
        print('   - Ahora online: $hasConnection');
        print('   - Listener activo: ${_messageSubscription != null}');
        print('   - Usuario ID: $_currentUserId');
      }

      if (wasOffline && hasConnection && _hasPendingMessages()) {
        if (kDebugMode) {
          print('Conexión recuperada. Enviando ${_getPendingMessagesCount()} mensajes pendientes...');
          _testFirestoreConnection();
        }
        _sendPendingMessages();
        _setupNewMessageListener();
      } else if (hasConnection && _messageSubscription == null && _currentUserId != null) {
        // Si tenemos conexión pero no hay listener activo, configurar uno nuevo
        // SOLO si ya se han cargado los mensajes iniciales (indicado por _lastMessageTimestamp o mensajes en cache)
        if (_lastMessageTimestamp != null || _messages.isNotEmpty) {
          if (kDebugMode) {
            print('🔗 Configurando listener - conexión disponible pero listener inactivo');
          }
          _setupNewMessageListener();
        } else {
          if (kDebugMode) {
            print('⏳ Esperando carga inicial de mensajes antes de configurar listener');
          }
        }
      } else if (!hasConnection && _messageSubscription != null) {
        // Si no hay conexión, cancelar el listener
        if (kDebugMode) {
          print('❌ Sin conexión - cancelando listener');
        }
        _messageSubscription?.cancel();
        _messageSubscription = null;
      } else if (hasConnection && _messageSubscription != null) {
        // Verificar que el listener esté funcionando correctamente
        if (kDebugMode) {
          print('✅ Conexión y listener activos');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error verificando conexión: $e');
      }
      setState(() {
        _hasInternet = false;
      });
      
      // Cancelar listener si hay error de conexión
      if (_messageSubscription != null) {
        _messageSubscription?.cancel();
        _messageSubscription = null;
      }
    }
  }

  void _startPeriodicConnectionCheck() {
    _connectionCheckTimer =
        Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkInternetConnection();
      
      // Verificar también que el listener esté activo cuando debería estarlo
      if (_hasInternet && _currentUserId != null && _messageSubscription == null) {
        // Solo reactivar si ya se completó la carga inicial
        if (_lastMessageTimestamp != null || _messages.isNotEmpty) {
          if (kDebugMode) {
            print('🔄 Detectado listener inactivo con conexión disponible - reactivando');
          }
          _setupNewMessageListener();
        }
      }
    });
  }

  Future<void> _checkAndSendPendingMessagesOnStartup() async {
    if (kDebugMode) {
      print('🔄 Verificando mensajes pendientes al iniciar la app...');
      print('   - Mensajes pendientes: ${_getPendingMessagesCount()}');
      print('   - Internet disponible: $_hasInternet');
      print('   - Usuario actual: $_currentUserId');
    }

    if (_hasPendingMessages()) {
      if (kDebugMode) {
        print('📤 Hay mensajes pendientes, verificando conexión a Firestore...');
      }

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

  Future<void> _sendPendingMessages() async {
    if (!_hasPendingMessages() || !_hasInternet || _isSendingPendingMessages)
      return;

    if (kDebugMode) {
      print('🚀 Iniciando envío de ${_getPendingMessagesCount()} mensajes pendientes...');
      print('   - Usuario actual: $_currentUserId');
      print('   - Nombre usuario: $_currentUserName');
      print('   - Internet disponible: $_hasInternet');
    }

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      if (kDebugMode) {
        print('❌ Usuario no autenticado, cancelando envío de mensajes pendientes');
      }
      return;
    }

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

    final messagesToSend = _getPendingMessages();
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
        continue;
      }

      try {
        if (!message.includeImage) {
          if (kDebugMode) {
            print('   - Enviando mensaje de texto...');
          }

          await _sendMessageToFirestore(message).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('Timeout enviando mensaje a Firestore',
                  const Duration(seconds: 10));
            },
          );

          sentCount++;
          sentMessageIds.add(message.id);
          if (kDebugMode) {
            print('   - ✅ Mensaje enviado exitosamente');
          }
        } else {
          failedCount++;
          if (kDebugMode) {
            print('   - ❌ Mensaje con imagen no enviado (sin conexión para imágenes)');
          }
        }
      } catch (e) {
        failedCount++;
        if (kDebugMode) {
          print('   - ❌ Error enviando mensaje: $e');
        }
      }
    }

    setState(() {
      for (final messageId in sentMessageIds) {
        final index = _messages.indexWhere((msg) => msg.id == messageId);
        if (index != -1) {
          final existingMsg = _messages[index];
          _messages[index] = Message(
            id: existingMsg.id,
            userId: existingMsg.userId,
            userName: existingMsg.userName,
            content: existingMsg.content,
            includeImage: existingMsg.includeImage,
            imageUrl: existingMsg.imageUrl,
            profilePictureUrl: existingMsg.profilePictureUrl,
            badgeProgress: existingMsg.badgeProgress,
            createdAt: existingMsg.createdAt,
            esPropio: existingMsg.esPropio,
            isPending: false,
          );
        }
      }
      _messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });

    await _savePendingMessages();

    if (kDebugMode) {
      print('🧹 Limpieza completada:');
      print('   - Mensajes enviados: ${sentMessageIds.length}');
      print('   - Mensajes pendientes restantes: ${_getPendingMessagesCount()}');
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

        if (!_hasPendingMessages()) {
          if (_messages.isNotEmpty) {
            _lastMessageTimestamp = _messages.first.createdAt;
          }

          Timer(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {}); 
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

  Future<bool> _testFirestoreConnection() async {
    if (kDebugMode) {
      print('🧪 Probando conexión a Firestore...');
    }

    try {
      final testDoc = await _firestore.collection('connection_test').add({
        'test': true,
        'createdAt': Timestamp.now(),
        'userId': _currentUserId ?? 'test',
        'purpose': 'connectivity_check',
      }).timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        print('✅ Prueba exitosa, documento creado con ID: ${testDoc.id}');
      }

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
        'createdAt': message.createdAt,
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
      rethrow;
    }
  }

  Future<void> _loadPendingMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingMessagesJson = prefs.getStringList('pending_messages') ?? [];

      if (kDebugMode) {
        print('📱 Cargando mensajes pendientes desde SharedPreferences...');
        print('   - Mensajes en caché: ${pendingMessagesJson.length}');
      }

      final pendingMessages = pendingMessagesJson
          .map((jsonString) => Message.fromJson(jsonDecode(jsonString)))
          .toList();

      final validPendingMessages = pendingMessages
          .where((msg) => msg.content.trim().isNotEmpty && msg.userId.isNotEmpty)
          .toList();
      
      validPendingMessages.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        for (final pendingMsg in validPendingMessages) {
          final exists = _messages.any((existingMsg) => 
            existingMsg.id == pendingMsg.id || 
            (existingMsg.userId == pendingMsg.userId &&
             existingMsg.content.trim() == pendingMsg.content.trim() &&
             (existingMsg.createdAt.seconds - pendingMsg.createdAt.seconds).abs() <= 5)
          );
          
          if (!exists) {
            _messages.add(pendingMsg);
          } else if (kDebugMode) {
            print('   - Mensaje duplicado ignorado: "${pendingMsg.content}"');
          }
        }
        
        _messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      });

      if (kDebugMode) {
        print('✅ Cargados ${validPendingMessages.length} mensajes pendientes válidos');
        for (int i = 0; i < validPendingMessages.length && i < 5; i++) {
          final msg = validPendingMessages[i];
          print('   Mensaje $i: "${msg.content}" - ID: ${msg.id} - Timestamp: ${msg.createdAt}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error cargando mensajes pendientes: $e');
      }
    }
  }

  Future<void> _savePendingMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingMessages = _getPendingMessages();
      
      final validPendingMessages = pendingMessages
          .where((msg) => msg.content.trim().isNotEmpty && msg.userId.isNotEmpty)
          .toList();
      
      validPendingMessages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      final pendingMessagesJson = validPendingMessages
          .map((message) => jsonEncode(message.toJson()))
          .toList();

      await prefs.setStringList('pending_messages', pendingMessagesJson);

      if (kDebugMode) {
        print('💾 Guardados ${validPendingMessages.length} mensajes pendientes válidos en caché');
        for (int i = 0; i < validPendingMessages.length && i < 3; i++) {
          final msg = validPendingMessages[i];
          print('   Guardado $i: "${msg.content}" - ID: ${msg.id}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error guardando mensajes pendientes: $e');
      }
    }
  }

  Future<void> _cleanupPendingMessages() async {
    try {
      final now = DateTime.now();
      const maxAge = Duration(hours: 24);
      
      final initialCount = _messages.length;
      final initialPendingCount = _getPendingMessagesCount();
      
      setState(() {
        _messages.removeWhere((msg) {
          if (!msg.isPending) return false;
          
          final messageAge = now.difference(msg.createdAt.toDate());
          if (messageAge > maxAge) {
            if (kDebugMode) {
              print('🗑️ Removiendo mensaje pendiente antiguo: "${msg.content}" (${messageAge.inHours}h)');
            }
            return true;
          }
          
          if (msg.content.trim().isEmpty || msg.userId.isEmpty || msg.userName.isEmpty) {
            if (kDebugMode) {
              print('🗑️ Removiendo mensaje pendiente inválido: "${msg.content}"');
            }
            return true;
          }
          
          return false;
        });
      });
      
      final removedMessages = initialCount - _messages.length;
      final finalPendingCount = _getPendingMessagesCount();
      
      if (removedMessages > 0) {
        await _savePendingMessages();
        if (kDebugMode) {
          print('🧹 Limpieza completada:');
          print('   - Mensajes removidos: $removedMessages');
          print('   - Pendientes antes: $initialPendingCount');
          print('   - Pendientes después: $finalPendingCount');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error limpiando mensajes pendientes: $e');
      }
    }
  }

  void _addPendingMessagesToUI() {
    if (kDebugMode) {
      print('ℹ️ Los mensajes pendientes ya están integrados en _messages');
    }
  }

  void _initializeMessageStream() {
    if (!_hasInternet) {
      if (kDebugMode) {
        print('Sin conexión: usando mensajes del cache local');
      }
      return;
    }

    _loadInitialMessages().then((_) {
      // Solo configurar el listener DESPUÉS de cargar los mensajes iniciales
      if (kDebugMode) {
        print('🔗 Configurando listener después de cargar mensajes iniciales');
        print('   - _lastMessageTimestamp: $_lastMessageTimestamp');
      }
      _setupNewMessageListener();
    });
  }

  Future<void> _loadInitialMessages() async {
    if (_currentUserId == null || !_hasInternet) return;

    setState(() => _isLoadingHistory = true);

    try {
      final querySnapshot = await _firestore
          .collection('group_chat')
          .orderBy('createdAt', descending: true)
          .limit(_messageLimit)
          .get();

      final messages = <Message>[];
      for (final doc in querySnapshot.docs) {
        try {
          final message = Message.fromFirestore(doc, _currentUserId!);
          messages.add(message);
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Documento ignorado en carga inicial: $e');
            print('   - Documento ID: ${doc.id}');
          }
        }
      }

      // Guardar el último documento para paginación
      if (querySnapshot.docs.isNotEmpty) {
        _lastDocument = querySnapshot.docs.last;
        _hasMoreMessages = querySnapshot.docs.length == _messageLimit;
      } else {
        _hasMoreMessages = false;
      }

      final messagesWithProfile = <Message>[];
      for (final message in messages) {
        final existsInCache = _messages.any((existingMsg) =>
          existingMsg.id == message.id ||
          (existingMsg.userId == message.userId &&
           existingMsg.content.trim() == message.content.trim() &&
           (existingMsg.createdAt.seconds - message.createdAt.seconds).abs() <= 10)
        );

        if (!existsInCache) {
          final messageWithProfile = await Message.loadUserProfileData(message);
          messagesWithProfile.add(messageWithProfile);
        } else if (kDebugMode) {
          print('🔄 Mensaje ya existe en caché: "${message.content.substring(0, message.content.length > 20 ? 20 : message.content.length)}..."');
        }
      }

      setState(() {
        _messages.addAll(messagesWithProfile);
        _messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _lastMessageTimestamp = _messages.isNotEmpty ? _messages.first.createdAt : null;
        _isLoadingHistory = false;
      });

      if (kDebugMode) {
        print('✅ Cargados ${messagesWithProfile.length} mensajes iniciales desde Firestore');
        print('   - Total mensajes en UI: ${_messages.length}');
        print('   - Tiene más mensajes: $_hasMoreMessages');
        print('   - Mensajes pendientes: ${_getPendingMessagesCount()}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error cargando mensajes iniciales: $e');
      }
      setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_currentUserId == null || !_hasInternet || _lastDocument == null || !_hasMoreMessages) {
      return;
    }

    setState(() => _isLoadingMore = true);

    try {
      final querySnapshot = await _firestore
          .collection('group_chat')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_loadMoreLimit)
          .get();

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _hasMoreMessages = false;
          _isLoadingMore = false;
        });
        return;
      }

      final messages = <Message>[];
      for (final doc in querySnapshot.docs) {
        try {
          final message = Message.fromFirestore(doc, _currentUserId!);
          messages.add(message);
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Documento ignorado en carga adicional: $e');
          }
        }
      }

      // Actualizar el último documento para la siguiente carga
      _lastDocument = querySnapshot.docs.last;
      _hasMoreMessages = querySnapshot.docs.length == _loadMoreLimit;

      final messagesWithProfile = <Message>[];
      for (final message in messages) {
        final existsInMessages = _messages.any((existingMsg) =>
          existingMsg.id == message.id ||
          (existingMsg.userId == message.userId &&
           existingMsg.content.trim() == message.content.trim() &&
           (existingMsg.createdAt.seconds - message.createdAt.seconds).abs() <= 10)
        );

        if (!existsInMessages) {
          final messageWithProfile = await Message.loadUserProfileData(message);
          messagesWithProfile.add(messageWithProfile);
        }
      }

      setState(() {
        _messages.addAll(messagesWithProfile);
        _messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _isLoadingMore = false;
      });

      if (kDebugMode) {
        print('✅ Cargados ${messagesWithProfile.length} mensajes adicionales');
        print('   - Total mensajes en UI: ${_messages.length}');
        print('   - Tiene más mensajes: $_hasMoreMessages');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error cargando más mensajes: $e');
      }
      setState(() => _isLoadingMore = false);
    }
  }

  void _setupNewMessageListener() {
    if (_currentUserId == null || !_hasInternet) {
      if (kDebugMode) {
        print('❌ No se puede configurar listener - UserId: $_currentUserId, Internet: $_hasInternet');
      }
      return;
    }

    // Cancelar listener anterior si existe
    if (_messageSubscription != null) {
      if (kDebugMode) {
        print('🔄 Cancelando listener anterior antes de crear uno nuevo');
      }
      _messageSubscription?.cancel();
      _messageSubscription = null;
    }

    if (kDebugMode) {
      print('🔗 Configurando nuevo listener de mensajes...');
      print('   - Usuario ID: $_currentUserId');
      print('   - Último timestamp: $_lastMessageTimestamp');
      print('   - Internet disponible: $_hasInternet');
    }

    // Si no hay timestamp de referencia, usar uno ligeramente en el pasado
    // para evitar perder mensajes que lleguen justo al momento de configurar el listener
    final referenceTimestamp = _lastMessageTimestamp ?? 
        Timestamp.fromDate(DateTime.now().subtract(const Duration(seconds: 10)));

    if (kDebugMode) {
      print('   - Timestamp de referencia: $referenceTimestamp');
    }

    _messageSubscription = _firestore
        .collection('group_chat')
        .orderBy('createdAt', descending: false)
        .where('createdAt', isGreaterThan: referenceTimestamp)
        .snapshots()
        .listen((snapshot) async {
      if (kDebugMode) {
        print('📨 Snapshot recibido: ${snapshot.docChanges.length} cambios');
      }
      
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          try {
            final message = Message.fromFirestore(change.doc, _currentUserId!);

            if (message.content.trim().isEmpty) {
              if (kDebugMode) {
                print('⚠️ Mensaje vacío ignorado del stream - ID: ${message.id}');
              }
              continue;
            }

            if (message.userId.isEmpty) {
              if (kDebugMode) {
                print('⚠️ Mensaje sin userId ignorado del stream - ID: ${message.id}');
              }
              continue;
            }

            bool shouldAdd = true;

            final isDuplicate = _messages.any((existingMsg) {
              if (existingMsg.id == message.id) return true;

              if (existingMsg.userId == message.userId &&
                  existingMsg.content.trim() == message.content.trim() &&
                  (existingMsg.createdAt.seconds - message.createdAt.seconds).abs() <= 10) {
                
                if (kDebugMode) {
                  print('🔍 Posible duplicado detectado:');
                  print('   - Contenido: "${message.content}"');
                  print('   - Existente ID: ${existingMsg.id} (isPending: ${existingMsg.isPending})');
                  print('   - Nuevo ID: ${message.id} (isPending: ${message.isPending})');
                  print('   - Diferencia tiempo: ${(existingMsg.createdAt.seconds - message.createdAt.seconds).abs()} segundos');
                }

                if (existingMsg.isPending && !message.isPending) {
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
                        print('✅ Mensaje pendiente actualizado con ID oficial de Firestore');
                      }
                      
                      _savePendingMessages();
                    }
                  });
                } else if (!existingMsg.isPending && !message.isPending) {
                  if (kDebugMode) {
                    print('🔄 Duplicado de Firestore ignorado');
                  }
                }

                return true;
              }

              return false;
            });

            shouldAdd = !isDuplicate;

            if (shouldAdd) {
              if (kDebugMode) {
                print('📥 Nuevo mensaje del stream: ${message.content.substring(0, message.content.length > 20 ? 20 : message.content.length)}...');
                print('   - De usuario: ${message.userName} (${message.userId})');
                print('   - Timestamp: ${message.createdAt}');
                print('   - Es propio: ${message.esPropio}');
              }

              final messageWithProfile = await Message.loadUserProfileData(message);

              setState(() {
                _messages.insert(0, messageWithProfile);
                _lastMessageTimestamp = message.createdAt;

                // Limpiar exceso de mensajes solo si no estamos cargando más
                if (!_isLoadingMore && _messages.length > _messageLimit * 3) {
                  final removedCount = _messages.length - _messageLimit * 2;
                  _messages.removeRange(_messageLimit * 2, _messages.length);
                  
                  // Si removemos mensajes, podríamos tener más mensajes disponibles
                  _hasMoreMessages = true;
                  
                  if (kDebugMode) {
                    print('🧹 Removidos $removedCount mensajes antiguos para mantener rendimiento');
                  }
                }
              });
            } else {
              if (kDebugMode) {
                print('🔄 Mensaje duplicado ignorado: ${message.content.substring(0, message.content.length > 10 ? 10 : message.content.length)}...');
              }
            }
          } catch (e) {
            if (kDebugMode) {
              print('⚠️ Documento ignorado del stream: $e');
              print('   - Documento ID: ${change.doc.id}');
            }
          }
        }
      }
    }, onError: (error) {
      if (kDebugMode) {
        print('❌ Error en stream de mensajes: $error');
        print('🔄 Reintentando configurar listener...');
      }
      
      // Marcar como desconectado y verificar conexión
      setState(() {
        _hasInternet = false;
      });
      
      // Cancelar el listener actual
      _messageSubscription?.cancel();
      _messageSubscription = null;
      
      // Verificar conexión y reintentar
      _checkInternetConnection();
    });

    if (kDebugMode) {
      print('✅ Listener de mensajes configurado exitosamente');
    }
  }

  void _sendMessage() async {
    final messageContent = _messageController.text.trim();
    
    if (messageContent.isEmpty && _image == null) {
      if (kDebugMode) {
        print('⚠️ Intento de enviar mensaje vacío sin imagen - cancelado');
      }
      return;
    }
    
    if (_image == null && messageContent.isEmpty) {
      if (kDebugMode) {
        print('⚠️ Intento de enviar mensaje de texto vacío - cancelado');
      }
      return;
    }

    if (_currentUserId == null || _currentUserName == null) {
      if (kDebugMode) {
        print('❌ Usuario no identificado - UserId: $_currentUserId, UserName: $_currentUserName');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'No se puede enviar el mensaje. Usuario no identificado.')),
      );
      return;
    }

    if (_currentUserName!.isEmpty || _currentUserName == "Usuario Desconocido") {
      if (kDebugMode) {
        print('⚠️ Nombre de usuario inválido: "$_currentUserName" - reobteniendo datos del usuario');
      }
      _getCurrentUser();
      
      if (_currentUserName == null || _currentUserName!.isEmpty || _currentUserName == "Usuario Desconocido") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Error en datos del usuario. Intenta cerrar sesión y volver a iniciar.')),
        );
        return;
      }
    }

    await _checkInternetConnection();

    if (!_hasInternet && _image != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Sin conexión. Las imágenes solo se pueden enviar con conexión a internet.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Validación adicional del tamaño de imagen antes de enviar
    if (_image != null) {
      try {
        final fileSizeInBytes = await _image!.length();
        const maxSizeInBytes = 8 * 1024 * 1024; // 8 MB en bytes
        
        if (fileSizeInBytes > maxSizeInBytes) {
          final fileSizeInMB = (fileSizeInBytes / (1024 * 1024)).toStringAsFixed(1);
          
          if (kDebugMode) {
            print('❌ Intento de enviar imagen muy grande: ${fileSizeInMB}MB');
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'La imagen es muy grande (${fileSizeInMB}MB). '
                'Máximo permitido: 8MB. Por favor, selecciona una imagen más pequeña.',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Cambiar imagen',
                textColor: Colors.white,
                onPressed: () {
                  _quitarImagenSeleccionada();
                  Future.delayed(const Duration(milliseconds: 300), () {
                    _seleccionarGaleria();
                  });
                },
              ),
            ),
          );
          return;
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error verificando tamaño de imagen antes de enviar: $e');
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error procesando la imagen: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
    }

    setState(() => _isSending = true);

    final tempImage = _image;

    final tempId = 'temp_${_currentUserId}_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
    final messageTimestamp = Timestamp.now();
    
    final tempMessage = Message(
      id: tempId,
      userId: _currentUserId!,
      userName: _currentUserName!,
      content: messageContent,
      includeImage: tempImage != null,
      imageUrl: null,
      profilePictureUrl: null,
      badgeProgress: "0/13",
      createdAt: messageTimestamp,
      esPropio: true,
      isPending: !_hasInternet,
    );

    final tempMessageWithProfile = await Message.loadUserProfileData(tempMessage);

    setState(() {
      _messages.insert(0, tempMessageWithProfile);
      _messageController.clear();
      _characterCount = 0; // Reset contador de caracteres
      _image = null;
      _isSending = false;
    });

    if (!_hasInternet) {
      await _savePendingMessages();

      if (kDebugMode) {
        print('💾 Mensaje guardado sin conexión - ID: ${tempMessage.id}');
      }

      return;
    }

    try {
      String? imageUrl;
      bool hasImage = false;
      if (tempImage != null) {
        final photoId = FirebaseFirestore.instance.collection('group_chat').doc().id;
        final ref = FirebaseStorage.instance
            .ref()
            .child('group_chat/$_currentUserId/$photoId.jpg');
        await ref.putFile(tempImage);
        imageUrl = await ref.getDownloadURL();
        hasImage = true;

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

      final finalMessage = Message(
        id: tempMessage.id,
        userId: _currentUserId!,
        userName: _currentUserName!,
        content: messageContent,
        includeImage: hasImage,
        imageUrl: imageUrl,
        profilePictureUrl: tempMessageWithProfile.profilePictureUrl,
        badgeProgress: tempMessageWithProfile.badgeProgress,
        createdAt: messageTimestamp,
        esPropio: true,
      );

      await _sendMessageToFirestore(finalMessage);
      
      setState(() {
        final index = _messages.indexWhere((m) => m.id == tempMessage.id);
        if (index != -1) {
          _messages[index] = Message(
            id: tempMessage.id,
            userId: finalMessage.userId,
            userName: finalMessage.userName,
            content: finalMessage.content,
            includeImage: finalMessage.includeImage,
            imageUrl: finalMessage.imageUrl,
            profilePictureUrl: finalMessage.profilePictureUrl,
            badgeProgress: finalMessage.badgeProgress,
            createdAt: finalMessage.createdAt,
            esPropio: finalMessage.esPropio,
            isPending: false,
          );
        }
      });
    } catch (e) {
      setState(() {
        _messages.removeWhere((m) => m.id == tempMessage.id);
        _messageController.text = messageContent;
        _characterCount = messageContent.length; // Actualizar contador
        _image = tempImage;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar mensaje: $e')),
        );
      }
    }
  }

  Future<void> _seleccionarGaleria() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (pickedFile != null) {
      try {
        final file = File(pickedFile.path);
        final fileSizeInBytes = await file.length();
        const maxSizeInBytes = 8 * 1024 * 1024; // 8 MB en bytes
        
        if (kDebugMode) {
          final fileSizeInMB = (fileSizeInBytes / (1024 * 1024)).toStringAsFixed(2);
          print('📷 Imagen seleccionada:');
          print('   - Tamaño: ${fileSizeInMB}MB');
          print('   - Límite: 8MB');
          print('   - Válida: ${fileSizeInBytes <= maxSizeInBytes}');
        }
        
        if (fileSizeInBytes <= maxSizeInBytes) {
          setState(() {
            _image = file;
          });
          
          // Mostrar información del tamaño de la imagen seleccionada
          final fileSizeInMB = (fileSizeInBytes / (1024 * 1024)).toStringAsFixed(1);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Imagen seleccionada: ${fileSizeInMB}MB'),
                backgroundColor: AppColors.buttonGreen2,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else {
          // La imagen es muy grande
          final fileSizeInMB = (fileSizeInBytes / (1024 * 1024)).toStringAsFixed(1);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'La imagen es muy grande (${fileSizeInMB}MB).\n'
                  'El tamaño máximo permitido es 8MB.\n'
                  'Por favor, selecciona una imagen más pequeña.',
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          
          // Opcional: Mostrar dialog con opciones para el usuario
          if (mounted) {
            _showImageSizeDialog(fileSizeInMB);
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error verificando tamaño de imagen: $e');
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al procesar la imagen: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  /// Muestra un dialog informativo cuando la imagen es muy grande
  void _showImageSizeDialog(String fileSizeInMB) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.darkTeal,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: const BorderSide(color: AppColors.seaGreen, width: 2),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 10),
              Text(
                'Imagen muy grande',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'La imagen seleccionada tiene un tamaño de ${fileSizeInMB}MB.',
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Límite máximo: 8MB',
                style: TextStyle(
                  color: AppColors.seaGreen,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'Consejos para reducir el tamaño:',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Comprime la imagen antes de seleccionarla\n'
                '• Usa una resolución más baja\n'
                '• Convierte a formato JPG si es PNG\n'
                '• Toma una nueva foto con menor calidad',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.seaGreen,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text(
                'Entendido',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Permitir seleccionar otra imagen inmediatamente
                Future.delayed(const Duration(milliseconds: 300), () {
                  _seleccionarGaleria();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.seaGreen,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Seleccionar otra',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _quitarImagenSeleccionada() {
    setState(() {
      _image = null;
    });
  }

  void _updateCharacterCount(String text) {
    setState(() {
      _characterCount = text.length;
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

  // Función para manejar cambios en el mensaje con validación de saltos de línea
  void _onMessageChanged(String value) {
    final limitedText = _limitLineBreaks(value, 3);
    if (limitedText != value) {
      // Si el texto fue limitado, actualizar el controller sin triggear onChanged
      _messageController.value = _messageController.value.copyWith(
        text: limitedText,
        selection: TextSelection.collapsed(offset: limitedText.length),
      );
    }
    _updateCharacterCount(limitedText);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: AppColors.backgroundPrimary,
        child: SafeArea(
          child: Column(
            children: [
              buildBanner(margin: const EdgeInsets.symmetric(vertical: 8)),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Foro de la Comunidad',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              if (!_hasInternet || _hasPendingMessages() || _isSendingPendingMessages)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  color: !_hasInternet
                      ? Colors.red
                      : (_isSendingPendingMessages ||
                              _hasPendingMessages())
                          ? Colors.orange
                          : AppColors.buttonGreen2,
                  child: Row(
                    children: [
                      Icon(
                        !_hasInternet
                            ? Icons.cloud_off
                            : (_isSendingPendingMessages ||
                                    _hasPendingMessages())
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
                                  : _hasPendingMessages()
                                      ? 'Preparando ${_getPendingMessagesCount()} mensaje(s) para envío...'
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
              Expanded(
                child: _isLoadingHistory
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.textWhite),
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
                            controller: _scrollController,
                            reverse: true,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
                            cacheExtent: 500,
                            addAutomaticKeepAlives: true,
                            addRepaintBoundaries: true,
                            itemBuilder: (context, index) {
                              // Show loading indicator at the bottom (top in reverse list)
                              if (index == _messages.length) {
                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  alignment: Alignment.center,
                                  child: const CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.textWhite),
                                  ),
                                );
                              }

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

              if (_image != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  color: AppColors.slateGreen.withOpacity(0.5),
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
                          style: TextStyle(
                              color: AppColors.textWhite.withOpacity(0.8)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon:
                            const Icon(Icons.close, color: AppColors.textWhite),
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
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add_a_photo),
                          // ignore: deprecated_member_use
                          color: _hasInternet
                              ? AppColors.white
                              : AppColors.white.withOpacity(0.5),
                          tooltip: _hasInternet
                              ? 'Adjuntar imagen'
                              : 'Sin conexión - Solo mensajes de texto',
                          onPressed: (_isSending || !_hasInternet)
                              ? null
                              : _seleccionarGaleria,
                        ),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            style: const TextStyle(color: AppColors.white),
                            maxLength: _maxCharacters,
                            onChanged: _onMessageChanged,
                            decoration: InputDecoration(
                              hintText: 'Escribe un mensaje...',
                              hintStyle: const TextStyle(color: AppColors.white),
                              filled: true,
                              fillColor: Colors.transparent,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              counterText: '', // Ocultar el contador por defecto
                            ),
                            onSubmitted: (_) => (_isSending ||
                                    (_messageController.text.trim().isEmpty &&
                                        _image == null))
                                ? null
                                : _sendMessage(),
                            minLines: 1,
                            maxLines: 3,
                          ),
                        ),
                        IconButton(
                          icon: _isSending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: AppColors.white))
                              : const Icon(Icons.send),
                          color: AppColors.white,
                          onPressed: _isSending ? null : _sendMessage,
                        ),
                      ],
                    ),
                    // Contador de caracteres personalizado
                    Padding(
                      padding: const EdgeInsets.only(right: 16, bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '$_characterCount/$_maxCharacters',
                            style: TextStyle(
                              color: _characterCount > _maxCharacters * 0.8
                                  ? _characterCount >= _maxCharacters
                                      ? Colors.red
                                      : Colors.orange
                                  : AppColors.white.withOpacity(0.6),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
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
      ),
    );
  }

  @override
  void dispose() {
    if (_hasPendingMessages()) {
      _savePendingMessages().catchError((e) {
        if (kDebugMode) {
          print('❌ Error guardando mensajes pendientes en dispose: $e');
        }
      });
    }
    
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    _messageSubscription?.cancel();
    _connectionCheckTimer?.cancel();
    disposeBanner();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      if (_hasPendingMessages()) {
        if (kDebugMode) {
          print('📱 App pausada/cerrada, guardando ${_getPendingMessagesCount()} mensajes pendientes...');
        }
        _savePendingMessages().catchError((e) {
          if (kDebugMode) {
            print('❌ Error guardando mensajes pendientes en pausa: $e');
          }
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      if (kDebugMode) {
        print('📱 App resumida, verificando estado del foro...');
        print('   - Internet: $_hasInternet');
        print('   - Usuario ID: $_currentUserId');
        print('   - Listener activo: ${_messageSubscription != null}');
        print('   - Mensajes pendientes: ${_getPendingMessagesCount()}');
      }
      
      // Verificar conexión y reactivar listener si es necesario
      _checkInternetConnection().then((_) {
        // Si hay mensajes pendientes, enviarlos
        if (_hasInternet && _hasPendingMessages()) {
          Timer(const Duration(seconds: 2), () {
            _sendPendingMessages();
          });
        }
        
        // Verificar que el listener esté activo
        if (_hasInternet && _currentUserId != null && _messageSubscription == null) {
          if (kDebugMode) {
            print('🔄 Reactivando listener al resumir la app');
          }
          Timer(const Duration(seconds: 1), () {
            _setupNewMessageListener();
          });
        }
      });
    }
  }
}

class ForoMensajeCard extends StatelessWidget {
  final bool esPropio;
  final String usuario;
  final String userId;
  final String hora;
  final String texto;
  final String? imagen;
  final String? profilePictureUrl;
  final String? badgeProgress;
  final bool isPending;

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
    this.isPending = false,
  });

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
                      backgroundImage: profilePictureUrl != null &&
                              profilePictureUrl!.isNotEmpty
                          ? CachedNetworkImageProvider(profilePictureUrl!)
                          : null,
                      child: profilePictureUrl == null ||
                              profilePictureUrl!.isEmpty
                          ? const Icon(Icons.person,
                              color: Colors.white, size: 18)
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
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: Colors.amber.shade300,
                                        width: 0.5),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
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
                      child: CachedNetworkImage(
                        imageUrl: imagen!,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        // Widget de carga optimizado
                        placeholder: (context, url) => Container(
                          height: 160,
                          width: double.infinity,
                          color: Colors.grey[300],
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.textWhite,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                        // Widget de error optimizado
                        errorWidget: (context, url, error) => Container(
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
                        ),
                        // Configuración de caché
                        cacheKey: imagen!, // Usar la URL como clave de caché
                        memCacheHeight: 160, // Limitar el tamaño en memoria
                        memCacheWidth: null, // Mantener proporción
                        maxHeightDiskCache: 400, // Tamaño máximo en disco
                        fadeInDuration: const Duration(milliseconds: 200), // Animación suave
                        fadeOutDuration: const Duration(milliseconds: 100),
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

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
  });

  // Verificar conexión a internet
  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('dns.google');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _downloadImage(BuildContext context) async {
    try {
      // VALIDACIÓN 1: Verificar conexión a internet antes de iniciar la descarga
      print('🔍 Verificando conexión a internet...');
      final hasInternet = await _checkInternetConnection();
      
      if (!hasInternet) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.wifi_off, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sin conexión a internet. Verifica tu conexión e inténtalo de nuevo.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.warning,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      // Mostrar indicador de descarga con información detallada
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.deepGreen),
                strokeWidth: 3.0,
              ),
              const SizedBox(height: 20),
              const Text(
                'Descargando imagen del foro...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Verificando conexión y descargando archivo\nEsto puede tomar unos momentos',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.wifi,
                    size: 16,
                    color: Colors.green[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Conexión verificada',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      print('🌐 Iniciando descarga de imagen del foro desde: $imageUrl');
      
      // DESCARGA CON TIMEOUT Y VALIDACIÓN DE CONEXIÓN
      final response = await http.get(
        Uri.parse(imageUrl),
      ).timeout(
        const Duration(seconds: 30), // Timeout de 30 segundos
        onTimeout: () {
          throw TimeoutException('La descarga tardó demasiado tiempo. Verifica tu conexión a internet.', const Duration(seconds: 30));
        },
      );

      if (response.statusCode == 200) {
        print('✅ Descarga exitosa. Tamaño: ${response.bodyBytes.length} bytes');
        
        // VALIDACIÓN 2: Verificar que los datos descargados no estén vacíos
        if (response.bodyBytes.isEmpty) {
          throw Exception('La imagen descargada está vacía. Verifica tu conexión e inténtalo de nuevo.');
        }
        
        // Generar nombre único para imagen del foro
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'BioDetect_Foro_$timestamp';
        
        print('💾 Guardando imagen del foro como: $fileName');
        
        // Usar MediaStore para guardar imagen
        await _saveImageToMediaStore(response.bodyBytes, fileName);
        
        // Cerrar indicador
        if (context.mounted) Navigator.of(context).pop();
        
        // Mostrar mensaje de éxito
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Imagen del foro guardada en Galería → BioDetect → Foro'),
              backgroundColor: AppColors.buttonGreen2,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else if (response.statusCode == 404) {
        throw Exception('La imagen no se encontró en el servidor (Error 404).');
      } else if (response.statusCode >= 500) {
        throw Exception('Error del servidor (${response.statusCode}). Inténtalo más tarde.');
      } else {
        throw Exception('Error al descargar la imagen (Código ${response.statusCode}). Verifica tu conexión.');
      }
    } on TimeoutException catch (_) {
      // Error específico de timeout
      print('⏰ Timeout en descarga de imagen del foro');
      if (context.mounted) Navigator.of(context).pop();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.access_time, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'La descarga tardó demasiado tiempo. Verifica tu conexión a internet e inténtalo de nuevo.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.warning,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } on SocketException catch (_) {
      // Error específico de conexión de red
      print('🌐 Error de conexión de red');
      if (context.mounted) Navigator.of(context).pop();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sin conexión a internet. Verifica tu conexión e inténtalo de nuevo.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.warning,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } on FormatException catch (_) {
      // Error de formato de datos
      print('📄 Error de formato en la respuesta');
      if (context.mounted) Navigator.of(context).pop();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'La imagen tiene un formato inválido. Por favor reporta este problema.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      // Manejo de otros errores con mensajes específicos
      print('❌ Error en descarga del foro: $e');
      if (context.mounted) Navigator.of(context).pop();
      
      String errorMessage = 'Error inesperado al descargar la imagen.';
      Color backgroundColor = Colors.red;
      IconData errorIcon = Icons.error_outline;
      
      // Analizar el tipo de error para proporcionar mensajes específicos
      final errorString = e.toString().toLowerCase();
      
      if (errorString.contains('connection') || errorString.contains('network') || errorString.contains('internet')) {
        errorMessage = 'Problema de conexión a internet. Verifica tu conexión e inténtalo de nuevo.';
        backgroundColor = AppColors.warning;
        errorIcon = Icons.wifi_off;
      } else if (errorString.contains('404')) {
        errorMessage = 'La imagen no se encontró en el servidor.';
        backgroundColor = AppColors.warning;
        errorIcon = Icons.image_not_supported;
      } else if (errorString.contains('500') || errorString.contains('server')) {
        errorMessage = 'Error del servidor. Inténtalo más tarde.';
        backgroundColor = AppColors.warning;
        errorIcon = Icons.cloud_off;
      } else if (errorString.contains('permission') || errorString.contains('storage')) {
        errorMessage = 'Error al guardar la imagen. Verifica los permisos de almacenamiento.';
        backgroundColor = Colors.orange;
        errorIcon = Icons.folder_off;
      } else if (errorString.contains('space') || errorString.contains('full')) {
        errorMessage = 'No hay suficiente espacio de almacenamiento.';
        backgroundColor = Colors.orange;
        errorIcon = Icons.storage;
      } else {
        // Error genérico con información útil
        errorMessage = 'Error al descargar: ${e.toString().length > 100 ? e.toString().substring(0, 100) + "..." : e.toString()}';
      }
      
      if (context.mounted) {
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
            backgroundColor: backgroundColor,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Reintentar',
              textColor: Colors.white,
              onPressed: () => _downloadImage(context),
            ),
          ),
        );
      }
    }
  }

  // Guardar imagen en MediaStore (Android) - Solo para foro
  Future<void> _saveImageToMediaStore(Uint8List imageBytes, String fileName) async {
    const platform = MethodChannel('biodetect/mediastore');
    
    try {
      await platform.invokeMethod('saveImage', {
        'bytes': imageBytes,
        'fileName': '$fileName.jpg',
        'mimeType': 'image/jpeg',
        'collection': 'DCIM/BioDetect/Foro', // Carpeta específica para imágenes del foro
      });
    } catch (e) {
      throw Exception('Error guardando imagen en MediaStore: $e');
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
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
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
            // Para pantalla completa, permitir resolución completa
            memCacheHeight: null,
            memCacheWidth: null,
            fadeInDuration: const Duration(milliseconds: 300),
          ),
        ),
      ),
    );
  }
}
