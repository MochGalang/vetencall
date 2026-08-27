import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/api_service.dart';
import 'utils/string_utils.dart';
import 'group_conversation_page.dart';

class CreateGroupPage extends StatefulWidget {
  final List<Map<String, dynamic>> contacts;

  const CreateGroupPage({super.key, required this.contacts});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  int _currentStep = 0; // 0: Select Participants, 1: Set Group Name
  
  // Contacts Selection
  final List<Map<String, dynamic>> _selectedContacts = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Group Info
  final TextEditingController _groupNameController = TextEditingController();
  bool _isCreating = false;

  List<Map<String, dynamic>> get _filteredContacts {
    if (_searchQuery.isEmpty) return widget.contacts;
    return widget.contacts.where((contact) {
      final name = contact['name']?.toString().toLowerCase() ?? '';
      final sipUsername = contact['sip_username']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || sipUsername.contains(query);
    }).toList();
  }

  void _toggleSelection(Map<String, dynamic> contact) {
    setState(() {
      final exists = _selectedContacts.any((c) => c['id'] == contact['id']);
      if (exists) {
        _selectedContacts.removeWhere((c) => c['id'] == contact['id']);
      } else {
        _selectedContacts.add(contact);
      }
    });
  }

  Future<void> _createGroup() async {
    if (_groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama grup tidak boleh kosong')),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final List<String> memberIds = _selectedContacts.map((c) => c['id'].toString()).toList();
      
      // Pastikan pembuat grup juga masuk ke dalam memberIds
      final myUserId = await ApiService.getUserId();
      if (myUserId != null && !memberIds.contains(myUserId)) {
        memberIds.add(myUserId);
      }

      final response = await ApiService.createGroup(_groupNameController.text.trim(), memberIds);

      if (!mounted) return;

      if (response['success'] == true) {
        final groupId = response['group_id']?.toString() ?? '';
        
        if (context.mounted) {
          // PushReplacement ke GroupConversationPage
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => GroupConversationPage(
                groupId: groupId,
                groupName: _groupNameController.text.trim(),
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Gagal membuat grup')),
        );
        setState(() {
          _isCreating = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan: $e')),
      );
      setState(() {
        _isCreating = false;
      });
    }
  }

  Widget _buildStep0() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0065FF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Grup Baru', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            Text('Tambah peserta', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
          ],
        ),
      ),
      floatingActionButton: _selectedContacts.isNotEmpty
          ? FloatingActionButton(
              onPressed: () {
                setState(() {
                  _currentStep = 1;
                });
              },
              backgroundColor: const Color(0xFF0065FF),
              child: const Icon(Icons.arrow_forward, color: Colors.white),
            )
          : null,
      body: Column(
        children: [
          // Selected Contacts Horizontal List
          if (_selectedContacts.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
              ),
              child: SizedBox(
                height: 70,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedContacts.length,
                  itemBuilder: (context, index) {
                    final contact = _selectedContacts[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: Stack(
                        children: [
                          Column(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: const Color(0xFF0065FF).withOpacity(0.1),
                                child: Text(
                                  StringUtils.getInitials(contact['name'] ?? ''),
                                  style: GoogleFonts.inter(color: const Color(0xFF0065FF), fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                contact['name']?.toString().split(' ')[0] ?? '',
                                style: GoogleFonts.inter(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: GestureDetector(
                              onTap: () => _toggleSelection(contact),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Cari kontak...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.withOpacity(0.1),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              ),
            ),
          ),

          // Contact List
          Expanded(
            child: ListView.builder(
              itemCount: _filteredContacts.length,
              itemBuilder: (context, index) {
                final contact = _filteredContacts[index];
                final isSelected = _selectedContacts.any((c) => c['id'] == contact['id']);

                return ListTile(
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFF0065FF).withOpacity(0.1),
                        child: Text(
                          StringUtils.getInitials(contact['name'] ?? ''),
                          style: GoogleFonts.inter(color: const Color(0xFF0065FF), fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (isSelected)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, size: 12, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                  title: Text(contact['name'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  subtitle: Text(contact['phone_number'] ?? '', style: GoogleFonts.inter(color: Colors.grey)),
                  onTap: () => _toggleSelection(contact),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0065FF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            setState(() {
              _currentStep = 0;
            });
          },
        ),
        title: Text('Grup Baru', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isCreating ? null : _createGroup,
        backgroundColor: const Color(0xFF0065FF),
        child: _isCreating 
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.check, color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24.0),
            color: Colors.grey.withOpacity(0.05),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.grey.withOpacity(0.3),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _groupNameController,
                    decoration: InputDecoration(
                      hintText: 'Ketik subjek grup di sini...',
                      hintStyle: GoogleFonts.inter(color: Colors.grey),
                      border: const UnderlineInputBorder(),
                    ),
                    style: GoogleFonts.inter(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            alignment: Alignment.centerLeft,
            child: Text(
              'Peserta: ${_selectedContacts.length}',
              style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              itemCount: _selectedContacts.length,
              itemBuilder: (context, index) {
                final contact = _selectedContacts[index];
                return Column(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFF0065FF).withOpacity(0.1),
                      child: Text(
                        StringUtils.getInitials(contact['name'] ?? ''),
                        style: GoogleFonts.inter(color: const Color(0xFF0065FF), fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      contact['name']?.toString().split(' ')[0] ?? '',
                      style: GoogleFonts.inter(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentStep == 0) return _buildStep0();
    return _buildStep1();
  }
}
