import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_service.dart';

/// Singleton WebSocket service yang dipakai bersama oleh semua halaman.
/// Mengelola koneksi, autentikasi, reconnect otomatis, dan distribusi pesan.
class WsService {
  static final WsService _instance = WsService._internal();
  factory WsService() => _instance;
  WsService._internal();

  WebSocketChannel? _channel;
  String? _authenticatedUserId;

  // Broadcast stream — banyak subscriber bisa listen tanpa menutup koneksi
  final StreamController<Map<String, dynamic>> _controller =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get stream => _controller.stream;
  bool get isConnected => _channel != null;

  Timer? _reconnectTimer;
  int _reconnectDelaySec = 2; // backoff awal 2 detik
  bool _shouldReconnect = false;

  /// Hubungkan ke server dengan userId tertentu.
  /// Idempotent — aman dipanggil berkali-kali.
  Future<void> connect(String userId) async {
    if (_channel != null && _authenticatedUserId == userId) {
      debugPrint('[WS] Sudah terhubung sebagai $userId, skip.');
      return;
    }
    _authenticatedUserId = userId;
    _shouldReconnect = true;
    _reconnectDelaySec = 2;
    _doConnect();
  }

  void _doConnect() {
    if (!_shouldReconnect) return;
    try {
      _channel = WebSocketChannel.connect(Uri.parse(ApiService.wsUrl));

      // Autentikasi sesegera mungkin
      _channel!.sink.add(jsonEncode({
        'type': 'auth',
        'user_id': _authenticatedUserId,
      }));

      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message) as Map<String, dynamic>;
            _controller.add(data);
            _reconnectDelaySec = 2; // reset backoff setelah pesan berhasil diterima
          } catch (e) {
            debugPrint('[WS] Parse error: $e');
          }
        },
        onError: (e) {
          debugPrint('[WS] Error: $e');
          _channel = null;
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('[WS] Koneksi ditutup');
          _channel = null;
          _scheduleReconnect();
        },
        cancelOnError: true,
      );

      debugPrint('[WS] Terhubung sebagai $_authenticatedUserId');
    } catch (e) {
      debugPrint('[WS] Gagal konek: $e');
      _channel = null;
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;
    debugPrint('[WS] Reconnect dalam $_reconnectDelaySec detik...');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _reconnectDelaySec), () {
      _reconnectDelaySec = (_reconnectDelaySec * 2).clamp(2, 60);
      _doConnect();
    });
  }

  /// Kirim data ke server melalui WebSocket.
  void send(Map<String, dynamic> data) {
    if (_channel != null) {
      try {
        _channel!.sink.add(jsonEncode(data));
      } catch (e) {
        debugPrint('[WS] Gagal kirim pesan: $e');
      }
    } else {
      debugPrint('[WS] Tidak terhubung, pesan tidak terkirim: ${data['type']}');
    }
  }

  /// Putuskan koneksi dan hentikan reconnect.
  void disconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _channel?.sink.close();
    _channel = null;
    _authenticatedUserId = null;
    debugPrint('[WS] Disconnected.');
  }
}
