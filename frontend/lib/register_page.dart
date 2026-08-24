import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import 'services/api_service.dart';
import 'profile_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _register() async {
    final username = _usernameController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || phone.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semua form wajib diisi')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // No need to strip 0 for SIP registration
    String formattedPhone = phone;

    final response = await ApiService.post('/register', {
      'username': username,
      'phone_number': formattedPhone,
      'password': password,
    });

    setState(() {
      _isLoading = false;
    });

    if (response['success'] == true) {
      if (!mounted) return;

      final data = response['data'];

      // Opsi A: Jika backend (teman) sudah mengembalikan data lengkap,
      // langsung simpan sesi sementara (untuk upload foto profil), lalu ke Isi Profil.
      if (data != null && data['id'] != null) {
        await ApiService.saveUserData(data);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Registrasi berhasil! Silakan lengkapi profil Anda.'),
              backgroundColor: Colors.green),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => ProfilePage(registeredName: username)),
          (route) => false,
        );
      } else {
        // Fallback: backend belum kirim data lengkap → arahkan ke login manual
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Registrasi berhasil! Silakan Login.'),
              backgroundColor: Colors.green),
        );
        Navigator.of(context).pop(); // Kembali ke LoginPage
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message'] ?? 'Registrasi gagal')),
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
                  'Buat Akun Baru',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.hankenGrotesk(
                    color: const Color(0xFF131B2E),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 40),

                // Username Form Label
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(
                    'Nama Lengkap',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF424656),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.28,
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                // Username Input
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
                          controller: _usernameController,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF131B2E),
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Masukkan nama Anda',
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
                            hintText: 'Buat password baru',
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

                // Daftar Button
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
                    onPressed: _isLoading ? null : _register,
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
                            'Daftar',
                            style: GoogleFonts.hankenGrotesk(
                              color: const Color(0xFFF7F6FF),
                              fontSize: 20,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 48),

                // Footer (Sudah punya akun? masuk)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Sudah punya akun? ',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF424656),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        // Go back to login
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        'masuk',
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
