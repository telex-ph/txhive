import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/channel.dart';

class ChatHeader extends StatelessWidget {
  final Channel channel;
  final String currentUserId;

  const ChatHeader({
    super.key,
    required this.channel,
    required this.currentUserId,
  });

  String _cleanChannelName(String value) {
    return value.trim().replaceFirst(RegExp(r'^#+\s*'), '');
  }

  @override
  Widget build(BuildContext context) {
    final isDm = channel.type == 'dm';

    final displayName = isDm
        ? channel.displayName(currentUserId)
        : '# ${_cleanChannelName(channel.name)}';

    final subtitle = isDm ? 'Chat' : 'Channel conversation';

    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          _ConversationIcon(isDm: isDm),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    displayName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _HeaderIconButton(
            icon: Icons.search_rounded,
            tooltip: 'Search in chat',
            onTap: () {},
          ),
          _HeaderIconButton(
            icon: Icons.people_outline_rounded,
            tooltip: 'Members',
            onTap: () {},
          ),
          _HeaderIconButton(
            icon: Icons.more_horiz_rounded,
            tooltip: 'More options',
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _ConversationIcon extends StatelessWidget {
  final bool isDm;

  const _ConversationIcon({
    required this.isDm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        isDm ? Icons.person_outline_rounded : Icons.tag_rounded,
        color: AppColors.white,
        size: 19,
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        splashRadius: 18,
        icon: Icon(
          icon,
          size: 19,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}
