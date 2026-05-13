import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/json_utils.dart';
import '../../../models/channel.dart';
import '../../../services/api_service.dart';

class ChannelMembersSaveResult {
  final bool saved;

  const ChannelMembersSaveResult({required this.saved});
}

Future<ChannelMembersSaveResult?> showChannelMembersDialog(
  BuildContext context, {
  required Channel channel,
  required Future<void> Function() onSaved,
  required void Function(String message) onError,
}) async {
  if (!channel.isPrivate) {
    onError('Specific member control is only available for private channels');
    return null;
  }

  Map<String, dynamic> data;

  try {
    data = Map<String, dynamic>.from(
      await ApiService.get('/channels/${channel.id}/members'),
    );
  } catch (e) {
    onError(e.toString());
    return null;
  }

  final canManage = data['canManage'] == true;
  final workspaceMembers = ((data['workspaceMembers'] as List?) ?? [])
      .whereType<Map>()
      .map((member) => Map<String, dynamic>.from(member))
      .toList();

  final currentMembers = ((data['members'] as List?) ?? [])
      .map((member) => readId(member))
      .where((id) => id.isNotEmpty)
      .toSet();

  final createdById = readId(data['createdBy']);
  final adminIds = ((data['admins'] as List?) ?? [])
      .map((member) => readId(member))
      .where((id) => id.isNotEmpty)
      .toSet();

  final selectedMemberIds = <String>{...currentMembers};
  final searchCtrl = TextEditingController();

  final result = await showDialog<ChannelMembersSaveResult>(
    context: context,
    builder: (dialogContext) {
      String query = '';
      bool saving = false;

      return StatefulBuilder(
        builder: (context, setDialogState) {
          final q = query.toLowerCase();
          final filteredMembers = workspaceMembers.where((user) {
            final name = (user['name'] ?? '').toString().toLowerCase();
            final email = (user['email'] ?? '').toString().toLowerCase();

            return q.isEmpty || name.contains(q) || email.contains(q);
          }).toList();

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              width: 500,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.16),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [AppColors.primaryDark, AppColors.primary],
                          ),
                        ),
                        child: const Icon(
                          Icons.lock_person_outlined,
                          color: AppColors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Manage #${cleanChannelName(channel.name)} members',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textDark,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              canManage
                                  ? 'Choose who can access this private channel.'
                                  : 'You can view members, but only owner/admin can update them.',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: saving ? null : () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search workspace members',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.primary,
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.4,
                        ),
                      ),
                    ),
                    onChanged: (value) => setDialogState(() => query = value),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 360,
                    child: filteredMembers.isEmpty
                        ? const Center(
                            child: Text(
                              'No members found',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredMembers.length,
                            itemBuilder: (_, index) {
                              final user = filteredMembers[index];
                              final userId = readId(user);
                              final name = readUserName(user);
                              final email = (user['email'] ?? '').toString();
                              final initial =
                                  name.isNotEmpty ? name[0].toUpperCase() : '?';

                              final isOwner = userId == createdById;
                              final isAdmin = adminIds.contains(userId);
                              final isSelected = selectedMemberIds.contains(userId);
                              final locked = isOwner || isAdmin;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: CheckboxListTile(
                                  value: isSelected,
                                  activeColor: AppColors.primary,
                                  onChanged: !canManage || locked
                                      ? null
                                      : (checked) {
                                          setDialogState(() {
                                            if (checked == true) {
                                              selectedMemberIds.add(userId);
                                            } else {
                                              selectedMemberIds.remove(userId);
                                            }
                                          });
                                        },
                                  secondary: CircleAvatar(
                                    backgroundColor: AppColors.softRedBorder,
                                    child: Text(
                                      initial,
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          name,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.textDark,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      if (isOwner)
                                        const _RolePill('Owner')
                                      else if (isAdmin)
                                        const _RolePill('Admin'),
                                    ],
                                  ),
                                  subtitle: email.isEmpty
                                      ? null
                                      : Text(
                                          email,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 12,
                                          ),
                                        ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: saving ? null : () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textDark,
                            side: const BorderSide(color: AppColors.border),
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: !canManage || saving
                              ? null
                              : () async {
                                  setDialogState(() => saving = true);

                                  try {
                                    await ApiService.put(
                                      '/channels/${channel.id}/members',
                                      {'memberIds': selectedMemberIds.toList()},
                                    );

                                    await onSaved();

                                    if (dialogContext.mounted) {
                                      Navigator.pop(
                                        dialogContext,
                                        const ChannelMembersSaveResult(saved: true),
                                      );
                                    }
                                  } catch (e) {
                                    onError(e.toString());
                                    setDialogState(() => saving = false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.white,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.white,
                                  ),
                                )
                              : const Text(
                                  'Save members',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  searchCtrl.dispose();
  return result;
}

class _RolePill extends StatelessWidget {
  final String label;

  const _RolePill(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.softRed,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.softRedBorder),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
