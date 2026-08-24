import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';
import 'webrtc_handler.dart';
import 'call_history_service.dart';
import 'api_service.dart';

/// Enum status registrasi SIP
enum SipRegState { none, registering, registered, failed }

/// Enum status panggilan
enum SipCallState { idle, calling, ringing, accepted, ended, failed }

/// Listener untuk update UI
abstract class SipListener {
  void onRegistrationState(SipRegState state);
  void onCallState(SipCallState state, {String? callId});
}

/// Mesin SIP buatan sendiri menggunakan WebSocket
/// Protokol: SIP over WebSocket (RFC 7118) - kompatibel dengan Asterisk
class SipEngine {
  static final SipEngine _instance = SipEngine._internal();
  factory SipEngine() => _instance;
  SipEngine._internal();

  WebSocketChannel? _channel;
  SipRegState regState = SipRegState.none;
  SipCallState callState = SipCallState.idle;

  String? _sipUser;
  String? _sipPassword;
  String? _sipDomain;
  String? _currentCallId;
  String? _currentTag;

  bool isIncomingCall = false;
  bool isIncomingVideoCall = false;
  String? incomingCaller;

  String? _incomingCallId;
  String? _incomingCseq;
  String? _incomingFrom;
  String? _incomingTo;
  String? _incomingVia;
  String _incomingRecordRoute = '';
  String? _incomingOfferSdp; // SDP dari body INVITE masuk
  String? _outgoingOfferSdp; // SDP dari WebRTC saat call keluar
  String? _remoteContact; // Simpan Contact header dari remote untuk Request-URI BYE
  String? _activeToHeader; // Simpan To header (dengan tag) untuk BYE
  String? _activeFromHeader; // Simpan From header untuk BYE
  String? _activeRouteHeader; // Simpan Route header untuk BYE

  String? _lastProcessedInviteKey; // Untuk dedup retransmission
  String? _lastInviteResponseMsg; // Menyimpan respons terakhir (180 atau 200)

  Timer? _regTimer;

  /// Getter untuk Call-ID aktif (dipakai CallScreen untuk guard dispose)
  String? get activeCallId => _currentCallId ?? _incomingCallId;

  // WebRTC handler
  final WebRtcHandler webRtc = WebRtcHandler();

  final List<SipListener> _listeners = [];

  void addListener(SipListener l) => _listeners.add(l);
  void removeListener(SipListener l) => _listeners.remove(l);
  void _notifyReg(SipRegState s) {
    for (final l in _listeners) {
      l.onRegistrationState(s);
    }
  }

  void _logCallHistory() {
    if (_currentTargetExtension == null && incomingCaller == null) return;
    
    String type;
    if (isIncomingCall) {
      if (callState == SipCallState.accepted) {
        type = 'Masuk';
      } else {
        type = 'Terlewat';
      }
    } else {
      type = 'Keluar';
    }

    final name = isIncomingCall 
        ? (incomingCaller ?? 'Unknown') 
        : (_currentTargetExtension ?? 'Unknown');

    final isVideo = isIncomingCall 
        ? isIncomingVideoCall 
        : (_outgoingOfferSdp?.contains('m=video') ?? false);

    CallHistoryService.addCallRecord(name: name, type: type, isVideo: isVideo).catchError((e) {
      debugPrint('[SIP] Error logging history: $e');
    });
  }

  void _notifyCall(SipCallState s, {String? callId}) {
    for (final l in _listeners) {
      l.onCallState(s, callId: callId);
    }
  }

  Future<void> connect() async {
    // Guard: jika sudah terhubung atau sedang proses registrasi, jangan buat koneksi baru
    if (_channel != null) {
      debugPrint('[SIP] Koneksi sudah aktif (channel tidak null), skip connect().');
      return;
    }
    if (regState == SipRegState.registered || regState == SipRegState.registering) {
      debugPrint('[SIP] Sudah registered/registering, skip connect().');
      return;
    }

    final userData = await ApiService.getUserData();
    _sipUser = userData['sip_username'];
    _sipPassword = userData['sip_password'];
    _sipDomain = ApiService.serverIp;

    if (_sipUser == null || _sipPassword == null) {
      debugPrint('[SIP] Kredensial kosong, tidak bisa konek.');
      return;
    }

    try {
      // Asterisk WebSocket SIP standar: port 8089, path /ws, protokol 'sip'
      // Diarahkan ke wss (secure) port standar HTTPS (443) via Nginx proxy
      final wsUri = Uri.parse('wss://$_sipDomain/ws');
      debugPrint('[SIP] Menghubungkan ke $wsUri ...');

      _channel = WebSocketChannel.connect(
        wsUri,
        protocols: ['sip'],
      );

      _channel!.stream.listen(
        _onMessage,
        onError: (e) {
          debugPrint('[SIP] WebSocket error: $e');
          _channel = null;
          _regTimer?.cancel();
          regState = SipRegState.failed;
          _notifyReg(SipRegState.failed);
        },
        onDone: () {
          debugPrint('[SIP] WebSocket ditutup oleh server');
          _channel = null;
          _regTimer?.cancel();
          if (regState == SipRegState.registered) {
            regState = SipRegState.none;
            _notifyReg(SipRegState.none);
          }
        },
        cancelOnError: true,
      );

      debugPrint('[SIP] WebSocket terhubung, mengirim REGISTER...');
      _register();
    } catch (e) {
      debugPrint('[SIP] Gagal konek ke Asterisk: $e');
      regState = SipRegState.failed;
      _notifyReg(SipRegState.failed);
    }
  }

