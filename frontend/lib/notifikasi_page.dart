import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NotifikasiPage extends StatefulWidget {
  const NotifikasiPage({super.key});

  @override
  State<NotifikasiPage> createState() => _NotifikasiPageState();
}

class _NotifikasiPageState extends State<NotifikasiPage> {
  bool _isNotifikasiPesan = true;
  bool _isNotifikasiPrioritasTinggi = true;
  bool _isNotifikasiGrup = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), // matches other pages
      appBar: AppBar(
        backgroundColor:
            const Color(0xFFFAF8FF).withValues(alpha: 0.8), // matches HTML
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF004FCB)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Notifikasi',
          style: GoogleFonts.hankenGrotesk(
            color: const Color(0xFF004FCB),
            fontSize: 24,
            fontWeight: FontWeight.w400,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF004FCB)),
            onPressed: () {},
          ),
        ],
        centerTitle: false,
        flexibleSpace: ClipRect(
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                    color: Color(0x1A004FCB), width: 1), // 10% opacity
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // NOTIFIKASI PESAN
            Text(
              'NOTIFIKASI PESAN',
              style: GoogleFonts.inter(
                color: const Color(0xFF004FCB),
                fontSize: 12,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),
            _buildContainer(
              child: Column(
                children: [
                  _buildToggleRow(
                    title: 'Notifikasi Pesan',
                    value: _isNotifikasiPesan,
                    onChanged: (val) =>
                        setState(() => _isNotifikasiPesan = val),
                    showBorder: true,
                  ),
                  _buildValueRow(
                    title: 'Nada Notifikasi',
                    value: 'Default',
                    valueColor: const Color(0xFF004FCB),
                    showBorder: true,
                  ),
                  _buildValueRow(
                    title: 'Getar',
                    value: 'Default',
                    valueColor: const Color(0xFF004FCB),
                    showBorder: true,
                  ),
                  _buildToggleRowWithSubtitle(
                    title: 'Notifikasi Prioritas Tinggi',
                    subtitle:
                        'Tampilkan pratinjau notifikasi di bagian\natas layar',
                    value: _isNotifikasiPrioritasTinggi,
                    onChanged: (val) =>
                        setState(() => _isNotifikasiPrioritasTinggi = val),
                    showBorder: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // NOTIFIKASI GRUP
            Text(
              'NOTIFIKASI GRUP',
              style: GoogleFonts.inter(
                color: const Color(0xFF004FCB),
                fontSize: 12,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),
            _buildContainer(
              child: Column(
                children: [
                  _buildToggleRow(
                    title: 'Notifikasi Grup',
                    value: _isNotifikasiGrup,
                    onChanged: (val) => setState(() => _isNotifikasiGrup = val),
                    showBorder: true,
                  ),
                  _buildValueRow(
                    title: 'Nada Notifikasi',
                    value: 'Chime',
                    valueColor: const Color(0xFF004FCB),
                    showBorder: true,
                  ),
                  _buildValueRow(
                    title: 'Getar',
                    value: 'Mati',
                    valueColor: const Color(0xFF424656),
                    showBorder: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // PANGGILAN
            Text(
              'PANGGILAN',
              style: GoogleFonts.inter(
                color: const Color(0xFF004FCB),
                fontSize: 12,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),
            _buildContainer(
              child: Column(
                children: [
                  _buildValueRow(
                    title: 'Nada Dering',
                    value: 'Lumina Ring',
                    valueColor: const Color(0xFF004FCB),
                    showBorder: true,
                  ),
                  _buildValueRow(
                    title: 'Getar',
                    value: 'Default',
                    valueColor: const Color(0xFF004FCB),
                    showBorder: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFF004FCB).withValues(alpha: 0.05)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0065FF), // 5% opacity
            blurRadius: 20,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: child,
    );
  }

  Widget _buildToggleRow({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool showBorder,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: showBorder
            ? const Border(
                bottom: BorderSide(color: Color(0x4DDAE2FD))) // 30% opacity
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: const Color(0xFF131B2E),
              fontSize: 14,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.28,
            ),
          ),
          SizedBox(
            width: 48,
            height: 24,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: const Color(0xFF0065FF),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: Colors.grey.shade300,
              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRowWithSubtitle({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool showBorder,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: showBorder
            ? const Border(
                bottom: BorderSide(color: Color(0x4DDAE2FD))) // 30% opacity
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF131B2E),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.28,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF424656),
                    fontSize: 14,
                    height: 1.25,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 48,
            height: 24,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: const Color(0xFF0065FF),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: Colors.grey.shade300,
              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValueRow({
    required String title,
    required String value,
    required Color valueColor,
    required bool showBorder,
  }) {
    return InkWell(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: showBorder
              ? const Border(
                  bottom: BorderSide(color: Color(0x4DDAE2FD))) // 30% opacity
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                color: const Color(0xFF131B2E),
                fontSize: 14,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.28,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.inter(
                color: valueColor,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
