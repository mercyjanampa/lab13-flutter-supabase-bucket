import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'config.dart';
import 'model_photo.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;
  final Uuid _uuid = const Uuid();

  // Subir imagen a Storage
  Future<String> uploadImage(File imageFile, String? description) async {
    try {
      final String fileName = '${_uuid.v4()}.jpg';
      final String filePath = fileName;
      
      await _client.storage
          .from(SupabaseConfig.bucketName)
          .upload(filePath, imageFile, fileOptions: const FileOptions(
            cacheControl: '3600',
            upsert: false,
          ));
   
      final String publicUrl = _client.storage
          .from(SupabaseConfig.bucketName)
          .getPublicUrl(filePath);
  
      await _client.from('photos').insert({
        'id': _uuid.v4(),
        'url': publicUrl,
        'description': description,
        'created_at': DateTime.now().toIso8601String(),
      });

      return publicUrl;
    } catch (e) {
      throw Exception('Error al subir imagen: $e');
    }
  }

  // Obtener todas las fotos
  Future<List<PhotoModel>> getPhotos() async {
    try {
      final response = await _client
          .from('photos')
          .select()
          .order('created_at', ascending: false);

      return (response as List).map((photo) => PhotoModel.fromMap(photo)).toList();
    } catch (e) {
      throw Exception('Error al obtener fotos: $e');
    }
  }
 
  Future<void> deletePhoto(String photoId, String url) async {
    try {
      // Extraer el path de la URL
      final uri = Uri.parse(url);
      final path = uri.pathSegments.skip(2).join('/');      
      await _client.storage.from(SupabaseConfig.bucketName).remove([path]);      
      await _client.from('photos').delete().eq('id', photoId);
    } catch (e) {
      throw Exception('Error al eliminar foto: $e');
    }
  }
}
