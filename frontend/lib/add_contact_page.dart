import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AddContactPage extends StatefulWidget {
  final Function(String name, String phone) onSave;

  const AddContactPage({super.key, required this.onSave});

  @override
  State<AddContactPage> createState() => _AddContactPageState();
}

class _AddContactPageState extends State<AddContactPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  void _handleSave() {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama dan Nomor Telepon tidak boleh kosong.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    widget.onSave(name, phone);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Kontak Baru',
          style: GoogleFonts.inter(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _handleSave,
            child: Text(
              'Simpan',
              style: GoogleFonts.inter(
                color: const Color(0xFF0065FF),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 32),
            // Avatar Placeholder
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  size: 50,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 40),
            // Form Fields
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _buildTextField(
                    icon: Icons.person_outline_rounded,
                    controller: _nameController,
                    hint: 'Nama Lengkap',
                    keyboardType: TextInputType.name,
                  ),
                  const SizedBox(height: 24),
                  _buildTextField(
                    icon: Icons.phone_outlined,
                    controller: _phoneController,
                    hint: 'Nomor Telepon / Ekstensi SIP',
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required IconData icon,
    required TextEditingController controller,
    required String hint,
    required TextInputType keyboardType,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Icon(icon, color: Colors.grey[600], size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: GoogleFonts.inter(fontSize: 16, color: Colors.black87),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
              border: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey, width: 0.5),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF0065FF), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
      ],
    );
  }
}
