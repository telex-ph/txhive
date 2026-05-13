import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

class EditProfileDialog extends StatefulWidget {
  const EditProfileDialog({super.key});

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  static const Color _primary = Color(0xFFA10000);
  static const Color _primaryDark = Color(0xFF650000);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _surface = Color(0xFFF7F7F9);
  static const Color _border = Color(0xFFE9E9ED);
  static const Color _textDark = Color(0xFF202020);
  static const Color _textMuted = Color(0xFF8A8A8F);

  late final TextEditingController _nameCtrl;
  late final TextEditingController _statusMessageCtrl;
  late final TextEditingController _jobTitleCtrl;
  late final TextEditingController _departmentCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _locationCtrl;

  String _status = 'online';
  bool _saving = false;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();

    final user = context.read<AuthProvider>().user;

    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _statusMessageCtrl = TextEditingController(
      text: user?.statusMessage ?? '',
    );
    _jobTitleCtrl = TextEditingController(text: user?.jobTitle ?? '');
    _departmentCtrl = TextEditingController(text: user?.department ?? '');
    _phoneCtrl = TextEditingController(text: user?.phone ?? '');
    _locationCtrl = TextEditingController(text: user?.location ?? '');

    _status = user?.status.isNotEmpty == true ? user!.status : 'online';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _statusMessageCtrl.dispose();
    _jobTitleCtrl.dispose();
    _departmentCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  String _initial(String name) {
    final value = name.trim();
    return value.isEmpty ? '?' : value[0].toUpperCase();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'online':
        return Colors.green;
      case 'busy':
        return Colors.red;
      case 'away':
        return Colors.orange;
      case 'offline':
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'online':
        return 'Available';
      case 'busy':
        return 'Busy';
      case 'away':
        return 'Away';
      case 'offline':
      default:
        return 'Appear offline';
    }
  }

  Future<void> _pickAvatar() async {
    if (_uploadingAvatar) return;

    final picker = ImagePicker();

    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 900,
    );

    if (picked == null) return;

    setState(() => _uploadingAvatar = true);

    try {
      final bytes = await picked.readAsBytes();

      await context.read<AuthProvider>().uploadAvatar(
            bytes: bytes,
            filename: picked.name,
          );
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _removeAvatar() async {
    setState(() => _uploadingAvatar = true);

    try {
      await context.read<AuthProvider>().removeAvatar();
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();

    if (name.isEmpty) {
      _showError('Name is required');
      return;
    }

    setState(() => _saving = true);

    try {
      await context.read<AuthProvider>().updateProfile(
            name: name,
            status: _status,
            statusMessage: _statusMessageCtrl.text.trim(),
            jobTitle: _jobTitleCtrl.text.trim(),
            department: _departmentCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            location: _locationCtrl.text.trim(),
          );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.replaceAll('Exception: ', '')),
        backgroundColor: _primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: _surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: _primary,
                width: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final name = user?.name ?? _nameCtrl.text;
    final avatar = user?.avatar ?? '';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: Container(
        width: 540,
        constraints: const BoxConstraints(maxHeight: 720),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryDark, _primary],
                ),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
              ),
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 42,
                        backgroundColor: Colors.white.withOpacity(0.18),
                        backgroundImage:
                            avatar.isNotEmpty ? NetworkImage(avatar) : null,
                        child: avatar.isEmpty
                            ? Text(
                                _initial(name),
                                style: const TextStyle(
                                  color: _white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                ),
                              )
                            : null,
                      ),
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: _statusColor(_status),
                          shape: BoxShape.circle,
                          border: Border.all(color: _white, width: 3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Edit profile',
                          style: TextStyle(
                            color: _white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.email ?? '',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.84),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _saving || _uploadingAvatar
                        ? null
                        : () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close_rounded, color: _white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed:
                              _uploadingAvatar ? null : () => _pickAvatar(),
                          icon: _uploadingAvatar
                              ? const SizedBox(
                                  width: 15,
                                  height: 15,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.photo_camera_outlined),
                          label: const Text('Change photo'),
                        ),
                        const SizedBox(width: 10),
                        TextButton.icon(
                          onPressed: avatar.isEmpty || _uploadingAvatar
                              ? null
                              : () => _removeAvatar(),
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Remove'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _field(
                      label: 'Display name',
                      controller: _nameCtrl,
                      hint: 'Your name',
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Availability',
                      style: TextStyle(
                        color: _textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _status,
                          isExpanded: true,
                          borderRadius: BorderRadius.circular(16),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          items: ['online', 'busy', 'away', 'offline']
                              .map(
                                (status) => DropdownMenuItem(
                                  value: status,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: _statusColor(status),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(_statusLabel(status)),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _saving
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setState(() => _status = value);
                                },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _field(
                      label: 'Status message',
                      controller: _statusMessageCtrl,
                      hint: 'Example: In a meeting until 3 PM',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 18),
                    const Divider(),
                    const SizedBox(height: 14),
                    _field(
                      label: 'Job title',
                      controller: _jobTitleCtrl,
                      hint: 'Example: Software Developer',
                    ),
                    const SizedBox(height: 14),
                    _field(
                      label: 'Department',
                      controller: _departmentCtrl,
                      hint: 'Example: Innovation Department',
                    ),
                    const SizedBox(height: 14),
                    _field(
                      label: 'Phone',
                      controller: _phoneCtrl,
                      hint: 'Optional phone number',
                    ),
                    const SizedBox(height: 14),
                    _field(
                      label: 'Location',
                      controller: _locationCtrl,
                      hint: 'Example: Manila, Philippines',
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _saving ? null : () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: _white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _white,
                              ),
                            )
                          : const Text(
                              'Save changes',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
