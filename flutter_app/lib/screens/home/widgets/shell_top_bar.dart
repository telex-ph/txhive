import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';

class ShellTopBar extends StatelessWidget {
  final VoidCallback? onOpenProfile;
  final VoidCallback? onLogout;

  const ShellTopBar({
    super.key,
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
        return const Color(0xFF2E9E44);
      case 'busy':
        return const Color(0xFFD64545);
      case 'away':
        return const Color(0xFFE0A100);
      case 'offline':
      default:
        return const Color(0xFF9196A1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Logo
          SizedBox(
            width: 110,
            height: 28,
            child: Image.asset(
              'assets/logos/txhive-logo-primary.png',
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              errorBuilder: (_, __, ___) => const Text(
                'TxHive',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),

          // Search bar centered
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: SizedBox(
                  height: 30,
                  child: TextField(
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textDark),
                    decoration: InputDecoration(
                      hintText: 'Search',
                      hintStyle: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 34,
                        minHeight: 30,
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // More menu
          IconButton(
            tooltip: 'More',
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(
              Icons.more_horiz_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 4),

          // Profile menu
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
                  radius: 20,
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
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      if (email.isNotEmpty)
                        Text(
                          email,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
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
          height: 36,
          child: Row(
            children: [
              Icon(Icons.account_circle_outlined, size: 17),
              SizedBox(width: 10),
              Text('Edit profile', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'logout',
          height: 36,
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 17),
              SizedBox(width: 10),
              Text('Logout', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFFF2D7D7),
            backgroundImage: avatarProvider,
            child: avatarProvider == null
                ? Text(
                    initial,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : null,
          ),
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: _statusColor(status),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.white, width: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