  int _regCSeq = 1;
  String? _regCallId;
  String? _regFromTag;
  bool _isAuthRetrying = false;

  bool _isCallAuthRetrying = false;
  String? _currentTargetExtension;
  String? _currentInviteBranch; // Simpan branch INVITE untuk ACK non-2xx
  int _currentCSeq = 1; // Simpan CSeq INVITE aktif

  // Counter atomik agar ID tidak pernah duplikat
  int _idCounter = 0;

  void _register() {
    _isAuthRetrying = false;
    _regCallId = _generateId();
    _regFromTag = _generateId();
    _regCSeq = 1;
    
    _sendRegisterRequest();

    // Auto renew registrasi tiap 100 detik (karena expires: 120)
    _regTimer?.cancel();
    _regTimer = Timer.periodic(const Duration(seconds: 100), (timer) {
      if (_channel != null && regState == SipRegState.registered) {
        _regCSeq++;
        _sendRegisterRequest();
      } else if (_channel == null) {
        timer.cancel();
      }
    });
  }

  void _sendRegisterRequest() {
    final branch = 'z9hG4bK-${_generateId()}';
    final msg = '''REGISTER sip:$_sipDomain SIP/2.0\r
Via: SIP/2.0/WS $_sipDomain:5060;branch=$branch\r
From: <sip:$_sipUser@$_sipDomain>;tag=$_regFromTag\r
To: <sip:$_sipUser@$_sipDomain>\r
Call-ID: $_regCallId\r
CSeq: $_regCSeq REGISTER\r
Contact: <sip:$_sipUser@$_sipDomain;transport=ws>\r
Max-Forwards: 70\r
Expires: 120\r
Content-Length: 0\r
\r
''';
    _send(msg);
    debugPrint('[SIP] REGISTER dikirim untuk $_sipUser (CSeq: $_regCSeq)');
    if (regState != SipRegState.registered) {
      regState = SipRegState.registering;
      _notifyReg(SipRegState.registering);
    }
  }

  /// Mulai panggilan keluar ke SIP extension tujuan
  void call(String targetExtension, {bool isVideo = false}) {
    if (regState != SipRegState.registered) {
      debugPrint('[SIP] Tidak bisa call: belum registered.');
      callState = SipCallState.failed;
      _notifyCall(SipCallState.failed);
      return;
    }
    // Cegah double-tap atau panggilan ganda
    if (callState == SipCallState.calling ||
        callState == SipCallState.ringing ||
        callState == SipCallState.accepted) {
      debugPrint('[SIP] Panggilan sedang berlangsung, abaikan call() baru.');
      return;
    }
    callState = SipCallState.calling;
    _notifyCall(SipCallState.calling);
    _callWithWebRtc(targetExtension, isVideo: isVideo);
  }

  Future<void> _callWithWebRtc(String targetExtension, {bool isVideo = false}) async {
    try {
      _isCallAuthRetrying = false;
      _currentTargetExtension = targetExtension;
      _currentCallId = _generateId();
      _currentTag = _generateId();
      _incomingCallId = null;
      _currentCSeq = 1;

      // 1. Buat SDP offer nyata via WebRTC (akses mikrofon/kamera browser)
      final sdpBody = await webRtc.createOffer(isVideo: isVideo);
      _outgoingOfferSdp = sdpBody; // Simpan untuk _handleCallAuth
      _currentInviteBranch = 'z9hG4bK-${_generateId()}';

      // 2. Kirim pesan SIP INVITE awal (tanpa autentikasi)
      final inviteMsg = '''INVITE sip:$_currentTargetExtension@$_sipDomain SIP/2.0\r
Via: SIP/2.0/WS $_sipDomain:5060;branch=$_currentInviteBranch\r
From: <sip:$_sipUser@$_sipDomain>;tag=$_currentTag\r
To: <sip:$_currentTargetExtension@$_sipDomain>\r
Call-ID: $_currentCallId\r
CSeq: $_currentCSeq INVITE\r
Contact: <sip:$_sipUser@$_sipDomain;transport=ws>\r
Max-Forwards: 70\r
Content-Type: application/sdp\r
Content-Length: ${utf8.encode(sdpBody).length}\r
\r
$sdpBody''';

      _send(inviteMsg);
      debugPrint('[SIP] Initial INVITE dikirim ke $_currentTargetExtension');

    } catch (e) {
      debugPrint('[SIP] Error setup WebRTC untuk outgoing call: $e');
      callState = SipCallState.failed;
      _notifyCall(SipCallState.failed);
      await webRtc.hangup();
    }
  }

