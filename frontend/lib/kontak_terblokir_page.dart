import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/api_service.dart';

class KontakTerblokirPage extends StatefulWidget {
  const KontakTerblokirPage({super.key});

  @override
  State<KontakTerblokirPage> createState() => _KontakTerblokirPageState();
}

class _KontakTerblokirPageState extends State<KontakTerblokirPage> {
  List<dynamic> blockedContacts = [];
  bool isLoading = true;
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    currentUserId = await ApiService.getUserId();
    if (currentUserId != null) {
      final res = await ApiService.getBlockedContacts(currentUserId!);
      if (res['success'] == true) {
        setState(() {
          blockedContacts = res['data'] ?? [];
        });
      } else {
        setState(() {
          blockedContacts = [];
        });
      }
    }
    setState(() => isLoading = false);
  }

  Future<void> _unblock(String blockedId) async {
    if (currentUserId == null) return;
    
    // Tampilkan loading dialog atau ubah state
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Membuka blokir...')),
    );

    final res = await ApiService.unblockContact(currentUserId!, blockedId);
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Blokir berhasil dibuka')),
      );
      _loadData(); // Refresh list
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Gagal membuka blokir')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: isLoading 
                ? const Center(child: CircularProgressIndicator())
                : blockedContacts.isEmpty
                  ? Center(
                      child: Text(
                        'Tidak ada kontak terblokir',
                        style: GoogleFonts.geist(color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                      itemCount: blockedContacts.length,
                      separatorBuilder: (context, index) => const Divider(
                        height: 32,
                        thickness: 1,
                        color: Color(0xFFF3F4F6),
                      ),
                      itemBuilder: (context, index) {
                        final contact = blockedContacts[index];
                        return _buildBlockedContactItem(
                          contact['id'].toString(), 
                          contact['username'] ?? contact['name'] ?? 'Unknown'
                        );
                      },
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
              'assets/images/blokir/container0.svg',
              width: 24,
              height: 24,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Kontak Terblokir',
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

  Widget _buildBlockedContactItem(String id, String name) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: Color(0xFFEAEDFF),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: GoogleFonts.inter(
              color: const Color(0xFF0065FF),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            name,
            style: GoogleFonts.geist(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF131B2E),
            ),
          ),
        ),
        InkWell(
          onTap: () => _unblock(id),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF96C0FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Buka Blokir',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
