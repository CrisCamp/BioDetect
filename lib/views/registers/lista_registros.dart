import 'package:biodetect/themes.dart';
import 'package:biodetect/views/registers/detalle_registro.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ListaRegistros extends StatefulWidget {
  final String taxonOrder;
  final List<Map<String, dynamic>> registros;

  const ListaRegistros({
    super.key,
    required this.taxonOrder,
    required this.registros,
  });

  @override
  State<ListaRegistros> createState() => _ListaRegistrosState();
}

class _ListaRegistrosState extends State<ListaRegistros> {
  late List<Map<String, dynamic>> _filteredRegistros;
  late List<Map<String, dynamic>> _registrosOriginales;
  String _searchText = '';
  String _selectedFiltro = 'recientes';
  bool _habitatAscendente = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _registrosOriginales = List<Map<String, dynamic>>.from(widget.registros);
    _filteredRegistros = List<Map<String, dynamic>>.from(widget.registros);
    _aplicarFiltro();
  }

  Future<void> _refrescarRegistros() async {
    setState(() => _isLoading = true);
    
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        // Obtener registros actualizados desde cache/servidor
        final query = await FirebaseFirestore.instance
            .collection('insect_photos')
            .where('userId', isEqualTo: userId)
            .where('taxonOrder', isEqualTo: widget.taxonOrder)
            .get(const GetOptions(source: Source.serverAndCache));

        final nuevosRegistros = query.docs.map((doc) => {
          ...doc.data(),
          'photoId': doc.id,
        }).toList();
        
        setState(() {
          _registrosOriginales = nuevosRegistros;
          _isLoading = false;
        });
        
        _aplicarFiltro();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al refrescar: $e')),
        );
      }
    }
  }

  void _aplicarFiltro() {
    List<Map<String, dynamic>> lista = List<Map<String, dynamic>>.from(_registrosOriginales);

    // Filtrado por búsqueda
    if (_searchText.isNotEmpty) {
      lista = lista.where((registro) {
        final habitat = (registro['habitat'] ?? 'Sin hábitat').toString().toLowerCase();
        final detalles = (registro['details'] ?? 'Sin detalles').toString().toLowerCase();
        final notas = (registro['notes'] ?? 'Sin notas').toString().toLowerCase();
        
        // Para registros offline, la fecha está en 'createdAt' como timestamp
        String fecha = '';
        if (registro['lastModifiedAt'] != null) {
          final date = registro['lastModifiedAt'];
          fecha = (date is DateTime ? date : date.toDate()).toString().toLowerCase();
        } else if (registro['createdAt'] != null) {
          final timestamp = registro['createdAt'] as int;
          fecha = DateTime.fromMillisecondsSinceEpoch(timestamp).toString().toLowerCase();
        }
        
        return habitat.contains(_searchText) ||
               detalles.contains(_searchText) ||
               notas.contains(_searchText) ||
               fecha.contains(_searchText);
      }).toList();
    }

    // Ordenamiento por filtro seleccionado
    switch (_selectedFiltro) {
      case 'recientes':
        lista.sort((a, b) => _compararFechas(b, a)); // Más recientes primero
        break;
      case 'viejos':
        lista.sort((a, b) => _compararFechas(a, b)); // Más antiguos primero
        break;
      case 'habitat':
        lista.sort((a, b) {
          final aHabitat = (a['habitat'] ?? 'Sin hábitat').toString().toLowerCase();
          final bHabitat = (b['habitat'] ?? 'Sin hábitat').toString().toLowerCase();
          return _habitatAscendente
              ? aHabitat.compareTo(bHabitat)
              : bHabitat.compareTo(aHabitat);
        });
        break;
    }

    setState(() {
      _filteredRegistros = lista;
    });
  }

  int _compararFechas(Map<String, dynamic> a, Map<String, dynamic> b) {
    DateTime? fechaA;
    DateTime? fechaB;

    // Obtener fecha de A
    if (a['lastModifiedAt'] != null) {
      final date = a['lastModifiedAt'];
      fechaA = date is DateTime ? date : date.toDate();
    } else if (a['createdAt'] != null) {
      fechaA = DateTime.fromMillisecondsSinceEpoch(a['createdAt'] as int);
    }

    // Obtener fecha de B
    if (b['lastModifiedAt'] != null) {
      final date = b['lastModifiedAt'];
      fechaB = date is DateTime ? date : date.toDate();
    } else if (b['createdAt'] != null) {
      fechaB = DateTime.fromMillisecondsSinceEpoch(b['createdAt'] as int);
    }

    if (fechaA == null && fechaB == null) return 0;
    if (fechaA == null) return 1;
    if (fechaB == null) return -1;
    
    return fechaA.compareTo(fechaB);
  }

  String _formatearFecha(Map<String, dynamic> registro) {
    if (registro['lastModifiedAt'] != null) {
      final date = registro['lastModifiedAt'];
      final dt = date is DateTime ? date : date.toDate();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } else if (registro['createdAt'] != null) {
      final dt = DateTime.fromMillisecondsSinceEpoch(registro['createdAt'] as int);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    }
    return 'Sin fecha';
  }

  // Método para construir el indicador de sincronización individual
  Widget _buildSyncIndicator(Map<String, dynamic> registro) {
    final syncedAt = registro['syncedAt'];
    
    if (syncedAt != null) {
      // El registro está sincronizado
      return Icon(
        Icons.cloud_done,
        color: AppColors.buttonGreen2,
        size: 18,
      );
    } else {
      // El registro no está sincronizado
      return Icon(
        Icons.cloud_off,
        color: AppColors.textPaleGreen,
        size: 18,
      );
    }
  }

  Widget _buildRegistroTile(Map<String, dynamic> registro) {
    // final isOnline = registro['isOnline'] ?? true; // Asumir que es online por defecto
    final imageSource = registro['imageUrl'] ?? '';

    return Card(
      color: AppColors.backgroundCard,
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetalleRegistro(registro: registro),
            ),
          ).then((result) {
            if (result == true) {
              _refrescarRegistros();
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Imagen miniatura
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: imageSource.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageSource,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: AppColors.paleGreen.withValues(alpha: 0.3),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.buttonGreen2,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: AppColors.paleGreen.withValues(alpha: 0.3),
                            child: const Icon(
                              Icons.error_outline,
                              color: AppColors.warning,
                              size: 20,
                            ),
                          ),
                        )
                      : Container(
                          color: AppColors.paleGreen.withValues(alpha: 0.3),
                          child: const Icon(
                            Icons.image_not_supported,
                            color: AppColors.textPaleGreen,
                            size: 20,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Información del registro
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            registro['taxonOrder'] ?? 'Orden no especificado',
                            style: const TextStyle(
                              color: AppColors.textWhite,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Indicador de estado
                        // Container(
                        //   padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        //   decoration: BoxDecoration(
                        //     color: isOnline ? AppColors.buttonGreen2 : AppColors.warning,
                        //     borderRadius: BorderRadius.circular(8),
                        //   ),
                        //   child: Text(
                        //     isOnline ? 'Online' : 'Offline',
                        //     style: const TextStyle(
                        //       color: AppColors.textBlack,
                        //       fontSize: 10,
                        //       fontWeight: FontWeight.bold,
                        //     ),
                        //   ),
                        // ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hábitat: ${registro['habitat'] ?? 'No especificado'}',
                      style: const TextStyle(
                        color: AppColors.textPaleGreen,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Fecha: ${_formatearFecha(registro)}',
                      style: const TextStyle(
                        color: AppColors.textPaleGreen,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // Indicador de sincronización individual
              _buildSyncIndicator(registro),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios,
                color: AppColors.textPaleGreen,
                size: 16,
              ),
            ],
          ),
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
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new),
                      color: AppColors.white,
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        widget.taxonOrder,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      color: AppColors.white,
                      onPressed: _isLoading ? null : _refrescarRegistros,
                    ),
                  ],
                ),
              ),
              // Barra de búsqueda y filtros
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Campo de búsqueda
                    TextField(
                      onChanged: (value) {
                        setState(() {
                          _searchText = value.toLowerCase();
                        });
                        _aplicarFiltro();
                      },
                      decoration: InputDecoration(
                        hintText: 'Buscar por hábitat, detalles, notas...',
                        hintStyle: const TextStyle(color: AppColors.textPaleGreen),
                        prefixIcon: const Icon(Icons.search, color: AppColors.buttonGreen2),
                        filled: true,
                        fillColor: AppColors.backgroundCard,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: const TextStyle(color: AppColors.textWhite),
                    ),
                    const SizedBox(height: 12),
                    // Filtros
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedFiltro,
                            dropdownColor: AppColors.backgroundCard,
                            style: const TextStyle(color: AppColors.textWhite),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppColors.backgroundCard,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'recientes', child: Text('Más recientes')),
                              DropdownMenuItem(value: 'viejos', child: Text('Más antiguos')),
                              DropdownMenuItem(value: 'habitat', child: Text('Por hábitat')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedFiltro = value ?? 'recientes';
                              });
                              _aplicarFiltro();
                            },
                          ),
                        ),
                        if (_selectedFiltro == 'habitat') ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              _habitatAscendente ? Icons.arrow_upward : Icons.arrow_downward,
                              color: AppColors.white,
                            ),
                            onPressed: () {
                              setState(() {
                                _habitatAscendente = !_habitatAscendente;
                              });
                              _aplicarFiltro();
                            },
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Lista de registros
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.buttonGreen2,
                        ),
                      )
                    : _filteredRegistros.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 80,
                                  color: AppColors.textPaleGreen,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No se encontraron registros',
                                  style: TextStyle(
                                    color: AppColors.textPaleGreen,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Intenta con otros términos de búsqueda',
                                  style: TextStyle(
                                    color: AppColors.textPaleGreen,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _refrescarRegistros,
                            color: AppColors.buttonGreen2,
                            child: ListView.builder(
                              padding: const EdgeInsets.only(bottom: 16),
                              itemCount: _filteredRegistros.length,
                              itemBuilder: (context, index) {
                                return _buildRegistroTile(_filteredRegistros[index]);
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