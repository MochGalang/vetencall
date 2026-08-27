import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_service.dart';
import 'services/sip_engine.dart';
import 'services/ws_service.dart';

import 'widgets/veten_bottom_nav.dart';
import 'chat_conversation_page.dart';
import 'group_conversation_page.dart';
import 'utils/string_utils.dart';

class HomeChatPage extends StatefulWidget {
  const HomeChatPage({super.key});

  @override
  State<HomeChatPage> createState() => _HomeChatPageState();
}

class _HomeChatPageState extends State<HomeChatPage> {
  List<Map<String, dynamic>> _chatData = [];
  bool _isLoading = true;
  String _currentUserId = '';
  // Set ini hanya bertambah saat user membuka percakapan, TIDAK pernah di-clear saat refresh.
  // Reset hanya terjadi saat user logout (dispose page).
  final Set<String> _readConversationIds = {};
  StreamSubscription<Map<String, dynamic>>? _wsSub;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  String _selectedFilter = 'Semua';
  bool _isSelectionMode = false;
  final Set<String> _selectedChats = {};

  List<Map<String, dynamic>> get _filteredChatData {
    List<Map<String, dynamic>> result = _chatData;

    if (_selectedFilter == 'Belum dibaca') {
      result = result.where((chat) => (chat['unread'] as int? ?? 0) > 0).toList();
    } else if (_selectedFilter == 'Grup') {
      result = result.where((chat) => chat['isGroup'] == true).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((chat) {
        final name = chat['name']?.toString().toLowerCase() ?? '';
        final message = chat['message']?.toString().toLowerCase() ?? '';
        return name.contains(query) || message.contains(query);
      }).toList();
    }
    
    return result;
  }


  @override
  void initState() {
    super.initState();
    _loadData().then((_) => _subscribeToWs());
    // Nyalakan koneksi SIP di background
    SipEngine().connect();
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _subscribeToWs() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id') ?? '';
    if (_currentUserId.isEmpty) return;

    await WsService().connect(_currentUserId);
    _wsSub = WsService().stream.listen(_onWsMessage);
  }

