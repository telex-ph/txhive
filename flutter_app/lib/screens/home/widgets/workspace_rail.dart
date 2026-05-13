import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';

class WorkspaceRail extends StatelessWidget {
  final List<dynamic> workspaces;
  final String? selectedWorkspaceId;
  final Future<void> Function(dynamic workspace) onWorkspaceSelected;
  final VoidCallback onCreateWorkspace;
  final VoidCallback onJoinWorkspace;
  final VoidCallback onEditProfile;
  final VoidCallback onLogout;

  const WorkspaceRail({
    super.key,
    required this.workspaces,
    required this.selectedWorkspaceId,
    required this.onWorkspaceSelected,
    required this.onCreateWorkspace,
    required this.onJoinWorkspace,
    required this.onEditProfile,
    required this.onLogout,
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

  String _initial(String value, {String fallback = '?'}) {
    final text = value.trim();
    return text.isEmpty ? fallback : text[0].toUpperCase();
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
      color: AppColors.dark,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          _profileButton(context),
          const SizedBox(height: 14),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  ...workspaces.map((workspace) {
                    final workspaceMap = workspace is Map
                        ? Map<String, dynamic>.from(workspace)
                        : <String, dynamic>{};

                    final id = (workspaceMap['_id'] ?? workspaceMap['id'] ?? '')
                        .toString();

                    final name =
                        (workspaceMap['name'] ?? 'Workspace').toString();

                    final selected = id == selectedWorkspaceId;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: _workspaceButton(
                        name: name,
                        selected: selected,
                        onTap: () {
                          onWorkspaceSelected(workspace);
                        },
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  Container(
                    width: 38,
                    height: 1,
                    color: Colors.white.withOpacity(0.10),
                  ),
                  const SizedBox(height: 12),
                  _railActionButton(
                    icon: Icons.add_rounded,
                    tooltip: 'Create workspace',
                    onTap: onCreateWorkspace,
                  ),
                  const SizedBox(height: 10),
                  _railActionButton(
                    icon: Icons.group_add_outlined,
                    tooltip: 'Join workspace',
                    onTap: onJoinWorkspace,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _railActionButton(
            icon: Icons.logout_rounded,
            tooltip: 'Logout',
            onTap: onLogout,
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _profileButton(BuildContext context) {
    final dynamic user = context.watch<AuthProvider>().user;

    final name = _safeString(() => user?.name, 'User');
    final email = _safeString(() => user?.email, '');
    final avatar = _safeString(() => user?.avatar, '');
    final status = _safeString(() => user?.status, 'offline');
    final initial = _initial(name);

    return PopupMenuButton<String>(
      tooltip: 'Profile',
      offset: const Offset(56, 0),
      onSelected: (value) {
        switch (value) {
          case 'profile':
            onEditProfile();
            break;
          case 'logout':
            onLogout();
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
                  backgroundImage:
                      avatar.isNotEmpty ? NetworkImage(avatar) : null,
                  child: avatar.isEmpty
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
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark,
                        ),
                      ),
                      if (email.isNotEmpty)
                        Text(
                          email,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
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
            radius: 25,
            backgroundColor: AppColors.darkSoft,
            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
            child: avatar.isEmpty
                ? Text(
                    initial,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : null,
          ),
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: _statusColor(status),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.dark,
                width: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _workspaceButton({
    required String name,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final initial = _initial(name, fallback: 'W');

    return Tooltip(
      message: name,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(selected ? 15 : 24),
            gradient: selected
                ? const LinearGradient(
                    colors: [
                      AppColors.primaryDark,
                      AppColors.primary,
                    ],
                  )
                : null,
            color: selected ? null : AppColors.darkSoft,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.32),
                      blurRadius: 16,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              initial,
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _railActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.darkSoft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            icon,
            color: AppColors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}
