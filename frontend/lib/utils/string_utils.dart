class StringUtils {
  static String getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      if (parts[0].isNotEmpty && parts[1].isNotEmpty) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
    }
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '?';
  }

  static String formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '';
    try {
      final date = DateTime.parse(timeStr).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final msgDate = DateTime(date.year, date.month, date.day);

      if (msgDate == today) {
        return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } else if (msgDate == yesterday) {
        return 'Kemarin';
      } else {
        final diffDays = today.difference(msgDate).inDays;
        if (diffDays < 7 && diffDays > 0) {
          switch (msgDate.weekday) {
            case 1: return 'Senin';
            case 2: return 'Selasa';
            case 3: return 'Rabu';
            case 4: return 'Kamis';
            case 5: return 'Jumat';
            case 6: return 'Sabtu';
            case 7: return 'Minggu';
          }
        }
        return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year.toString().substring(2)}';
      }
    } catch (e) {
      return '';
    }
  }

  static String formatLastSeen(String? lastSeen) {
    if (lastSeen == null || lastSeen.isEmpty) return 'Offline';
    try {
      final date = DateTime.parse(lastSeen).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final msgDate = DateTime(date.year, date.month, date.day);

      final timeString = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

      if (msgDate == today) {
        return 'Terakhir dilihat hari ini $timeString';
      } else if (msgDate == yesterday) {
        return 'Terakhir dilihat kemarin $timeString';
      } else {
        return 'Terakhir dilihat ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year.toString().substring(2)}';
      }
    } catch (e) {
      return 'Offline';
    }
  }
}
