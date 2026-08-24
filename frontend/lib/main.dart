import 'package:flutter/material.dart';
import 'splash_screen.dart';
import 'services/sip_engine.dart';
import 'call_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp>
    with WidgetsBindingObserver
    implements SipListener {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SipEngine().addListener(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SipEngine().removeListener(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Cek apakah SIP terputus saat di background. Jika ya, reconnect.
      if (SipEngine().regState != SipRegState.registered) {
        debugPrint('[Main] App resumed, mere-koneksi SIP...');
        SipEngine().connect();
      }
    } else if (state == AppLifecycleState.detached) {
      SipEngine().disconnect();
    }
  }

  @override
  void onRegistrationState(SipRegState state) {}

  String? _lastRingingCallId;
  bool _isCallScreenOpen = false; // Guard agar tidak membuka lebih dari 1 CallScreen

  @override
  void onCallState(SipCallState state, {String? callId}) {
    if (state == SipCallState.ringing && SipEngine().isIncomingCall) {
      if (_lastRingingCallId == callId && callId != null) return;
      _lastRingingCallId = callId;

      // Guard: jangan buka CallScreen baru jika sudah ada yang terbuka
      if (_isCallScreenOpen) {
        debugPrint('[Main] CallScreen sudah terbuka, abaikan incoming call push.');
        return;
      }

      final caller = SipEngine().incomingCaller ?? 'Unknown';

      // Tunggu build selesai sebelum navigasi (mencegah error if navigating during build)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _isCallScreenOpen = true;
        final isVideoCall = SipEngine().isIncomingVideoCall;
        debugPrint('[Main] Incoming call — isVideoCall: $isVideoCall, caller: $caller');
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => CallScreen(
              callerName: caller,
              sipTarget: caller,
              isIncoming: true,
              isVideoCall: isVideoCall,
            ),
          ),
        ).then((_) {
          _isCallScreenOpen = false; // Reset saat CallScreen ditutup
        });
      });
    } else if (state == SipCallState.ended || state == SipCallState.failed) {
      _lastRingingCallId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'VetenCall',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
