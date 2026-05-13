import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';

class ShellTopBar extends StatelessWidget {
  final String title;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onLogout;

  const ShellTopBar({
    super.key,
    required this.title,
    this.onOpenProfile,
    this.onLogout,
  });

  String _safeString(dynamic Function() read, String fallback) {
    try {
      final value = read();

      if (value == null) return fallback;

      final text = value.toString().trim();
      return text.isEmpty ? fallback : text;
    } catch (_) {
      return fallback;
    }
  }

  String _initial(String value) {
    final text = value.trim();
    return text.isEmpty ? '?' : text[0].toUpperCase();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'online':
        return Colors.green;
      case 'busy':
        return Colors.red;
      case 'away':
        return Colors.orange;
      case 'offline':
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.apps_rounded,
            size: 18,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SizedBox(
                  height: 34,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search',
                      hintStyle: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 17,
                        color: AppColors.textMuted,
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(
                          color: AppColors.border,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(
                          color: AppColors.border,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          IconButton(
            tooltip: 'More',
            onPressed: () {},
            icon: const Icon(
              Icons.more_horiz_rounded,
              size: 20,
              color: AppColors.textMuted,
            ),
          ),
          _profileMenu(context),
        ],
      ),
    );
  }

  Widget _profileMenu(BuildContext context) {
    final dynamic user = context.watch<AuthProvider>().user;

    final name = _safeString(() => user?.name, 'User');
    final email = _safeString(() => user?.email, '');
    final avatar = _safeString(() => user?.avatar, '');
    final status = _safeString(() => user?.status, 'offline');
    final initial = _initial(name);

    final ImageProvider? avatarProvider =
        avatar.isNotEmpty ? NetworkImage(avatar) : null;

    return PopupMenuButton<String>(
      tooltip: 'Profile',
      offset: const Offset(0, 38),
      onSelected: (value) {
        switch (value) {
          case 'profile':
            onOpenProfile?.call();
            break;
          case 'logout':
            onLogout?.call();
            break;
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: SizedBox(
            width: 240,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFF2D7D7),
                  backgroundImage: avatarProvider,
                  child: avatarProvider == null
                      ? Text(
                          initial,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (email.isNotEmpty)
                        Text(
                          email,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'profile',
          child: Row(
            children: [
              Icon(Icons.account_circle_outlined, size: 19),
              SizedBox(width: 10),
              Text('Edit profile'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 19),
              SizedBox(width: 10),
              Text('Logout'),
            ],
          ),
        ),
      ],
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFF2D7D7),
            backgroundImage: avatarProvider,
            child: avatarProvider == null
                ? Text(
                    initial,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : null,
          ),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _statusColor(status),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.white,
                width: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
