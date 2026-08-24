import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CallHistoryService {
  static const String _storageKey = 'vetencall_call_history';
  static const int _maxRecords = 100;

  /// Mengambil semua riwayat panggilan
  static Future<List<Map<String, dynamic>>> getCallHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_storageKey);

    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> decodedList = jsonDecode(jsonString);
      return decodedList.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error decoding call history: $e');
      return [];
    }
  }

  /// Menyimpan satu riwayat panggilan baru
  static Future<void> addCallRecord({
    required String name,
    required String type, // 'Masuk', 'Keluar', 'Terlewat'
    bool isVideo = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> history = await getCallHistory();

    // Generate color setup based on type
    int colorValue = 0xFF10B981; // Green (Masuk)
    if (type == 'Keluar') {
      colorValue = 0xFF2B7FFF; // Blue
    } else if (type == 'Terlewat') {
      colorValue = 0xFFEF4444; // Red
    }

    // Avatar color logic (randomize or fixed based on name length)
    final avatarColors = [
      0xFFE0F2FE, // Light Blue
      0xFFD1FAE5, // Light Green
      0xFFFEE2E2, // Light Red
      0xFFFEF3C7, // Light Yellow
      0xFFF3E8FF, // Light Purple
    ];
    final avatarColorValue = avatarColors[name.length % avatarColors.length];

    // Format current time
    final now = DateTime.now();
    final String formattedTime =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    final newRecord = {
      'name': name,
      'type': type,
      'time': formattedTime,
      'timestamp': now.millisecondsSinceEpoch,
      'isVideo': isVideo,
      'colorValue': colorValue, // Save as integer since Color object can't be JSON serialized
      'avatarColorValue': avatarColorValue,
      'transcription': '', // Bisa disetel di fitur AI selanjutnya
      'hasAudio': false,
    };

    // Add to top of list
    history.insert(0, newRecord);

    // Enforce limit
    if (history.length > _maxRecords) {
      history = history.sublist(0, _maxRecords);
    }

    await prefs.setString(_storageKey, jsonEncode(history));
  }

  /// Menghapus semua riwayat panggilan
  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