  /// Akhiri panggilan
  Future<void> hangup() async {
    final targetCallId = _currentCallId ?? _incomingCallId;
    if (targetCallId == null) {
      // Tidak ada dialog aktif, reset saja state
      callState = SipCallState.idle;
      isIncomingCall = false;
      isIncomingVideoCall = false;
      return;
    }

    debugPrint('[SIP] Hangup dipanggil, mengakhiri panggilan lokal.');

    _currentCSeq++;
    if (callState == SipCallState.calling || callState == SipCallState.ringing) {
      if (!isIncomingCall) {
        // Kirim CANCEL
        final cancelMsg = '''CANCEL sip:$_currentTargetExtension@$_sipDomain SIP/2.0\r
Via: SIP/2.0/WS $_sipDomain:5060;branch=$_currentInviteBranch\r
From: <sip:$_sipUser@$_sipDomain>;tag=$_currentTag\r
To: <sip:$_currentTargetExtension@$_sipDomain>\r
Call-ID: $targetCallId\r
CSeq: $_currentCSeq CANCEL\r
Max-Forwards: 70\r
Content-Length: 0\r
\r
''';
        _send(cancelMsg);
        debugPrint('[SIP] Sent CANCEL');
      } else {
        // Reject incoming call (486 Busy Here)
        final busyMsg = '''SIP/2.0 486 Busy Here\r
Via: $_incomingVia\r
From: $_incomingFrom\r
To: $_incomingTo\r
Call-ID: $_incomingCallId\r
CSeq: $_incomingCseq\r
Content-Length: 0\r
\r
''';
        _send(busyMsg);
        debugPrint('[SIP] Sent 486 Busy Here (Rejected by user)');
      }
    } else if (callState == SipCallState.accepted) {
      // Kirim BYE
      String targetUri = '';
      if (_remoteContact != null && _remoteContact!.isNotEmpty) {
        final regex = RegExp(r'<([^>]+)>');
        final match = regex.firstMatch(_remoteContact!);
        if (match != null) {
          targetUri = match.group(1)!;
        } else {
          targetUri = _remoteContact!.trim();
        }
      } else {
        targetUri = isIncomingCall ? 'sip:$incomingCaller@$_sipDomain' : 'sip:$_currentTargetExtension@$_sipDomain';
      }

      String routeHeaders = '';
      if (isIncomingCall && _incomingRecordRoute.isNotEmpty) {
         routeHeaders = 'Route: ' + _incomingRecordRoute.replaceAll('Record-Route:', 'Route:') + '\r\n';
      } else if (!isIncomingCall && _activeRouteHeader != null && _activeRouteHeader!.isNotEmpty) {
         routeHeaders = 'Route: ' + _activeRouteHeader!.replaceAll('Record-Route:', 'Route:') + '\r\n';
      }
      
      String toStr = _activeToHeader ?? (isIncomingCall ? _incomingFrom! : '<sip:$_currentTargetExtension@$_sipDomain>');
      String fromStr = _activeFromHeader ?? (isIncomingCall ? _incomingTo! : '<sip:$_sipUser@$_sipDomain>;tag=$_currentTag');

      if (isIncomingCall && _activeToHeader == null) {
         fromStr = _incomingTo!;
         toStr = _incomingFrom!;
      }

      final byeMsg = '''BYE $targetUri SIP/2.0\r
Via: SIP/2.0/WS $_sipDomain:5060;branch=z9hG4bK-${_generateId()}\r
From: $fromStr\r
To: $toStr\r
Call-ID: $targetCallId\r
CSeq: $_currentCSeq BYE\r
Max-Forwards: 70\r
$routeHeaders'''
          'Content-Length: 0\r\n\r\n';
      _send(byeMsg);
      debugPrint('[SIP] Sent BYE');
    }

    // Reset semua state
    _logCallHistory();
    callState = SipCallState.ended;
    _notifyCall(SipCallState.ended);
    _resetCallState();
    await webRtc.hangup();
  }

  /// Reset semua field terkait panggilan ke kondisi awal
  void _resetCallState() {
    _currentCallId = null;
    _incomingCallId = null;
    _isCallAuthRetrying = false;
    isIncomingCall = false;
    isIncomingVideoCall = false;
    _currentTag = null;
    _remoteContact = null;
    _activeToHeader = null;
    _activeFromHeader = null;
    _activeRouteHeader = null;
    _currentTargetExtension = null;
    _outgoingOfferSdp = null;
    _incomingOfferSdp = null;
    _incomingFrom = null;
    _incomingTo = null;
    _incomingVia = null;
    _incomingCseq = null;
    _incomingRecordRoute = '';
    _lastProcessedInviteKey = null;
    _lastInviteResponseMsg = null;
    _currentCSeq = 1;
  }

  /// Angkat panggilan masuk
  void answer({bool isVideo = false}) {
    if (!isIncomingCall || _incomingCallId == null) return;
    _answerWithWebRtc(isVideo: isVideo);
  }

