import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'model_photo.dart';
import 'supabase_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final ImagePicker _picker = ImagePicker();
  List<PhotoModel> _photos = [];
  bool _isLoading = false;
  bool _isUploading = false;
  List<PhotoModel> _filteredPhotos = [];
  final TextEditingController _searchController = TextEditingController();
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    setState(() => _isLoading = true);
    try {
      final photos = await _supabaseService.getPhotos();
      setState(() {
        _photos = photos;
        _filteredPhotos = photos;
      });
    } catch (e) {
      _showSnackBar('Error al cargar fotos: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterPhotos(String query) {
    setState(() {
      _filteredPhotos = _photos.where((photo) {
        final description = photo.description?.toLowerCase() ?? '';
        final search = query.toLowerCase();

        final matchesDescription = description.contains(search);

        final matchesDate =
            _selectedDate == null ||
            (photo.createdAt.day == _selectedDate!.day &&
                photo.createdAt.month == _selectedDate!.month &&
                photo.createdAt.year == _selectedDate!.year);

        return matchesDescription && matchesDate;
      }).toList();
    });
  }

  Future<void> _selectDateFilter() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
      _filterPhotos(_searchController.text);
    }
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedDate = null;
      _filteredPhotos = _photos;
    });
  }

  Future<void> _takePhoto() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
      if (!status.isGranted) {
        _showSnackBar('Permiso de cámara denegado', isError: true);
        return;
      }
    }

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 100,
        requestFullMetadata: true,
      );

      if (photo != null) {
        await _uploadPhoto(File(photo.path));
      }
    } catch (e) {
      _showSnackBar('Error al tomar foto: $e', isError: true);
    }
  }

  Future<void> _pickFromGallery() async {
    var status = await Permission.photos.status;

    // 2. Si fue denegado permanentemente, abrir la configuración del celular
    if (status.isPermanentlyDenied) {
      _showSnackBar(
        'El permiso fue denegado permanentemente. Actívalo en Ajustes.',
        isError: true,
      );
      await Future.delayed(
        const Duration(milliseconds: 500),
      ); // Pequeña pausa para que se vea el mensaje
      await openAppSettings(); // Abre la pantalla de ajustes de la app
      return;
    }

    if (status.isDenied) {
      status = await Permission.photos.request();
    }

    if (!status.isGranted) {
      _showSnackBar(
        'Permiso de galería necesario para seleccionar fotos.',
        isError: true,
      );
      return;
    }

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (photo != null) {
        await _uploadPhoto(File(photo.path));
      }
    } catch (e) {
      _showSnackBar('Error al seleccionar foto: $e', isError: true);
    }
  }

  Future<void> _uploadPhoto(File imageFile) async {
    final TextEditingController descriptionController = TextEditingController();

    final bool? shouldUpload = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar Descripción'),
        content: TextField(
          controller: descriptionController,
          decoration: const InputDecoration(
            hintText: 'Descripción opcional',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Subir'),
          ),
        ],
      ),
    );

    if (shouldUpload == true) {
      setState(() => _isUploading = true);
      try {
        await _supabaseService.uploadImage(
          imageFile,
          descriptionController.text.isEmpty
              ? null
              : descriptionController.text,
        );
        _showSnackBar('Foto subida exitosamente');
        await _loadPhotos();
      } catch (e) {
        _showSnackBar('Error al subir foto: $e', isError: true);
      } finally {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _deletePhoto(PhotoModel photo) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Foto'),
        content: const Text('¿Estás seguro de que deseas eliminar esta foto?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supabaseService.deletePhoto(photo.id, photo.url);
        _showSnackBar('Foto eliminada');
        await _loadPhotos();
      } catch (e) {
        _showSnackBar('Error al eliminar foto: $e', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supabase Camera'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadPhotos),
        ],
      ),
      body: Column(
        children: [
          // Botones de acción
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _isUploading ? null : _takePhoto,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Cámara'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isUploading ? null : _pickFromGallery,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Galería'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Indicador de carga
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar por descripción',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearFilters,
                      )
                    : null,
              ),
              onChanged: (value) {
                _filterPhotos(value);
                setState(() {});
              },
            ),
          ),

          const SizedBox(height: 10),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectDateFilter,
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      _selectedDate == null
                          ? 'Filtrar por fecha'
                          : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.filter_alt_off),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          if (_isUploading) const LinearProgressIndicator(),

          // Lista de fotos
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPhotos.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_library_outlined, size: 64),
                        SizedBox(height: 16),
                        Text(
                          'No hay fotos aún',
                          style: TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 0.75,
                        ),
                    itemCount: _filteredPhotos.length,
                    itemBuilder: (context, index) {
                      final photo = _filteredPhotos[index];
                      return _buildPhotoCard(photo);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCard(PhotoModel photo) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: photo.url,
            fit: BoxFit.cover,
            placeholder: (context, url) =>
                const Center(child: CircularProgressIndicator()),
            errorWidget: (context, url, error) => const Icon(Icons.error),
          ),
          // Overlay con información
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
              ),
            ),
          ),
          // Descripción
          if (photo.description != null)
            Positioned(
              bottom: 40,
              left: 8,
              right: 8,
              child: Text(
                photo.description!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          // Fecha
          Positioned(
            bottom: 8,
            left: 8,
            child: Text(
              '${photo.createdAt.day}/${photo.createdAt.month}/${photo.createdAt.year}',
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ),
          // Botón eliminar
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              style: IconButton.styleFrom(backgroundColor: Colors.black54),
              onPressed: () => _deletePhoto(photo),
            ),
          ),
        ],
      ),
    );
  }
}
