import 'dart:async';
import 'dart:io';
import 'package:biodetect/themes.dart';
import 'package:biodetect/services/bitacora_service.dart';
import 'package:biodetect/views/notes/detalle_bitacora_screen.dart';
import 'package:biodetect/views/notes/crear_editar_bitacora_screen.dart';
import 'package:biodetect/views/notes/mis_bitacoras.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ExplorarBitacorasPublicasScreen extends StatefulWidget {
  const ExplorarBitacorasPublicasScreen({super.key});

  @override
  State<ExplorarBitacorasPublicasScreen> createState() => _ExplorarBitacorasPublicasScreenState();
}

class _ExplorarBitacorasPublicasScreenState extends State<ExplorarBitacorasPublicasScreen> {
  List<Map<String, dynamic>> _bitacoras = [];
  List<Map<String, dynamic>> _filteredBitacoras = [];
  bool _isLoading = true;
  bool _hasInternet = true;
  Timer? _connectionCheckTimer; // Timer para verificación de conexión automática
  String _searchText = '';
  String _ordenActual = 'fecha'; // fecha, alfabetico

  @override
  void initState() {
    super.initState();
    _loadBitacoras();
    _checkInternetConnection();
    _startPeriodicConnectionCheck(); // Iniciar verificación de conexión automática
  }

