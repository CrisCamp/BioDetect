import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:biodetect/menu.dart';
import 'package:biodetect/views/session/inicio_sesion.dart';
import 'package:biodetect/themes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar AdMob
  await MobileAds.instance.initialize();
  
  // Configurar Mapbox access token
  const String mapboxAccessToken = "pk.eyJ1IjoiYmlvZGV0ZWN0YXBwIiwiYSI6ImNtZjAyMnE1YTBpaXYydHByaTR3dm9xZjkifQ.wrMFQYEPE_iWQnezMPPbwQ";
  mapbox.MapboxOptions.setAccessToken(mapboxAccessToken);
  
  // Inicializar Firebase
  await Firebase.initializeApp();
  
  // Habilitar persistencia de Firestore para cache offline
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BioDetect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: AppColors.backgroundPrimary,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.backgroundNavBarsLigth,
          foregroundColor: AppColors.textWhite,
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isCheckingAutoLogin = true;

  @override
  void initState() {
    super.initState();
    _checkAutoLoginFirst();
  }

  Future<void> _checkAutoLoginFirst() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final autoLogin = prefs.getBool('auto_login') ?? false;
      final user = FirebaseAuth.instance.currentUser;

      // Si hay usuario pero NO marcó recordar sesión, hacer logout
      if (user != null && !autoLogin) {
        await prefs.clear();
        await FirebaseAuth.instance.signOut();
      }
    } catch (e) {
      // Si hay error, simplemente continuar
    }

    setState(() {
      _isCheckingAutoLogin = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Mostrar loading mientras verificamos auto-login
    if (_isCheckingAutoLogin) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.buttonGreen1),
        ),
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.backgroundPrimary,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.buttonGreen1),
            ),
          );
        }
        
        final user = snapshot.data;
        
        if (user != null) {
          if (user.providerData.any((info) => info.providerId == 'password')) {
            if (user.emailVerified) {
              return const MainMenu();
            } else {
              // Usuario no verificado, enviar de vuelta al login
              return const InicioSesion();
            }
          } 
          else {
            return const MainMenu();
          }
        }
        
        return const InicioSesion();
      },
    );
  }
}