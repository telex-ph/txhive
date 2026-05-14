import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

enum AppRailDestination { activity, chat, teams }

class AppRail extends StatelessWidget {
  final AppRailDestination selected;
  final int unreadActivityCount;
  final ValueChanged<AppRailDestination> onDestinationSelected;
  final VoidCallback onOpenTeamsPopover;
  final VoidCallback onCreateWorkspace;
  final VoidCallback onJoinWorkspace;

  const AppRail({
    super.key,
    required this.selected,
    required this.onDestinationSelected,
    required this.onOpenTeamsPopover,
    required this.onCreateWorkspace,
    required this.onJoinWorkspace,
    this.unreadActivityCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      color: AppColors.dark,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          _RailItem(
            icon: Icons.notifications_outlined,
            label: 'Activity',
            selected: selected == AppRailDestination.activity,
            badgeCount: unreadActivityCount,
            onTap: () => onDestinationSelected(AppRailDestination.activity),
          ),
          const SizedBox(height: 6),
          _RailItem(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Chat',
            selected: selected == AppRailDestination.chat,
            onTap: () => onDestinationSelected(AppRailDestination.chat),
          ),
          const SizedBox(height: 6),
          _RailItem(
            icon: Icons.groups_outlined,
            label: 'Teams',
            selected: selected == AppRailDestination.teams,
            onTap: onOpenTeamsPopover,
          ),
          const Spacer(),
          _CreateMenuButton(
            onCreateWorkspace: onCreateWorkspace,
            onJoinWorkspace: onJoinWorkspace,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;

  const _RailItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 56,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.darkSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    color: selected
                        ? Colors.white
                        : Colors.white.withOpacity(0.78),
                    size: 22,
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      right: -8,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.dark, width: 1.5),
                        ),
                        constraints:
                            const BoxConstraints(minWidth: 18, minHeight: 14),
                        child: Text(
                          badgeCount > 99 ? '99+' : '$badgeCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color:
                      selected ? Colors.white : Colors.white.withOpacity(0.7),
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateMenuButton extends StatelessWidget {
  final VoidCallback onCreateWorkspace;
  final VoidCallback onJoinWorkspace;

  const _CreateMenuButton({
    required this.onCreateWorkspace,
    required this.onJoinWorkspace,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Create or join',
      child: PopupMenuButton<String>(
        tooltip: '',
        offset: const Offset(60, -90),
        color: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: (value) {
          switch (value) {
            case 'create':
              onCreateWorkspace();
              break;
            case 'join':
              onJoinWorkspace();
              break;
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(
            value: 'create',
            child: Row(
              children: [
                Icon(Icons.add_business_rounded,
                    size: 18, color: AppColors.primary),
                SizedBox(width: 10),
                Text('Create workspace'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'join',
            child: Row(
              children: [
                Icon(Icons.group_add_outlined,
                    size: 18, color: AppColors.primary),
                SizedBox(width: 10),
                Text('Join workspace'),
              ],
            ),
          ),
        ],
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.darkSoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
