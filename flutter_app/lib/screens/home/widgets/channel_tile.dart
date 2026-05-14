import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class ChannelTile extends StatelessWidget {
  final IconData leading;
  final String title;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onSettings;
  final VoidCallback? onMembers;
  final VoidCallback? onEodSettings;
  final VoidCallback? onDelete;

  const ChannelTile({
    super.key,
    required this.leading,
    required this.title,
    required this.selected,
    required this.onTap,
    this.onSettings,
    this.onMembers,
    this.onEodSettings,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onSettings,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: selected ? AppColors.selectedBg : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                leading,
                size: 15,
                color: selected ? AppColors.primary : AppColors.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    color: selected ? AppColors.primary : AppColors.textDark,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Channel options',
                padding: EdgeInsets.zero,
                iconSize: 16,
                icon: Icon(
                  Icons.more_horiz_rounded,
                  size: 16,
                  color: selected ? AppColors.primary : AppColors.textMuted,
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'settings':
                      onSettings?.call();
                      break;
                    case 'members':
                      onMembers?.call();
                      break;
                    case 'eod':
                      onEodSettings?.call();
                      break;
                    case 'delete':
                      onDelete?.call();
                      break;
                  }
                },
                itemBuilder: (_) => [
                  if (onSettings != null)
                    const PopupMenuItem(
                      value: 'settings',
                      height: 34,
                      child: Row(
                        children: [
                          Icon(Icons.settings_outlined, size: 16),
                          SizedBox(width: 10),
                          Text('Channel settings',
                              style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  if (onMembers != null)
                    const PopupMenuItem(
                      value: 'members',
                      height: 34,
                      child: Row(
                        children: [
                          Icon(Icons.lock_person_outlined, size: 16),
                          SizedBox(width: 10),
                          Text('Manage members',
                              style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  if (onEodSettings != null)
                    const PopupMenuItem(
                      value: 'eod',
                      height: 34,
                      child: Row(
                        children: [
                          Icon(Icons.summarize_outlined, size: 16),
                          SizedBox(width: 10),
                          Text('EOD settings', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  if (onDelete != null) const PopupMenuDivider(height: 4),
                  if (onDelete != null)
                    const PopupMenuItem(
                      value: 'delete',
                      height: 34,
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded,
                              size: 16, color: Colors.red),
                          SizedBox(width: 10),
                          Text(
                            'Delete channel',
                            style: TextStyle(fontSize: 12, color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
