import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../homechat_page.dart';
import '../kontak_page.dart';
import '../riwayat_telp_page.dart';
import '../homeprofil_page.dart';

class VetenBottomNav extends StatelessWidget {
  final int currentIndex;

  const VetenBottomNav({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 65,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(context, 0, 'assets/images/homechat_page/margin0.svg', 'Pesan'),
              _buildNavItem(context, 1, 'assets/images/homechat_page/margin1.svg', 'Kontak'),
              _buildNavItem(context, 2, 'assets/images/homechat_page/margin2.svg', 'Riwayat'),
              _buildNavItem(context, 3, 'assets/images/homechat_page/margin3.svg', 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, String iconPath, String label) {
    final bool isActive = currentIndex == index;
    final Color color = isActive ? const Color(0xFF0065FF) : const Color(0xFF9CA3AF);

    return GestureDetector(
      onTap: () {
        if (isActive) return; // Prevent pushing the same page

        Widget targetPage;
        switch (index) {
          case 0:
            targetPage = const HomeChatPage();
            break;
          case 1:
            targetPage = const KontakPage();
            break;
          case 2:
            targetPage = const RiwayatTelpPage();
            break;
          case 3:
            targetPage = const HomeProfilPage();
            break;
          default:
            return;
        }

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => targetPage,
            transitionDuration: Duration.zero,
          ),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(horizontal: isActive ? 16 : 8, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF0065FF).withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              width: isActive ? 24 : 22,
              height: isActive ? 24 : 22,
              child: SvgPicture.asset(
                iconPath,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
