import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/json_utils.dart';
import '../../../models/channel.dart';
import '../utils/channel_helpers.dart';
import 'channel_tile.dart';
import 'dm_tile.dart';
import 'section_header.dart';

class ChannelSidebar extends StatelessWidget {
  final List<dynamic> workspaces;
  final List<Channel> channels;
  final List<Channel> dms;
  final String? selectedWorkspaceId;
  final Channel? selectedChannel;
  final String currentUserId;
  final VoidCallback onOpenWorkspaceDetails;
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
    required this.onOpenWorkspaceDetails,
    required this.onCreateChannel,
    required this.onNewDirectMessage,
    required this.onSelectChannel,
    required this.onOpenChannelSettings,
    required this.onOpenChannelMembers,
    required this.onOpenEodSettings,
    required this.onDeleteChannel,
  });

  @override
  Widget build(BuildContext context) {
    final wsName = workspaces.isEmpty
        ? 'No Workspace'
        : (workspaces
                .firstWhere(
                  (w) => w['_id'] == selectedWorkspaceId,
                  orElse: () => {'name': 'No Workspace'},
                )['name']
                ?.toString() ??
            'No Workspace');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
          width: 290,
          decoration: const BoxDecoration(
            color: AppColors.panel,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wsName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Workspace channels and direct messages',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (selectedWorkspaceId != null)
                IconButton(
                  icon: const Icon(
                    Icons.people_outline_rounded,
                    color: AppColors.primary,
                  ),
                  tooltip: 'Members & invite',
                  onPressed: onOpenWorkspaceDetails,
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
            children: [
              SectionHeader(
                title: 'CHANNELS',
                actionIcon: Icons.add_box_outlined,
                actionTooltip: 'Create channel',
                onAction: selectedWorkspaceId == null ? null : onCreateChannel,
              ),
              const SizedBox(height: 8),
              if (channels.isEmpty)
                _emptyListTile('No channels yet')
              else
                ...channels.map((channel) {
                  final canManage = canManageChannel(channel, currentUserId);

                  return ChannelTile(
                    leading: channel.isPrivate
                        ? Icons.lock_outline_rounded
                        : Icons.tag_rounded,
                    title: cleanChannelName(channel.name),
                    selected: selectedChannel?.id == channel.id,
                    onTap: () => onSelectChannel(channel),
                    onSettings:
                        canManage ? () => onOpenChannelSettings(channel) : null,
                    onMembers: channel.isPrivate
                        ? () => onOpenChannelMembers(channel)
                        : null,
                    onEodSettings: () => onOpenEodSettings(channel),
                    onDelete: canManage ? () => onDeleteChannel(channel) : null,
                  );
                }),
              const SizedBox(height: 18),
              SectionHeader(
                title: 'DIRECT MESSAGES',
                actionIcon: Icons.add_comment_outlined,
                actionTooltip: 'New direct message',
                onAction:
                    selectedWorkspaceId == null ? null : onNewDirectMessage,
              ),
              const SizedBox(height: 8),
              if (dms.isEmpty)
                _emptyListTile('No direct messages yet')
              else
                ...dms.map((dm) {
                  final rawName = dm.displayName(currentUserId);
                  final name = rawName.isEmpty ? 'Direct Message' : rawName;

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
    );
  }

  Widget _emptyListTile(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}
