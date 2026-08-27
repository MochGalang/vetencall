import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  // SATU SUMBER KEBENARAN UNTUK IP SERVER
  static const String serverIp = 'vetencall.vetencode.com';

  // Node.js Backend URL (HTTPS via Nginx proxy ke port 3001)
  static const String baseUrl = 'https://$serverIp/api';
  // WebSocket Node.js Chat (via Nginx /chat-ws location ke port 3001/ws)
  static const String wsUrl = 'wss://$serverIp/chat-ws';

  // Helper method for POST requests
  static Future<Map<String, dynamic>> post(
      String endpoint, Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.body.isEmpty) {
        return {
          'success': false,
          'message': 'Server mengembalikan respons kosong'
        };
      }

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Koneksi ke server gagal: $e'};
    }
  }

  // Helper method for GET requests
  static Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.body.isEmpty) {
        return {
          'success': false,
          'message': 'Server mengembalikan respons kosong'
        };
      }

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Koneksi ke server gagal: $e'};
    }
  }

  static String? _sessionSipPassword;

  // Session Methods
  static Future<void> saveUserData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', data['id']?.toString() ?? '');
    await prefs.setString('username', data['username'] ?? '');
    await prefs.setString('phone_number', data['phone_number'] ?? '');
    await prefs.setString('sip_username', data['sip_username'] ?? '');

    // Save sip_password securely
    final sipPass = data['sip_password'] ?? '';
    if (kIsWeb) {
      _sessionSipPassword = sipPass;
    } else {
      const storage = FlutterSecureStorage();
      await storage.write(key: 'sip_password', value: sipPass);
    }

    if (data['profile_picture'] != null) {
      await prefs.setString('profile_picture', data['profile_picture'] ?? '');
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (kIsWeb) {
      _sessionSipPassword = null;
    } else {
      const storage = FlutterSecureStorage();
      await storage.delete(key: 'sip_password');
    }
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

  static Future<List<Map<String, dynamic>>> fetchCommonGroups(String targetUserId) async {
    final myUserId = await getUserId();
    if (myUserId == null || myUserId.isEmpty) return [];

    final response = await get('/users/$targetUserId/common-groups?user_id=$myUserId');
    if (response['success'] == true && response['data'] != null) {
      return List<Map<String, dynamic>>.from(response['data']);
    }
    return [];
  }

  static Future<Map<String, dynamic>> fetchBlockStatus(String targetUserId) async {
    final myUserId = await getUserId();
    if (myUserId == null || myUserId.isEmpty) return {'success': false};
    return await get('/users/$targetUserId/block-status?user_id=$myUserId');
  }

  static Future<Map<String, dynamic>> toggleBlock(String targetUserId, String action) async {
    final myUserId = await getUserId();
    if (myUserId == null || myUserId.isEmpty) return {'success': false};
    return await post('/users/block', {
      'blocker_id': myUserId,
      'blocked_id': targetUserId,
      'action': action,
    });
  }

  static Future<Map<String, dynamic>> toggleMute(String conversationId, bool isMuted) async {
    final myUserId = await getUserId();
    if (myUserId == null || myUserId.isEmpty) return {'success': false};
    return await post('/conversations/mute', {
      'user_id': myUserId,
      'conversation_id': conversationId,
      'is_muted': isMuted,
    });
  }

  static Future<Map<String, dynamic>> uploadFile(String filePath) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'));
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.body.isEmpty) return {'success': false, 'message': 'Respons kosong'};
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Upload gagal: $e'};
    }
  }

  static Future<Map<String, String?>> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    String? sipPassword;
    if (kIsWeb) {
      sipPassword = _sessionSipPassword;
    } else {
      const storage = FlutterSecureStorage();
      sipPassword = await storage.read(key: 'sip_password');
    }

    return {
      'user_id': prefs.getString('user_id'),
      'username': prefs.getString('username'),
      'phone_number': prefs.getString('phone_number'),
      'sip_username': prefs.getString('sip_username'),
      'sip_password': sipPassword,
      'profile_picture': prefs.getString('profile_picture'),
    };
  }

  // Upload Profile Picture Method
  static Future<Map<String, dynamic>> uploadProfilePicture(
      String userId, List<int> imageBytes, String filename) async {
    try {
      final uri = Uri.parse('$baseUrl/profile/upload-photo');
      var request = http.MultipartRequest('POST', uri);

      request.fields['user_id'] = userId;
      request.files.add(
        http.MultipartFile.fromBytes(
          'photo',
          imageBytes,
          filename: filename,
        ),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        // Update stored profile picture URL if successful
        if (jsonResponse['success'] == true &&
            jsonResponse['data'] != null && 
            jsonResponse['data']['profile_pic'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
              'profile_picture', jsonResponse['data']['profile_pic']);
          jsonResponse['profile_picture'] = jsonResponse['data']['profile_pic']; // mapping for existing frontend code
        }

        return jsonResponse;
      } else {
        return {
          'success': false,
          'message': 'Gagal mengupload gambar. Status: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Koneksi ke server gagal: $e'};
    }
  }

  // ==========================================
  // GROUP CHAT APIs
  // ==========================================

  static Future<Map<String, dynamic>> createGroup(
      String name, List<String> memberIds) async {
    return await post('/groups', {
      'name': name,
      'member_ids': memberIds,
    });
  }

  static Future<Map<String, dynamic>> getGroups(String userId) async {
    return await get('/groups?user_id=$userId');
  }

  static Future<Map<String, dynamic>> getGroupMessages(String groupId) async {
    return await get('/groups/messages?group_id=$groupId');
  }

  // ==========================================
  // PROFILE APIs
  // ==========================================
  static Future<Map<String, dynamic>> updateProfile(
      String userId, String username) async {
    return await post('/profile/update', {
      'user_id': userId,
      'username': username,
    });
  }

  // ==========================================
  // BLOCKED CONTACTS APIs
  // ==========================================
  static List<String> blockedSipUsernames = [];

  static Future<Map<String, dynamic>> getBlockedContacts(String userId) async {
    final res = await get('/contacts/blocked?user_id=$userId');
    if (res['success'] == true && res['data'] is List) {
      blockedSipUsernames = (res['data'] as List)
          .map((c) => c['sip_username']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return res;
  }

  static Future<Map<String, dynamic>> blockContact(String blockerId, String blockedId) async {
    return await post('/contacts/block', {
      'user_id': blockerId,
      'blocked_id': blockedId,
    });
  }

  static Future<Map<String, dynamic>> unblockContact(String blockerId, String blockedId) async {
    return await post('/contacts/unblock', {
      'user_id': blockerId,
      'blocked_id': blockedId,
    });
  }
}