  Future<void> _answerWithWebRtc({bool isVideo = false}) async {
    try {
      // 1. Buat SDP answer nyata dari offer yang ada di INVITE
      final offerSdp = _incomingOfferSdp ?? '';
      if (offerSdp.isEmpty) {
        debugPrint(
            '[SIP] Tidak ada SDP offer dari INVITE — tidak bisa answer WebRTC');
        callState = SipCallState.failed;
        _notifyCall(SipCallState.failed);
        return;
      }
      final sdpBody = await webRtc.createAnswer(offerSdp, isVideo: isVideo);

      // 2. Kirim 200 OK dengan SDP answer asli
      final answerMsg = 'SIP/2.0 200 OK\r\n'
          'Via: $_incomingVia\r\n'
          'From: $_incomingFrom\r\n'
          'To: $_incomingTo\r\n'
          'Call-ID: $_incomingCallId\r\n'
          'CSeq: $_incomingCseq\r\n'
          'Contact: <sip:$_sipUser@$_sipDomain;transport=ws>\r\n'
          '${_incomingRecordRoute.isNotEmpty ? 'Record-Route: $_incomingRecordRoute\r\n' : ''}'
          'Content-Type: application/sdp\r\n'
          'Content-Length: ${utf8.encode(sdpBody).length}\r\n'
          '\r\n'
          '$sdpBody';
      _send(answerMsg);
      _lastInviteResponseMsg = answerMsg; // Simpan untuk retransmission
      debugPrint('[SIP] Sent 200 OK (WebRTC SDP Answer)');
      callState = SipCallState.accepted;
      _notifyCall(SipCallState.accepted);
    } catch (e) {
      debugPrint('[SIP] Error setup WebRTC untuk answer: $e');
      callState = SipCallState.failed;
      _notifyCall(SipCallState.failed);
      await webRtc.hangup();
    }
  }

  /// RFC 3261: Header field values can be "folded" across multiple lines.
  /// A line that starts with SP (space) or HT (tab) is a continuation of the
  /// previous header. We unfold them before parsing.
  String _unfoldHeaders(String msg) {
    // Split on CRLF+whitespace and join with a single space
    return msg.replaceAll(RegExp(r'\r\n[ \t]+'), ' ');
  }

