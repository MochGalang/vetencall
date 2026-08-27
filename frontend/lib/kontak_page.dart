import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_service.dart';
import 'utils/string_utils.dart';
import 'chat_conversation_page.dart';
import 'widgets/veten_bottom_nav.dart';
import 'create_group_page.dart';
import 'add_contact_page.dart';
class KontakPage extends StatefulWidget {
  const KontakPage({super.key});

  @override
  State<KontakPage> createState() => _KontakPageState();
}

class _KontakPageState extends State<KontakPage> {
  // Indeks tab Kontak = 1, dikelola oleh VetenBottomNav

  // Menghapus data kontak dummy untuk fokus ke data real
  List<Map<String, dynamic>> _contactData = [];
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<Map<String, dynamic>> get _filteredContactData {
    if (_searchQuery.isEmpty) {
      return _contactData;
    }
    return _contactData.where((contact) {
      final name = contact['name']?.toString().toLowerCase() ?? '';
      final sipUsername = contact['sip_username']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || sipUsername.contains(query);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // State untuk fitur Blast (Multi-select)
  bool _isSelectionMode = false;
  final List<String> _selectedContactIds = [];

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedContactIds.clear();
    });
  }

  void _toggleContactSelection(String id) {
    setState(() {
      if (_selectedContactIds.contains(id)) {
        _selectedContactIds.remove(id);
      } else {
        _selectedContactIds.add(id);
      }
      // Otomatis keluar dari mode seleksi jika tidak ada yang terpilih
      if (_selectedContactIds.isEmpty && _isSelectionMode) {
        _isSelectionMode = false;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      if (userId == null) return;

      // Gunakan flutter_contacts hanya di mobile (Android/iOS)
      // Di web, gunakan endpoint server langsung (tidak ada akses kontak HP)
      if (kIsWeb) {
        await _loadContactsFromServer(userId);
        return;
      }

      // 1. Request Izin Akses Kontak (Mobile only)
      if (!await FlutterContacts.requestPermission(readonly: true)) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Izin akses kontak ditolak. Tidak bisa sinkronisasi.')),
        );
        return;
      }

      // 2. Baca Kontak Bawaan HP
      final contacts = await FlutterContacts.getContacts(withProperties: true);

      // 3. Normalisasi Nomor Telepon
      List<String> phoneNumbers = [];
      for (var contact in contacts) {
        for (var phone in contact.phones) {
          // Hapus semua karakter non-digit (spasi, strip, plus, dll)
          String normalized = phone.number.replaceAll(RegExp(r'\D'), ''); 
          
          // Standarisasi: ubah awalan '08' menjadi '628'
          if (normalized.startsWith('08')) {
            normalized = '628${normalized.substring(2)}';
          }
          
          if (normalized.isNotEmpty && !phoneNumbers.contains(normalized)) {
            phoneNumbers.add(normalized);
          }
        }
      }

      // 4. Panggil Endpoint /api/contacts/sync
      final response = await ApiService.post('/contacts/sync', {
        'user_id': userId,
        'phone_numbers': phoneNumbers,
      });

      if (response['success'] == true && response['data'] != null) {
        List<Map<String, dynamic>> serverContacts = List<Map<String, dynamic>>.from(response['data']);
        if (!mounted) return;
        _applyContacts(serverContacts);
        return;
      }
    } catch (e) {
      debugPrint("Gagal load API Kontak Sync: $e");
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }


  // ==========================================
  // FALLBACK: Load dari server langsung (untuk Web)
  // ==========================================
  Future<void> _loadContactsFromServer(String userId) async {
    try {
      final response = await ApiService.get('/contacts?user_id=$userId');
      if (response['success'] == true && response['data'] != null) {
        final serverContacts = List<Map<String, dynamic>>.from(response['data']);
        if (!mounted) return;
        _applyContacts(serverContacts);
        return;
      }
    } catch (e) {
      debugPrint('Gagal load kontak dari server: $e');
    }
    if (!mounted) return;
    setState(() { _isLoading = false; });
  }

  // ==========================================
  // HELPER: Terapkan data kontak ke UI
  // ==========================================
  void _applyContacts(List<Map<String, dynamic>> contacts) {
    final List<Color> avatarColors = [
      const Color(0xFFEAEDFF),
      const Color(0xFFE6F0FF),
      const Color(0xFFE8F5E9),
      const Color(0xFFFFF3E0),
      const Color(0xFFFFEBEE)
    ];
    setState(() {
      int colorIndex = 0;
      _contactData = contacts.map((c) {
        final color = avatarColors[colorIndex % avatarColors.length];
        colorIndex++;
        return {
          'id': c['id']?.toString() ?? '',
          'name': c['username'] ?? c['name'] ?? 'Unknown',
          'sip_username': c['sip_username'] ?? c['phone_number'] ?? '',
          'avatarColor': color,
        };
      }).toList();
      _isLoading = false;
    });
  }

  // ==========================================
  // LOGIKA TAMBAH KONTAK MANUAL (LOKAL)
  // ==========================================

  void _showAddContactDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddContactPage(
          onSave: (name, phone) async {
            await _saveManualContact(name, phone);
          },
        ),
      ),
    );
  }

  Future<void> _saveManualContact(String name, String phone) async {
    try {
      // Pastikan ada izin tulis kontak
      if (await FlutterContacts.requestPermission()) {
        final newContact = Contact()
          ..name.first = name
          ..phones = [Phone(phone)];
          
        await newContact.insert();
        
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Kontak berhasil disimpan ke HP!'), backgroundColor: Colors.green),
           );
        }
        
        // Refresh UI & Sync Ulang
        setState(() {
          _isLoading = true;
        });
        _loadContacts();
      } else {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Gagal: Butuh izin akses kontak untuk menyimpan.')),
           );
        }
      }
    } catch (e) {
      debugPrint("Gagal menyimpan kontak ke HP: $e");
    }
  }





  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
                _buildTopBar(),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _contactData.isEmpty
                          ? Center(
                              child: Text(
                                'Belum ada pengguna lain di server.\n\nMinta teman Anda mendaftar agar muncul di sini!',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF6B7280),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            )
                          : _filteredContactData.isEmpty
                              ? Center(
                                  child: Text(
                                    'Kontak tidak ditemukan.',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF6B7280),
                                      fontSize: 14,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.only(
                                      top: 8, bottom: 100, left: 16, right: 16),
                                  itemCount: _filteredContactData.length + 1,
                                  separatorBuilder: (context, index) => Divider(
                                    color: const Color(0xFFB9B9B9)
                                        .withValues(alpha: 0.2),
                                    height: 1,
                                    thickness: 1,
                                  ),
                                  itemBuilder: (context, index) {
                                    if (index == 0) {
                                      return InkWell(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => CreateGroupPage(contacts: _contactData),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              Container(
                                                width: 52,
                                                height: 52,
                                                decoration: const BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Color(0xFF0065FF),
                                                ),
                                                alignment: Alignment.center,
                                                child: const Icon(Icons.group_add_rounded, color: Colors.white, size: 26),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Text(
                                                  'Grup Baru',
                                                  style: GoogleFonts.inter(
                                                    color: const Color(0xFF131B2E),
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }
                                    return _buildContactItem(_filteredContactData[index - 1]);
                                  },
                                ),
                ),
              ],
            ),
      ),
      floatingActionButton: _isSelectionMode && _selectedContactIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () {
                // TODO: Integrasi ke backend API blast
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Siap kirim pesan Blast ke ${_selectedContactIds.length} kontak! (Backend sedang disiapkan)'),
                    backgroundColor: Colors.green,
                  ),
                );
                _toggleSelectionMode();
              },
              backgroundColor: const Color(0xFF0065FF),
              icon: const Icon(Icons.campaign_rounded,
                  color: Colors.white),
              label: Text('Blast Pesan',
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMiniFab(Icons.person_rounded,
                    onTap: _showAddContactDialog),
                const SizedBox(height: 12),

                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B7FFF),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0059B8)
                            .withValues(alpha: 0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.sync_rounded,
                        color: Colors.white, size: 28),
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                      });
                      _loadContacts();
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: const VetenBottomNav(currentIndex: 1),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 10),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                _isSelectionMode
                    ? '${_selectedContactIds.length} Terpilih'
                    : 'Daftar Kontak',
                style: GoogleFonts.hankenGrotesk(
                  color: const Color(0xFF0065FF),
                  fontSize: _isSelectionMode ? 20 : 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.6,
                ),
              ),
              const Spacer(),
              if (_isSelectionMode)
                TextButton(
                  onPressed: _toggleSelectionMode,
                  child: Text('Batal',
                      style: GoogleFonts.inter(
                          color: Colors.red, fontWeight: FontWeight.bold)),
                )
              else
                IconButton(
                  icon: const Icon(Icons.checklist_rounded,
                      color: Color(0xFF0065FF)),
                  onPressed: _toggleSelectionMode,
                ),
              const Icon(
                Icons.more_vert_rounded,
                color: Color(0xFF0065FF),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.shade200, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Cari Kontak',
                hintStyle: GoogleFonts.inter(
                  color: Colors.grey.shade500,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                icon: const Icon(Icons.search_rounded,
                    color: Color(0xFF0065FF), size: 22),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
              style: GoogleFonts.inter(
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(Map<String, dynamic> contact) {
    final String contactId = contact['id'].toString();
    final bool isSelected = _selectedContactIds.contains(contactId);

    return InkWell(
        onLongPress: () {
          if (!_isSelectionMode) _toggleSelectionMode();
          _toggleContactSelection(contactId);
        },
        onTap: () async {
          if (_isSelectionMode) {
            _toggleContactSelection(contactId);
            return;
          }

          // Ambil user_id kita sendiri dari SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          final currentUserId = prefs.getString('user_id');

          if (currentUserId == null || contact['id'] == null) return;

          // Panggil API untuk membuat/mendapatkan conversation_id
          final response = await ApiService.post('/conversations', {
            'user1_id': currentUserId,
            'user2_id': contact['id'].toString(),
          });

          if (response['success'] == true) {
            final convId = response['conversation_id'];
            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ChatConversationPage(
                    conversationId: convId.toString(),
                    receiverId: contact['id'].toString(),
                    userName: contact['name'],
                    sipUsername: contact['sip_username']?.toString() ?? '',
                  ),
                ),
              );
            }
          } else {
            debugPrint("Gagal membuat/mendapatkan conversation id");
          }
        },
        child: Container(
          color: isSelected ? const Color(0xFFE6F0FF) : Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: contact['avatarColor'],
                ),
                alignment: Alignment.center,
                child: Text(
                  StringUtils.getInitials(contact['name']),
                  style: GoogleFonts.inter(
                    color: const Color(0xFF0065FF),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact['name'],
                      style: GoogleFonts.inter(
                        color: const Color(0xFF131B2E),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Ext: ${contact['sip_username']}',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF6B7280),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isSelectionMode)
                Checkbox(
                  value: isSelected,
                  onChanged: (bool? value) {
                    _toggleContactSelection(contactId);
                  },
                  activeColor: const Color(0xFF0065FF),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
            ],
          ),
        ));
  }

  Widget _buildMiniFab(IconData icon, {VoidCallback? onTap}) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFF2B7FFF),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0059B8).withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onTap ?? () {},
      ),
    );
  }
}
