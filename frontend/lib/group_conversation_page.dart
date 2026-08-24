import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'utils/string_utils.dart';
import 'group_detail_page.dart';
import 'services/api_service.dart';

class GroupConversationPage extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String membersText;

  const GroupConversationPage({
    super.key,
    required this.groupId,
    this.groupName = 'Grup',
    this.membersText = '',
  });

  @override
  State<GroupConversationPage> createState() => _GroupConversationPageState();
}

class _GroupConversationPageState extends State<GroupConversationPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _messages = [];
  String _currentUserId = '';
  WebSocketChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id') ?? '';

    if (widget.groupId.isNotEmpty) {
      final response = await ApiService.getGroupMessages(widget.groupId);
      if (response['success'] == true && response['data'] != null) {
        if (mounted) {
          setState(() {
            _messages = List<Map<String, dynamic>>.from(response['data']);
          });
        }
      }
    }

    // Connect WebSocket
    try {
      _channel = WebSocketChannel.connect(Uri.parse(ApiService.wsUrl));
      _channel?.sink.add(jsonEncode({
        'type': 'auth',
        'user_id': _currentUserId,
      }));

      _channel?.stream.listen((message) {
        try {
          final data = jsonDecode(message);
          if (data['type'] == 'new_group_message') {
            final msgData = data['data'];
            if (msgData['group_id'].toString() == widget.groupId) {
              if (mounted) {
                setState(() {
                  _messages.add(msgData);
                });
                _scrollToBottom();
              }
            }
          }
        } catch (e) {
          debugPrint('[WS] Error parsing message: $e');
        }
      });
    } catch (e) {
      debugPrint('WS error: $e');
    }

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

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty || widget.groupId.isEmpty) return;

    _messageController.clear();

    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        'type': 'send_group_message',
        'group_id': widget.groupId,
        'sender_id': _currentUserId,
        'content': text,
      }));
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _channel?.sink.close();
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
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _buildChatArea(),
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
                color: const Color(0xFFC2C6D8).withValues(alpha: 0.1)),
          ),
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
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Color(0xFF0065FF),
                    size: 20,
                  ),
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
                              GroupDetailPage(groupName: widget.groupName),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFE6F0FF),
                            border: Border.all(
                              color: const Color(0xFFC2C6D8)
                                  .withValues(alpha: 0.2),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.groups_rounded,
                            color: Color(0xFF0065FF),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.groupName,
                                style: GoogleFonts.hankenGrotesk(
                                  color: const Color(0xFF131B2E),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                widget.membersText,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF01070F)
                                      .withValues(alpha: 0.5),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    const IconButton(
                      icon: Icon(
                        Icons.call_outlined,
                        color: Colors.grey, // Disabled for group
                      ),
                      onPressed: null,
                    ),
                    const IconButton(
                      icon: Icon(
                        Icons.videocam_outlined,
                        color: Colors.grey, // Disabled for group
                      ),
                      onPressed: null,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: Color(0xFF0065FF),
                      ),
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
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final bool isMe = msg['sender_id'].toString() == _currentUserId;
        final String time = StringUtils.formatTime(msg['created_at']?.toString());
        
        if (isMe) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: _buildSentMessage(msg['content'] ?? '', time),
          );
        } else {
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: _buildGroupReceivedMessage(
              senderName: msg['sender_name'] ?? 'User',
              senderColor: const Color(0xFF004FCB), // Could be randomized based on ID
              text: msg['content'] ?? '',
              time: time,
            ),
          );
        }
      },
    );
  }

  Widget _buildGroupReceivedMessage({
    required String senderName,
    required Color senderColor,
    required String text,
    required String time,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            margin: const EdgeInsets.only(top: 24), // align with bubble
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE6F0FF),
              border: Border.all(
                color: const Color(0xFFC2C6D8).withValues(alpha: 0.2),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              StringUtils.getInitials(senderName),
              style: GoogleFonts.inter(
                color: const Color(0xFF0065FF),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Name, Message Bubble, Time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Text(
                    senderName,
                    style: GoogleFonts.inter(
                      color: senderColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
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
                  child: Text(
                    text,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF131B2E),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    time,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF424656),
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48), // Padding on right
        ],
      ),
    );
  }

  Widget _buildSentMessage(String text, String? time, {int readStatus = 0}) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(left: 48), // Padding on left
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
              child: Text(
                text,
                style: GoogleFonts.inter(
                  color: const Color(0xFFF7F6FF),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
            if (time != null) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    time,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF424656),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (readStatus == 1)
                    const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Color(0xFF424656),
                    ),
                  if (readStatus == 2)
                    const Icon(
                      Icons.done_all_rounded,
                      size: 14,
                      color: Color(0xFF0065FF),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomInputArea() {
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
                    Icon(
                      Icons.sentiment_satisfied_alt_rounded,
                      color: Colors.grey.shade700,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: InputDecoration(
                          hintText: 'tulis pesan...',
                          hintStyle: GoogleFonts.inter(
                            color: Colors.black.withValues(alpha: 0.5),
                            fontSize: 16,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showAttachmentMenu(context),
                      child: Icon(
                        Icons.attach_file_rounded,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.camera_alt_outlined,
                      color: Colors.grey.shade700,
                    ),
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
                icon: const Icon(Icons.send_rounded, color: Colors.white),
                onPressed: _sendMessage,
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
          margin: const EdgeInsets.only(
              left: 16, right: 16, bottom: 80), // Positioned above input
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF8FF).withValues(alpha: 0.85),
                  border: Border.all(
                      color: const Color(0xFFC2C6D8).withValues(alpha: 0.2)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildAttachmentIcon(
                          icon: Icons.insert_drive_file_outlined,
                          color: const Color(0xFFFF9800),
                          label: 'Document',
                        ),
                        _buildAttachmentIcon(
                          icon: Icons.camera_alt_outlined,
                          color: const Color(0xFF00BFA5),
                          label: 'Camera',
                        ),
                        _buildAttachmentIcon(
                          icon: Icons.image_outlined,
                          color: const Color(0xFF9C27B0),
                          label: 'Gallery',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildAttachmentIcon(
                          icon: Icons.headphones_outlined,
                          color: const Color(0xFF4CAF50),
                          label: 'Audio',
                        ),
                        _buildAttachmentIcon(
                          icon: Icons.location_on_outlined,
                          color: const Color(0xFFF44336),
                          label: 'Location',
                        ),
                        _buildAttachmentIcon(
                          icon: Icons.person_outline_rounded,
                          color: const Color(0xFF2196F3),
                          label: 'Contact',
                        ),
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

  Widget _buildAttachmentIcon({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        // Handle attachment tap
      },
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