  void _onMessage(dynamic raw) {
    final msg = _unfoldHeaders(raw.toString());
    debugPrint('[SIP] << $msg');

    final cseqHeader = _extractHeader(msg, 'CSeq');

    if (msg.startsWith('SIP/2.0 200') && cseqHeader.contains('REGISTER')) {
      // --- 200 OK untuk REGISTER ---
      _isAuthRetrying = false;
      regState = SipRegState.registered;
      _notifyReg(SipRegState.registered);
      debugPrint('[SIP] ✅ Registered!');
    } else if (msg.startsWith('SIP/2.0 401') &&
        msg.contains('WWW-Authenticate')) {
      if (cseqHeader.contains('REGISTER')) {
        if (!_isAuthRetrying) {
          _isAuthRetrying = true;
          _handleRegisterAuth(msg);
        } else {
          regState = SipRegState.failed;
          _notifyReg(SipRegState.failed);
          debugPrint('[SIP] ❌ Auth gagal beruntun. Cek Password/User!');
        }
      } else if (cseqHeader.contains('INVITE')) {
        _sendAckForNon2xx(msg);

        final cseqNum = int.tryParse(cseqHeader.split(' ').first) ?? 1;
        if (cseqNum == 1) {
          if (!_isCallAuthRetrying) {
            _isCallAuthRetrying = true;
            _handleCallAuth(msg);
          } else {
            debugPrint('[SIP] Mengabaikan retransmisi 401 untuk INVITE CSeq 1');
          }
        } else {
          callState = SipCallState.failed;
          _notifyCall(SipCallState.failed);
          debugPrint('[SIP] ❌ INVITE Auth gagal beruntun (CSeq $cseqNum).');
          webRtc.hangup();
        }
      }
    } else if (msg.startsWith('SIP/2.0 403')) {
      if (cseqHeader.contains('REGISTER')) {
        regState = SipRegState.failed;
        _notifyReg(SipRegState.failed);
      } else {
        if (cseqHeader.contains('INVITE')) _sendAckForNon2xx(msg);
        _isCallAuthRetrying = false;
        callState = SipCallState.failed;
        _notifyCall(SipCallState.failed);
        webRtc.hangup();
      }
      debugPrint('[SIP] ❌ Auth gagal (403)');
    } else if ((msg.startsWith('SIP/2.0 503') || msg.startsWith('SIP/2.0 5')) && cseqHeader.contains('REGISTER')) {
      // 503 Service Unavailable atau 5xx error lainnya saat REGISTER
      // Tutup channel agar guard di connect() tidak memblokir reconnect
      final statusLine = msg.split('\r\n').first;
      debugPrint('[SIP] ⚠️ Server error ($statusLine). Menutup koneksi, coba ulang dalam 5 detik...');
      _channel?.sink.close();
      _channel = null;
      _regTimer?.cancel();
      regState = SipRegState.failed;
      _notifyReg(SipRegState.failed);
      // Coba reconnect setelah 5 detik
      Future.delayed(const Duration(seconds: 5), () {
        debugPrint('[SIP] Mencoba reconnect setelah 503...');
        connect();
      });
    } else if (msg.startsWith('SIP/2.0 180') || msg.startsWith('SIP/2.0 183')) {
      // Ringing atau Session Progress
      callState = SipCallState.ringing;
      _notifyCall(SipCallState.ringing);
    } else if (msg.startsWith('SIP/2.0 200') && cseqHeader.contains('INVITE')) {
      // Set remote SDP answer SEBELUM kirim ACK (agar WebRTC bisa setup audio)
      // Hindari set ulang jika sudah accepted (menghindari error InvalidStateError)
      if (callState != SipCallState.accepted) {
        final remoteSdp = _extractBody(msg);
        if (remoteSdp.isNotEmpty) {
          webRtc.setRemoteAnswer(remoteSdp).catchError((e) {
            debugPrint('[WebRTC] setRemoteAnswer error: $e');
          });
        }
        callState = SipCallState.accepted;
        _notifyCall(SipCallState.accepted);
      }

      // Kirim ACK
      final toStr = _extractHeader(msg, 'To');
      _activeToHeader = toStr;
      _activeFromHeader = _extractHeader(msg, 'From');
      _remoteContact = _extractHeader(msg, 'Contact'); // Simpan Contact untuk routing BYE
      _activeRouteHeader = _extractAllHeader(msg, 'Record-Route');

      final cseqRaw = _extractHeader(msg, 'CSeq');
      final cseqNum = cseqRaw.split(' ').first;
      final target = _currentTargetExtension ?? _sipUser ?? _sipDomain!;
      final callId = _currentCallId ?? _incomingCallId ?? '';
      final tag = _currentTag ?? '';

      // ACK Request-URI harus menggunakan URI dari Contact header 200 OK
      String ackUri = 'sip:$target@$_sipDomain';
      if (_remoteContact != null && _remoteContact!.isNotEmpty) {
        final regex = RegExp(r'<([^>]+)>');
        final match = regex.firstMatch(_remoteContact!);
        if (match != null) {
          ackUri = match.group(1)!;
        } else {
          ackUri = _remoteContact!.trim();
        }
      }

      final recordRouteRaw = _extractAllHeader(msg, 'Record-Route');
      String routeHeaders = '';
      if (recordRouteRaw.isNotEmpty) {
        routeHeaders = 'Route: ' + recordRouteRaw.replaceAll('Record-Route:', 'Route:') + '\r\n';
      }

      final ackMsg = 'ACK $ackUri SIP/2.0\r\n'
          'Via: SIP/2.0/WS $_sipDomain:5060;branch=z9hG4bK-${_generateId()}\r\n'
          'From: <sip:$_sipUser@$_sipDomain>;tag=$tag\r\n'
          'To: $toStr\r\n'
          'Call-ID: $callId\r\n'
          'CSeq: $cseqNum ACK\r\n'
          'Max-Forwards: 70\r\n'
          '$routeHeaders'
          'Content-Length: 0\r\n'
          '\r\n';
      _send(ackMsg);
      debugPrint('[SIP] Sent ACK for 200 OK');
    } else if (msg.startsWith('BYE ')) {
      // Balas BYE dengan 200 OK
      final byeCallId = _extractHeader(msg, 'Call-ID');
      final byeFrom = _extractHeader(msg, 'From');
      final byeTo = _extractHeader(msg, 'To');
      final byeVia = _extractHeader(msg, 'Via');
      final byeCseq = _extractHeader(msg, 'CSeq').split(' ').first;
      final byeOkMsg = '''SIP/2.0 200 OK\r
Via: $byeVia\r
From: $byeFrom\r
To: $byeTo\r
Call-ID: $byeCallId\r
CSeq: $byeCseq BYE\r
Content-Length: 0\r
\r
''';
      _send(byeOkMsg);
      debugPrint('[SIP] Received BYE, sent 200 OK, call ended');
      _logCallHistory();
      callState = SipCallState.ended;
      _notifyCall(SipCallState.ended);
      _resetCallState();
      webRtc.hangup();
    } else if (msg.startsWith('SIP/2.0 487') || msg.startsWith('SIP/2.0 481')) {
      if (cseqHeader.contains('INVITE')) _sendAckForNon2xx(msg);
      _logCallHistory();
      callState = SipCallState.ended;
      _notifyCall(SipCallState.ended);
      _resetCallState();
      webRtc.hangup();
    } else if (msg.startsWith('SIP/2.0 4') ||
        msg.startsWith('SIP/2.0 5') ||
        msg.startsWith('SIP/2.0 6')) {
      if (callState == SipCallState.calling ||
          callState == SipCallState.ringing) {
        _sendAckForNon2xx(msg);

        _logCallHistory();
        callState = SipCallState.failed;
        _notifyCall(SipCallState.failed);
        _resetCallState();
        webRtc.hangup();
      }
    } else if (msg.startsWith('INVITE sip:')) {
      final callId = _extractHeader(msg, 'Call-ID');
      final cseq = _extractHeader(msg, 'CSeq');
      final incomingKey = '$callId-$cseq';

      if (_lastProcessedInviteKey == incomingKey) {
        // Ini adalah retransmission dari INVITE yang sama!
        if (_lastInviteResponseMsg != null) {
          _send(_lastInviteResponseMsg!);
          debugPrint(
              '[SIP] Retransmission INVITE dideteksi. Resend respons terakhir.');
        }
        return; // Jangan diproses ulang (jangan buat PeerConnection baru!)
      }
      _lastProcessedInviteKey = incomingKey;

      final fromStr = _extractHeader(msg, 'From');
      final toStr = _extractHeader(msg, 'To');
      final via = _extractAllHeader(msg, 'Via');
      final recordRoute = _extractAllHeader(msg, 'Record-Route');

      // 100 Trying dikirim CEPAT sebelum proses apapun (menghindari retransmission Asterisk)
      final tryingMsg = '''SIP/2.0 100 Trying\r
Via: $via\r
From: $fromStr\r
To: $toStr\r
Call-ID: $callId\r
CSeq: $cseq\r
Content-Length: 0\r
\r
''';
      _send(tryingMsg);
      debugPrint('[SIP] Sent 100 Trying.');

      // Reset state lama sebelum memproses INVITE baru
      if (callState != SipCallState.idle) {
        callState = SipCallState.idle;
        isIncomingCall = false;
        isIncomingVideoCall = false;
        _incomingCallId = null;
      }

      // Ambil username si penelepon
      final match = RegExp(r'sip:([^@]+)@').firstMatch(fromStr);
      incomingCaller = match?.group(1) ?? 'Unknown';

      // Cek apakah penelepon ada di daftar blokir
      if (ApiService.blockedSipUsernames.contains(incomingCaller)) {
        debugPrint('[SIP] Penelepon ($incomingCaller) diblokir. Mengirim 486 Busy Here.');
        final busyMsg = '''SIP/2.0 486 Busy Here\r
Via: $via\r
From: $fromStr\r
To: $toStr;tag=\${_generateId()}\r
Call-ID: $callId\r
CSeq: $cseq\r
Content-Length: 0\r
\r
''';
        _send(busyMsg);
        return;
      }

      isIncomingCall = true;

      _remoteContact = _extractHeader(msg, 'Contact'); // Simpan Contact untuk routing BYE

      _incomingCallId = callId;
      _incomingCseq = cseq;
      _incomingFrom = fromStr;
      _incomingTo = '$toStr;tag=${_generateId()}';
      _incomingVia = via;
      _incomingRecordRoute = recordRoute;
      // Simpan SDP body dari INVITE untuk dipakai di createAnswer()
      _incomingOfferSdp = _extractBody(msg);
      isIncomingVideoCall = _incomingOfferSdp?.contains('m=video') ?? false;

      final ringingMsg = '''SIP/2.0 180 Ringing\r
Via: $_incomingVia\r
From: $_incomingFrom\r
To: $_incomingTo\r
Call-ID: $_incomingCallId\r
CSeq: $_incomingCseq\r
Contact: <sip:$_sipUser@$_sipDomain;transport=ws>\r
${_incomingRecordRoute.isNotEmpty ? 'Record-Route: $_incomingRecordRoute\r\n' : ''}Content-Length: 0\r
\r
''';
      _send(ringingMsg);
      _lastInviteResponseMsg = ringingMsg; // Simpan untuk retransmission
      debugPrint('[SIP] Incoming Call! Sent 180 Ringing.');
      callState = SipCallState.ringing;
      _notifyCall(SipCallState.ringing, callId: callId);
    } else if (msg.startsWith('CANCEL ')) {
      // Caller membatalkan panggilan sebelum dijawab
      final cancelVia = _extractAllHeader(msg, 'Via');
      final cancelFrom = _extractHeader(msg, 'From');
      final cancelTo = _extractHeader(msg, 'To');
      final cancelCallId = _extractHeader(msg, 'Call-ID');
      final cancelCseq = _extractHeader(msg, 'CSeq');

      // Langkah 1: Balas CANCEL dengan 200 OK
      final cancelOkMsg = '''SIP/2.0 200 OK\r
Via: $cancelVia\r
From: $cancelFrom\r
To: $cancelTo\r
Call-ID: $cancelCallId\r
CSeq: $cancelCseq\r
Content-Length: 0\r
\r
''';
      _send(cancelOkMsg);
      debugPrint('[SIP] Sent 200 OK for CANCEL');

      // Langkah 2: Kirim 487 Request Terminated untuk INVITE asal
      if (_incomingCallId != null && _incomingCallId == cancelCallId) {
        final terminatedMsg = '''SIP/2.0 487 Request Terminated\r
Via: $_incomingVia\r
From: $_incomingFrom\r
To: $_incomingTo\r
Call-ID: $_incomingCallId\r
CSeq: $_incomingCseq\r
Content-Length: 0\r
\r
''';
        _send(terminatedMsg);
        debugPrint(
            '[SIP] Sent 487 Request Terminated (INVITE cancelled by caller)');
      }

      // Reset semua state panggilan
      _logCallHistory();
      callState = SipCallState.ended;
      _notifyCall(SipCallState.ended);
      _resetCallState();
      webRtc.hangup();
    }
  }

