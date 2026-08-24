import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'login_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  // Top spacing for aesthetics
                  const SizedBox(height: 20),

                  // Scattered Images Container
                  // Using FittedBox ensures the 397x500 box scales perfectly on any screen
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: 397,
                      height: 500,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _buildImage(
                            'assets/images/welcome_page/foto-40.png',
                            width: 85,
                            height: 84,
                            left: -25,
                            top: 173.6,
                            rotationDeg: -14.718,
                          ),
                          _buildImage(
                            'assets/images/welcome_page/image-10.png',
                            width: 100,
                            height: 100,
                            left: 315,
                            top: 399.39,
                            rotationDeg: -15.895,
                          ),
                          _buildImage(
                            'assets/images/welcome_page/foto-50.png',
                            width: 100,
                            height: 100,
                            left: 85.11,
                            top: 94.41,
                            rotationDeg: -12.889,
                          ),
                          _buildImage(
                            'assets/images/welcome_page/foto-70.png',
                            width: 75,
                            height: 75,
                            left: 76,
                            top: 410,
                          ),
                          _buildImage(
                            'assets/images/welcome_page/foto-60.png',
                            width: 85,
                            height: 85,
                            left: 331.37,
                            top: 248.73,
                            rotationDeg: 9.232,
                          ),
                          _buildImage(
                            'assets/images/welcome_page/foto-41.png',
                            width: 90,
                            height: 90,
                            left: 19.24,
                            top: 303,
                            rotationDeg: 37.761,
                          ),
                          _buildImage(
                            'assets/images/welcome_page/foto-30.png',
                            width: 120,
                            height: 120,
                            left: 249,
                            top: 91,
                          ),
                          _buildImage(
                            'assets/images/welcome_page/foto-20.png',
                            width: 130,
                            height: 130.42,
                            left: 111,
                            top: 253.98,
                            rotationDeg: -11.529,
                          ),
                          _buildImage(
                            'assets/images/welcome_page/foto0.png',
                            width: 81,
                            height: 81,
                            left: 218.74,
                            top: 415.8,
                            rotationDeg: 16.611,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(flex: 3),

                  // Text Section
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      children: [
                        Text(
                          'Selamat Datang di VetenCall!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'KonkhmerSleokchher',
                            color: Color(0xFF2B7FFF),
                            fontSize: 25,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Chat cepat, mudah, aman dengan siapa saja,\nkapan saja, dan dimana saja.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            color: Colors.black,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 4),

                  // Start Button
                  SizedBox(
                    width: 324, // Exact width from Figma
                    height: 56, // Exact height from Figma
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          PageRouteBuilder(
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    const LoginPage(),
                            transitionsBuilder: (context, animation,
                                secondaryAnimation, child) {
                              const begin = Offset(1.0, 0.0);
                              const end = Offset.zero;
                              const curve = Curves.easeInOutCubic;

                              var tween = Tween(begin: begin, end: end)
                                  .chain(CurveTween(curve: curve));

                              return SlideTransition(
                                position: animation.drive(tween),
                                child: child,
                              );
                            },
                            transitionDuration:
                                const Duration(milliseconds: 400),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2B7FFF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50.0),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Mulai',
                        style: TextStyle(
                          fontFamily: 'KonkhmerSleokchher',
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 48), // Spacing from bottom
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage(
    String assetPath, {
    required double width,
    required double height,
    required double left,
    required double top,
    double rotationDeg = 0,
    double innerScale = 1.0,
  }) {
    Widget imageWidget = ClipRRect(
      borderRadius: BorderRadius.circular(200), // Makes it circular
      child: Transform.scale(
        scale: innerScale,
        child: Image.asset(
          assetPath,
          width: width,
          height: height,
          fit: BoxFit.cover,
        ),
      ),
    );

    if (rotationDeg != 0) {
      imageWidget = Transform.rotate(
        angle: rotationDeg * math.pi / 180,
        alignment: Alignment.topLeft,
        child: imageWidget,
      );
    }

    return Positioned(
      left: left,
      top: top,
      child: imageWidget,
    );
  }
}
