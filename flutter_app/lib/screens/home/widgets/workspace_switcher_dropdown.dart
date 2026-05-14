import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class WorkspaceSwitcherDropdown extends StatelessWidget {
  final List<dynamic> workspaces;
  final String? selectedWorkspaceId;
  final Future<void> Function(dynamic workspace) onWorkspaceSelected;
  final VoidCallback onCreateWorkspace;
  final VoidCallback onJoinWorkspace;
  final VoidCallback onOpenWorkspaceDetails;

  const WorkspaceSwitcherDropdown({
    super.key,
    required this.workspaces,
    required this.selectedWorkspaceId,
    required this.onWorkspaceSelected,
    required this.onCreateWorkspace,
    required this.onJoinWorkspace,
    required this.onOpenWorkspaceDetails,
  });

  String _initial(String value, {String fallback = 'W'}) {
    final text = value.trim();
    return text.isEmpty ? fallback : text[0].toUpperCase();
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    final selected = workspaces.firstWhere(
      (w) => _asMap(w)['_id']?.toString() == selectedWorkspaceId,
      orElse: () => null,
    );
    final selectedMap = selected != null ? _asMap(selected) : null;
    final selectedName = selectedMap?['name']?.toString() ?? 'No Workspace';

    return PopupMenuButton<dynamic>(
      tooltip: 'Switch workspace',
      offset: const Offset(0, 50),
      color: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 320),
      onSelected: (value) {
        if (value is String) {
          switch (value) {
            case '__create__':
              onCreateWorkspace();
              break;
            case '__join__':
              onJoinWorkspace();
              break;
            case '__manage__':
              onOpenWorkspaceDetails();
              break;
          }
        } else {
          onWorkspaceSelected(value);
        }
      },
      itemBuilder: (_) {
        final items = <PopupMenuEntry<dynamic>>[];

        // Section header
        items.add(
          const PopupMenuItem(
            enabled: false,
            height: 32,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'YOUR WORKSPACES',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        );

        // Workspace list
        for (final workspace in workspaces) {
          final map = _asMap(workspace);
          final id = (map['_id'] ?? '').toString();
          final name = (map['name'] ?? 'Workspace').toString();
          final isSelected = id == selectedWorkspaceId;

          items.add(
            PopupMenuItem(
              value: workspace,
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryDark, AppColors.primary],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _initial(name),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                        color:
                            isSelected ? AppColors.primary : AppColors.textDark,
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_rounded,
                        size: 18, color: AppColors.primary),
                ],
              ),
            ),
          );
        }

        items.add(const PopupMenuDivider());

        if (selectedWorkspaceId != null) {
          items.add(
            const PopupMenuItem(
              value: '__manage__',
              child: Row(
                children: [
                  Icon(Icons.people_outline_rounded,
                      size: 18, color: AppColors.primary),
                  SizedBox(width: 10),
                  Text('Manage members'),
                ],
              ),
            ),
          );
          items.add(const PopupMenuDivider());
        }

        items.add(
          const PopupMenuItem(
            value: '__create__',
            child: Row(
              children: [
                Icon(Icons.add_business_rounded,
                    size: 18, color: AppColors.primary),
                SizedBox(width: 10),
                Text('Create workspace'),
              ],
            ),
          ),
        );
        items.add(
          const PopupMenuItem(
            value: '__join__',
            child: Row(
              children: [
                Icon(Icons.group_add_outlined,
                    size: 18, color: AppColors.primary),
                SizedBox(width: 10),
                Text('Join workspace'),
              ],
            ),
          ),
        );

        return items;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.panelSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primary],
                ),
              ),
              child: Center(
                child: Text(
                  _initial(selectedName),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Tap to switch',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.expand_more_rounded,
                color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
