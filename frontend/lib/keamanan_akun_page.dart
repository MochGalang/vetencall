import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class KeamananAkunPage extends StatefulWidget {
  const KeamananAkunPage({super.key});

  @override
  State<KeamananAkunPage> createState() => _KeamananAkunPageState();
}

class _KeamananAkunPageState extends State<KeamananAkunPage> {
  bool _is2FAEnabled = true;
  bool _isSecurityNotificationEnabled = false;

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon + Text 'Hapus Akun'
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F0),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFD6D6)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.delete_outline_rounded,
                          color: Color(0xFFBA1A1A)),
                      const SizedBox(height: 8),
                      Text(
                        'Hapus Akun',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFBA1A1A),
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Apakah anda yakin akan menghapus akun ini?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF131B2E),
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFFFF3333), // Bright red
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(99),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                        ),
                        child: Text(
                          'Batalkan',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          // Handle delete account logic here
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF0065FF), // Bright blue
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(99),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                        ),
                        child: Text(
                          'Ya, saya yakin',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

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
          'Keamanan Akun',
          style: GoogleFonts.hankenGrotesk(
            color: const Color(0xFF004FCB),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Hero Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFF0065FF).withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF004FCB).withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF004FCB).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(Icons.shield_rounded,
                                color: Color(0xFF0065FF), size: 24),
                            Positioned(
                              bottom: 2,
                              right: 2,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A),
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.check,
                                    color: Colors.white, size: 8),
                              ),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Akun Anda Aman',
                              style: GoogleFonts.hankenGrotesk(
                                color: const Color(0xFF131B2E),
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pemeriksaan keamanan terakhir hari ini pukul 10:45',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF424656),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1, color: Color(0xFFF0F0F0)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF004FCB),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      minimumSize: const Size(double.infinity, 44),
                      elevation: 0,
                    ),
                    child: Text(
                      'Lihat Laporan Keamanan',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // PROTEKSI AKUN
            Text(
              'PROTEKSI AKUN',
              style: GoogleFonts.inter(
                color: const Color(0xFF424656),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFF0065FF).withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                  )
                ],
              ),
              child: Column(
                children: [
                  _buildListTile(
                    icon: Icons.phonelink_lock_rounded,
                    title: 'Verifikasi 2 Langkah',
                    subtitle: 'Aktif • SMS & App',
                    trailing: Switch(
                      value: _is2FAEnabled,
                      onChanged: (val) => setState(() => _is2FAEnabled = val),
                      activeThumbColor: Colors.white,
                      activeTrackColor: const Color(0xFF0065FF),
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: Colors.grey.shade300,
                      trackOutlineColor:
                          WidgetStateProperty.all(Colors.transparent),
                    ),
                  ),
                  const Divider(
                      height: 1, indent: 64, color: Color(0xFFF0F0F0)),
                  _buildListTile(
                    icon: Icons.notifications_active_outlined,
                    title: 'Notifikasi Keamanan',
                    subtitle: 'Waspada login baru',
                    trailing: Switch(
                      value: _isSecurityNotificationEnabled,
                      onChanged: (val) =>
                          setState(() => _isSecurityNotificationEnabled = val),
                      activeThumbColor: Colors.white,
                      activeTrackColor: const Color(0xFF0065FF),
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: Colors.grey.shade300,
                      trackOutlineColor:
                          WidgetStateProperty.all(Colors.transparent),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // AKSES & PERANGKAT
            Text(
              'AKSES & PERANGKAT',
              style: GoogleFonts.inter(
                color: const Color(0xFF424656),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFF0065FF).withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                  )
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0065FF).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.devices_rounded,
                            color: Color(0xFF0065FF)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Perangkat Tertaut',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF131B2E),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          color: Color(0xFFBCCBB9), size: 16),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF0F0F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.phone_iphone_rounded,
                            color: Color(0xFF0065FF), size: 20),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'iPhone 14 Pro (Perangkat Ini)',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF131B2E),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Sedang Aktif Sekarang',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF16A34A),
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () {},
                      child: Text(
                        'Lihat 2 Perangkat Lainnya',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF004FCB),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ZONA SENSITIF
            Text(
              'ZONA SENSITIF',
              style: GoogleFonts.inter(
                color: const Color(0xFFBA1A1A),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _showDeleteAccountDialog,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F0),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color(0xFFBA1A1A).withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFBA1A1A).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.delete_outline_rounded,
                          color: Color(0xFFBA1A1A)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hapus Akun',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFBA1A1A),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Nonaktifkan layanan permanen',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF424656),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        color: Color(0xFFBA1A1A), size: 16),
                  ],
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
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF0065FF).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF0065FF)),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF424656),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
