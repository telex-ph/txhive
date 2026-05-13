import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

Future<String?> showEditMessageDialog(
  BuildContext context, {
  required String initialContent,
}) async {
  final ctrl = TextEditingController(text: initialContent);

  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          minLines: 1,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'Update your message',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, ctrl.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text(
              'Save',
              style: TextStyle(color: AppColors.white),
            ),
          ),
        ],
      );
    },
  );

  ctrl.dispose();
  return result;
}
