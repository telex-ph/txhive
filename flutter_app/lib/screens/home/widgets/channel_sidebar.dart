import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/json_utils.dart';
import '../../../models/channel.dart';
import '../utils/channel_helpers.dart';
import 'channel_tile.dart';
import 'dm_tile.dart';

class ChannelSidebar extends StatelessWidget {
  final List<dynamic> workspaces;
  final List<Channel> channels;
  final List<Channel> dms;
  final String? selectedWorkspaceId;
  final Channel? selectedChannel;
  final String currentUserId;
  final Future<void> Function(dynamic workspace) onWorkspaceSelected;
  final VoidCallback onOpenWorkspaceDetails;
  final VoidCallback onCreateWorkspace;
  final VoidCallback onJoinWorkspace;
  final VoidCallback onCreateChannel;
  final VoidCallback onNewDirectMessage;
  final void Function(Channel channel) onSelectChannel;
  final void Function(Channel channel) onOpenChannelSettings;
  final void Function(Channel channel) onOpenChannelMembers;
  final void Function(Channel channel) onOpenEodSettings;
  final void Function(Channel channel) onDeleteChannel;

  const ChannelSidebar({
    super.key,
    required this.workspaces,
    required this.channels,
    required this.dms,
    required this.selectedWorkspaceId,
    required this.selectedChannel,
    required this.currentUserId,
    required this.onWorkspaceSelected,
    required this.onOpenWorkspaceDetails,
    required this.onCreateWorkspace,
    required this.onJoinWorkspace,
    required this.onCreateChannel,
    required this.onNewDirectMessage,
    required this.onSelectChannel,
    required this.onOpenChannelSettings,
    required this.onOpenChannelMembers,
    required this.onOpenEodSettings,
    required this.onDeleteChannel,
  });

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _selectedWorkspaceName() {
    if (workspaces.isEmpty) return 'No workspace';
    final found = workspaces.firstWhere(
      (w) => _asMap(w)['_id']?.toString() == selectedWorkspaceId,
      orElse: () => null,
    );
    if (found == null) return 'No workspace';
    final name = _asMap(found)['name']?.toString();
    return name?.isNotEmpty == true ? name! : 'Workspace';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      color: AppColors.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "Chat" title bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
            decoration: const BoxDecoration(
              color: AppColors.panel,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Chat',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.edit_note_rounded,
                    color: AppColors.textMuted,
                    size: 18,
                  ),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                  tooltip: 'New message',
                  onPressed:
                      selectedWorkspaceId == null ? null : onNewDirectMessage,
                ),
              ],
            ),
          ),

          Expanded(
            child: workspaces.isEmpty
                ? _NoWorkspacesPrompt(
                    onCreateWorkspace: onCreateWorkspace,
                    onJoinWorkspace: onJoinWorkspace,
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    children: [
                      // WORKSPACE header (Teams-style — name in bold, click to switch)
                      _WorkspaceHeader(
                        name: _selectedWorkspaceName(),
                        onTap: () => _showWorkspaceSwitcher(context),
                        onManage: selectedWorkspaceId != null
                            ? onOpenWorkspaceDetails
                            : null,
                      ),

                      const SizedBox(height: 4),

                      // CHANNELS section
                      _SectionRow(
                        label: 'Channels',
                        onAdd: selectedWorkspaceId == null
                            ? null
                            : onCreateChannel,
                      ),

                      if (channels.isEmpty)
                        _emptyTile('No channels yet')
                      else
                        ...channels.map((channel) {
                          final canManage =
                              canManageChannel(channel, currentUserId);
                          return ChannelTile(
                            leading: channel.isPrivate
                                ? Icons.lock_outline_rounded
                                : Icons.tag_rounded,
                            title: cleanChannelName(channel.name),
                            selected: selectedChannel?.id == channel.id,
                            onTap: () => onSelectChannel(channel),
                            onSettings: canManage
                                ? () => onOpenChannelSettings(channel)
                                : null,
                            onMembers: channel.isPrivate
                                ? () => onOpenChannelMembers(channel)
                                : null,
                            onEodSettings: () => onOpenEodSettings(channel),
                            onDelete: canManage
                                ? () => onDeleteChannel(channel)
                                : null,
                          );
                        }),

                      const SizedBox(height: 12),

                      // DIRECT MESSAGES section
                      _SectionRow(
                        label: 'Direct messages',
                        onAdd: selectedWorkspaceId == null
                            ? null
                            : onNewDirectMessage,
                      ),

                      if (dms.isEmpty)
                        _emptyTile('No direct messages yet')
                      else
                        ...dms.map((dm) {
                          final rawName = dm.displayName(currentUserId);
                          final name =
                              rawName.isEmpty ? 'Direct Message' : rawName;
                          return DmTile(
                            name: name,
                            selected: selectedChannel?.id == dm.id,
                            onTap: () => onSelectChannel(dm),
                          );
                        }),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showWorkspaceSwitcher(BuildContext context) async {
    if (workspaces.length <= 1) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'Switch workspace',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
            ),
            ...workspaces.map((workspace) {
              final map = _asMap(workspace);
              final id = (map['_id'] ?? '').toString();
              final name = (map['name'] ?? 'Workspace').toString();
              final isSelected = id == selectedWorkspaceId;
              return ListTile(
                dense: true,
                leading: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryDark, AppColors.primary],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'W',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? AppColors.primary : AppColors.textDark,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_rounded,
                        size: 16, color: AppColors.primary)
                    : null,
                onTap: () {
                  Navigator.pop(sheetContext);
                  onWorkspaceSelected(workspace);
                },
              );
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _emptyTile(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  final String name;
  final VoidCallback onTap;
  final VoidCallback? onManage;

  const _WorkspaceHeader({
    required this.name,
    required this.onTap,
    this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.textMuted,
              size: 18,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
            ),
            if (onManage != null)
              IconButton(
                icon: const Icon(
                  Icons.people_outline_rounded,
                  color: AppColors.textMuted,
                  size: 16,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'Manage members',
                onPressed: onManage,
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  final String label;
  final VoidCallback? onAdd;

  const _SectionRow({required this.label, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 0.4,
              ),
            ),
          ),
          if (onAdd != null)
            IconButton(
              icon: const Icon(
                Icons.add_rounded,
                size: 16,
                color: AppColors.textMuted,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              tooltip: 'Add',
              onPressed: onAdd,
            ),
        ],
      ),
    );
  }
}

class _NoWorkspacesPrompt extends StatelessWidget {
  final VoidCallback onCreateWorkspace;
  final VoidCallback onJoinWorkspace;

  const _NoWorkspacesPrompt({
    required this.onCreateWorkspace,
    required this.onJoinWorkspace,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.softRed,
                border: Border.all(color: AppColors.softRedBorder),
              ),
              child: const Icon(
                Icons.workspaces_outline,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No workspace yet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Create or join a workspace to start chatting.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_business_rounded, size: 15),
                label: const Text('Create', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: onCreateWorkspace,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.group_add_outlined, size: 15),
                label: const Text('Join', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: onJoinWorkspace,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