  @override
  void dispose() {
    _connectionCheckTimer?.cancel(); // Cancelar timer al destruir widget
    super.dispose();
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

  // Iniciar verificación automática cada 10 segundos
  void _startPeriodicConnectionCheck() {
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkInternetConnection();
    });
  }

  // Detectar si un error es de conectividad
  bool _isConnectionError(dynamic error) {
    if (error == null) return false;
    
    final errorString = error.toString().toLowerCase();
    return errorString.contains('network') ||
           errorString.contains('connection') ||
           errorString.contains('timeout') ||
           errorString.contains('unreachable') ||
           errorString.contains('failed host lookup') ||
           errorString.contains('no address associated') ||
           errorString.contains('socketexception');
  }

  // Método para reintentar carga con verificación de conexión
  Future<void> _retryLoad() async {
    await _checkInternetConnection();
    await _loadBitacoras();
  }

  Future<void> _loadBitacoras() async {
    setState(() => _isLoading = true);
    
    try {
      final bitacoras = await BitacoraService.getPublicBitacoras();
      
      setState(() {
        _bitacoras = bitacoras;
        _isLoading = false;
      });
      
      _aplicarFiltros();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        // Verificar si es un error de conexión
        String errorMessage;
        
        if (_isConnectionError(e)) {
          // Es un error de conexión
          await _checkInternetConnection(); // Actualizar estado de conexión
          errorMessage = 'Error de conexión. Verifica tu conexión a internet y vuelve a intentar.';
        } else {
          errorMessage = 'Error al cargar bitácoras: $e';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: _isConnectionError(e) ? AppColors.warning : AppColors.warningDark,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _aplicarFiltros() {
    List<Map<String, dynamic>> lista = List<Map<String, dynamic>>.from(_bitacoras);

    // Filtro por búsqueda
    if (_searchText.isNotEmpty) {
      lista = lista.where((bitacora) {
        final titulo = (bitacora['title'] ?? '').toString().toLowerCase();
        final descripcion = (bitacora['description'] ?? '').toString().toLowerCase();
        final autor = (bitacora['authorName'] ?? '').toString().toLowerCase();
        
        return titulo.contains(_searchText.toLowerCase()) ||
               descripcion.contains(_searchText.toLowerCase()) ||
               autor.contains(_searchText.toLowerCase());
      }).toList();
    }

    // Ordenamiento
    switch (_ordenActual) {
      case 'alfabetico':
        lista.sort((a, b) => (a['title'] ?? '').toString().compareTo((b['title'] ?? '').toString()));
        break;
      case 'fecha':
        lista.sort((a, b) {
          final aDate = a['createdAt'];
          final bDate = b['createdAt'];
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          
          try {
            final aDateTime = aDate is DateTime ? aDate : aDate.toDate();
            final bDateTime = bDate is DateTime ? bDate : bDate.toDate();
            return bDateTime.compareTo(aDateTime); // Más recientes primero
          } catch (e) {
            return 0;
          }
        });
        break;
    }

    setState(() {
      _filteredBitacoras = lista;
    });
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundLightGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Bitácoras',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _hasInternet ? AppColors.buttonGreen2 : AppColors.warning,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _hasInternet ? Icons.wifi : Icons.wifi_off,
                                size: 16,
                                color: AppColors.textBlack,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _hasInternet ? 'En línea' : 'Sin conexión',
                                style: const TextStyle(
                                  color: AppColors.textBlack,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.library_books_outlined),
                          color: AppColors.textWhite,
                          tooltip: 'Mis bitácoras',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const MisBitacorasScreen(),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          color: AppColors.textWhite,
                          tooltip: 'Crear bitácora',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CrearEditarBitacoraScreen(),
                              ),
                            ).then((_) {
                              _retryLoad();
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          color: AppColors.textWhite,
                          tooltip: 'Refrescar',
                          onPressed: _isLoading ? null : () => _retryLoad(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Barra de búsqueda
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
                child: TextField(
                  onChanged: (value) {
                    _searchText = value;
                    _aplicarFiltros();
                  },
                  decoration: InputDecoration(
                    hintText: 'Buscar bitácoras públicas...',
                    hintStyle: const TextStyle(color: AppColors.textPaleGreen),
                    prefixIcon: const Icon(Icons.search, color: AppColors.textWhite),
                    filled: true,
                    fillColor: AppColors.slateGreen,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  ),
                  style: const TextStyle(color: AppColors.textWhite),
                ),
              ),
              // Chips de filtrado
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('Alfabético'),
                      selected: _ordenActual == 'alfabetico',
                      backgroundColor: _ordenActual == 'alfabetico' 
                          ? AppColors.buttonGreen2 
                          : AppColors.backgroundCard,
                      selectedColor: AppColors.buttonGreen2,
                      shape: const StadiumBorder(
                        side: BorderSide(color: AppColors.brownDark3, width: 1),
                      ),
                      labelStyle: TextStyle(
                        color: _ordenActual == 'alfabetico' 
                            ? AppColors.textBlack 
                            : AppColors.textWhite,
                      ),
                      onSelected: (_) {
                        setState(() => _ordenActual = 'alfabetico');
                        _aplicarFiltros();
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Fecha'),
                      selected: _ordenActual == 'fecha',
                      backgroundColor: _ordenActual == 'fecha' 
                          ? AppColors.buttonGreen2 
                          : AppColors.backgroundCard,
                      selectedColor: AppColors.buttonGreen2,
                      shape: const StadiumBorder(
                        side: BorderSide(color: AppColors.brownDark3, width: 1),
                      ),
                      labelStyle: TextStyle(
                        color: _ordenActual == 'fecha' 
                            ? AppColors.textBlack 
                            : AppColors.textWhite,
                      ),
                      onSelected: (_) {
                        setState(() => _ordenActual = 'fecha');
                        _aplicarFiltros();
                      },
                    ),
                  ],
                ),
              ),
              // Lista de bitácoras públicas
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
                                  _hasInternet 
                                      ? (_searchText.isNotEmpty ? Icons.search_off : Icons.public_off)
                                      : Icons.wifi_off,
                                  size: 80,
                                  color: AppColors.textPaleGreen,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _hasInternet 
                                      ? (_searchText.isNotEmpty 
                                          ? 'No se encontraron bitácoras'
                                          : 'No hay bitácoras públicas disponibles')
                                      : 'Sin conexión a internet',
                                  style: const TextStyle(
                                    color: AppColors.textPaleGreen,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _hasInternet 
                                      ? (_searchText.isNotEmpty 
                                          ? 'Intenta con otros términos de búsqueda'
                                          : 'Los usuarios aún no han compartido bitácoras públicas')
                                      : 'Verifica tu conexión y vuelve a intentar',
                                  style: const TextStyle(
                                    color: AppColors.textPaleGreen,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 20),
                                if (!_hasInternet)
                                  ElevatedButton(
                                    onPressed: () => _retryLoad(),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.buttonGreen2,
                                      foregroundColor: AppColors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    child: const Text('Reintentar'),
                                  ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadBitacoras,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                              itemCount: _filteredBitacoras.length,
                              itemBuilder: (context, index) {
                                final bitacora = _filteredBitacoras[index];
                                return BitacoraPublicaListItem(
                                  bitacora: bitacora,
                                  onTap: () => _verBitacora(bitacora),
                                );
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
}

class BitacoraPublicaListItem extends StatelessWidget {
  final Map<String, dynamic> bitacora;
  final VoidCallback onTap;

  const BitacoraPublicaListItem({
    super.key,
    required this.bitacora,
    required this.onTap,
  });

  String _formatDate(dynamic createdAt) {
    if (createdAt == null) return 'Sin fecha';
    
    try {
      final date = createdAt is DateTime ? createdAt : createdAt.toDate();
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return 'Sin fecha';
    }
  }

  @override
  Widget build(BuildContext context) {
    final titulo = bitacora['title'] ?? 'Sin título';
    final autor = bitacora['authorName'] ?? 'Usuario desconocido';
    final registros = (bitacora['selectedPhotos'] as List?)?.length ?? 0;
    final fechaCreacion = _formatDate(bitacora['createdAt']);

    return Card(
      color: AppColors.slateGreen,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.buttonGreen2, width: 1),
      ),
      elevation: 8,
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Row(
          children: [
            // Ícono de bitácora pública
            Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                color: AppColors.slateGreen,
                borderRadius: BorderRadius.horizontal(left: Radius.circular(18)),
              ),
              child: Stack(
                children: [
                  const Center(
                    child: Icon(Icons.menu_book, size: 48, color: AppColors.textWhite),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.buttonGreen2,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.public,
                        size: 16,
                        color: AppColors.textBlack,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Información de la bitácora
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        color: AppColors.buttonGreen2,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 14, color: AppColors.textSand),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            autor,
                            style: const TextStyle(
                              color: AppColors.textSand,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Primera fila: registros
                    Row(
                      children: [
                        const Icon(Icons.photo_library, size: 14, color: AppColors.textPaleGreen),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '$registros registros',
                            style: const TextStyle(
                              color: AppColors.textPaleGreen,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Segunda fila: fecha
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 14, color: Color.fromARGB(255, 169, 193, 170)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            fechaCreacion,
                            style: const TextStyle(
                              color: AppColors.textPaleGreen,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Flecha indicadora
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Icon(
                Icons.arrow_forward_ios,
                color: AppColors.textPaleGreen,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}