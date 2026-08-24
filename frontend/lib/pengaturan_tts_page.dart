import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

class PengaturanTtsPage extends StatefulWidget {
  const PengaturanTtsPage({super.key});

  @override
  State<PengaturanTtsPage> createState() => _PengaturanTtsPageState();
}

class _PengaturanTtsPageState extends State<PengaturanTtsPage> {
  double _kecepatan = 1.0;
  double _nada = 1.0;
  final TextEditingController _previewController = TextEditingController(
      text: "Halo, ini adalah contoh suara Text-to-Speech.");

  @override
  void dispose() {
    _previewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Adjust based on design
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
                    _buildSectionTitle('PENGATURAN SUARA'),
                    const SizedBox(height: 12),
                    _buildPengaturanSuaraSection(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('KECEPATAN & NADA'),
                    const SizedBox(height: 12),
                    _buildKecepatanNadaSection(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('PRATINJAU'),
                    const SizedBox(height: 12),
                    _buildPratinjauSection(),
                    const SizedBox(height: 32),
                    _buildFooterText(),
                    const SizedBox(height: 24),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: SvgPicture.asset(
                  'assets/images/pengaturan_tts/container1.svg',
                  width: 24,
                  height: 24,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 16),
              Text(
                'Pengaturan TTS',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF131B2E),
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () {},
            icon: SvgPicture.asset(
              'assets/images/pengaturan_tts/button1.svg',
              width: 24,
              height: 24,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF6B7280),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildPengaturanSuaraSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildDropdownRow(
            label: 'Bahasa',
            value: 'Indonesian',
            iconPath: 'assets/images/pengaturan_tts/image0.svg',
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
          _buildDropdownRow(
            label: 'Suara',
            value: 'Lumina Male 1 (Budi)',
            iconPath: 'assets/images/pengaturan_tts/image1.svg',
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownRow({
    required String label,
    required String value,
    required String iconPath,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF374151),
            ),
          ),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SvgPicture.asset(
                  iconPath,
                  width: 24,
                  height: 24,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF9CA3AF), size: 20),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKecepatanNadaSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          _buildSliderRow(
            label: 'Kecepatan Bicara',
            valueText: '${_kecepatan.toStringAsFixed(1)}x',
            value: _kecepatan,
            min: 0.5,
            max: 2.0,
            minLabel: 'Lambat',
            maxLabel: 'Cepat',
            onChanged: (val) {
              setState(() {
                _kecepatan = val;
              });
            },
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
          _buildSliderRow(
            label: 'Nada Bicara',
            valueText: _nada == 1.0
                ? 'Normal'
                : _nada < 1.0
                    ? 'Rendah'
                    : 'Tinggi',
            value: _nada,
            min: 0.5,
            max: 1.5,
            minLabel: 'Rendah',
            maxLabel: 'Tinggi',
            onChanged: (val) {
              setState(() {
                _nada = val;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required String valueText,
    required double value,
    required double min,
    required double max,
    required String minLabel,
    required String maxLabel,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF374151),
                ),
              ),
              Text(
                valueText,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0065FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              activeTrackColor: const Color(0xFF0065FF),
              inactiveTrackColor: const Color(0xFFE5E7EB),
              thumbColor: Colors.white,
              overlayColor: const Color(0xFF0065FF).withValues(alpha: 0.1),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 4),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                minLabel,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
              Text(
                maxLabel,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPratinjauSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _previewController,
                  maxLines: 3,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF374151),
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (val) {
                    setState(() {});
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    '${_previewController.text.length}/200',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0065FF),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  'assets/images/pengaturan_tts/container31.svg',
                  width: 20,
                  height: 20,
                  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
                const SizedBox(width: 8),
                Text(
                  'Putar',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterText() {
    return Center(
      child: Text(
        'Pengaturan ini akan diterapkan secara global\npada seluruh asisten Lumina Essence.',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: const Color(0xFF6B7280),
          height: 1.5,
        ),
      ),
    );
  }
}