  /// Ekstrak SDP body dari pesan SIP mentah (dipisahkan oleh \r\n\r\n)
  String _extractBody(String msg) {
    final idx = msg.indexOf('\r\n\r\n');
    if (idx == -1) return '';

    final rawBody = msg.substring(idx + 4).trim();
    if (rawBody.isEmpty) return '';

    // Normalisasi SDP: WebRTC (Chrome) sangat ketat harus \r\n di setiap baris dan diakhiri \r\n
    var sdp = rawBody.replaceAll(RegExp(r'\r\n|\r|\n'), '\r\n');

    // NAT REWRITE: Jika Asterisk mengirim IP lokal (misal 172.31.x.x), WebRTC tidak akan bisa konek.
    // Ganti di baris c=IN IP4, o=IN IP4, DAN a=candidate: lines.
    if (_sipDomain != null) {
      final ipMatch = RegExp(r'c=IN IP4 ([\d\.]+)').firstMatch(sdp);
      if (ipMatch != null) {
        final internalIp = ipMatch.group(1)!;
        if (internalIp != _sipDomain) {
          // Ganti di c= line
          sdp = sdp.replaceAll('c=IN IP4 $internalIp', 'c=IN IP4 $_sipDomain');
          // Ganti di o= line (origin)
          sdp = sdp.replaceAll('o=IN IP4 $internalIp', 'o=IN IP4 $_sipDomain');
        }
        
        // Selalu ganti IP di a=candidate: lines agar ICE bisa konek ke public IP
        // Asterisk sering menyertakan IP lokal di a=candidate walaupun c=IN IP4 sudah benar
        sdp = sdp.replaceAllMapped(
          RegExp(r'(a=candidate:\S+\s+\d+\s+\w+\s+\d+\s+)([\d\.]+)(\s)'),
          (m) {
            final candidateIp = m.group(2)!;
            // Jika IP candidate bukan public IP server, ganti dengan public IP server
            if (candidateIp != _sipDomain) {
              return '${m.group(1)}$_sipDomain${m.group(3)}';
            }
            return m.group(0)!;
          },
        );
        debugPrint('[SIP] NAT Rewrite SDP: Diganti IP lokal menjadi $_sipDomain');
      }
    }

    if (!sdp.endsWith('\r\n')) {
      sdp += '\r\n';
    }
    return sdp;
  }

