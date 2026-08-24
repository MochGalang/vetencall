import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AiBroadcastPage extends StatefulWidget {
  const AiBroadcastPage({super.key});

  @override
  State<AiBroadcastPage> createState() => _AiBroadcastPageState();
}

class _AiBroadcastPageState extends State<AiBroadcastPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  bool _isLoading = false;

  void _startBroadcast() {
    if (_phoneController.text.isEmpty || _messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Nomor tujuan dan pesan tidak boleh kosong!')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Simulasi request ke backend Node.js
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _phoneController.clear();
        _messageController.clear();

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF10B981), size: 28),
                const SizedBox(width: 8),
                Text(
                  'Berhasil',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: Text(
              'Pesan sedang diproses dan server VoIP akan segera menghubungi nomor tujuan.',
              style: GoogleFonts.inter(color: const Color(0xFF4B5563)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Tutup',
                  style: GoogleFonts.inter(
                      color: const Color(0xFF0065FF),
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF191C1E), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Panggilan AI (TTS)',
          style: GoogleFonts.inter(
            color: const Color(0xFF191C1E),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0065FF).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color(0xFF0065FF).withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.record_voice_over_rounded,
                          color: Color(0xFF0065FF), size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Text-to-Speech Broadcast',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF191C1E),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Ketik pesan, AI akan membacakannya melalui telepon secara otomatis.',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF6B7280),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Nomor Tujuan',
                style: GoogleFonts.inter(
                  color: const Color(0xFF374151),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: GoogleFonts.inter(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Contoh: 101 atau 08123456789',
                  hintStyle: GoogleFonts.inter(color: const Color(0xFF9CA3AF)),
                  prefixIcon: const Icon(Icons.dialpad_rounded,
                      color: Color(0xFF6B7280), size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFE5E7EB), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFF0065FF), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Pesan Teks (TTS)',
                style: GoogleFonts.inter(
                  color: const Color(0xFF374151),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _messageController,
                maxLines: 5,
                style: GoogleFonts.inter(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Tuliskan pesan yang ingin dibacakan oleh AI...',
                  hintStyle: GoogleFonts.inter(color: const Color(0xFF9CA3AF)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFE5E7EB), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFF0065FF), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isLoading ? null : _startBroadcast,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0065FF),
                  disabledBackgroundColor: const Color(0xFF9CA3AF),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.send_rounded,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Kirim Panggilan',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
