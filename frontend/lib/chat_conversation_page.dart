import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'user_chat_detail_page.dart';
import 'services/api_service.dart';
import 'services/ws_service.dart';
import 'utils/string_utils.dart';
import 'call_screen.dart';

class ChatConversationPage extends StatefulWidget {
  final String userName;
  final String conversationId;
  final String receiverId;
  final String sipUsername;
  final bool isOnline;
  final String? lastSeen;

  const ChatConversationPage({
    super.key,
    required this.userName,
    required this.conversationId,
    required this.receiverId,
    this.sipUsername = '',
    this.isOnline = false,
    this.lastSeen,
  });

  @override
  State<ChatConversationPage> createState() => _ChatConversationPageState();
}

class _ChatConversationPageState extends State<ChatConversationPage> {
  final TextEditingController _messageController = TextEditingController();
  bool _isTyping = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _messages = [];
  String _currentUserId = '';
  String _mySipUsername = '';
  StreamSubscription<Map<String, dynamic>>? _wsSub;
  bool _isOnline = false;
  String? _lastSeen;
  bool _isBlocked = false;
  final ScrollController _scrollController = ScrollController();

  /// True jika sipUsername kontak sama dengan sip sendiri (cegah self-call)
  bool get _isSelfCall =>
      _mySipUsername.isNotEmpty &&
      widget.sipUsername.isNotEmpty &&
      widget.sipUsername == _mySipUsername;

  @override
  void initState() {
    super.initState();
    _isOnline = widget.isOnline;
    _lastSeen = widget.lastSeen;
    _messageController.addListener(() {
      setState(() {
        _isTyping = _messageController.text.trim().isNotEmpty;
      });
    });
    _loadMessages();
    _checkBlockStatus();
  }

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id') ?? '';
    _mySipUsername = prefs.getString('sip_username') ?? ''; 

    if (widget.conversationId.isNotEmpty) {
      final response = await ApiService.get(
          '/chat?conversation_id=${widget.conversationId}&user_id=$_currentUserId');
      if (response['success'] == true && response['data'] != null) {
        if (mounted) {
          setState(() {
            _messages = List<Map<String, dynamic>>.from(response['data']);
          });
        }
      }

      debugPrint('[MarkRead] Memanggil POST /chat/read untuk conversation: ${widget.conversationId}');
      final readResponse = await ApiService.post('/chat/read', {
        'conversation_id': widget.conversationId,
        'user_id': _currentUserId,
      });
      debugPrint('[MarkRead] Response: $readResponse');
    }

