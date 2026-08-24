import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

class KunciAplikasiPage extends StatefulWidget {
  const KunciAplikasiPage({super.key});

  @override
  State<KunciAplikasiPage> createState() => _KunciAplikasiPageState();
}

class _KunciAplikasiPageState extends State<KunciAplikasiPage> {
  bool _isBiometricEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FE),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0065FF).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF0065FF).withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6F0FF),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0065FF).withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: SvgPicture.asset(
                              'assets/images/kunci_aplikasi/key-alt-fill0.svg',
                              width: 28,
                              height: 28,
                              colorFilter: const ColorFilter.mode(Color(0xFF0065FF), BlendMode.srcIn),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Lindungi VetenCall Anda Dengan\nKunci Biometrik Atau PIN',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF131B2E),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Options Card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF0065FF).withValues(alpha: 0.1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF004FCB).withValues(alpha: 0.05),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          _buildSwitchRow(
                            iconPath: 'assets/images/kunci_aplikasi/container1.svg',
                            title: 'Kunci Sidik Jari/Wajah',
                            subtitle: 'Gunakan Biometrik Untuk Membuka\nAplikasi',
                            value: _isBiometricEnabled,
                            onChanged: (val) {
                              setState(() {
                                _isBiometricEnabled = val;
                              });
                            },
                          ),
                          const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
                          _buildNavRow(
                            iconPath: 'assets/images/kunci_aplikasi/password0.svg',
                            title: 'Kunci PIN',
                            subtitle: 'Buat Kode PIN 6 Digit',
                            onTap: () {
                              // Action to set PIN
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF8FF).withValues(alpha: 0.9),
        border: const Border(
          bottom: BorderSide(
            color: Color(0x1A004FCB),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF004FCB).withValues(alpha: 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: SvgPicture.asset(
              'assets/images/kunci_aplikasi/container11.svg',
              width: 24,
              height: 24,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Kunci Aplikasi',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF004FCB),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchRow({
    required String iconPath,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF004FCB).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: SvgPicture.asset(
              iconPath,
              width: 20,
              height: 20,
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
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF131B2E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF424656),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF0065FF),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFDCE3EB),
          ),
        ],
      ),
    );
  }

  Widget _buildNavRow({
    required String iconPath,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF004FCB).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: SvgPicture.asset(
                iconPath,
                width: 20,
                height: 20,
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
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF131B2E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF424656),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFF9CA3AF), size: 20),
          ],
        ),
      ),
    );
  }
}
