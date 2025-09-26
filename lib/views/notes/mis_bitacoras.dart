import 'dart:io';
import 'package:biodetect/themes.dart';
import 'package:biodetect/services/bitacora_service.dart';
import 'package:biodetect/views/notes/crear_editar_bitacora_screen.dart';
import 'package:biodetect/views/notes/detalle_bitacora_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MisBitacorasScreen extends StatefulWidget {
  const MisBitacorasScreen({super.key});

  @override
  State<MisBitacorasScreen> createState() => _MisBitacorasScreenState();
}

class _MisBitacorasScreenState extends State<MisBitacorasScreen> {
  List<Map<String, dynamic>> _bitacoras = [];
  List<Map<String, dynamic>> _filteredBitacoras = [];
  bool _isLoading = true;
  bool _hasInternet = true;
  String _searchText = '';
  String _filtroActivo = 'todas'; // todas, publicas, privadas

  @override
  void initState() {
    super.initState();
    _loadBitacoras();
    _checkInternetConnection();
  }

  Future<void> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      setState(() {
        _hasInternet = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      });
    } catch (_) {
      setState(() {
        _hasInternet = false;
      });
    }
  }

  Future<void> _loadBitacoras() async {
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final bitacoras = await BitacoraService.getMyBitacoras(user.uid);
      
      setState(() {
        _bitacoras = bitacoras;
        _isLoading = false;
      });
      
      _aplicarFiltros();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar bitácoras: $e'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    }
  }

  void _aplicarFiltros() {
    List<Map<String, dynamic>> lista = List<Map<String, dynamic>>.from(_bitacoras);

    // Filtro por tipo
    switch (_filtroActivo) {
      case 'publicas':
        lista = lista.where((b) => b['isPublic'] == true).toList();
        break;
      case 'privadas':
        lista = lista.where((b) => b['isPublic'] != true).toList();
        break;
      // 'todas' no filtra nada
    }

    // Filtro por búsqueda
    if (_searchText.isNotEmpty) {
      lista = lista.where((bitacora) {
        final titulo = (bitacora['title'] ?? '').toString().toLowerCase();
        final descripcion = (bitacora['description'] ?? '').toString().toLowerCase();
        return titulo.contains(_searchText.toLowerCase()) ||
               descripcion.contains(_searchText.toLowerCase());
      }).toList();
    }

    setState(() {
      _filteredBitacoras = lista;
    });
  }

  String _formatDate(dynamic createdAt) {
    if (createdAt == null) return 'Sin fecha';
    
    try {
      final date = createdAt is DateTime ? createdAt : createdAt.toDate();
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return 'Sin fecha';
    }
  }

  Future<void> _eliminarBitacora(String bitacoraId, String titulo) async {
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        title: const Text(
          'Eliminar Bitácora',
          style: TextStyle(color: AppColors.textWhite),
        ),
        content: Text(
          '¿Estás seguro de que quieres eliminar la bitácora "$titulo"?',
          style: const TextStyle(color: AppColors.textWhite),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textPaleGreen),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: AppColors.warning),
            ),
          ),
        ],
      ),
    );

    if (confirmacion == true) {
      try {
        await BitacoraService.deleteBitacora(bitacoraId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bitácora eliminada correctamente'),
              backgroundColor: AppColors.buttonGreen2,
            ),
          );
          _loadBitacoras();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar: $e'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      }
    }
  }

  Future<void> _editarBitacora(Map<String, dynamic> bitacora) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CrearEditarBitacoraScreen(
          bitacoraId: bitacora['id'],
          bitacoraData: bitacora,
        ),
      ),
    );

    if (result == true) {
      _loadBitacoras();
    }
  }

  Future<void> _verBitacora(Map<String, dynamic> bitacora) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetalleBitacoraScreen(
          bitacoraData: bitacora,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.buttonGreen2,
        foregroundColor: AppColors.white,
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CrearEditarBitacoraScreen()),
          );
          if (result == true) {
            _loadBitacoras();
          }
        },
        child: const Icon(Icons.add),
        tooltip: 'Nueva bitácora',
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: AppColors.backgroundPrimary, // Cambiar de gradiente a color sólido
        child: SafeArea(
          child: Column(
            children: [
              // Header con indicador de conexión
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
                          const Text(
                            'Mis Bitácoras',
                            style: TextStyle(
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
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      color: AppColors.white,
                      onPressed: _isLoading ? null : () {
                        _checkInternetConnection();
                        _loadBitacoras();
                      },
                    ),
                  ],
                ),
              ),
              // Barra de búsqueda
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: TextField(
                  onChanged: (value) {
                    _searchText = value;
                    _aplicarFiltros();
                  },
                  decoration: InputDecoration(
                    hintText: 'Buscar mis bitácoras...',
                    hintStyle: const TextStyle(color: AppColors.textPaleGreen),
                    prefixIcon: const Icon(Icons.search, color: AppColors.white),
                    filled: true,
                    fillColor: AppColors.slateGreen,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  ),
                  style: const TextStyle(color: AppColors.white),
                ),
              ),
              // Chips de filtrado
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('Todas'),
                      selected: _filtroActivo == 'todas',
                      backgroundColor: _filtroActivo == 'todas' 
                          ? AppColors.buttonGreen2 
                          : AppColors.backgroundCard,
                      selectedColor: AppColors.buttonGreen2,
                      shape: StadiumBorder(
                        side: BorderSide(color: AppColors.brownDark3, width: 1),
                      ),
                      labelStyle: TextStyle(
                        color: _filtroActivo == 'todas' 
                            ? AppColors.textBlack 
                            : AppColors.textWhite,
                      ),
                      onSelected: (_) {
                        setState(() => _filtroActivo = 'todas');
                        _aplicarFiltros();
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Públicas'),
                      selected: _filtroActivo == 'publicas',
                      backgroundColor: _filtroActivo == 'publicas' 
                          ? AppColors.buttonGreen2 
                          : AppColors.backgroundCard,
                      selectedColor: AppColors.buttonGreen2,
                      shape: StadiumBorder(
                        side: BorderSide(color: AppColors.brownDark3, width: 1),
                      ),
                      labelStyle: TextStyle(
                        color: _filtroActivo == 'publicas' 
                            ? AppColors.textBlack 
                            : AppColors.textWhite,
                      ),
                      onSelected: (_) {
                        setState(() => _filtroActivo = 'publicas');
                        _aplicarFiltros();
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Privadas'),
                      selected: _filtroActivo == 'privadas',
                      backgroundColor: _filtroActivo == 'privadas' 
                          ? AppColors.buttonGreen2 
                          : AppColors.backgroundCard,
                      selectedColor: AppColors.buttonGreen2,
                      shape: StadiumBorder(
                        side: BorderSide(color: AppColors.brownDark3, width: 1),
                      ),
                      labelStyle: TextStyle(
                        color: _filtroActivo == 'privadas' 
                            ? AppColors.textBlack 
                            : AppColors.textWhite,
                      ),
                      onSelected: (_) {
                        setState(() => _filtroActivo = 'privadas');
                        _aplicarFiltros();
                      },
                    ),
                  ],
                ),
              ),
              // Lista de bitácoras
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.buttonGreen2,
                        ),
                      )
                    : _filteredBitacoras.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _searchText.isNotEmpty ? Icons.search_off : Icons.library_books_outlined,
                                  size: 80,
                                  color: AppColors.textPaleGreen,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchText.isNotEmpty 
                                      ? 'No se encontraron bitácoras'
                                      : 'No tienes bitácoras creadas',
                                  style: const TextStyle(
                                    color: AppColors.textPaleGreen,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _searchText.isNotEmpty 
                                      ? 'Intenta con otros términos de búsqueda'
                                      : 'Toca el botón + para crear tu primera bitácora',
                                  style: const TextStyle(
                                    color: AppColors.textPaleGreen,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadBitacoras,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: _filteredBitacoras.length,
                              itemBuilder: (context, index) {
                                final bitacora = _filteredBitacoras[index];
                                return _buildBitacoraCard(bitacora);
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBitacoraCard(Map<String, dynamic> bitacora) {
    final titulo = bitacora['title'] ?? 'Sin título';
    final descripcion = bitacora['description'] ?? 'Sin descripción';
    final isPublic = bitacora['isPublic'] ?? false;
    final registros = (bitacora['selectedPhotos'] as List?)?.length ?? 0;
    final fechaCreacion = _formatDate(bitacora['createdAt']);

    return Card(
      color: AppColors.backgroundCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.buttonGreen2, width: 1),
      ),
      elevation: 8,
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _verBitacora(bitacora),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icono del libro a la izquierda
              Container(
                margin: const EdgeInsets.only(right: 16),
                child: Icon(
                  Icons.menu_book_rounded,
                  size: 48,
                  color: AppColors.buttonGreen2,
                ),
              ),
              
              // Contenido principal en el centro
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge de visibilidad y título en la misma línea
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isPublic ? AppColors.buttonGreen2 : AppColors.warning,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPublic ? Icons.public : Icons.lock,
                                size: 12,
                                color: AppColors.textBlack,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                isPublic ? 'Pública' : 'Privada',
                                style: const TextStyle(
                                  color: AppColors.textBlack,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            titulo,
                            style: const TextStyle(
                              color: AppColors.textWhite,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    
                    // Descripción
                    Text(
                      descripcion,
                      style: const TextStyle(
                        color: AppColors.textPaleGreen,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    
                    // Información adicional en una línea
                    Row(
                      children: [
                        Icon(
                          Icons.photo_library_outlined,
                          size: 14,
                          color: AppColors.buttonGreen2,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$registros registros',
                          style: const TextStyle(
                            color: AppColors.buttonGreen2,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: AppColors.textPaleGreen,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          fechaCreacion,
                          style: const TextStyle(
                            color: AppColors.textPaleGreen,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Botones de acción a la derecha
              if (_hasInternet) ...[
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Botón Editar
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0), // Azul más oscuro
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.edit,
                          color: AppColors.white,
                          size: 18,
                        ),
                        tooltip: 'Editar bitácora',
                        onPressed: () => _editarBitacora(bitacora),
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Botón Eliminar
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppColors.warning,
                          size: 18,
                        ),
                        tooltip: 'Eliminar bitácora',
                        onPressed: () => _eliminarBitacora(bitacora['id'], titulo),
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}