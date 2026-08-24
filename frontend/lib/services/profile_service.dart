import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';

/// Centralized service untuk memilih dan mengupload gambar profil.
/// Menggantikan duplikasi _pickAndUploadImage() di profile_page.dart dan homeprofil_page.dart.
class ProfileService {
  /// Buka galeri, ambil gambar, lakukan upload ke server.
  ///
  /// [userId]           — ID user yang diupload fotonya
  /// [onLocalPreview]   — callback dipanggil segera dengan bytes gambar (untuk preview instan)
  /// [onLoadingChange]  — callback untuk mengontrol state loading di UI
  ///
  /// Return: URL foto profil baru jika sukses, null jika gagal atau user batal.
  static Future<String?> pickAndUpload({
    required BuildContext context,
    required String? userId,
    required void Function(Uint8List bytes) onLocalPreview,
    required void Function(bool isLoading) onLoadingChange,
  }) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (image == null) return null; // User membatalkan

    final bytes = await image.readAsBytes();
    onLocalPreview(bytes); // Tampilkan preview langsung tanpa menunggu upload

    onLoadingChange(true);
    try {
      if (userId == null || userId.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sesi tidak valid, silakan login ulang.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return null;
      }

      final result = await ApiService.uploadProfilePicture(userId, bytes, image.name);

      if (result['success'] == true) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto profil berhasil diperbarui!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        return result['profile_picture'] as String?;
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']?.toString() ?? 'Gagal mengupload foto.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return null;
      }
    } catch (e) {
      debugPrint('[ProfileService] Upload error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Terjadi kesalahan saat upload foto.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    } finally {
      // Pastikan loading state selalu di-reset meski terjadi exception
      onLoadingChange(false);
    }
  }
}
