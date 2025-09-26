import 'package:biodetect/views/notes/explorar_bitacoras_publicas_screen.dart';
import 'package:biodetect/screens/forum_screen.dart';
import 'package:biodetect/views/registers/album_fotos.dart';
import 'package:biodetect/screens/profile_screen.dart';
import 'package:biodetect/themes.dart';
import 'package:flutter/material.dart';

class MainMenu extends StatefulWidget {
  const MainMenu({super.key});

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    const AlbumFotos(),
    const ForumScreen(),
    const ExplorarBitacorasPublicasScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: AppColors.backgroundNavBarsLigth,
        selectedItemColor: AppColors.selectedItemLightBottomNavBar,
        unselectedItemColor: AppColors.unselectedItemLightBottomNavBar,
        type: BottomNavigationBarType.fixed,
        selectedIconTheme: const IconThemeData(size: 28),
        unselectedIconTheme: const IconThemeData(size: 24),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.photo_library),
            label: 'Album',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.forum),
            label: 'Forum',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Binnacle',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}