import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ai_broadcast_page.dart';
import 'services/call_history_service.dart';
import 'utils/string_utils.dart';
import 'widgets/veten_bottom_nav.dart';

class RiwayatTelpPage extends StatefulWidget {
  const RiwayatTelpPage({super.key});

  @override
  State<RiwayatTelpPage> createState() => _RiwayatTelpPageState();
}

class _RiwayatTelpPageState extends State<RiwayatTelpPage> {

  // Data history panggilan
  List<Map<String, dynamic>> _callHistory = [];
  bool _isLoading = true;
  
  int _countMasuk = 0;
  int _countKeluar = 0;
  int _countTerlewat = 0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await CallHistoryService.getCallHistory();
    int masuk = 0;
    int keluar = 0;
    int terlewat = 0;

    for (var call in history) {
      if (call['type'] == 'Masuk') masuk++;
      if (call['type'] == 'Keluar') keluar++;
      if (call['type'] == 'Terlewat') terlewat++;
    }

    if (mounted) {
      setState(() {
        _callHistory = history;
        _countMasuk = masuk;
        _countKeluar = keluar;
        _countTerlewat = terlewat;
        _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FE),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
                _buildTopBar(),
                const SizedBox(height: 16),
                _buildStatsCards(),
                const SizedBox(height: 24),
                Expanded(
                  child: _buildCallHistoryList(),
                ),
              ],
            ),
      ),
      floatingActionButton: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFF2B7FFF),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0059B8).withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: IconButton(
          icon: const Icon(Icons.record_voice_over_rounded,
              color: Colors.white, size: 28),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const AiBroadcastPage()),
            );
          },
        ),
      ),
      bottomNavigationBar: const VetenBottomNav(currentIndex: 2),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Riwayat Telepon',
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
                icon:
                    const Icon(Icons.search_rounded, color: Color(0xFF0065FF)),
                onPressed: () {},
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 16),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF0065FF)),
                padding: EdgeInsets.zero,
                onSelected: (value) async {
                  if (value == 'hapus') {
                    await CallHistoryService.clearHistory();
                    _loadHistory();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'hapus',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Text('Hapus Riwayat', style: GoogleFonts.inter(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2B7FFF),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0059B8).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStatCard(
              _countMasuk.toString(),
              'Masuk',
              Icons.south_west_rounded,
              const Color(0xFF10B981), // Green arrow
              Colors.white,
            ),
            _buildStatCard(
              _countKeluar.toString(),
              'Keluar',
              Icons.north_east_rounded,
              const Color(0xFF2B7FFF), // Blue arrow
              Colors.white,
            ),
            _buildStatCard(
              _countTerlewat.toString(),
              'Terlewat',
              Icons.trending_down_rounded, // Alternative to missed arrow
              const Color(0xFFEF4444), // Red arrow
              const Color(0xFFFEE2E2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String count,
    String label,
    IconData icon,
    Color iconColor,
    Color iconBgColor,
  ) {
    return Container(
      width: (MediaQuery.of(context).size.width - 48 - 32 - 16) / 3,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            count,
            style: GoogleFonts.hankenGrotesk(
              color: const Color(0xFF191C1E),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF717785),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallHistoryList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        border: Border.all(
          color: const Color(0xFF0065FF).withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Riwayat Panggilan',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF000000),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Lihat semua',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF2B7FFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _callHistory.isEmpty
                    ? Center(
                        child: Text(
                          'Belum ada riwayat panggilan.',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF6B7280),
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      )
                : ListView.separated(
                    padding: const EdgeInsets.only(
                        top: 0, bottom: 100, left: 20, right: 20),
                    itemCount: _callHistory.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final call = _callHistory[index];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF3F4F6)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: call['avatarColorValue'] != null ? Color(call['avatarColorValue']) : const Color(0xFFE0F2FE),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                StringUtils.getInitials(call['name']),
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF0065FF),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        call['name'],
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF000000),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (call['time'] != null &&
                                          call['time'].toString().isNotEmpty)
                                        Text(
                                          call['time'],
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFF9CA3AF),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(
                                            (call['isVideo'] == true) 
                                                ? Icons.videocam_rounded
                                                : (call['type'] == 'Masuk'
                                                    ? Icons.call_received_rounded
                                                    : call['type'] == 'Keluar'
                                                        ? Icons.call_made_rounded
                                                        : Icons.call_missed_rounded),
                                            size: 14,
                                            color: call['colorValue'] != null ? Color(call['colorValue']) : const Color(0xFF2B7FFF),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            (call['isVideo'] == true) ? '${call['type']} (Video)' : call['type'],
                                            style: GoogleFonts.inter(
                                              color: call['colorValue'] != null ? Color(call['colorValue']) : const Color(0xFF2B7FFF),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                  if (call['transcription'] != null &&
                                      call['transcription']
                                          .toString()
                                          .isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: const Color(0xFFE5E7EB)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(
                                                  Icons.transcribe_rounded,
                                                  size: 14,
                                                  color: Color(0xFF6B7280)),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Transkripsi AI',
                                                style: GoogleFonts.inter(
                                                  color:
                                                      const Color(0xFF6B7280),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '"${call['transcription']}"',
                                            style: GoogleFonts.inter(
                                              color: const Color(0xFF374151),
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic,
                                              height: 1.4,
                                            ),
                                          ),
                                          if (call['hasAudio'] == true) ...[
                                            const SizedBox(height: 8),
                                            InkWell(
                                              onTap: () {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                      content: Text(
                                                          'Memutar rekaman audio...')),
                                                );
                                              },
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                              0xFF0065FF)
                                                          .withValues(
                                                              alpha: 0.1),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(
                                                        Icons
                                                            .play_arrow_rounded,
                                                        size: 14,
                                                        color:
                                                            Color(0xFF0065FF)),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Putar Rekaman',
                                                    style: GoogleFonts.inter(
                                                      color: const Color(
                                                          0xFF0065FF),
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
