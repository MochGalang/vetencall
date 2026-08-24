import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Mengelola RTCPeerConnection dan media audio WebRTC.
/// Dipakai oleh SipEngine untuk menggantikan SDP statis.
class WebRtcHandler {
  RTCPeerConnection? _pc;
  MediaStream? _localStream;

  // Renderer untuk memainkan video/audio remote
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  // Renderer untuk menampilkan video lokal
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  bool _rendererInitialized = false;

  final Map<String, dynamic> _rtcConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  final Map<String, dynamic> _pcConstraints = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ],
  };

  /// Inisialisasi renderer — panggil satu kali di awal
  Future<void> initRenderer() async {
    if (!_rendererInitialized) {
      await remoteRenderer.initialize();
      await localRenderer.initialize();
      _rendererInitialized = true;
    }
  }

  /// Ambil media dari browser
  Future<MediaStream> getLocalStream({bool isVideo = false}) async {
    _localStream?.getTracks().forEach((t) => t.stop());
    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': false,
          'autoGainControl': false,
        },
        'video': isVideo
            ? {
                'facingMode': 'user',
              }
            : false,
      });
      if (isVideo) {
        localRenderer.srcObject = _localStream;
      }
      debugPrint('[WebRTC] getUserMedia OK — Video: $isVideo');
    } catch (e) {
      debugPrint('[WebRTC] getUserMedia Error: $e');
      rethrow;
    }
    return _localStream!;
  }

  Future<void> _createPeerConnection({bool isVideo = false}) async {
    await initRenderer(); // Pastikan renderer diinisialisasi sebelum digunakan
    await _closePeerConnection();

    // Ambil stream SETELAH mematikan koneksi lama
    await getLocalStream(isVideo: isVideo);

    _pc = await createPeerConnection(_rtcConfig, _pcConstraints);

    // Pasang track lokal ke PC
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await _pc!.addTrack(track, _localStream!);
      }
    }

    // Terima track remote → pasang ke renderer supaya audio/video keluar
    _pc!.onTrack = (RTCTrackEvent event) {
      debugPrint('[WebRTC] onTrack: ${event.track.kind} (streams: ${event.streams.length})');
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams[0];
      }
    };

    // Fallback: onAddStream selalu mengirim MediaStream lengkap
    // Di beberapa implementasi unified-plan, onTrack bisa dipanggil dengan
    // event.streams kosong (terutama di sisi callee). onAddStream lebih
    // reliable untuk memastikan remote video/audio ter-render.
    _pc!.onAddStream = (MediaStream stream) {
      debugPrint('[WebRTC] onAddStream: ${stream.id} (tracks: ${stream.getTracks().length})');
      remoteRenderer.srcObject = stream;
    };

    _pc!.onIceConnectionState = (s) => debugPrint('[WebRTC] ICE state: $s');
    _pc!.onConnectionState = (s) => debugPrint('[WebRTC] PC state:  $s');
    // CATATAN: onIceGatheringState TIDAK di-set di sini karena _waitIce()
    // akan meng-assign handler-nya sendiri. Meng-assign di sini hanya akan
    // ditimpa oleh _waitIce(), jadi dihilangkan untuk menghindari kebingungan.
  }

  /// Tunggu ICE gathering selesai (max [timeoutSec] detik)
  Future<void> _waitIce({int timeoutSec = 1}) async {
    if (_pc == null) return;
    final c = Completer<void>();
    _pc!.onIceGatheringState = (RTCIceGatheringState s) {
      debugPrint('[WebRTC] Gathering: $s');
      if (s == RTCIceGatheringState.RTCIceGatheringStateComplete &&
          !c.isCompleted) {
        c.complete();
      }
    };
    try {
      await c.future.timeout(Duration(seconds: timeoutSec));
      debugPrint('[WebRTC] ICE gathering complete');
    } catch (_) {
      debugPrint(
          '[WebRTC] ICE gathering timeout ($timeoutSec s), lanjut dengan kandidat yang ada');
    }
  }

  /// Buat SDP Offer
  Future<String> createOffer({bool isVideo = false}) async {
    await _createPeerConnection(isVideo: isVideo);

    final offer = await _pc!
        .createOffer({'offerToReceiveAudio': 1, 'offerToReceiveVideo': isVideo ? 1 : 0});
    await _pc!.setLocalDescription(offer);
    await _waitIce();

    final desc = await _pc!.getLocalDescription();
    final sdp = desc?.sdp ?? offer.sdp ?? '';
    debugPrint('[WebRTC] SDP Offer siap (${sdp.length} chars)');
    return sdp;
  }

  /// Buat SDP Answer
  Future<String> createAnswer(String remoteSdp, {bool isVideo = false}) async {
    await _createPeerConnection(isVideo: isVideo);

    await _pc!.setRemoteDescription(RTCSessionDescription(remoteSdp, 'offer'));
    final answer = await _pc!
        .createAnswer({'offerToReceiveAudio': 1, 'offerToReceiveVideo': isVideo ? 1 : 0});
    await _pc!.setLocalDescription(answer);
    await _waitIce();

    final desc = await _pc!.getLocalDescription();
    final sdp = desc?.sdp ?? answer.sdp ?? '';
    debugPrint('[WebRTC] SDP Answer siap (${sdp.length} chars)');
    return sdp;
  }

  /// Set remote SDP answer setelah menerima 200 OK (sisi caller).
  Future<void> setRemoteAnswer(String remoteSdp) async {
    if (_pc == null) {
      debugPrint('[WebRTC] setRemoteAnswer dipanggil tapi PC belum ada');
      return;
    }
    await _pc!.setRemoteDescription(RTCSessionDescription(remoteSdp, 'answer'));
    debugPrint('[WebRTC] Remote SDP Answer di-set → audio seharusnya mengalir');
  }


  /// Tutup semua koneksi dan hentikan track lokal
  Future<void> hangup() async {
    await _closePeerConnection();
    debugPrint('[WebRTC] hangup selesai');
  }

  Future<void> _closePeerConnection() async {
    _localStream?.getTracks().forEach((t) => t.stop());
    await _localStream?.dispose();
    _localStream = null;
    
    // Putuskan stream dari renderer agar browser mematikan lampu indikator kamera
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;

    await _pc?.close();
    _pc = null;
  }

  void setMute(bool isMuted) {
    if (_localStream != null && _localStream!.getAudioTracks().isNotEmpty) {
      _localStream!.getAudioTracks()[0].enabled = !isMuted;
    }
  }

  void setVideoEnabled(bool isEnabled) {
    if (_localStream != null && _localStream!.getVideoTracks().isNotEmpty) {
      _localStream!.getVideoTracks()[0].enabled = isEnabled;
    }
  }

  Future<void> switchCamera() async {
    if (_localStream != null && _localStream!.getVideoTracks().isNotEmpty) {
      await Helper.switchCamera(_localStream!.getVideoTracks()[0]);
    }
  }

  void setSpeakerphoneOn(bool isSpeakerOn) {
    if (!kIsWeb) {
      Helper.setSpeakerphoneOn(isSpeakerOn);
    } else {
      debugPrint(
          '[WebRTC] setSpeakerphoneOn diabaikan (tidak didukung di Web)');
    }
  }

  /// Dispose renderer saat app ditutup
  Future<void> dispose() async {
    await _closePeerConnection();
    if (_rendererInitialized) {
      remoteRenderer.dispose();
      localRenderer.dispose();
      _rendererInitialized = false;
    }
  }
}
