import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/json_utils.dart';
import '../../../models/channel.dart';

class ChannelSettingsResult {
  final String name;
  final String description;
  final bool isPrivate;

  const ChannelSettingsResult({
    required this.name,
    required this.description,
    required this.isPrivate,
  });
}

Future<ChannelSettingsResult?> showChannelSettingsDialog(
  BuildContext context, {
  required Channel channel,
}) async {
  final nameCtrl = TextEditingController(text: cleanChannelName(channel.name));
  final descCtrl = TextEditingController(text: channel.description);
  bool isPrivate = channel.isPrivate;

  final result = await showDialog<ChannelSettingsResult>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  isPrivate ? Icons.lock_outline_rounded : Icons.tag_rounded,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Channel settings',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 430,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FieldLabel('Channel name'),
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    decoration: _inputDecoration(
                      hintText: 'e.g. eod-report',
                      prefixIcon: Icons.tag_rounded,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const _FieldLabel('Description'),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: _inputDecoration(
                      hintText: 'What is this channel about?',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: SwitchListTile(
                      value: isPrivate,
                      activeColor: AppColors.primary,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      title: Row(
                        children: [
                          Icon(
                            isPrivate
                                ? Icons.lock_outline_rounded
                                : Icons.public_rounded,
                            size: 18,
                            color: isPrivate
                                ? AppColors.primary
                                : AppColors.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isPrivate ? 'Private channel' : 'Public channel',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        isPrivate
                            ? 'Only invited members can access this channel.'
                            : 'Everyone in the workspace can access this channel.',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      onChanged: (value) {
                        setDialogState(() => isPrivate = value);
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  final name = cleanChannelName(nameCtrl.text);

                  if (name.isEmpty) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Channel name is required'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  Navigator.pop(
                    dialogContext,
                    ChannelSettingsResult(
                      name: name,
                      description: descCtrl.text.trim(),
                      isPrivate: isPrivate,
                    ),
                  );
                },
                child: const Text(
                  'Save changes',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          );
        },
      );
    },
  );

  nameCtrl.dispose();
  descCtrl.dispose();
  return result;
}

class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textMuted,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration({
  required String hintText,
  IconData? prefixIcon,
}) {
  return InputDecoration(
    hintText: hintText,
    prefixIcon:
        prefixIcon == null ? null : Icon(prefixIcon, color: AppColors.primary),
    filled: true,
    fillColor: AppColors.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
    ),
  );
}
