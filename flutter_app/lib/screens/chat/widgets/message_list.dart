import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/message.dart';
import 'message_bubble.dart';

class MessageList extends StatelessWidget {
  final List<Message> messages;
  final String currentUserId;
  final ScrollController scrollController;
  final bool isMobile;
  final void Function(Message message) onCopy;
  final void Function(Message message) onEdit;
  final void Function(Message message) onDelete;

  const MessageList({
    super.key,
    required this.messages,
    required this.currentUserId,
    required this.scrollController,
    required this.isMobile,
    required this.onCopy,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: _TelexPhWatermark(),
        ),
        ListView.builder(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(
            isMobile ? 12 : 28,
            18,
            isMobile ? 12 : 28,
            22,
          ),
          itemCount: messages.length,
          itemBuilder: (_, index) {
            final message = messages[index];
            final isMe = message.sender.id == currentUserId;

            return MessageBubble(
              message: message,
              isMe: isMe,
              onCopy: () => onCopy(message),
              onEdit: isMe ? () => onEdit(message) : null,
              onDelete: isMe ? () => onDelete(message) : null,
            );
          },
        ),
      ],
    );
  }
}

class _TelexPhWatermark extends StatelessWidget {
  const _TelexPhWatermark();

  static const String _assetPath =
      'assets/logos/telexph_watermark_detail_gray.png';

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;

          final watermarkWidth = availableWidth < 720
              ? availableWidth * 0.58
              : availableWidth < 1100
                  ? 380.0
                  : 500.0;

          return Center(
            child: Opacity(
              opacity: 0.075,
              child: Image.asset(
                _assetPath,
                width: watermarkWidth,
                fit: BoxFit.contain,
                errorBuilder: (_, error, stackTrace) {
                  debugPrint('❌ Watermark asset failed to load: $_assetPath');
                  debugPrint('Asset error: $error');
                  return const SizedBox.shrink();
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
