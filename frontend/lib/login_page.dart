import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import 'register_page.dart';
import 'services/api_service.dart';
import 'homechat_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Nomor HP dan Password tidak boleh kosong')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // No need to strip 0 for SIP login
    String formattedPhone = phone;
    // We assume the backend expects the raw number or with +62?
    // Let's just use the entered phone directly as sip_username for now.

    final response = await ApiService.post('/login', {
      'sip_username': formattedPhone,
      'password': password,
    });

    setState(() {
      _isLoading = false;
    });

    if (response['success'] == true) {
      await ApiService.saveUserData(response['data']);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeChatPage()),
        (route) => false,
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message'] ?? 'Login gagal')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header (Back Button)
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: IconButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: SvgPicture.asset(
                        'assets/images/login_page/container6.svg',
                        width: 24,
                        height: 24,
                      ),
                      splashRadius: 24,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Logo VetenCall (logo.png)
                Center(
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 137,
                    height: 137,
                  ),
                ),

                const SizedBox(height: 32),

                // Title
                Text(
                  'Masuk ke akun Anda',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.hankenGrotesk(
                    color: const Color(0xFF131B2E),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 40),

                // Phone Number Form Label
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(
                    'SIP Username / Extension',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF424656),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.28,
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                // Input Row
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F3FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      // TextField
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.text,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF131B2E),
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            hintText: 'Misal: 1001 atau UserA',
                            hintStyle: GoogleFonts.inter(
                              color: const Color(0xFF424656)
                                  .withValues(alpha: 0.5),
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Password Label
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(
                    'Password',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF424656),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.28,
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                // Password Input
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F3FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF131B2E),
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Masukkan password',
                            hintStyle: GoogleFonts.inter(
                              color: const Color(0xFF424656)
                                  .withValues(alpha: 0.5),
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: const Color(0xFF424656),
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Masuk Button
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0065FF).withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0065FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'Masuk',
                            style: GoogleFonts.hankenGrotesk(
                              color: const Color(0xFFF7F6FF),
                              fontSize: 20,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 60),

                // Footer (Tidak punya akun? mendaftar)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Tidak punya akun? ',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF424656),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          PageRouteBuilder(
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    const RegisterPage(),
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
                      child: Text(
                        'mendaftar',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF004FCB),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.28,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
