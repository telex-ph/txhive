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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onSettings,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: selected ? AppColors.softRed : Colors.transparent,
              border: Border.all(
                color: selected ? AppColors.softRedBorder : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  leading,
                  size: 18,
                  color: selected ? AppColors.primary : AppColors.textMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? AppColors.primary : AppColors.textDark,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Channel options',
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    size: 18,
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
                        child: Row(
                          children: [
                            Icon(Icons.settings_outlined, size: 18),
                            SizedBox(width: 10),
                            Text('Channel settings'),
                          ],
                        ),
                      ),
                    if (onMembers != null)
                      const PopupMenuItem(
                        value: 'members',
                        child: Row(
                          children: [
                            Icon(Icons.lock_person_outlined, size: 18),
                            SizedBox(width: 10),
                            Text('Manage members'),
                          ],
                        ),
                      ),
                    if (onEodSettings != null)
                      const PopupMenuItem(
                        value: 'eod',
                        child: Row(
                          children: [
                            Icon(Icons.summarize_outlined, size: 18),
                            SizedBox(width: 10),
                            Text('EOD settings'),
                          ],
                        ),
                      ),
                    if (onDelete != null) const PopupMenuDivider(),
                    if (onDelete != null)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded,
                                size: 18, color: Colors.red),
                            SizedBox(width: 10),
                            Text('Delete channel',
                                style: TextStyle(color: Colors.red)),
                          ],
                        ),
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
}
