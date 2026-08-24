import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GroupDetailPage extends StatefulWidget {
  final String groupName;

  const GroupDetailPage({
    super.key,
    this.groupName = 'Jual Beli Musang Cianjur',
  });

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  bool _muteNotifications = false;

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
          _buildGroupSettingsSection(),
          _buildMemberListSection(),
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
                color: const Color(0xFF004FCB).withValues(alpha: 0.1)),
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
                      'Messenger',
                      style: GoogleFonts.hankenGrotesk(
                        color: const Color(0xFF004FCB),
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(
                    Icons.edit_square,
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
          // Group Avatar
          Stack(
            children: [
              Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x330065FF), width: 4),
                  image: const DecorationImage(
                    image: NetworkImage(
                        'https://images.unsplash.com/photo-1541364983171-a8ba01e95cfc?auto=format&fit=crop&w=150&q=80'),
                    fit: BoxFit.cover,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
              ),
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFF004FCB),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.groupName,
            style: GoogleFonts.hankenGrotesk(
              color: const Color(0xFF131B2E),
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '24 Members • Active now',
            style: GoogleFonts.inter(
              color: const Color(0xFF727687),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildActionButton(
                icon: Icons.person_add_alt_1_rounded,
                label: 'Add',
                onTap: () {},
              ),
              const SizedBox(width: 24),
              _buildActionButton(
                icon: Icons.search_rounded,
                label: 'Search',
                onTap: () {},
              ),
              const SizedBox(width: 24),
              _buildActionButton(
                icon: Icons.notifications_off_rounded,
                label: 'Mute',
                onTap: () {},
              ),
              const SizedBox(width: 24),
              _buildActionButton(
                icon: Icons.exit_to_app_rounded,
                label: 'Leave',
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
              color: const Color(0xFFE2E7FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF004FCB),
              size: 22,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            color: const Color(0xFF424656),
            fontSize: 12,
            fontWeight: FontWeight.w600,
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
              color: const Color(0xFF004FCB),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'A creative space for designers to share\ninspiration, project updates, and\ncollaborate on fluid user experiences.',
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
      padding: const EdgeInsets.only(top: 24),
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
                    color: const Color(0xFF004FCB),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
                Text(
                  'See all',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF004FCB),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
                Container(
                  width: 120,
                  height: 96,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F3FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF004FCB).withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.picture_as_pdf_rounded,
                          color: Color(0xFF004FCB), size: 32),
                      const SizedBox(height: 8),
                      Text(
                        'GUIDELINES.PDF',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF004FCB),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _buildMediaThumbnail(
                    'https://images.unsplash.com/photo-1551288049-bebda4e38f71?auto=format&fit=crop&w=300&q=80'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaThumbnail(String imageUrl) {
    return Container(
      width: 120,
      height: 96,
      decoration: BoxDecoration(
        color: const Color(0xFFE6F0FF),
        borderRadius: BorderRadius.circular(12),
        image: DecorationImage(
          image: NetworkImage(imageUrl),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildGroupSettingsSection() {
    return Container(
      margin: const EdgeInsets.only(top: 24, left: 16, right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFF0065FF).withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildListTile(
            icon: Icons.settings_rounded,
            title: 'Group Settings',
            trailing:
                const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ),
          const Divider(height: 1, color: Color(0x0D004FCB)),
          _buildListTile(
            icon: Icons.lock_outline_rounded,
            title: 'Encryption',
            subtitle: 'End-to-end encrypted',
          ),
          const Divider(height: 1, color: Color(0x0D004FCB)),
          _buildListTile(
            icon: Icons.notifications_none_rounded,
            title: 'Mute notifications',
            trailing: Switch(
              value: _muteNotifications,
              onChanged: (val) {
                setState(() {
                  _muteNotifications = val;
                });
              },
              activeThumbColor: Colors.white,
              activeTrackColor: const Color(0xFF0065FF),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFFDAE2FD),
              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberListSection() {
    return Container(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              '24 MEMBERS',
              style: GoogleFonts.inter(
                color: const Color(0xFF004FCB),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFF0065FF).withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildListTile(
                  icon: Icons.person_add_alt_1_rounded,
                  iconColor: Colors.white,
                  iconBgColor: const Color(0xFF0065FF),
                  title: 'Add Members',
                  titleColor: const Color(0xFF004FCB),
                ),
                const Divider(height: 1, color: Color(0x0D004FCB)),
                _buildMemberTile(
                  imageUrl: 'https://randomuser.me/api/portraits/women/44.jpg',
                  name: 'Lela Nova',
                  role: 'Group Admin',
                ),
                const Divider(height: 1, color: Color(0x0D004FCB)),
                _buildMemberTile(
                  initials: 'JD',
                  name: 'You',
                  role: 'Designer',
                  isSelf: true,
                ),
                const Divider(height: 1, color: Color(0x0D004FCB)),
                _buildMemberTile(
                  imageUrl: 'https://randomuser.me/api/portraits/men/32.jpg',
                  name: 'Marc',
                  role: 'UI Developer',
                ),
                const Divider(height: 1, color: Color(0x0D004FCB)),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      'View all members',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF004FCB),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberTile({
    String? imageUrl,
    String? initials,
    required String name,
    required String role,
    bool isSelf = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSelf ? const Color(0xFF0065FF) : Colors.transparent,
              shape: BoxShape.circle,
              image: imageUrl != null
                  ? DecorationImage(
                      image: NetworkImage(imageUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: initials != null
                ? Text(
                    initials,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF131B2E),
                    fontSize: 16,
                  ),
                ),
                Text(
                  role,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF727687),
                    fontSize: 12,
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
    return Container(
      margin: const EdgeInsets.only(top: 24, left: 16, right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1ABA1A1A)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildDangerTile(
            icon: Icons.logout_rounded,
            title: 'Exit Group',
          ),
          const Divider(height: 1, color: Color(0x0DBA1A1A)),
          _buildDangerTile(
            icon: Icons.report_problem_outlined,
            title: 'Report Group',
          ),
        ],
      ),
    );
  }

  Widget _buildDangerTile({required IconData icon, required String title}) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFBA1A1A), size: 22),
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
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFF0065FF).withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildListTile({
    required IconData icon,
    Color? iconColor,
    Color? iconBgColor,
    required String title,
    Color titleColor = const Color(0xFF131B2E),
    String? subtitle,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (iconBgColor != null)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  color: iconColor ?? Colors.grey.shade700, size: 22),
            )
          else
            Icon(icon, color: iconColor ?? Colors.grey.shade700, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: titleColor,
                    fontSize: 16,
                    fontWeight: titleColor != const Color(0xFF131B2E)
                        ? FontWeight.w500
                        : FontWeight.normal,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF727687),
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
