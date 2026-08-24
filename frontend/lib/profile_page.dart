import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:typed_data';
import 'services/api_service.dart';
import 'services/profile_service.dart';
import 'utils/string_utils.dart';
import 'login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  final String? registeredName;
  final bool isEditMode;
  const ProfilePage({super.key, this.registeredName, this.isEditMode = false});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  // Email controller disiapkan untuk fitur mendatang
  
  bool _isUploading = false;
  String? _profilePicUrl;
  Uint8List? _localImageBytes;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.registeredName ?? '';
    _loadExistingProfileData();
  }
  
  Future<void> _loadExistingProfileData() async {
    final userData = await ApiService.getUserData();
    if (userData['profile_picture'] != null && userData['profile_picture']!.isNotEmpty) {
      if (mounted) {
        setState(() {
          _profilePicUrl = userData['profile_picture'];
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final userId = await ApiService.getUserId();
    if (!mounted) return;
    final newUrl = await ProfileService.pickAndUpload(
      context: context,
      userId: userId,
      onLocalPreview: (bytes) {
        if (mounted) setState(() => _localImageBytes = bytes);
      },
      onLoadingChange: (loading) {
        if (mounted) setState(() => _isUploading = loading);
      },
    );
    if (newUrl != null && mounted) {
      setState(() => _profilePicUrl = newUrl);
    }
  }

  Widget _buildTextField({
    String? labelText,
    required String hintText,
    required TextEditingController controller,
    Widget? trailingIcon,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelText != null) ...[
          Text(
            labelText,
            style: GoogleFonts.inter(
              color: const Color(0xFF131B2E),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF0065FF).withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    readOnly: readOnly,
                    onTap: onTap,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF131B2E),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: hintText,
                      hintStyle: GoogleFonts.inter(
                        color: const Color(0xFFBCCBB9).withValues(alpha: 0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
                if (trailingIcon != null) ...[
                  const SizedBox(width: 8),
                  trailingIcon,
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () async {
                if (widget.isEditMode) {
                  final prefs = await SharedPreferences.getInstance();
                  final userId = prefs.getString('user_id');
                  if (userId != null) {
                    final response = await ApiService.updateProfile(userId, _nameController.text);
                    if (response['success'] == true) {
                      await prefs.setString('username', _nameController.text);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Profil berhasil diperbarui'), backgroundColor: Colors.green),
                        );
                        Navigator.of(context).pop();
                      }
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(response['message'] ?? 'Gagal memperbarui profil'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  } else {
                    await prefs.setString('username', _nameController.text); // Fallback

                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  }
                } else {
                  Navigator.of(context).pushAndRemoveUntil(
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          const LoginPage(),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
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
                      transitionDuration: const Duration(milliseconds: 400),
                    ),
                    (route) => false,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0065FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9999),
                ),
                elevation: 0,
              ),
              child: Text(
                widget.isEditMode ? 'Simpan' : 'Lanjutkan',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: SvgPicture.asset(
                        'assets/images/profile_page/container0.svg',
                        width: 24,
                        height: 24,
                      ),
                      splashRadius: 24,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 24, minHeight: 24),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      widget.isEditMode ? 'Edit Profil' : 'Isi Profil Anda',
                      style: GoogleFonts.hankenGrotesk(
                        color: const Color(0xFF131B2E),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // Profile Image Section
                    Center(
                      child: GestureDetector(
                        onTap: _isUploading ? null : _pickAndUploadImage,
                        child: SizedBox(
                          width: 136,
                          height: 136,
                          child: Stack(
                            children: [
                              Align(
                                alignment: Alignment.topLeft,
                                child: Container(
                                  width: 128,
                                  height: 128,
                                  decoration: BoxDecoration(
                                    color: (_localImageBytes == null && (_profilePicUrl == null || _profilePicUrl!.isEmpty)) 
                                        ? const Color(0xFFE0F2FE) 
                                        : Colors.white,
                                    shape: BoxShape.circle,
                                    border:
                                        Border.all(color: Colors.white, width: 4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF0065FF)
                                            .withValues(alpha: 0.05),
                                        blurRadius: 20,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                    image: _localImageBytes != null 
                                      ? DecorationImage(
                                          image: MemoryImage(_localImageBytes!),
                                          fit: BoxFit.cover,
                                        )
                                      : _profilePicUrl != null && _profilePicUrl!.isNotEmpty
                                        ? DecorationImage(
                                            image: NetworkImage(
                                                _profilePicUrl!.startsWith('http') 
                                                    ? _profilePicUrl! 
                                                    : '${ApiService.baseUrl.replaceAll('/api', '')}$_profilePicUrl'
                                            ),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: _isUploading 
                                      ? const Center(child: CircularProgressIndicator())
                                      : (_localImageBytes == null && (_profilePicUrl == null || _profilePicUrl!.isEmpty))
                                          ? Center(
                                              child: Text(
                                                StringUtils.getInitials(_nameController.text),
                                                style: GoogleFonts.inter(
                                                  color: const Color(0xFF0065FF),
                                                  fontSize: 44,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            )
                                          : null,
                                ),
                              ),
                              Positioned(
                                right: 4,
                                bottom: 4,
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0065FF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: SvgPicture.asset(
                                      'assets/images/profile_page/container2.svg',
                                      width: 16,
                                      height: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                    // Nama Lengkap
                    _buildTextField(
                      labelText: 'Nama Lengkap',
                      hintText: 'Nama Anda',
                      controller: _nameController,
                      readOnly: !widget.isEditMode,
                    ),
                    // Catatan: Field Email disembunyikan sementara
                    // karena kolom tersebut belum ada di tabel database backend.
                    // Akan diaktifkan setelah schema DB di-update.
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
