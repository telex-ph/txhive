import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class WorkspaceRail extends StatelessWidget {
  final List<dynamic> workspaces;
  final String? selectedWorkspaceId;
  final Future<void> Function(dynamic workspace) onWorkspaceSelected;
  final VoidCallback onCreateWorkspace;
  final VoidCallback onJoinWorkspace;

  const WorkspaceRail({
    super.key,
    required this.workspaces,
    required this.selectedWorkspaceId,
    required this.onWorkspaceSelected,
    required this.onCreateWorkspace,
    required this.onJoinWorkspace,
  });

  String _initial(String value, {String fallback = 'W'}) {
    final text = value.trim();
    return text.isEmpty ? fallback : text[0].toUpperCase();
  }

  Map<String, dynamic> _workspaceMap(dynamic workspace) {
    if (workspace is Map<String, dynamic>) return workspace;
    if (workspace is Map) return Map<String, dynamic>.from(workspace);
    return <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.dark,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          const SizedBox(height: 2),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  ...workspaces.map((workspace) {
                    final map = _workspaceMap(workspace);

                    final id = (map['_id'] ?? map['id'] ?? '').toString();
                    final name = (map['name'] ?? 'Workspace').toString();
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
                  const SizedBox(height: 10),
                  Container(
                    width: 34,
                    height: 1,
                    color: Colors.white.withOpacity(0.10),
                  ),
                  const SizedBox(height: 10),
                  _railActionButton(
                    icon: Icons.add_rounded,
                    tooltip: 'Create workspace',
                    onTap: onCreateWorkspace,
                  ),
                  const SizedBox(height: 8),
                  _railActionButton(
                    icon: Icons.group_add_outlined,
                    tooltip: 'Join workspace',
                    onTap: onJoinWorkspace,
                  ),
                ],
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
    final initial = _initial(name);

    return Tooltip(
      message: name,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.darkSoft,
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? Border.all(
                    color: Colors.white.withOpacity(0.16),
                  )
                : null,
          ),
          child: Center(
            child: Text(
              initial,
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
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
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.darkSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: AppColors.white,
            size: 21,
          ),
        ),
      ),
    );
  }
}
