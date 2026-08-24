import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PengaturanVoipPage extends StatefulWidget {
  const PengaturanVoipPage({super.key});

  @override
  State<PengaturanVoipPage> createState() => _PengaturanVoipPageState();
}

class _PengaturanVoipPageState extends State<PengaturanVoipPage> {
  bool _useWss = true;

  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _wsPortController =
      TextEditingController(text: '8089');
  final TextEditingController _apiPortController =
      TextEditingController(text: '8000');

  @override
  void dispose() {
    _ipController.dispose();
    _wsPortController.dispose();
    _apiPortController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF8FF).withValues(alpha: 0.8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF004FCB)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Pengaturan VoIP',
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
                bottom: BorderSide(color: Color(0x1A004FCB), width: 1),
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
            // Banner Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF96C0FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE6F0FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.dns_rounded,
                          color: Color(0xFF004FCB), size: 24),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Ubah Alamat IP Dan Port Asterisk\nAnda Disini',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // DETAIL KONEKSI
            Text(
              'DETAIL KONEKSI',
              style: GoogleFonts.inter(
                color: const Color(0xFF004FCB),
                fontSize: 12,
                fontWeight: FontWeight.w400,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),

            // Form Container
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF0065FF).withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInputField(
                    label: 'IP/Domain Server Asterisk',
                    controller: _ipController,
                    hintText: 'Misal: 192.168.1.100 atau pbx.vetencall.com',
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    label: 'Port WebSocket',
                    controller: _wsPortController,
                    hintText: '8089',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    label: 'Port API Backend',
                    controller: _apiPortController,
                    hintText: '8000',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gunakan Secure WebSocket (WSS)',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF131B2E),
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Aktifkan Enkripsi SSL/TLS\npada WebSocket',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF424656),
                                fontSize: 11,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _useWss,
                        onChanged: (val) => setState(() => _useWss = val),
                        activeThumbColor: Colors.white,
                        activeTrackColor: const Color(0xFF0065FF),
                        inactiveThumbColor: Colors.white,
                        inactiveTrackColor: Colors.grey.shade300,
                        trackOutlineColor:
                            WidgetStateProperty.all(Colors.transparent),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Save Button
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0065FF),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9999),
                ),
                elevation: 4,
                shadowColor: Colors.black.withValues(alpha: 0.3),
              ),
              child: Text(
                'Simpan Konfigurasi',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    String? hintText,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: const Color(0xFF424242),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFE6F0FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: GoogleFonts.inter(
              color: const Color(0xFF131B2E),
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: GoogleFonts.inter(
                color: const Color(0xFF424242).withValues(alpha: 0.5),
                fontSize: 14,
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}
