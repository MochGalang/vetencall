import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'utils/string_utils.dart';

class UserChatDetailPage extends StatefulWidget {
  final String userName;
  final String sipUsername;

  const UserChatDetailPage({
    super.key,
    required this.userName,
    this.sipUsername = '',
  });

  @override
  State<UserChatDetailPage> createState() => _UserChatDetailPageState();
}

class _UserChatDetailPageState extends State<UserChatDetailPage> {
  bool _disappearingMessages = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      appBar: _buildAppBar(),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          _buildProfileHeader(),
          _buildBioSection(),
          _buildMediaSection(),
          _buildChatSettingsSection(),
          _buildCommonGroupsSection(),
          _buildDangerZoneSection(),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
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
                    const SizedBox(width: 12),
                    Text(
                      widget.userName,
                      style: GoogleFonts.hankenGrotesk(
                        color: const Color(0xFF131B2E),
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
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
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.only(top: 32, bottom: 24),
      child: Column(
        children: [
          // Avatar
          Stack(
            children: [
              Container(
                width: 128,
                height: 128,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF004FCB), Color(0xFFB3C5FF)],
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                  ),
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    color: const Color(0xFFE6F0FF),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    StringUtils.getInitials(widget.userName),
                    style: GoogleFonts.inter(
                      color: const Color(0xFF0065FF),
                      fontSize: 48,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.userName,
            style: GoogleFonts.hankenGrotesk(
              color: const Color(0xFF131B2E),
              fontSize: 32,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.32,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '@${widget.userName.replaceAll(' ', '').toLowerCase()} • Online',
            style: GoogleFonts.inter(
              color: const Color(0xFF424656),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildActionButton(
                icon: Icons.chat_bubble_rounded,
                label: 'MESSAGE',
                isPrimary: true,
                onTap: () =>
                    Navigator.of(context).pop(), // Just pop back to chat
              ),
              const SizedBox(width: 16),
              _buildActionButton(
                icon: Icons.call_rounded,
                label: 'AUDIO',
                isPrimary: false,
                onTap: () {},
              ),
              const SizedBox(width: 16),
              _buildActionButton(
                icon: Icons.videocam_rounded,
                label: 'VIDEO',
                isPrimary: false,
                onTap: () {},
              ),
              const SizedBox(width: 16),
              _buildActionButton(
                icon: Icons.notifications_off_rounded,
                label: 'MUTE',
                isPrimary: false,
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color:
                  isPrimary ? const Color(0xFF0065FF) : const Color(0xFFE2E7FF),
              borderRadius: BorderRadius.circular(12),
              border: isPrimary
                  ? null
                  : Border.all(
                      color: const Color(0xFF004FCB).withValues(alpha: 0.1)),
              boxShadow: isPrimary
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              color: isPrimary ? Colors.white : const Color(0xFF004FCB),
              size: 20,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            color:
                isPrimary ? const Color(0xFF004FCB) : const Color(0xFF424656),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }

  Widget _buildBioSection() {
    return _buildSectionContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ABOUT',
            style: GoogleFonts.inter(
              color: const Color(0xFF424656),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.sipUsername.isNotEmpty 
              ? 'SIP Extension: ${widget.sipUsername}\nPengguna aplikasi Vetencall. Terhubung untuk komunikasi suara, video, dan pesan teks yang lancar.'
              : 'Pengguna aplikasi Vetencall. Terhubung untuk komunikasi suara, video, dan pesan teks yang lancar.',
            style: GoogleFonts.inter(
              color: const Color(0xFF131B2E),
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaSection() {
    return Container(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'MEDIA, LINKS, AND DOCS',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF424656),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
                Text(
                  'View all',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF004FCB),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 96,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildMediaThumbnail(
                    'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?auto=format&fit=crop&w=300&q=80'),
                const SizedBox(width: 12),
                _buildMediaThumbnail(
                    'https://images.unsplash.com/photo-1497366216548-37526070297c?auto=format&fit=crop&w=300&q=80'),
                const SizedBox(width: 12),
                _buildMediaThumbnail(
                    'https://images.unsplash.com/photo-1551288049-bebda4e38f71?auto=format&fit=crop&w=300&q=80'),
                const SizedBox(width: 12),
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E7FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFFC2C6D8).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.picture_as_pdf_rounded,
                          color: Color(0xFF004FCB), size: 32),
                      const SizedBox(height: 8),
                      Text(
                        'PDF',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF424656),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaThumbnail(String imageUrl) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: const Color(0xFFE6F0FF),
        borderRadius: BorderRadius.circular(8),
        image: DecorationImage(
          image: NetworkImage(imageUrl),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildChatSettingsSection() {
    return _buildListSection(
      title: 'CHAT SETTINGS',
      children: [
        _buildListTile(
          icon: Icons.lock_outline_rounded,
          title: 'Encryption',
          subtitle: 'Messages are end-to-end encrypted',
          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        ),
        const Divider(height: 1, color: Color(0x1AC2C6D8)),
        _buildListTile(
          icon: Icons.history_rounded,
          title: 'Disappearing messages',
          subtitle: 'Off',
          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        ),
        const Divider(height: 1, color: Color(0x1AC2C6D8)),
        _buildListTile(
          icon: Icons.notifications_none_rounded,
          title: 'Mute notifications',
          trailing: Switch(
            value: _disappearingMessages,
            onChanged: (val) {
              setState(() {
                _disappearingMessages = val;
              });
            },
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF0065FF),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFDCE3EB),
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ),
      ],
    );
  }

  Widget _buildCommonGroupsSection() {
    return _buildListSection(
      title: 'COMMON GROUPS',
      children: [
        _buildGroupTile(
          initials: 'LL',
          color: const Color(0x330065FF),
          textColor: const Color(0xFF004FCB),
          title: 'Lumina Labs Product Team',
          subtitle: 'Lela, Marc, Sarah + 12 others',
        ),
        const Divider(height: 1, color: Color(0x1AC2C6D8)),
        _buildGroupTile(
          initials: 'D',
          color: const Color(0xFFDCE3EB),
          textColor: const Color(0xFF5E656C),
          title: 'Design Sync',
          subtitle: 'Lela, You + 4 others',
        ),
      ],
    );
  }

  Widget _buildGroupTile({
    required String initials,
    required Color color,
    required Color textColor,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: GoogleFonts.inter(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
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
                    fontSize: 16,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF424656),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZoneSection() {
    return _buildListSection(
      title: 'DANGER ZONE',
      titleColor: const Color(0xFFBA1A1A),
      borderColor: const Color(0x33BA1A1A),
      children: [
        _buildDangerTile(
          icon: Icons.block_outlined,
          title: 'Block ${widget.userName}',
        ),
        const Divider(height: 1, color: Color(0x1AC2C6D8)),
        _buildDangerTile(
          icon: Icons.error_outline_rounded,
          title: 'Report User',
        ),
      ],
    );
  }

  Widget _buildDangerTile({required IconData icon, required String title}) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFBA1A1A)),
            const SizedBox(width: 16),
            Text(
              title,
              style: GoogleFonts.inter(
                color: const Color(0xFFBA1A1A),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionContainer({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildListSection({
    required String title,
    required List<Widget> children,
    Color titleColor = const Color(0xFF424656),
    Color borderColor = const Color(0x33C2C6D8),
  }) {
    return Container(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              title,
              style: GoogleFonts.inter(
                color: titleColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade700, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF131B2E),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF424656),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