  void _handleRegisterAuth(String msg) {
    final realm = _extractParam(msg, 'realm');
    final nonce = _extractParam(msg, 'nonce');
    final qop = _extractParam(msg, 'qop');
    final opaque = _extractParam(msg, 'opaque');

    if (realm.isEmpty || nonce.isEmpty) return;

    final cnonce = _generateId();
    const nc = '00000001';
    final uri = 'sip:$_sipDomain';
    const method = 'REGISTER';

    // MD5 Hashing (Digest Auth)
    final ha1 =
        md5.convert(utf8.encode('$_sipUser:$realm:$_sipPassword')).toString();
    final ha2 = md5.convert(utf8.encode('$method:$uri')).toString();
    final response = md5
        .convert(utf8.encode('$ha1:$nonce:$nc:$cnonce:$qop:$ha2'))
        .toString();

    String authHeader =
        'Digest username="$_sipUser", realm="$realm", nonce="$nonce", uri="$uri", response="$response", algorithm=MD5, cnonce="$cnonce", nc=$nc, qop="$qop"';
    if (opaque.isNotEmpty) authHeader += ', opaque="$opaque"';

    _regCSeq++;
    final branch = 'z9hG4bK-${_generateId()}';

    final authMsg = '''REGISTER sip:$_sipDomain SIP/2.0\r
Via: SIP/2.0/WS $_sipDomain:5060;branch=$branch\r
From: <sip:$_sipUser@$_sipDomain>;tag=$_regFromTag\r
To: <sip:$_sipUser@$_sipDomain>\r
Call-ID: $_regCallId\r
CSeq: $_regCSeq REGISTER\r
Contact: <sip:$_sipUser@$_sipDomain;transport=ws>\r
Authorization: $authHeader\r
Max-Forwards: 70\r
Expires: 120\r
Content-Length: 0\r
\r
''';
    _send(authMsg);
    debugPrint('[SIP] REGISTER (with Auth) dikirim');
  }

