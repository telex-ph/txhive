import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';

class SendMessageIntent extends Intent {
  const SendMessageIntent();
}

class InsertNewLineIntent extends Intent {
  const InsertNewLineIntent();
}

class MessageComposer extends StatelessWidget {
  final TextEditingController controller;
  final String channelName;
  final bool isChannel;
  final bool sending;
  final VoidCallback onSend;
  final ValueChanged<String> onChanged;

  const MessageComposer({
    super.key,
    required this.controller,
    required this.channelName,
    required this.isChannel,
    required this.sending,
    required this.onSend,
    required this.onChanged,
  });

  void _insertNewLine() {
    final text = controller.text;
    final selection = controller.selection;

    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;
    final nextText = text.replaceRange(start, end, '\n');

    controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: start + 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 720;

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          isMobile ? 10 : 16,
          12,
          isMobile ? 10 : 16,
          12,
        ),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.attach_file_rounded,
                  color: AppColors.textMuted,
                ),
                onPressed: () {},
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Actions(
                  actions: <Type, Action<Intent>>{
                    SendMessageIntent: CallbackAction<SendMessageIntent>(
                      onInvoke: (_) {
                        onSend();
                        return null;
                      },
                    ),
                    InsertNewLineIntent: CallbackAction<InsertNewLineIntent>(
                      onInvoke: (_) {
                        _insertNewLine();
                        return null;
                      },
                    ),
                  },
                  child: Shortcuts(
                    shortcuts: <ShortcutActivator, Intent>{
                      const SingleActivator(LogicalKeyboardKey.enter):
                          const SendMessageIntent(),
                      const SingleActivator(
                        LogicalKeyboardKey.enter,
                        shift: true,
                      ): const InsertNewLineIntent(),
                    },
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                        hintText: isChannel
                            ? 'Message #$channelName'
                            : 'Type a message...',
                        hintStyle: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                      ),
                      onChanged: onChanged,
                      onSubmitted: (_) => onSend(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primary],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: sending ? null : onSend,
                icon: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppColors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, color: AppColors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
