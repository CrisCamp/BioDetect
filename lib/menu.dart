import 'package:biodetect/screens/note_screen.dart';
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

class _MainMenuState extends State<MainMenu> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late PageController _pageController;
  
  // Lista de widgets que se mantendrán en memoria
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    
    // Inicializar las pantallas una sola vez
    _screens = [
      const _KeepAliveWrapper(child: AlbumFotos()),
      const _KeepAliveWrapper(child: ForumScreen()),
      const _KeepAliveWrapper(child: BinnacleScreen()),
      const _KeepAliveWrapper(child: ProfileScreen()),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (index != _currentIndex) {
      setState(() {
        _currentIndex = index;
      });
      
      // Animar suavemente a la nueva página
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        // Permitir deslizamiento horizontal entre páginas (opcional)
        physics: const NeverScrollableScrollPhysics(), // Deshabilitar swipe si prefieres solo navegación por botones
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        backgroundColor: AppColors.backgroundNavBarsLigth,
        selectedItemColor: AppColors.selectedItemLightBottomNavBar,
        unselectedItemColor: AppColors.unselectedItemLightBottomNavBar,
        type: BottomNavigationBarType.fixed,
        selectedIconTheme: const IconThemeData(size: 28),
        unselectedIconTheme: const IconThemeData(size: 24),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.photo_library),
            label: 'Álbum',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.forum),
            label: 'Foro',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Bitácoras',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

// Wrapper que mantiene vivas las páginas para evitar que se recarguen
class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  
  const _KeepAliveWrapper({required this.child});

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Importante: llamar super.build()
    return widget.child;
  }
}