  void _handleCallAuth(String msg) {
    if (_currentTargetExtension == null) return;

    final realm = _extractParam(msg, 'realm');
    final nonce = _extractParam(msg, 'nonce');
    final qop = _extractParam(msg, 'qop');
    final opaque = _extractParam(msg, 'opaque');

    if (realm.isEmpty || nonce.isEmpty) return;

    final cnonce = _generateId();
    const nc = '00000001';
    final uri = 'sip:$_currentTargetExtension@$_sipDomain';
    const method = 'INVITE';

    final ha1 =
        md5.convert(utf8.encode('$_sipUser:$realm:$_sipPassword')).toString();
    final ha2 = md5.convert(utf8.encode('$method:$uri')).toString();
    final response = md5
        .convert(utf8.encode('$ha1:$nonce:$nc:$cnonce:$qop:$ha2'))
        .toString();

    String authHeader =
        'Digest username="$_sipUser", realm="$realm", nonce="$nonce", uri="$uri", response="$response", algorithm=MD5, cnonce="$cnonce", nc=$nc, qop="$qop"';
    if (opaque.isNotEmpty) authHeader += ', opaque="$opaque"';

    // Update branch dan CSeq → disimpan agar ACK untuk non-2xx pakai branch yang tepat
    _currentCSeq = 2;
    _currentInviteBranch = 'z9hG4bK-${_generateId()}';

    // Gunakan SDP WebRTC asli yang disimpan sebelumnya, jangan pakai dummy!
    final sdpBody = _outgoingOfferSdp ?? '';

    final authMsg = '''INVITE sip:$_currentTargetExtension@$_sipDomain SIP/2.0\r
Via: SIP/2.0/WS $_sipDomain:5060;branch=$_currentInviteBranch\r
From: <sip:$_sipUser@$_sipDomain>;tag=$_currentTag\r
To: <sip:$_currentTargetExtension@$_sipDomain>\r
Call-ID: $_currentCallId\r
CSeq: $_currentCSeq INVITE\r
Contact: <sip:$_sipUser@$_sipDomain;transport=ws>\r
Authorization: $authHeader\r
Max-Forwards: 70\r
Content-Type: application/sdp\r
Content-Length: ${utf8.encode(sdpBody).length}\r
\r
$sdpBody''';

    _send(authMsg);
    debugPrint('[SIP] INVITE (with Auth) dikirim ke $_currentTargetExtension');
  }

  String _extractParam(String header, String param) {
    final match = RegExp('$param="?([^",\r\n]+)"?').firstMatch(header);
    return match?.group(1) ?? '';
  }

  String _extractHeader(String msg, String headerName) {
    final regex = RegExp('^$headerName\\s*:\\s*(.+)\$',
        multiLine: true, caseSensitive: false);
    final match = regex.firstMatch(msg);
    return match?.group(1)?.trim() ?? '';
  }

  String _extractAllHeader(String msg, String headerName) {
    final regex = RegExp('^$headerName\\s*:\\s*(.+)\$',
        multiLine: true, caseSensitive: false);
    final matches = regex.allMatches(msg);
    if (matches.isEmpty) return '';
    return matches
        .map((m) => m.group(1)?.trim() ?? '')
        .join('\r\n$headerName: ');
  }

  void _send(String msg) {
    if (_channel != null) {
      _channel!.sink.add(msg);
    }
  }

  void _sendAckForNon2xx(String msg) {
    if (!_extractHeader(msg, 'CSeq').contains('INVITE')) return;

    final toStr = _extractHeader(msg, 'To');
    final cseqRaw = _extractHeader(msg, 'CSeq');
    final cseqNum = cseqRaw.split(' ').first;
    final viaRaw = _extractHeader(msg, 'Via');
    final branchMatch = RegExp(r'branch=([^;\r\n]+)').firstMatch(viaRaw);
    final branch = branchMatch?.group(1) ??
        _currentInviteBranch ??
        'z9hG4bK-${_generateId()}';
    final target = _currentTargetExtension ?? _sipUser ?? _sipDomain!;
    final callId = _currentCallId ?? _incomingCallId ?? '';
    final tag = _currentTag ?? '';

    final ackMsg = '''ACK sip:$target@$_sipDomain SIP/2.0\r
Via: SIP/2.0/WS $_sipDomain:5060;branch=$branch\r
From: <sip:$_sipUser@$_sipDomain>;tag=$tag\r
To: $toStr\r
Call-ID: $callId\r
CSeq: $cseqNum ACK\r
Max-Forwards: 70\r
Content-Length: 0\r
\r
''';
    _send(ackMsg);
    debugPrint('[SIP] Sent ACK for non-2xx');
  }

  void disconnect() {
    if (_channel != null &&
        regState == SipRegState.registered &&
        _regCallId != null &&
        _regFromTag != null) {
      final branch = 'z9hG4bK-${_generateId()}';
      _regCSeq++;
      _regTimer?.cancel();
      final unregMsg = '''REGISTER sip:$_sipDomain SIP/2.0\r
Via: SIP/2.0/WS $_sipDomain:5060;branch=$branch\r
From: <sip:$_sipUser@$_sipDomain>;tag=$_regFromTag\r
To: <sip:$_sipUser@$_sipDomain>\r
Call-ID: $_regCallId\r
CSeq: $_regCSeq REGISTER\r
Contact: <sip:$_sipUser@$_sipDomain;transport=ws>\r
Max-Forwards: 70\r
Expires: 0\r
Content-Length: 0\r
\r
''';
      _send(unregMsg);
      debugPrint('[SIP] Unregister dikirim sebelum disconnect');
    }
    _channel?.sink.close();
    _channel = null;
    regState = SipRegState.none;
    _sipUser = null;
    _sipPassword = null;
    _sipDomain = null;
  }

  // Gunakan counter atomik agar ID selalu unik, tidak tergantung waktu
  String _generateId() {
    _idCounter++;
    final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final counter = _idCounter.toString().padLeft(5, '0');
    return '$ts$counter';
  }
}
