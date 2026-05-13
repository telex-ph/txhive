import 'package:flutter/material.dart';
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
    return ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 18,
        vertical: 16,
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
    );
  }
}
