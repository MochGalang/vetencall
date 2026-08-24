import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'kontak_terblokir_page.dart';

class PrivasiPage extends StatefulWidget {
  const PrivasiPage({super.key});

  @override
  State<PrivasiPage> createState() => _PrivasiPageState();
}

class _PrivasiPageState extends State<PrivasiPage> {
  bool _isLaporanDibacaEnabled = true;
  bool _isKunciAplikasiEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9FAFB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF004FCB)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Privasi',
          style: GoogleFonts.hankenGrotesk(
            color: const Color(0xFF004FCB),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF424656)),
            onPressed: () {},
          ),
        ],
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // SIAPA YANG DAPAT MELIHAT INFORMASI SAYA
            Text(
              'SIAPA YANG DAPAT MELIHAT INFORMASI SAYA',
              style: GoogleFonts.inter(
                color: const Color(0xFF004FCB),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF0065FF).withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  )
                ],
              ),
              child: Column(
                children: [
                  _buildListTile(
                    svgAsset: 'assets/images/privasi/container4.svg',
                    title: 'Terakhir Dilihat & Online',
                    trailingWidget: _buildTextTrailing('Semua orang'),
                  ),
                  const Divider(
                      height: 1, indent: 64, color: Color(0xFFF0F0F0)),
                  _buildListTile(
                    svgAsset: 'assets/images/privasi/container10.svg',
                    title: 'Foto Profil',
                    trailingWidget: _buildTextTrailing('Kontak saya'),
                  ),
                  const Divider(
                      height: 1, indent: 64, color: Color(0xFFF0F0F0)),
                  _buildListTile(
                    svgAsset: 'assets/images/privasi/container16.svg',
                    title: 'Info',
                    trailingWidget: _buildTextTrailing('Kontak saya'),
                  ),
                  const Divider(
                      height: 1, indent: 64, color: Color(0xFFF0F0F0)),
                  _buildListTile(
                    svgAsset: 'assets/images/privasi/container22.svg',
                    title: 'Status',
                    trailingWidget: _buildTextTrailing('Kontak saya'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // PESAN
            Text(
              'PESAN',
              style: GoogleFonts.inter(
                color: const Color(0xFF004FCB),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF0065FF).withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  )
                ],
              ),
              child: _buildListTileWithSubtitle(
                svgAsset: 'assets/images/privasi/margin0.svg',
                title: 'Laporan Dibaca',
                subtitle:
                    'Jika dimatikan, Anda tidak akan mengirim atau menerima laporan dibaca.',
                trailingWidget: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isLaporanDibacaEnabled = !_isLaporanDibacaEnabled;
                    });
                  },
                  child: _isLaporanDibacaEnabled
                      ? const Icon(Icons.check_circle,
                          color: Color(0xFF2563EB), size: 28)
                      : const Icon(Icons.circle_outlined,
                          color: Colors.grey, size: 28),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // GRUP & KONTAK
            Text(
              'GRUP & KONTAK',
              style: GoogleFonts.inter(
                color: const Color(0xFF004FCB),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF0065FF).withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  )
                ],
              ),
              child: Column(
                children: [
                  _buildListTile(
                    svgAsset: 'assets/images/privasi/container34.svg',
                    title: 'Grup',
                    iconSize: 20,
                    trailingWidget: _buildTextTrailing('Semua orang'),
                  ),
                  const Divider(
                      height: 1, indent: 64, color: Color(0xFFF0F0F0)),
                  _buildListTile(
                    svgAsset: 'assets/images/privasi/container40.svg',
                    title: 'Lokasi Terkini',
                    trailingWidget: _buildTextTrailing('Tidak ada'),
                  ),
                  const Divider(
                      height: 1, indent: 64, color: Color(0xFFF0F0F0)),
                  _buildListTile(
                    svgAsset: 'assets/images/privasi/container46.svg',
                    title: 'Kontak Diblokir',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const KontakTerblokirPage()),
                      );
                    },
                    trailingWidget: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF004FCB).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            '12',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF004FCB),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios_rounded,
                            color: Color(0xFFBCCBB9), size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // KEAMANAN
            Text(
              'KEAMANAN',
              style: GoogleFonts.inter(
                color: const Color(0xFF004FCB),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF0065FF).withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  )
                ],
              ),
              child: _buildListTile(
                svgAsset: 'assets/images/privasi/container52.svg',
                title: 'Kunci Aplikasi',
                trailingWidget: Switch(
                  value: _isKunciAplikasiEnabled,
                  onChanged: (val) =>
                      setState(() => _isKunciAplikasiEnabled = val),
                  activeThumbColor: Colors.white,
                  activeTrackColor: const Color(0xFF2563EB),
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Colors.grey.shade300,
                  trackOutlineColor:
                      WidgetStateProperty.all(Colors.transparent),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile({
    required String svgAsset,
    required String title,
    required Widget trailingWidget,
    double iconSize = 24,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap ?? () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Center(
                child: SvgPicture.asset(
                  svgAsset,
                  width: iconSize,
                  height: iconSize,
                  colorFilter: const ColorFilter.mode(
                      Color(0xFF004FCB), BlendMode.srcIn),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  color: const Color(0xFF131B2E),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            trailingWidget,
          ],
        ),
      ),
    );
  }

  Widget _buildListTileWithSubtitle({
    required String svgAsset,
    required String title,
    required String subtitle,
    required Widget trailingWidget,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SvgPicture.asset(
            svgAsset,
            width: 24,
            height: 24,
            colorFilter:
                const ColorFilter.mode(Color(0xFF004FCB), BlendMode.srcIn),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF131B2E),
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF424656),
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          trailingWidget,
        ],
      ),
    );
  }

  Widget _buildTextTrailing(String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: GoogleFonts.inter(
            color: const Color(0xFF424656),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.arrow_forward_ios_rounded,
            color: Color(0xFFBCCBB9), size: 16),
      ],
    );
  }
}
