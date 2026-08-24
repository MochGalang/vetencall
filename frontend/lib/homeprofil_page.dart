import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';

import 'keamanan_akun_page.dart';
import 'privasi_page.dart';
import 'notifikasi_page.dart';
import 'pengaturan_voip_page.dart';
import 'pengaturan_tts_page.dart';
import 'penyimpanan_page.dart';
import 'kunci_aplikasi_page.dart';
import 'login_page.dart';
import 'profile_page.dart';
import 'services/api_service.dart';
import 'services/profile_service.dart';
import 'widgets/veten_bottom_nav.dart';
import 'services/sip_engine.dart';
import 'utils/string_utils.dart';

class HomeProfilPage extends StatefulWidget {
  const HomeProfilPage({super.key});

  @override
  State<HomeProfilPage> createState() => _HomeProfilPageState();
}

class _HomeProfilPageState extends State<HomeProfilPage> {

  String _userName = 'Pengguna';
  String _sipExtension = '---';
  String _initials = '?';
  String? _profilePicUrl;
  Uint8List? _localImageBytes;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('username') ?? 'Pengguna Baru';
    final sip = prefs.getString('sip_username') ?? '---';
    final picUrl = prefs.getString('profile_picture');

    setState(() {
      _userName = name;
      _sipExtension = sip;
      _initials = StringUtils.getInitials(name);
      _profilePicUrl = picUrl;
    });
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
      // Simpan ke SharedPreferences agar konsisten dengan sesi berikutnya
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_picture', newUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FE),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // Watermark Text
            Positioned(
              left: 24,
              top: 90,
              child: Text(
                'VetenCall',
                style: GoogleFonts.inter(
                  color: Colors.black.withValues(alpha: 0.05),
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.02,
                ),
              ),
            ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopBar(),
                const SizedBox(height: 16),
                _buildUserProfile(),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView(
                    padding:
                        const EdgeInsets.only(left: 24, right: 24, bottom: 120),
                    children: [
                      _buildSettingsSection([
                        _buildSettingsRow(
                          iconPath: 'assets/images/homeprofil_page/chield0.svg',
                          title: 'Keamanan akun',
                          subtitle:
                              'Perbarui kata sandi, verifikasi dua langkah, dan\nperangkat yang saat ini tertaut pada akun Anda',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const KeamananAkunPage()),
                            );
                          },
                        ),
                        const Divider(
                            height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
                        _buildSettingsRow(
                          iconPath:
                              'assets/images/homeprofil_page/group-80.svg',
                          title: 'Privasi',
                          subtitle:
                              'Atur siapa yang dapat melihat info Anda, laporan dibaca,\ndan manajemen kontak grup',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const PrivasiPage()),
                            );
                          },
                        ),
                        const Divider(
                            height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
                        _buildSettingsRow(
                          iconPath:
                              'assets/images/homeprofil_page/bell-pin0.svg',
                          title: 'Notifikasi',
                          subtitle:
                              'Atur nada dering pesan, getaran, dan preferensi\npemberitahuan panggilan masuk',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const NotifikasiPage()),
                            );
                          },
                        ),
                      ]),
                      const SizedBox(height: 20),
                      _buildSettingsSection([
                        _buildSettingsRow(
                          iconPath:
                              'assets/images/homeprofil_page/server-fill0.svg',
                          title: 'Pengaturan Server VoIP',
                          subtitle:
                              'Konfigurasi alamat server, port, dan kredensial\nSIP/VoIP Anda untuk panggilan',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const PengaturanVoipPage()),
                            );
                          },
                        ),
                        const Divider(
                            height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
                        _buildSettingsRow(
                          iconPath: 'assets/images/homeprofil_page/chat0.svg',
                          title: 'Pengaturan TTS (Text To Speech)',
                          subtitle:
                              'Atur jenis suara, bahasa, dan kecepatan baca untuk\nfitur Text To Speech pada pesan teks',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const PengaturanTtsPage()),
                            );
                          },
                        ),
                        const Divider(
                            height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
                        _buildSettingsRow(
                          iconPath:
                              'assets/images/homeprofil_page/folder-file-010.svg',
                          title: 'Penyimpanan',
                          subtitle:
                              'Kelola penggunaan data jaringan, unduhan otomatis,\ndan bersihkan cache memori aplikasi',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const PenyimpananPage()),
                            );
                          },
                        ),
                      ]),
                      const SizedBox(height: 20),
                      _buildSettingsSection([
                        _buildSettingsRow(
                          iconPath:
                              'assets/images/homeprofil_page/key-alt-fill0.svg',
                          title: 'Kunci Aplikasi',
                          subtitle:
                              'Amankan aplikasi Anda dengan PIN tambahan, pola,\natau pengenalan biometrik sidik jari',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const KunciAplikasiPage()),
                            );
                          },
                        ),
                        const Divider(
                            height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
                        _buildSettingsRow(
                          iconPath:
                              'assets/images/homeprofil_page/user-add-alt-fill0.svg',
                          title: 'Permintaan Pertemanan',
                          subtitle:
                              'Lihat daftar dan kelola permintaan pertemanan yang\nmasuk atau telah Anda kirim',
                        ),
                        const Divider(
                            height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
                        _buildSettingsRow(
                          iconPath: 'assets/images/homeprofil_page/cancel0.svg',
                          title: 'Blokir',
                          subtitle:
                              'Daftar kontak yang telah diblokir dan pengaturan\npembatasan interaksi pesan',
                        ),
                      ]),
                      const SizedBox(height: 20),
                      // TOMBOL LOGOUT
                      _buildSettingsSection([
                        _buildSettingsRow(
                          iconPath:
                              'assets/images/homeprofil_page/cancel0.svg', // Pakai icon cancel sementara
                          title: 'Keluar (Log Out)',
                          subtitle:
                              'Akhiri sesi Anda dan kembali ke halaman masuk utama',
                          onTap: () {
                            _showLogoutDialog();
                          },
                        ),
                      ]),
                      const SizedBox(
                          height: 100), // Extra padding for scrolling
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: const VetenBottomNav(currentIndex: 3),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Profile',
            style: GoogleFonts.inter(
              color: const Color(0xFF0065FF),
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: Color(0xFF0065FF)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfilePage(isEditMode: true),
                    ),
                  ).then((_) {
                    _loadUserProfile();
                  });
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon:
                    const Icon(Icons.search_rounded, color: Color(0xFF0065FF)),
                onPressed: () {},
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.more_vert_rounded,
                    color: Color(0xFF0065FF)),
                onPressed: () {},
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          )
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Konfirmasi Keluar',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          content: Text(
            'Apakah Anda yakin ingin keluar dari VetenCall?',
            style: GoogleFonts.inter(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Batal',
                style: GoogleFonts.inter(color: Colors.grey.shade600),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                // Putus koneksi SIP dan bersihkan instansinya
                SipEngine().disconnect();

                // Hapus semua sesi user (termasuk FlutterSecureStorage)
                await ApiService.logout();

                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (Route<dynamic> route) => false,
                  );
                }
              },
              child: Text(
                'Keluar',
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUserProfile() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          GestureDetector(
            onTap: _isUploading ? null : _pickAndUploadImage,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFE6F0FF),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
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
                                      ? _profilePicUrl!.replaceFirst(
                                          RegExp(r'https?://[^/]+'),
                                          'https://${ApiService.serverIp}',
                                        )
                                      : 'https://${ApiService.serverIp}$_profilePicUrl'
                              ),
                              fit: BoxFit.cover,
                            )
                          : null,
                  ),
                  alignment: Alignment.center,
                  child: (_localImageBytes == null && (_profilePicUrl == null || _profilePicUrl!.isEmpty))
                      ? Text(
                          _initials,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF0065FF),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                if (_isUploading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF000000),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hai, saya menggunakan VetenCall',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF717785),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ext. $_sipExtension',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF0065FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF0065FF).withValues(alpha: 0.08), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSettingsRow({
    required String iconPath,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFEDF3FD),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: SvgPicture.asset(
                iconPath,
                width: 22,
                height: 22,
                colorFilter:
                    const ColorFilter.mode(Color(0xFF0065FF), BlendMode.srcIn),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF000000),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF737373),
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }
}