    if (!WsService().isConnected) {
      await WsService().connect(_currentUserId);
    }
    _wsSub = WsService().stream.listen((data) {
      try {
        if (data['type'] == 'new_message') {
          final msgData = data['data'];
          if (msgData['conversation_id'].toString() == widget.conversationId) {
            if (mounted) {
              setState(() {
                bool exists = _messages.any((m) =>
                    (m['id'] == msgData['id']) ||
                    (m['sender_id'].toString() == _currentUserId &&
                        m['content'] == msgData['content'] &&
                        m['id'].toString().startsWith('temp_')));

                if (!exists) {
                  _messages.add(msgData);
                } else {
                  final idx = _messages.indexWhere((m) =>
                      m['sender_id'].toString() == _currentUserId &&
                      m['content'] == msgData['content'] &&
                      m['id'].toString().startsWith('temp_'));
                  if (idx != -1) {
                    _messages[idx] = msgData;
                  }
                }
              });
              _scrollToBottom();
            }
          }
        } else if (data['type'] == 'status_update') {
          final statusData = data['data'];
          if (statusData['user_id'].toString() == widget.receiverId) {
            if (mounted) {
              setState(() {
                _isOnline = statusData['is_online'] == true;
                _lastSeen = statusData['last_seen']?.toString();
              });
            }
          }
        }
      } catch (e) {
        debugPrint('[WS] Error parsing message: $e');
      }
    });

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _checkBlockStatus() async {
    final response = await ApiService.fetchBlockStatus(widget.receiverId);
    if (mounted && response['success'] == true && response['data'] != null) {
      setState(() {
        _isBlocked = response['data']['is_blocked_by_me'] == true || response['data']['has_blocked_me'] == true;
      });
    }
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    
    if (pickedFile != null) {
      final uploadRes = await ApiService.uploadFile(pickedFile.path);
      if (uploadRes['success'] == true) {
        final mediaUrl = uploadRes['data']['media_url'];
        _sendMessage(mediaUrl, messageType: 'image');
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload gagal: ${uploadRes['message']}')),
          );
        }
      }
    }
  }

  Future<void> _sendMessage(String text, {String messageType = 'text'}) async {
    if (text.isEmpty || widget.conversationId.isEmpty) return;

    _messageController.clear();

    final tempMsg = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'sender_id': _currentUserId,
      'content': text,
      'message_type': messageType,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (mounted) {
      setState(() {
        _messages.add(tempMsg);
      });
      _scrollToBottom();
    }

    final response = await ApiService.post('/chat', {
      'conversation_id': widget.conversationId,
      'sender_id': _currentUserId,
      'receiver_id': widget.receiverId,
      'content': text,
      'message_type': messageType,
    });

    if (response['success'] != true) {
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m['id'] == tempMsg['id']);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengirim pesan')),
        );
      }
    }
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: _buildChatArea(),
          ),
          _buildBottomInputArea(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFAF8FF).withValues(alpha: 0.8),
          border: Border(
              bottom: BorderSide(
                  color: const Color(0xFFC2C6D8).withValues(alpha: 0.1))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Color(0xFF0065FF), size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              UserChatDetailPage(
                                userId: widget.receiverId,
                                userName: widget.userName,
                                sipUsername: widget.sipUsername,
                                isOnline: _isOnline,
                                lastSeen: _lastSeen,
                              ),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFE6F0FF),
                                border: Border.all(
                                    color: const Color(0xFFC2C6D8)
                                        .withValues(alpha: 0.2)),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                StringUtils.getInitials(widget.userName),
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF0065FF),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (_isOnline)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF22C55E),
                                    shape: BoxShape.circle,
                                    border:
                                        Border.all(color: Colors.white, width: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.userName,
                                style: GoogleFonts.hankenGrotesk(
                                  color: const Color(0xFF131B2E),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _isOnline ? 'Online' : StringUtils.formatLastSeen(_lastSeen),
                                style: GoogleFonts.inter(
                                  color: _isOnline ? const Color(0xFF004FCB) : const Color(0xFF6B7280),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.call_outlined,
                        color: _isSelfCall ? Colors.grey.shade400 : const Color(0xFF0065FF),
                      ),
                      tooltip: _isSelfCall ? 'Tidak bisa menelepon diri sendiri' : null,
                      onPressed: _isSelfCall ? null : () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => CallScreen(
                            callerName: widget.userName,
                            sipTarget: widget.sipUsername.isNotEmpty
                                ? widget.sipUsername
                                : widget.receiverId,
                            isIncoming: false,
                          ),
                        ));
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.videocam_outlined,
                        color: _isSelfCall ? Colors.grey.shade400 : const Color(0xFF0065FF),
                      ),
                      tooltip: _isSelfCall ? 'Tidak bisa menelepon diri sendiri' : null,
                      onPressed: _isSelfCall ? null : () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => CallScreen(
                            callerName: widget.userName,
                            sipTarget: widget.sipUsername.isNotEmpty
                                ? widget.sipUsername
                                : widget.receiverId,
                            isIncoming: false,
                            isVideoCall: true,
                          ),
                        ));
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert_rounded,
                          color: Color(0xFF0065FF)),
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatArea() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF2F3FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: Color(0xFF0065FF),
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Belum ada pesan',
              style: GoogleFonts.inter(
                color: const Color(0xFF131B2E),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Kirim pesan untuk memulai obrolan\ndengan ${widget.userName}',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: const Color(0xFF6B7280),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isMe = msg['sender_id'].toString() == _currentUserId;

        String timeStr = '';
        DateTime? currentDate;
        if (msg['created_at'] != null) {
          try {
            currentDate = DateTime.parse(msg['created_at']).toLocal();
            timeStr =
                '${currentDate.hour.toString().padLeft(2, '0')}:${currentDate.minute.toString().padLeft(2, '0')}';
          } catch (e) {
          }
        }

        bool showDateHeader = false;
        if (currentDate != null) {
          if (index == 0) {
            showDateHeader = true;
          } else {
            final prevMsg = _messages[index - 1];
            if (prevMsg['created_at'] != null) {
              try {
                final prevDate = DateTime.parse(prevMsg['created_at']).toLocal();
                if (currentDate.year != prevDate.year ||
                    currentDate.month != prevDate.month ||
                    currentDate.day != prevDate.day) {
                  showDateHeader = true;
                }
              } catch (e) {
              }
            }
          }
        }

        Widget messageWidget;
        if (isMe) {
          messageWidget = Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: _buildSentMessage(
                msg, timeStr.isEmpty ? null : timeStr),
          );
        } else {
          messageWidget = Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: _buildReceivedMessage(msg, timeStr),
          );
        }

        if (showDateHeader && currentDate != null) {
          return Column(
            children: [
              _buildDateHeader(currentDate),
              messageWidget,
            ],
          );
        }

        return messageWidget;
      },
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(date.year, date.month, date.day);

    if (msgDate == today) {
      return 'Hari Ini';
    } else if (msgDate == yesterday) {
      return 'Kemarin';
    } else {
      final diffDays = today.difference(msgDate).inDays;
      if (diffDays < 7 && diffDays > 0) {
        const days = ['', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
        return days[msgDate.weekday];
      }
      return StringUtils.formatLastSeen(date.toIso8601String())
          .replaceFirst('Terakhir dilihat ', '');
    }
  }

  Widget _buildDateHeader(DateTime date) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        _formatDateHeader(date),
        style: GoogleFonts.inter(
          color: const Color(0xFF6B7280),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildReceivedMessage(Map<String, dynamic> msg, String time) {
    final text = msg['content'] ?? '';
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E7FF),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: msg['message_type'] == 'image'
                ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(text, width: 200, fit: BoxFit.cover))
                : Text(text, style: GoogleFonts.inter(color: const Color(0xFF131B2E), fontSize: 14, height: 1.4)),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(time, style: GoogleFonts.inter(color: const Color(0xFF424656), fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _buildSentMessage(Map<String, dynamic> msg, String? time, {int readStatus = 0}) {
    final text = msg['content'] ?? '';
    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0065FF),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: msg['message_type'] == 'image'
                ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(text, width: 200, fit: BoxFit.cover))
                : Text(text, style: GoogleFonts.inter(color: const Color(0xFFF7F6FF), fontSize: 14, height: 1.4)),
          ),
          if (time != null) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(time, style: GoogleFonts.inter(color: const Color(0xFF424656), fontSize: 10)),
                const SizedBox(width: 4),
                if (readStatus == 1) const Icon(Icons.check_rounded, size: 14, color: Color(0xFF424656)),
                if (readStatus == 2) const Icon(Icons.done_all_rounded, size: 14, color: Color(0xFF0065FF)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomInputArea() {
    if (_isBlocked) {
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          color: const Color(0xFFF1F5F9),
          alignment: Alignment.center,
          child: Text(
            'Anda tidak dapat membalas percakapan ini.',
            style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 14),
          ),
        ),
      );
    }

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Colors.white,
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 57,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(color: const Color(0xFFC2C6D8)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.sentiment_satisfied_alt_rounded, color: Colors.grey.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'tulis pesan...',
                          hintStyle: GoogleFonts.inter(color: Colors.black.withValues(alpha: 0.5), fontSize: 16),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showAttachmentMenu(context),
                      child: Icon(Icons.attach_file_rounded, color: Colors.grey.shade700),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.camera_alt_outlined, color: Colors.grey.shade700),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 49,
              height: 49,
              decoration: const BoxDecoration(
                color: Color(0xFF0065FF),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  _isTyping ? Icons.send_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: _isTyping ? 20 : 24,
                ),
                onPressed: () {
                  if (_isTyping) {
                    _sendMessage(_messageController.text.trim());
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachmentMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.only(left: 16, right: 16, bottom: 80),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 4))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF8FF).withValues(alpha: 0.85),
                  border: Border.all(color: const Color(0xFFC2C6D8).withValues(alpha: 0.2)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildAttachmentIcon(icon: Icons.insert_drive_file_outlined, color: const Color(0xFFFF9800), label: 'Document'),
                        _buildAttachmentIcon(icon: Icons.camera_alt_outlined, color: const Color(0xFF00BFA5), label: 'Camera', onTap: () { Navigator.pop(context); _pickAndUploadImage(ImageSource.camera); }),
                        _buildAttachmentIcon(icon: Icons.image_outlined, color: const Color(0xFF9C27B0), label: 'Gallery', onTap: () { Navigator.pop(context); _pickAndUploadImage(ImageSource.gallery); }),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentIcon({required IconData icon, required Color color, required String label, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF424656),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
