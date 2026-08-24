import 'package:flutter/material.dart';
import 'dart:async';
import 'welcome_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Navigate to WelcomePage after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const WelcomePage(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2B7FFF), // --foundation-blue-b200
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo App
            Image.asset(
              'assets/images/logo.png',
              width: MediaQuery.of(context).size.width * 0.33, // 33.44%
              color: Colors.white,
            ),
            const SizedBox(height: 32), // Spacing between logo and text
            // Text "VetenCall"
            const Text(
              'VetenCall',
              style: TextStyle(
                fontFamily: 'KonkhmerSleokchher',
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
