import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:volume_controller/volume_controller.dart';
import 'services/sip_engine.dart';
import 'services/api_service.dart';
import 'utils/string_utils.dart';

class CallScreen extends StatefulWidget {
  final String callerName;
  final String sipTarget; // SIP extension tujuan, misal "1001"
  final bool isIncoming;
  final bool isVideoCall;

  const CallScreen({
    super.key,
    required this.callerName,
    required this.sipTarget,
    this.isIncoming = false,
    this.isVideoCall = false,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen>
    with SingleTickerProviderStateMixin
    implements SipListener {
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isVideoEnabled = true;
  String _callStatus = 'Menghubungi...';
  int _callDuration = 0;
  Timer? _durationTimer;
  bool _hasPopped = false; // Guard untuk mencegah double Navigator.pop()
  String? _myCallId; // Simpan Call-ID saat screen dibuka, untuk guard dispose()

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  double _volume = 0.5;

  late String _displayCallerName;

  @override
  void initState() {
    super.initState();
    _displayCallerName = widget.callerName;
    _resolveCallerName();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    SipEngine().addListener(this);

    // Inisialisasi renderer audio WebRTC untuk playback suara remote
    SipEngine().webRtc.initRenderer();

    // Simpan Call-ID aktif saat screen ini dibuka
    // Digunakan di dispose() untuk menghindari mematikan panggilan lain
    _myCallId = SipEngine().activeCallId;

    if (widget.isIncoming) {
      setState(() => _callStatus = widget.isVideoCall ? 'Panggilan Video Masuk...' : 'Panggilan Masuk...');
    } else {
      _startOutgoingCall();
    }

    if (!kIsWeb) {
      try {
        VolumeController.instance.getVolume().then((volume) {
          if (mounted) setState(() => _volume = volume);
        });
        VolumeController.instance.addListener((volume) {
          if (mounted) setState(() => _volume = volume);
        });
      } catch (e) {
        debugPrint('Volume controller error: $e');
      }
    }
  }

  Future<void> _resolveCallerName() async {
    // Apabila nama caller sudah berupa huruf (bukan nomor ekstensi), tidak perlu resolve
    if (int.tryParse(widget.callerName) == null) return;
    
    try {
      final currentUserId = await ApiService.getUserId();
      if (currentUserId != null) {
        // Ambil data kontak untuk mencocokkan sip_username (ekstensi) dengan nama aslinya
        final response = await ApiService.get('/contacts?user_id=$currentUserId');
        if (response['success'] == true && response['data'] != null) {
          final List contacts = response['data'];
          final contact = contacts.firstWhere(
            (c) => c['sip_username'].toString() == widget.callerName,
            orElse: () => null,
          );
          if (contact != null && mounted) {
            setState(() {
              _displayCallerName = contact['username'];
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Gagal me-resolve nama pemanggil: $e');
    }
  }

  void _startOutgoingCall() {
    SipEngine().call(widget.sipTarget, isVideo: widget.isVideoCall);
    setState(() => _callStatus = 'Memanggil...');
  }

  void _startTimer() {
    _pulseController.stop();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) setState(() => _callDuration++);
    });
  }

  String get _formattedDuration {
    final m = (_callDuration ~/ 60).toString().padLeft(2, '0');
    final s = (_callDuration % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _endCall() {
    if (_hasPopped) return; // Jangan proses jika sudah di-pop
    setState(() => _callStatus = 'Panggilan Berakhir');
    SipEngine().hangup();
    _durationTimer?.cancel();
    _safePop();
  }

  /// Pop screen dengan delay dan guard agar hanya terjadi sekali
  void _safePop() {
    if (_hasPopped) return;
    _hasPopped = true;
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  // --- SipListener ---
  @override
  void onRegistrationState(SipRegState state) {}

  @override
  void onCallState(SipCallState state, {String? callId}) {
    if (!mounted) return;
    setState(() {
      switch (state) {
        case SipCallState.ringing:
          _callStatus = 'Berdering...';
          break;
        case SipCallState.accepted:
          _callStatus = 'Terhubung';
          // Update _myCallId karena saat incoming call, callId baru tersedia setelah answer
          _myCallId ??= SipEngine().activeCallId;
          if (_durationTimer == null) _startTimer();
          break;
        case SipCallState.ended:
          _durationTimer?.cancel();
          if (_callStatus != 'Panggilan Berakhir') {
            _callStatus = 'Panggilan Berakhir';
            _safePop();
          }
          break;
        case SipCallState.failed:
          _durationTimer?.cancel();
          if (_callStatus == 'Memanggil...') {
            // Delay 5 detik (bukan 60) agar user tidak menunggu terlalu lama
            Future.delayed(const Duration(seconds: 5), () {
              if (mounted && _callStatus == 'Memanggil...') {
                setState(() {
                  _callStatus = 'Tidak dapat dihubungi';
                });
                // Panggil hangup di luar setState
                SipEngine().webRtc.hangup();
              }
            });
          } else {
            _callStatus = 'Panggilan Gagal';
            _safePop();
          }
          break;
        default:
          break;
      }
    });
  }

  @override
  void dispose() {
    // Hanya hangup jika panggilan ini masih milik screen ini
    // (mencegah mematikan panggilan baru saat screen lama di-dispose)
    final isStillMyCall = _myCallId != null &&
        _myCallId == SipEngine().activeCallId;
    if (isStillMyCall &&
        (SipEngine().callState == SipCallState.calling ||
            SipEngine().callState == SipCallState.ringing ||
            SipEngine().callState == SipCallState.accepted)) {
      SipEngine().hangup();
    }
    SipEngine().removeListener(this);
    _pulseController.dispose();
    _durationTimer?.cancel();
    if (!kIsWeb) {
      try {
        VolumeController.instance.removeListener();
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF244C8A);
    const textColor = Colors.white;
    const subTextColor = Colors.white70;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        SipEngine().hangup();
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: SizedBox.expand(
          child: Container(
            decoration: (!widget.isVideoCall || (_callStatus != 'Terhubung' && !_callStatus.contains('Menghubungi') && !_callStatus.contains('Berdering') && !_callStatus.contains('Memanggil')))
                ? const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF4F6E9D), Color(0xFF244C8A)],
                    ),
                  )
                : null,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. BACKGROUND WIDGETS (For Video)
                if (widget.isVideoCall && (_callStatus == 'Terhubung' || _callStatus.contains('Menghubungi') || _callStatus.contains('Berdering') || _callStatus.contains('Memanggil')))
                  Positioned.fill(
                    child: RTCVideoView(
                      _callStatus == 'Terhubung' 
                          ? SipEngine().webRtc.remoteRenderer
                          : SipEngine().webRtc.localRenderer,
                      mirror: _callStatus != 'Terhubung',
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),

            // Overlay gelap sedikit untuk Video agar header terbaca
            if (widget.isVideoCall && (_callStatus == 'Terhubung' || _callStatus.contains('Menghubungi') || _callStatus.contains('Berdering') || _callStatus.contains('Memanggil')))
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 150,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

            // Local Preview (PiP)
            if (widget.isVideoCall && _callStatus == 'Terhubung')
              Positioned(
                top: 40,
                right: 16,
                child: Container(
                  width: 110,
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))
                    ]
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: RTCVideoView(
                    SipEngine().webRtc.localRenderer,
                    mirror: true,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),

            // 2. TOP HEADER (Name & Status)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _displayCallerName,
                        style: GoogleFonts.inter(
                          color: widget.isVideoCall ? Colors.white : textColor,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_callStatus == 'Terhubung' && widget.isVideoCall)
                            const Icon(Icons.lock_outline_rounded, size: 12, color: Colors.white70),
                          if (_callStatus == 'Terhubung' && widget.isVideoCall)
                            const SizedBox(width: 4),
                          Text(
                            _callDuration > 0
                                ? _formattedDuration
                                : (_callStatus == 'Terhubung' && widget.isVideoCall 
                                   ? 'Terenkripsi secara end-to-end' 
                                   : _callStatus),
                            style: GoogleFonts.inter(
                              color: widget.isVideoCall ? Colors.white70 : subTextColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 3. CENTER AVATAR (Hanya untuk Audio Call)
            if (!widget.isVideoCall || (_callStatus != 'Terhubung' && !_callStatus.contains('Menghubungi') && !_callStatus.contains('Berdering') && !_callStatus.contains('Memanggil')))
              Center(
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Lingkaran luar (efek ombak)
                        Container(
                          width: 220 * _pulseAnimation.value,
                          height: 220 * _pulseAnimation.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        Container(
                          width: 170 * _pulseAnimation.value,
                          height: 170 * _pulseAnimation.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        // Avatar Inti (Match CSS)
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.1),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 4),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            StringUtils.getInitials(_displayCallerName),
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

            // TOP RIGHT ACTION BUTTONS (Khusus Video Call)
            if (widget.isVideoCall && (_callStatus == 'Terhubung' || _callStatus.contains('Menghubungi') || _callStatus.contains('Berdering') || _callStatus.contains('Memanggil')))
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(top: _callStatus == 'Terhubung' ? 200 : 10, right: 20),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildFloatingSmallButton(Icons.person_add_alt_1_rounded, onTap: _showAddPersonModal),
                        const SizedBox(height: 16),
                        _buildFloatingSmallButton(Icons.flip_camera_ios_rounded, onTap: () {
                          SipEngine().webRtc.switchCamera();
                        }),
                        const SizedBox(height: 16),
                        _buildFloatingSmallButton(Icons.auto_fix_high_rounded),
                      ],
                    ),
                  ),
                ),
              ),

            // 4. BOTTOM ACTION PILL
            Align(
              alignment: Alignment.bottomCenter,
              child: (widget.isIncoming && _callStatus.contains('Masuk...'))
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 30, left: 24, right: 24),
                      child: _buildIncomingPill(),
                    )
                  : (_callStatus == 'Tidak dapat dihubungi')
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 30, left: 24, right: 24),
                          child: _buildUnreachablePill(),
                        )
                      : _buildActiveCallPill(),
            ),
          ],
        ),
        ),
        ),
      ),
    );
  }

  Widget _buildFloatingSmallButton(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildIncomingPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildPillButton(
            icon: Icons.call_end_rounded,
            color: const Color(0xFFEF4444),
            iconColor: Colors.white,
            onTap: _endCall,
          ),
          _buildPillButton(
            icon: Icons.message_rounded,
            color: const Color(0xFFF3F4F6),
            iconColor: const Color(0xFF4B5563),
            onTap: () {},
          ),
          _buildPillButton(
            icon: Icons.call_rounded,
            color: const Color(0xFF10B981),
            iconColor: Colors.white,
            onTap: () {
              SipEngine().answer(isVideo: widget.isVideoCall);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCallPill() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(45)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.only(left: 24, right: 24, top: 32, bottom: 32),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12), // True glassmorphism over the blue bg
            borderRadius: const BorderRadius.vertical(top: Radius.circular(45)),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // TOP ROW: Mute, Speaker, Video/Hold, End
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabeledButton(
                    icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    label: 'Mute',
                    isActive: _isMuted,
                    activeBgColor: Colors.white,
                    activeIconColor: const Color(0xFF0065FF), // Blue icon when active
                    inactiveBgColor: Colors.white.withValues(alpha: 0.15),
                    inactiveIconColor: Colors.white,
                    onTap: () {
                      setState(() => _isMuted = !_isMuted);
                      SipEngine().webRtc.setMute(_isMuted);
                    },
                  ),
                  _buildLabeledButton(
                    icon: _isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                    label: 'Speaker',
                    isActive: _isSpeakerOn,
                    activeBgColor: Colors.white,
                    activeIconColor: const Color(0xFF0065FF),
                    inactiveBgColor: Colors.white.withValues(alpha: 0.15),
                    inactiveIconColor: Colors.white,
                    onTap: () {
                      setState(() => _isSpeakerOn = !_isSpeakerOn);
                      SipEngine().webRtc.setSpeakerphoneOn(_isSpeakerOn);
                    },
                  ),
                  _buildLabeledButton(
                    icon: widget.isVideoCall 
                        ? (_isVideoEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded) 
                        : Icons.videocam_rounded,
                    label: 'Video',
                    isActive: widget.isVideoCall && !_isVideoEnabled, 
                    activeBgColor: Colors.white,
                    activeIconColor: const Color(0xFF0065FF),
                    inactiveBgColor: Colors.white.withValues(alpha: 0.15),
                    inactiveIconColor: Colors.white,
                    onTap: () {
                      if (!widget.isVideoCall) {
                        SipEngine().upgradeToVideo();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Meminta perubahan ke Video...')),
                        );
                        return;
                      }
                      setState(() => _isVideoEnabled = !_isVideoEnabled);
                      SipEngine().webRtc.setVideoEnabled(_isVideoEnabled);
                    },
                  ),
                  _buildLabeledButton(
                    icon: Icons.call_end_rounded,
                    label: 'End',
                    isActive: true,
                    activeBgColor: const Color(0xFFF44336), // Vibrant red
                    activeIconColor: Colors.white,
                    inactiveBgColor: const Color(0xFFF44336),
                    inactiveIconColor: Colors.white,
                    labelColor: const Color(0xFFF44336),
                    isEndButton: true,
                    onTap: _endCall,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // BOTTOM ROW: Add Person, Volume Slider
              Row(
                children: [
                  GestureDetector(
                    onTap: _showAddPersonModal,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.volume_up_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                                activeTrackColor: Colors.white,
                                inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                                thumbColor: Colors.white,
                              ),
                              child: Slider(
                                value: _volume,
                                onChanged: (val) {
                                  setState(() => _volume = val);
                                  if (!kIsWeb) {
                                    VolumeController.instance.setVolume(val);
                                  }
                                }, 
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabeledButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeBgColor,
    required Color activeIconColor,
    required Color inactiveBgColor,
    required Color inactiveIconColor,
    Color? labelColor,
    bool isEndButton = false,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: isEndButton ? 64 : 56,
            height: isEndButton ? 64 : 56,
            decoration: BoxDecoration(
              color: isActive ? activeBgColor : inactiveBgColor,
              shape: BoxShape.circle,
              boxShadow: isEndButton 
                  ? [BoxShadow(color: const Color(0xFFF44336).withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 6))]
                  : [],
            ),
            child: Icon(icon, color: isActive ? activeIconColor : inactiveIconColor, size: isEndButton ? 32 : 26),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            color: labelColor ?? Colors.white.withValues(alpha: 0.9),
            fontSize: 12,
            fontWeight: isEndButton ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPillButton({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
    );
  }

  Widget _buildUnreachablePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      color: Colors.transparent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildTextButton(
            icon: Icons.close_rounded,
            color: Colors.white,
            iconColor: Colors.black87,
            label: 'Batal',
            onTap: () => Navigator.of(context).pop(),
          ),
          _buildTextButton(
            icon: Icons.mic_rounded,
            color: const Color(0xFF2C3E50),
            iconColor: Colors.white,
            label: 'Pesan Suara',
            onTap: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (context) {
                  return Container(
                    height: 240,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F0FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.mic_rounded, size: 40, color: Color(0xFF0065FF)),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Tahan untuk merekam pesan suara',
                          style: GoogleFonts.inter(fontSize: 16, color: Colors.black87),
                        ),
                        const SizedBox(height: 24),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Batal', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          _buildTextButton(
            icon: Icons.call_rounded,
            color: const Color(0xFF10B981),
            iconColor: Colors.white,
            label: 'Telepon lagi',
            onTap: () {
              setState(() {
                 _callStatus = 'Memanggil...';
              });
              SipEngine().call(widget.sipTarget, isVideo: widget.isVideoCall);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTextButton({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            color: widget.isVideoCall ? Colors.white70 : const Color(0xFF4B5563),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _showAddPersonModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tambah Partisipan',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<Map<String, dynamic>>(
                  future: ApiService.getUserId().then((id) => ApiService.get('/contacts?user_id=$id')),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final contacts = snapshot.data?['data'] as List? ?? [];
                    if (contacts.isEmpty) {
                      return const Center(child: Text('Tidak ada kontak'));
                    }
                    return ListView.builder(
                      itemCount: contacts.length,
                      itemBuilder: (context, index) {
                        final c = contacts[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFE6F0FF),
                            child: Text(
                              StringUtils.getInitials(c['username']),
                              style: const TextStyle(color: Color(0xFF0065FF)),
                            )
                          ),
                          title: Text(c['username']),
                          subtitle: Text('Ext: ${c['sip_username']}'),
                          onTap: () async {
                            Navigator.pop(context);
                            final myCallId = SipEngine().activeCallId;
                            if (myCallId != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Mengundang ${c['username']}...'))
                              );
                              await ApiService.post('/calls/conference', {
                                'current_call_id': myCallId,
                                'target_sip_extension': c['sip_username'],
                              });
                            }
                          },
                        );
                      },
                    );
                  }
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}
