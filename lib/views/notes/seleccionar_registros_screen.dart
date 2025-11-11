import 'package:biodetect/themes.dart';
import 'package:biodetect/services/bitacora_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SeleccionarRegistrosScreen extends StatefulWidget {
  final List<String> selectedPhotoIds; // IDs ya seleccionados

  const SeleccionarRegistrosScreen({
    super.key,
    required this.selectedPhotoIds,
  });

  @override
  State<SeleccionarRegistrosScreen> createState() => _SeleccionarRegistrosScreenState();
}

class _SeleccionarRegistrosScreenState extends State<SeleccionarRegistrosScreen> {
  Map<String, List<Map<String, dynamic>>> _photoGroups = {};
  Set<String> _selectedPhotoIds = {};
  bool _isLoading = true;
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _selectedPhotoIds = Set<String>.from(widget.selectedPhotoIds);
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final photoGroups = await BitacoraService.getAvailablePhotosByTaxon(user.uid);
      
      setState(() {
        _photoGroups = photoGroups;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar fotos: $e'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    }
  }

  Map<String, List<Map<String, dynamic>>> get _filteredPhotoGroups {
    if (_searchText.isEmpty) return _photoGroups;
    
    final filtered = <String, List<Map<String, dynamic>>>{};
    
    _photoGroups.forEach((taxonOrder, photos) {
      if (taxonOrder.toLowerCase().contains(_searchText.toLowerCase())) {
        filtered[taxonOrder] = photos;
      } else {
        final filteredPhotos = photos.where((photo) {
          final habitat = (photo['habitat'] ?? '').toString().toLowerCase();
          final details = (photo['details'] ?? '').toString().toLowerCase();
          final notes = (photo['notes'] ?? '').toString().toLowerCase();
          
          return habitat.contains(_searchText.toLowerCase()) ||
                 details.contains(_searchText.toLowerCase()) ||
                 notes.contains(_searchText.toLowerCase());
        }).toList();
        
        if (filteredPhotos.isNotEmpty) {
          filtered[taxonOrder] = filteredPhotos;
        }
      }
    });
    
    return filtered;
  }

  void _togglePhotoSelection(String photoId) {
    setState(() {
      if (_selectedPhotoIds.contains(photoId)) {
        _selectedPhotoIds.remove(photoId);
      } else {
        _selectedPhotoIds.add(photoId);
      }
    });
  }

  void _toggleTaxonSelection(String taxonOrder) {
    final photos = _photoGroups[taxonOrder] ?? [];
    final photoIds = photos.map((photo) => photo['photoId'] as String).toSet();
    
    final allSelected = photoIds.every((id) => _selectedPhotoIds.contains(id));
    
    setState(() {
      if (allSelected) {
        // Deseleccionar todos
        _selectedPhotoIds.removeAll(photoIds);
      } else {
        // Seleccionar todos
        _selectedPhotoIds.addAll(photoIds);
      }
    });
  }

  List<Map<String, dynamic>> _getSelectedPhotos() {
    List<Map<String, dynamic>> selectedPhotos = [];
    
    _photoGroups.forEach((taxonOrder, photos) {
      for (final photo in photos) {
        if (_selectedPhotoIds.contains(photo['photoId'])) {
          selectedPhotos.add(photo);
        }
      }
    });
    
    return selectedPhotos;
  }

  @override
  Widget build(BuildContext context) {
    final filteredGroups = _filteredPhotoGroups;
    
    return Scaffold(
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new),
                      color: AppColors.textWhite,
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            'Seleccionar Registros',
                            style: TextStyle(
                              color: AppColors.textWhite,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            '${_selectedPhotoIds.length} seleccionados',
                            style: const TextStyle(
                              color: AppColors.textPaleGreen,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.buttonGreen2,
                        foregroundColor: AppColors.textBlack,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _selectedPhotoIds.isNotEmpty
                          ? () => Navigator.pop(context, _getSelectedPhotos())
                          : null,
                      child: const Text('Confirmar'),
                    ),
                  ],
                ),
              ),
              // Barra de búsqueda
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchText = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Buscar por orden, hábitat, detalles...',
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
              ),
              // Lista de órdenes taxonómicos
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.buttonGreen2,
                        ),
                      )
                    : filteredGroups.isEmpty
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
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadPhotos,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: filteredGroups.length,
                              itemBuilder: (context, index) {
                                final entry = filteredGroups.entries.toList()[index];
                                return _buildTaxonExpansionTile(entry.key, entry.value);
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

  Widget _buildTaxonExpansionTile(String taxonOrder, List<Map<String, dynamic>> photos) {
    final photoIds = photos.map((photo) => photo['photoId'] as String).toSet();
    final selectedCount = photoIds.where((id) => _selectedPhotoIds.contains(id)).length;
    final allSelected = photoIds.every((id) => _selectedPhotoIds.contains(id));
    final partiallySelected = selectedCount > 0 && !allSelected;

    return Card(
      color: AppColors.backgroundCard,
      margin: const EdgeInsets.only(bottom: 8),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: GestureDetector(
            onTap: () => _toggleTaxonSelection(taxonOrder),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                border: Border.all(
                  color: allSelected ? AppColors.buttonGreen2 : AppColors.textPaleGreen,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(4),
                color: allSelected ? AppColors.buttonGreen2 : Colors.transparent,
              ),
              child: allSelected
                  ? const Icon(Icons.check, color: AppColors.textBlack, size: 16)
                  : partiallySelected
                      ? const Icon(Icons.remove, color: AppColors.textPaleGreen, size: 16)
                      : null,
            ),
          ),
          title: Text(
            taxonOrder,
            style: const TextStyle(
              color: AppColors.textWhite,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            '$selectedCount/${photos.length} seleccionados',
            style: const TextStyle(
              color: AppColors.textPaleGreen,
            ),
          ),
          iconColor: AppColors.textWhite,
          collapsedIconColor: AppColors.textWhite,
          children: photos.map((photo) => _buildPhotoTile(photo)).toList(),
        ),
      ),
    );
  }

  Widget _buildPhotoTile(Map<String, dynamic> photo) {
    final photoId = photo['photoId'] as String;
    final isSelected = _selectedPhotoIds.contains(photoId);

    return ListTile(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => _togglePhotoSelection(photoId),
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? AppColors.buttonGreen2 : AppColors.textPaleGreen,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(4),
                color: isSelected ? AppColors.buttonGreen2 : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: AppColors.textBlack, size: 12)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: CachedNetworkImage(
              imageUrl: photo['imageUrl'] ?? '',
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 40,
                height: 40,
                color: AppColors.paleGreen.withValues(alpha: 0.3),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.buttonGreen2,
                    strokeWidth: 2,
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                width: 40,
                height: 40,
                color: AppColors.paleGreen.withValues(alpha: 0.3),
                child: const Icon(
                  Icons.image_not_supported,
                  color: AppColors.textPaleGreen,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
      title: Text(
        'Hábitat: ${photo['habitat'] ?? 'No especificado'}',
        style: const TextStyle(
          color: AppColors.textWhite,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        photo['details'] ?? 'Sin detalles',
        style: const TextStyle(
          color: AppColors.textPaleGreen,
          fontSize: 12,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => _togglePhotoSelection(photoId),
    );
  }
}