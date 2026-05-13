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

  @override
  Widget build(BuildContext context) {
    final displayName = channel.type == 'dm'
        ? channel.displayName(currentUserId)
        : '# ${channel.name}';

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [AppColors.primaryDark, AppColors.primary],
              ),
            ),
            child: Icon(
              channel.type == 'dm'
                  ? Icons.person_outline_rounded
                  : Icons.tag_rounded,
              color: AppColors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  channel.type == 'dm'
                      ? 'Direct message conversation'
                      : 'Channel conversation',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