  void _onWsMessage(Map<String, dynamic> data) {
    try {
      if (data['type'] == 'new_message') {
        final msgData = data['data'];
        // Jangan notif jika dari diri sendiri
        if (msgData['sender_id'].toString() != _currentUserId) {
           if (mounted) {
             setState(() {
               final convId = msgData['conversation_id'].toString();
               final index = _chatData.indexWhere((c) => c['conversationId'] == convId);
               if (index != -1) {
                 final chat = _chatData.removeAt(index);
                 // Jangan naikkan badge jika user sedang berada di dalam percakapan ini
                 if (!_readConversationIds.contains(convId)) {
                   chat['unread'] = ((chat['unread'] as int?) ?? 0) + 1;
                 }
                 chat['message'] = msgData['content'] ?? chat['message'];
                 chat['time'] = StringUtils.formatTime(msgData['created_at']?.toString());
                 _chatData.insert(0, chat);
               } else {
                 _loadData();
               }
             });
           }
        }
      } else if (data['type'] == 'new_group_message') {
        final msgData = data['data'];
        if (msgData['sender_id'].toString() != _currentUserId) {
           if (mounted) {
             setState(() {
               final groupId = msgData['group_id'].toString();
               final index = _chatData.indexWhere((c) => c['isGroup'] == true && c['conversationId'] == groupId);
               if (index != -1) {
                 final chat = _chatData.removeAt(index);
                 if (!_readConversationIds.contains('group_$groupId')) {
                   chat['unread'] = ((chat['unread'] as int?) ?? 0) + 1;
                 }
                 chat['message'] = "${msgData['sender_name']}: ${msgData['content']}";
                 chat['time'] = StringUtils.formatTime(msgData['created_at']?.toString());
                 _chatData.insert(0, chat);
               } else {
                 _loadData();
               }
             });
           }
        }
      } else if (data['type'] == 'user_status') {
        final statusData = data['data'];
        final uid = statusData['user_id'].toString();
        final isOnline = statusData['is_online'] == true;
        final lastSeen = statusData['last_seen'];
        debugPrint("[WS] Status User ${uid} berubah: ${isOnline ? 'ONLINE' : 'OFFLINE'} (Last seen: $lastSeen)");        if (mounted) {
          setState(() {
            for (var chat in _chatData) {
              if (chat['receiverId'] == uid) {
                chat['isOnline'] = isOnline;
                chat['lastSeen'] = lastSeen;
              }
            }
          });
        }
      }
    } catch (e) {
      debugPrint('WS error in Home: $e');
    }
  }


  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      if (userId != null) {
        // Sync daftar blokir ke memori
        await ApiService.getBlockedContacts(userId);

        // Fetch 1-on-1 conversations
        final convResponse = await ApiService.get('/conversations?user_id=$userId');
        List<Map<String, dynamic>> convList = [];
        if (convResponse['success'] == true && convResponse['data'] is List) {
          convList = (convResponse['data'] as List).map((c) {
            final convId = c['id']?.toString() ?? '';
            final rawUnread = (c['unread_count'] ?? c['unread'] ?? 0) as int;
            final unread = _readConversationIds.contains(convId) ? 0 : rawUnread;
            final lastMessageTimeStr = c['last_message_time']?.toString() ?? c['updated_at']?.toString() ?? c['created_at']?.toString();
            return {
              'isGroup': false,
              'conversationId': convId,
              'receiverId': c['contact_id']?.toString() ?? '',
              'name': c['contact_name'] ?? 'Unknown',
              'sipUsername': c['contact_sip_username']?.toString() ?? c['sip_username']?.toString() ?? '',
              'time': StringUtils.formatTime(lastMessageTimeStr),
              'rawTime': DateTime.tryParse(lastMessageTimeStr ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
              'message': c['last_message'] ?? 'Memulai obrolan',
              'unread': unread,
              'isOnline': c['is_online'] == true,
              'lastSeen': c['last_seen'],
              'avatarUrl': '',
            };
          }).toList();
        }

        // Fetch group conversations
        final groupResponse = await ApiService.getGroups(userId);
        List<Map<String, dynamic>> groupList = [];
        if (groupResponse['success'] == true && groupResponse['data'] is List) {
          groupList = (groupResponse['data'] as List).map((g) {
            final groupId = g['id']?.toString() ?? '';
            final rawUnread = (g['unread_count'] ?? g['unread'] ?? 0) as int;
            final unread = _readConversationIds.contains('group_$groupId') ? 0 : rawUnread;
            final lastMessageTimeStr = g['last_message_time']?.toString() ?? g['created_at']?.toString();
            return {
              'isGroup': true,
              'conversationId': groupId,
              'name': g['name'] ?? 'Group',
              'membersText': g['members_text'] ?? '',
              'time': StringUtils.formatTime(lastMessageTimeStr),
              'rawTime': DateTime.tryParse(lastMessageTimeStr ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
              'message': g['last_message'] ?? 'Grup dibuat',
              'unread': unread,
              'avatarUrl': '',
            };
          }).toList();
        }

        if (!mounted) return;
        setState(() {
          _chatData = [...convList, ...groupList];
          _chatData.sort((a, b) => (b['rawTime'] as DateTime).compareTo(a['rawTime'] as DateTime));
          _isLoading = false;
          // TIDAK memanggil _readConversationIds.clear() di sini untuk menghindari
          // race condition: set dibersihkan tapi user sedang membuka percakapan.
        });
        return;
      }
    } catch (e) {
      debugPrint("Gagal load API: $e");
    }

    if (!mounted) return;
    setState(() {
      _chatData = [];
      _isLoading = false;
    });
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
                      : _chatData.isEmpty
                          ? Center(
                              child: Text(
                                'Belum ada pesan.\n\nMulai ngobrol dengan masuk ke menu Kontak.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF6B7280),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            )
                          : _filteredChatData.isEmpty
                              ? Center(
                                  child: Text(
                                    'Pesan tidak ditemukan.',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF6B7280),
                                      fontSize: 14,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.only(
                                      top: 8, bottom: 100, left: 16, right: 16),
                                  itemCount: _filteredChatData.length,
                                  itemBuilder: (context, index) {
                                    final chat = _filteredChatData[index];
                                    return _buildChatItem(chat);
                                  },
                                ),
                ),
              ],
            ),
      ),
      bottomNavigationBar: const VetenBottomNav(currentIndex: 0),
    );
  }

  Widget _buildTopBar() {
    if (_isSelectionMode) {
      return Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 10),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.black54),
              onPressed: () {
                setState(() {
                  _isSelectionMode = false;
                  _selectedChats.clear();
                });
              },
            ),
            const SizedBox(width: 8),
            Text(
              '${_selectedChats.length}',
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () {
                setState(() {
                  _chatData.removeWhere((chat) {
                     String id = chat['isGroup'] ? 'group_${chat['conversationId']}' : chat['conversationId'];
                     return _selectedChats.contains(id);
                  });
                  _selectedChats.clear();
                  _isSelectionMode = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chat dihapus (Sementara di Frontend)')),
                );
              },
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 10),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'VetenCall',
                style: GoogleFonts.hankenGrotesk(
                  color: const Color(0xFF0065FF),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFF70F15F),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE6F0FF), width: 2),
                ),
              ),
              const Spacer(),
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
                hintText: 'Cari Pesan',
                hintStyle: GoogleFonts.inter(
                  color: Colors.grey.shade500,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
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
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Semua'),
                const SizedBox(width: 8),
                _buildFilterChip('Belum dibaca'),
                const SizedBox(width: 8),
                _buildFilterChip('Grup'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF133E87) : const Color(0xFFF0F2F5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF133E87) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildChatItem(Map<String, dynamic> chat) {
    final bool isUnread = chat['unread'] > 0;
    final String convId = chat['conversationId']?.toString() ?? '';
    final String uniqueId = chat['isGroup'] == true ? 'group_$convId' : convId;
    final bool isSelected = _selectedChats.contains(uniqueId);

    return GestureDetector(
        onLongPress: () {
          setState(() {
            _isSelectionMode = true;
            if (isSelected) {
              _selectedChats.remove(uniqueId);
              if (_selectedChats.isEmpty) _isSelectionMode = false;
            } else {
              _selectedChats.add(uniqueId);
            }
          });
        },
        onTap: () {
          if (_isSelectionMode) {
            setState(() {
              if (isSelected) {
                _selectedChats.remove(uniqueId);
                if (_selectedChats.isEmpty) _isSelectionMode = false;
              } else {
                _selectedChats.add(uniqueId);
              }
            });
            return;
          }

          // Reset badge unread ke 0 saat chat dibuka
          if ((chat['unread'] as int?) != null && chat['unread'] > 0) {
            setState(() {
              chat['unread'] = 0;
            });
          }
          // Simpan ke set lokal agar tidak muncul lagi setelah _loadData()
          if (chat['isGroup'] == true) {
            _readConversationIds.add('group_$convId');
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => GroupConversationPage(
                  groupId: convId,
                  groupName: chat['name'],
                  membersText: chat['membersText'],
                ),
              ),
            ).then((_) => _loadData()); // Refresh badge setelah kembali
          } else {
            _readConversationIds.add(convId);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ChatConversationPage(
                  userName: chat['name'],
                  conversationId: convId,
                  receiverId: chat['receiverId'] ?? '',
                  sipUsername: chat['sipUsername'] ?? '',
                  isOnline: chat['isOnline'] == true,
                  lastSeen: chat['lastSeen'],
                ),
              ),
            ).then((_) => _loadData()); // Refresh badge + last_message setelah kembali
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: isUnread
              ? const EdgeInsets.all(12)
              : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFE6F0FF) : (isUnread ? Colors.white : Colors.transparent),
            borderRadius: BorderRadius.circular(16),
            border: (isUnread || isSelected) ? Border.all(color: isSelected ? const Color(0xFF0065FF) : Colors.grey.shade100, width: 1) : null,
            boxShadow: isUnread
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              Stack(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFE6F0FF),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      StringUtils.getInitials(chat['name']),
                      style: GoogleFonts.inter(
                        color: const Color(0xFF0065FF),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (chat['isOnline'] == true)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            chat['name'],
                            style: GoogleFonts.inter(
                              color: const Color(0xFF131B2E),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          chat['time'],
                          style: GoogleFonts.inter(
                            color: isUnread
                                ? const Color(0xFF004FCB)
                                : const Color(0xFF6B7280),
                            fontSize: 11,
                            fontWeight:
                                isUnread ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            chat['message'],
                            style: GoogleFonts.inter(
                              color: isUnread
                                  ? const Color(0xFF131B2E)
                                  : const Color(0xFF6B7280),
                              fontSize: 13,
                              fontWeight:
                                  isUnread ? FontWeight.w500 : FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isUnread) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF004FCB),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              (chat['unread'] as int) > 999 ? '999+' : chat['unread'].toString(),
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ));
  }
}
