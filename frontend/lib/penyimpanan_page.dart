import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

class PenyimpananPage extends StatefulWidget {
  const PenyimpananPage({super.key});

  @override
  State<PenyimpananPage> createState() => _PenyimpananPageState();
}

class _PenyimpananPageState extends State<PenyimpananPage> {
  // --- State untuk toggle dan pilihan ---
  bool _kurangiDataPanggilan = false;

  // Pilihan unduh otomatis
  String _unduhSeluler = 'Foto';
  String _unduhWifi = 'Semua media';
  String _unduhRoaming = 'Tidak ada media';

  // Pilihan kualitas unggahan
  String _kualitasFoto = 'Otomatis (disarankan)';

  final List<String> _opsiUnduh = [
    'Tidak ada media',
    'Foto',
    'Video',
    'Dokumen',
    'Semua media',
  ];

  final List<String> _opsiKualitas = [
    'Standar',
    'HD',
    'Otomatis (disarankan)',
  ];

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
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- SECTION 1: PENGGUNAAN PENYIMPANAN ---
                    _buildSectionTitle('PENGGUNAAN PENYIMPANAN'),
                    const SizedBox(height: 12),
                    _buildCard(children: [
                      _buildNavRow(
                        iconPath: 'assets/images/penyimpanan/container1.svg',
                        title: 'Kelola Penyimpanan',
                        subtitle: '1.2 GB digunakan',
                        onTap: () {},
                        showArrow: true,
                      ),
                      _buildDivider(),
                      _buildNavRow(
                        iconPath: 'assets/images/penyimpanan/container7.svg',
                        title: 'Penggunaan Jaringan',
                        subtitle: '450 MB digunakan',
                        onTap: () {},
                        showArrow: true,
                      ),
                    ]),

                    const SizedBox(height: 24),

                    // --- SECTION 2: UNDUH OTOMATIS MEDIA ---
                    _buildSectionTitle('UNDUH OTOMATIS MEDIA'),
                    const SizedBox(height: 12),
                    _buildCard(children: [
                      _buildPickerRow(
                        label: 'Saat menggunakan data seluler',
                        value: _unduhSeluler,
                        options: _opsiUnduh,
                        onChanged: (val) => setState(() => _unduhSeluler = val),
                        isBlue: true,
                      ),
                      _buildDivider(),
                      _buildPickerRow(
                        label: 'Saat terhubung ke Wi-Fi',
                        value: _unduhWifi,
                        options: _opsiUnduh,
                        onChanged: (val) => setState(() => _unduhWifi = val),
                        isBlue: true,
                      ),
                      _buildDivider(),
                      _buildPickerRow(
                        label: 'Saat roaming',
                        value: _unduhRoaming,
                        options: _opsiUnduh,
                        onChanged: (val) =>
                            setState(() => _unduhRoaming = val),
                        isBlue: false,
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'Pesan suara selalu diunduh secara otomatis untuk pengalaman terbaik.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: const Color(0xFF424656).withValues(alpha: 0.7),
                          height: 1.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // --- SECTION 3: KUALITAS UNDUHAN MEDIA ---
                    _buildSectionTitle('KUALITAS UNDUHAN MEDIA'),
                    const SizedBox(height: 12),
                    _buildCard(children: [
                      _buildPickerRow(
                        label: 'Kualitas unggahan foto',
                        value: _kualitasFoto,
                        options: _opsiKualitas,
                        onChanged: (val) =>
                            setState(() => _kualitasFoto = val),
                        isBlue: true,
                      ),
                    ]),

                    const SizedBox(height: 24),

                    // --- SECTION 4: PENGATURAN PANGGILAN ---
                    _buildSectionTitle('PENGATURAN PANGGILAN'),
                    const SizedBox(height: 12),
                    _buildCard(children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Kurangi penggunaan data panggilan',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF131B2E),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Menghemat data saat melakukan panggilan',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xFF424656),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Switch(
                              value: _kurangiDataPanggilan,
                              onChanged: (val) {
                                setState(() => _kurangiDataPanggilan = val);
                              },
                              activeThumbColor: const Color(0xFF0065FF),
                              inactiveThumbColor: Colors.white,
                              inactiveTrackColor: const Color(0xFFDCE3EB),
                            ),
                          ],
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==============================
  // HELPER WIDGETS
  // ==============================

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
              'assets/images/penyimpanan/container24.svg',
              width: 24,
              height: 24,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Penyimpanan & Data',
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF424656),
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
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
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: const Color(0xFF004FCB).withValues(alpha: 0.05),
    );
  }

  Widget _buildNavRow({
    required String iconPath,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showArrow = false,
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
                      fontSize: 13,
                      color: const Color(0xFF424656),
                    ),
                  ),
                ],
              ),
            ),
            if (showArrow)
              const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFF9CA3AF), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerRow({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
    required bool isBlue,
  }) {
    return InkWell(
      onTap: () => _showPickerDialog(label, value, options, onChanged),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF131B2E),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: isBlue
                    ? const Color(0xFF004FCB)
                    : const Color(0xFF424656),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF9CA3AF), size: 18),
          ],
        ),
      ),
    );
  }

  void _showPickerDialog(
    String title,
    String currentValue,
    List<String> options,
    ValueChanged<String> onChanged,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF131B2E),
                  ),
                ),
              ),
              const Divider(height: 1),
              ...options.map((opt) {
                final isSelected = opt == currentValue;
                return ListTile(
                  title: Text(
                    opt,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? const Color(0xFF0065FF)
                          : const Color(0xFF131B2E),
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_rounded,
                          color: Color(0xFF0065FF))
                      : null,
                  onTap: () {
                    onChanged(opt);
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
