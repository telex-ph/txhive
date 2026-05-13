import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/channel.dart';
import 'chat_screen.dart';
import 'workspace_details_screen.dart';
import 'eod_settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> workspaces = [];
  List<Channel> channels = [];
  List<Channel> dms = [];
  String? selectedWorkspaceId;
  Channel? selectedChannel;
  bool loading = true;

  String _cleanChannelName(String value) {
    return value.trim().replaceFirst(RegExp(r'^#+\s*'), '');
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const Color _primary = Color(0xFFA10000);
  static const Color _primaryDark = Color(0xFF650000);
  static const Color _dark = Color(0xFF171717);
  static const Color _darkSoft = Color(0xFF222222);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _surface = Color(0xFFF7F7F9);
  static const Color _surfaceAlt = Color(0xFFF1F1F4);
  static const Color _textDark = Color(0xFF202020);
  static const Color _textMuted = Color(0xFF8A8A8F);
  static const Color _border = Color(0xFFE9E9ED);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => loading = true);
    try {
      final ws = await ApiService.get('/workspaces');
      workspaces = ws;
      if (workspaces.isNotEmpty) {
        selectedWorkspaceId = workspaces[0]['_id'];
        await _loadChannels(selectedWorkspaceId!);
      }
      await _loadDms();
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadChannels(String wsId) async {
    final data = await ApiService.get('/channels/workspace/$wsId');
    channels = (data as List).map((c) => Channel.fromJson(c)).toList();
    if (channels.isNotEmpty && selectedChannel == null) {
      selectedChannel = channels.first;
    }
  }

  Future<void> _loadDms() async {
    final data = await ApiService.get('/channels/dms');
    dms = (data as List).map((c) => Channel.fromJson(c)).toList();
  }

  Future<void> _createOrOpenDm(String userId) async {
    if (selectedWorkspaceId == null) {
      _showError('Please select a workspace first');
      return;
    }

    try {
      final data = await ApiService.post(
        '/channels/dm',
        {
          'userId': userId,
          'workspaceId': selectedWorkspaceId,
        },
      );

      final dm = Channel.fromJson(data);

      await _loadDms();

      if (!mounted) return;

      setState(() {
        final exists = dms.any((item) => item.id == dm.id);

        if (!exists) {
          dms.insert(0, dm);
        }

        selectedChannel = dm;
      });
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _openNewDirectMessageDialog(String currentUserId) async {
    if (selectedWorkspaceId == null) {
      _showError('Please select a workspace first');
      return;
    }

    List<dynamic> members = [];

    try {
      final data = await ApiService.get('/workspaces/$selectedWorkspaceId');
      final rawMembers = (data['members'] as List?) ?? [];

      members = rawMembers.where((m) {
        final user = m['user'];

        if (user is! Map) return false;

        return user['_id']?.toString() != currentUserId.toString();
      }).toList();
    } catch (e) {
      _showError(e.toString());
      return;
    }

    if (!mounted) return;

    final searchCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        String query = '';

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredMembers = members.where((m) {
              final user = m['user'];

              if (user is! Map) return false;

              final name = (user['name'] ?? '').toString().toLowerCase();
              final email = (user['email'] ?? '').toString().toLowerCase();
              final q = query.toLowerCase();

              return q.isEmpty || name.contains(q) || email.contains(q);
            }).toList();

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: 430,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _white,
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
                              colors: [_primaryDark, _primary],
                            ),
                          ),
                          child: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: _white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'New Direct Message',
                                style: TextStyle(
                                  color: _textDark,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Choose a teammate to message privately.',
                                style: TextStyle(
                                  color: _textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Search member',
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: _primary,
                        ),
                        filled: true,
                        fillColor: _surface,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(color: _border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(
                            color: _primary,
                            width: 1.4,
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        setDialogState(() => query = value);
                      },
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 330,
                      child: filteredMembers.isEmpty
                          ? const Center(
                              child: Text(
                                'No members found',
                                style: TextStyle(
                                  color: _textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredMembers.length,
                              itemBuilder: (_, index) {
                                final m = filteredMembers[index];
                                final user = Map<String, dynamic>.from(
                                  (m['user'] as Map?) ?? {},
                                );

                                final userId = user['_id']?.toString() ?? '';
                                final name =
                                    (user['name'] ?? 'Unknown User').toString();
                                final email = (user['email'] ?? '').toString();
                                final initial = name.isNotEmpty
                                    ? name[0].toUpperCase()
                                    : '?';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: _surface,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: _border),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    leading: CircleAvatar(
                                      backgroundColor: const Color(0xFFF2D7D7),
                                      child: Text(
                                        initial,
                                        style: const TextStyle(
                                          color: _primary,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      name,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: _textDark,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    subtitle: email.isEmpty
                                        ? null
                                        : Text(
                                            email,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: _textMuted,
                                              fontSize: 12,
                                            ),
                                          ),
                                    trailing: const Icon(
                                      Icons.arrow_forward_rounded,
                                      color: _primary,
                                    ),
                                    onTap: userId.isEmpty
                                        ? null
                                        : () async {
                                            Navigator.pop(dialogContext);

                                            await _createOrOpenDm(userId);

                                            if (!mounted) return;

                                            if (_scaffoldKey.currentState
                                                    ?.isDrawerOpen ??
                                                false) {
                                              Navigator.of(context).pop();
                                            }
                                          },
                                  ),
                                );
                              },
                            ),
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
  }

  Future<void> _openCreateChannelDialog() async {
    if (selectedWorkspaceId == null) {
      _showError('Please select a workspace first');
      return;
    }

    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool isPrivate = false;

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: 430,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: _white,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              colors: [_primaryDark, _primary],
                            ),
                          ),
                          child: const Icon(Icons.tag_rounded, color: _white),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Create Channel',
                                style: TextStyle(
                                  color: _textDark,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Channels are where your team communicates.',
                                style: TextStyle(
                                  color: _textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 6),
                      child: Text(
                        'Channel name',
                        style: TextStyle(
                          fontSize: 12,
                          color: _textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'e.g. marketing',
                        prefixIcon:
                            const Icon(Icons.tag_rounded, color: _primary),
                        filled: true,
                        fillColor: _surface,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(color: _border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide:
                              const BorderSide(color: _primary, width: 1.4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 6),
                      child: Text(
                        'Description (optional)',
                        style: TextStyle(
                          fontSize: 12,
                          color: _textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'What is this channel about?',
                        filled: true,
                        fillColor: _surface,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(color: _border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide:
                              const BorderSide(color: _primary, width: 1.4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _border),
                      ),
                      child: SwitchListTile(
                        value: isPrivate,
                        activeColor: _primary,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        title: Row(
                          children: [
                            Icon(
                              isPrivate
                                  ? Icons.lock_outline_rounded
                                  : Icons.public_rounded,
                              size: 18,
                              color: isPrivate ? _primary : _textMuted,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isPrivate ? 'Private channel' : 'Public channel',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _textDark,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            isPrivate
                                ? 'Only invited people can join'
                                : 'Anyone in the workspace can join',
                            style: const TextStyle(
                              fontSize: 12,
                              color: _textMuted,
                            ),
                          ),
                        ),
                        onChanged: (v) => setDialogState(() => isPrivate = v),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _textDark,
                              side: const BorderSide(color: _border),
                              minimumSize: const Size.fromHeight(50),
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
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                colors: [_primaryDark, _primary],
                              ),
                            ),
                            child: ElevatedButton(
                              onPressed: () async {
                                final name = _cleanChannelName(nameCtrl.text);
                                if (name.isEmpty) {
                                  ScaffoldMessenger.of(dialogContext)
                                      .showSnackBar(
                                    const SnackBar(
                                      content: Text('Channel name is required'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }
                                try {
                                  final data = await ApiService.post(
                                    '/channels',
                                    {
                                      'name': name,
                                      'description': descCtrl.text.trim(),
                                      'workspace': selectedWorkspaceId,
                                      'isPrivate': isPrivate,
                                    },
                                  );

                                  final newChannel = Channel.fromJson(data);

                                  if (!mounted) return;
                                  Navigator.pop(dialogContext, true);

                                  await _loadChannels(selectedWorkspaceId!);

                                  if (!mounted) return;
                                  setState(() => selectedChannel = newChannel);

                                  if (_scaffoldKey.currentState?.isDrawerOpen ??
                                      false) {
                                    Navigator.of(context).pop();
                                  }
                                } catch (e) {
                                  _showError(e.toString());
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                minimumSize: const Size.fromHeight(50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Create',
                                style: TextStyle(
                                  color: _white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
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

    nameCtrl.dispose();
    descCtrl.dispose();
  }

  Future<void> _refreshChannelsAfterChange(String channelId) async {
    if (selectedWorkspaceId == null) return;

    final wasSelected = selectedChannel?.id == channelId;

    await _loadChannels(selectedWorkspaceId!);

    if (!mounted) return;

    if (wasSelected) {
      setState(() {
        final index = channels.indexWhere((c) => c.id == channelId);

        selectedChannel = index >= 0
            ? channels[index]
            : channels.isNotEmpty
                ? channels.first
                : null;
      });
    } else {
      setState(() {});
    }
  }

  void _openEodSettingsFor(Channel channel) {
    if (selectedWorkspaceId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EodSettingsScreen(
          channelId: channel.id,
          channelName: _cleanChannelName(channel.name),
          workspaceId: selectedWorkspaceId!,
        ),
      ),
    );
  }

  Future<void> _openChannelSettingsDialog(Channel channel) async {
    final nameCtrl = TextEditingController(
      text: _cleanChannelName(channel.name),
    );

    final descCtrl = TextEditingController(
      text: channel.description,
    );

    bool isPrivate = channel.isPrivate;
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    isPrivate ? Icons.lock_outline_rounded : Icons.tag_rounded,
                    color: _primary,
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
                    const Text(
                      'Channel name',
                      style: TextStyle(
                        fontSize: 12,
                        color: _textMuted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'e.g. eod-report',
                        prefixIcon: const Icon(
                          Icons.tag_rounded,
                          color: _primary,
                        ),
                        filled: true,
                        fillColor: _surface,
                        border: OutlineInputBorder(
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
                    const SizedBox(height: 14),
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 12,
                        color: _textMuted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'What is this channel about?',
                        filled: true,
                        fillColor: _surface,
                        border: OutlineInputBorder(
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
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _border),
                      ),
                      child: SwitchListTile(
                        value: isPrivate,
                        activeColor: _primary,
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
                              color: isPrivate ? _primary : _textMuted,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isPrivate ? 'Private channel' : 'Public channel',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _textDark,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          isPrivate
                              ? 'Only invited members can access this channel.'
                              : 'Everyone in the workspace can access this channel.',
                          style: const TextStyle(
                            color: _textMuted,
                            fontSize: 12,
                          ),
                        ),
                        onChanged: saving
                            ? null
                            : (value) {
                                setDialogState(() {
                                  isPrivate = value;
                                });
                              },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: _white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: saving
                      ? null
                      : () async {
                          final name = _cleanChannelName(nameCtrl.text);

                          if (name.isEmpty) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text('Channel name is required'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => saving = true);

                          final ok = await _updateChannel(
                            channel,
                            name: name,
                            description: descCtrl.text.trim(),
                            isPrivate: isPrivate,
                          );

                          if (!mounted) return;

                          if (ok) {
                            Navigator.pop(dialogContext);
                          } else {
                            setDialogState(() => saving = false);
                          }
                        },
                  child: saving
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
              ],
            );
          },
        );
      },
    );

    nameCtrl.dispose();
    descCtrl.dispose();
  }

  Future<bool> _updateChannel(
    Channel channel, {
    required String name,
    required String description,
    required bool isPrivate,
  }) async {
    try {
      await ApiService.put(
        '/channels/${channel.id}',
        {
          'name': name,
          'description': description,
          'isPrivate': isPrivate,
        },
      );

      await _refreshChannelsAfterChange(channel.id);

      return true;
    } catch (e) {
      _showError(e.toString());
      return false;
    }
  }

  Future<void> _confirmDeleteChannel(Channel channel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete channel?'),
          content: Text(
            'This will delete #${_cleanChannelName(channel.name)} and its messages. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteChannel(channel);
    }
  }

  Future<void> _deleteChannel(Channel channel) async {
    if (selectedWorkspaceId == null) return;

    try {
      await ApiService.delete('/channels/${channel.id}');

      final deletedSelectedChannel = selectedChannel?.id == channel.id;

      await _loadChannels(selectedWorkspaceId!);

      if (!mounted) return;

      setState(() {
        if (deletedSelectedChannel) {
          selectedChannel = channels.isNotEmpty ? channels.first : null;
        }
      });
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _createWorkspace() async {
    final result = await _showWorkspaceDialog(
      title: 'Create Workspace',
      hint: 'Workspace name',
      actionLabel: 'Create',
      icon: Icons.add_business_rounded,
    );

    if (result != null && result.trim().isNotEmpty) {
      try {
        await ApiService.post('/workspaces', {'name': result.trim()});
        await _loadData();
      } catch (e) {
        _showError(e.toString());
      }
    }
  }

  Future<void> _joinWorkspace() async {
    final code = await _showWorkspaceDialog(
      title: 'Join Workspace',
      hint: 'Invite code',
      actionLabel: 'Join',
      icon: Icons.group_add_rounded,
    );

    if (code != null && code.trim().isNotEmpty) {
      try {
        await ApiService.post('/workspaces/join', {'inviteCode': code.trim()});
        await _loadData();
      } catch (e) {
        _showError(e.toString());
      }
    }
  }

  Future<String?> _showWorkspaceDialog({
    required String title,
    required String hint,
    required String actionLabel,
    required IconData icon,
  }) async {
    final ctrl = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: _white,
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
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [_primaryDark, _primary],
                    ),
                  ),
                  child: Icon(icon, color: _white, size: 26),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the required information below.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: _textMuted,
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: hint,
                    filled: true,
                    fillColor: _surface,
                    prefixIcon:
                        const Icon(Icons.edit_outlined, color: _primary),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: _primary, width: 1.4),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _textDark,
                          side: const BorderSide(color: _border),
                          minimumSize: const Size.fromHeight(50),
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
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [_primaryDark, _primary],
                          ),
                        ),
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, ctrl.text),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            actionLabel,
                            style: const TextStyle(
                              color: _white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
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
  }

  void _openWorkspaceDetails() {
    if (selectedWorkspaceId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            WorkspaceDetailsScreen(workspaceId: selectedWorkspaceId!),
      ),
    ).then((_) => _loadData());
  }

  void _openEodSettings() {
    if (selectedChannel == null || selectedWorkspaceId == null) return;
    if (selectedChannel!.type != 'channel') {
      _showError('EOD settings only available for channels');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EodSettingsScreen(
          channelId: selectedChannel!.id,
          channelName: selectedChannel!.name,
          workspaceId: selectedWorkspaceId!,
        ),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg.replaceAll('Exception: ', '')),
        backgroundColor: _dark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _selectChannel(Channel c) {
    setState(() => selectedChannel = c);
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 720;

    if (loading) {
      return const Scaffold(
        backgroundColor: _surface,
        body: Center(
          child: CircularProgressIndicator(color: _primary),
        ),
      );
    }

    final workspaceRail = _buildWorkspaceRail();
    final channelList = _buildChannelList(user?.id ?? '');

    if (isMobile) {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: _surface,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: _white,
          foregroundColor: _textDark,
          centerTitle: false,
          titleSpacing: 8,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                selectedChannel != null
                    ? (selectedChannel!.type == 'channel'
                        ? '# ${selectedChannel!.name}'
                        : selectedChannel!.displayName(user?.id ?? ''))
                    : 'TxHive',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _textDark,
                ),
              ),
              const Text(
                'TelexPH Messaging Workspace',
                style: TextStyle(
                  fontSize: 11,
                  color: _textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            if (selectedWorkspaceId != null)
              IconButton(
                icon: const Icon(Icons.people_alt_outlined),
                tooltip: 'Members',
                onPressed: _openWorkspaceDetails,
              ),
            IconButton(
              icon: const Icon(Icons.summarize_outlined),
              tooltip: 'EOD Settings',
              onPressed: _openEodSettings,
            ),
          ],
        ),
        drawer: SizedBox(
          width: width < 420 ? width * 0.92 : 380,
          child: Drawer(
            backgroundColor: _white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            child: SafeArea(
              child: Row(
                children: [
                  SizedBox(width: 72, child: workspaceRail),
                  Expanded(child: channelList),
                ],
              ),
            ),
          ),
        ),
        body: selectedChannel == null
            ? _buildEmptyState(
                icon: Icons.forum_outlined,
                title: 'No channel selected',
                subtitle:
                    'Open the menu and choose a channel to start chatting.',
              )
            : ChatScreen(
                channel: selectedChannel!,
                key: ValueKey(selectedChannel!.id),
              ),
      );
    }

    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: Row(
          children: [
            SizedBox(width: 86, child: workspaceRail),
            Container(
              width: 300,
              margin: const EdgeInsets.fromLTRB(0, 12, 12, 12),
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: _border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: channelList,
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                decoration: BoxDecoration(
                  color: _white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: _border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: selectedChannel == null
                    ? _buildEmptyState(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: 'Select a channel',
                        subtitle:
                            'Choose a channel or direct message from the sidebar to start chatting.',
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: ChatScreen(
                          channel: selectedChannel!,
                          key: ValueKey(selectedChannel!.id),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkspaceRail() {
    return Container(
      color: _dark,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_primaryDark, _primary],
              ),
            ),
            child: const Center(
              child: Text(
                'T',
                style: TextStyle(
                  color: _white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  ...workspaces.map((w) {
                    final isSelected = w['_id'] == selectedWorkspaceId;
                    final name = w['name']?.toString() ?? 'W';
                    final initial =
                        name.isNotEmpty ? name[0].toUpperCase() : 'W';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Tooltip(
                        message: name,
                        child: GestureDetector(
                          onTap: () async {
                            setState(() {
                              selectedWorkspaceId = w['_id'];
                              selectedChannel = null;
                            });
                            await _loadChannels(w['_id']);
                            setState(() {});
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(isSelected ? 15 : 24),
                              gradient: isSelected
                                  ? const LinearGradient(
                                      colors: [_primaryDark, _primary],
                                    )
                                  : null,
                              color: isSelected ? null : _darkSoft,
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: _primary.withOpacity(0.32),
                                        blurRadius: 16,
                                        offset: const Offset(0, 7),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  color: _white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  Container(
                    width: 38,
                    height: 1,
                    color: Colors.white.withOpacity(0.10),
                  ),
                  const SizedBox(height: 12),
                  _railActionButton(
                    icon: Icons.add_rounded,
                    tooltip: 'Create workspace',
                    onTap: _createWorkspace,
                  ),
                  const SizedBox(height: 10),
                  _railActionButton(
                    icon: Icons.group_add_outlined,
                    tooltip: 'Join workspace',
                    onTap: _joinWorkspace,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _railActionButton(
            icon: Icons.logout_rounded,
            tooltip: 'Logout',
            onTap: () => context.read<AuthProvider>().logout(),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _railActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _darkSoft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: _white, size: 22),
        ),
      ),
    );
  }

  Widget _buildChannelList(String currentUserId) {
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
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _border)),
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
                        color: _textDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Workspace channels and direct messages',
                      style: TextStyle(
                        fontSize: 12,
                        color: _textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (selectedWorkspaceId != null)
                IconButton(
                  icon:
                      const Icon(Icons.people_outline_rounded, color: _primary),
                  tooltip: 'Members & invite',
                  onPressed: _openWorkspaceDetails,
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
            children: [
              _channelsHeader(),
              const SizedBox(height: 8),
              if (channels.isEmpty)
                _emptyListTile('No channels yet')
              else
                ...channels.map(
                  (c) => _channelTile(
                    leading: c.isPrivate
                        ? Icons.lock_outline_rounded
                        : Icons.tag_rounded,
                    title: _cleanChannelName(c.name),
                    selected: selectedChannel?.id == c.id,
                    onTap: () => _selectChannel(c),
                    onSettings: () => _openChannelSettingsDialog(c),
                    onEodSettings: () => _openEodSettingsFor(c),
                    onDelete: () => _confirmDeleteChannel(c),
                  ),
                ),
              const SizedBox(height: 18),
              _directMessagesHeader(currentUserId),
              const SizedBox(height: 8),
              if (dms.isEmpty)
                _emptyListTile('No direct messages yet')
              else
                ...dms.map((d) {
                  final rawName = d.displayName(currentUserId);
                  final name = rawName.isEmpty ? 'Direct Message' : rawName;
                  final initial = name[0].toUpperCase();

                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 12,
                      backgroundColor: const Color(0xFFF2D7D7),
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: _primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    title: Text(
                      name.isEmpty ? 'Direct Message' : name,
                      overflow: TextOverflow.ellipsis,
                    ),
                    selected: selectedChannel?.id == d.id,
                    onTap: () => _selectChannel(d),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          color: _textMuted,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _emptyListTile(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: _textMuted,
        ),
      ),
    );
  }

  Widget _channelTile({
    required IconData leading,
    required String title,
    required bool selected,
    required VoidCallback onTap,
    VoidCallback? onSettings,
    VoidCallback? onEodSettings,
    VoidCallback? onDelete,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onSettings,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: selected ? const Color(0xFFFBEAEA) : Colors.transparent,
              border: Border.all(
                color: selected ? const Color(0xFFF2CACA) : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  leading,
                  size: 18,
                  color: selected ? _primary : _textMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? _primary : _textDark,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Channel options',
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    size: 18,
                    color: selected ? _primary : _textMuted,
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'settings':
                        onSettings?.call();
                        break;
                      case 'eod':
                        onEodSettings?.call();
                        break;
                      case 'delete':
                        onDelete?.call();
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    if (onSettings != null)
                      const PopupMenuItem(
                        value: 'settings',
                        child: Row(
                          children: [
                            Icon(Icons.settings_outlined, size: 18),
                            SizedBox(width: 10),
                            Text('Channel settings'),
                          ],
                        ),
                      ),
                    if (onEodSettings != null)
                      const PopupMenuItem(
                        value: 'eod',
                        child: Row(
                          children: [
                            Icon(Icons.summarize_outlined, size: 18),
                            SizedBox(width: 10),
                            Text('EOD settings'),
                          ],
                        ),
                      ),
                    if (onDelete != null) const PopupMenuDivider(),
                    if (onDelete != null)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: Colors.red,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Delete channel',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dmTile({
    required String name,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: selected ? const Color(0xFFFBEAEA) : Colors.transparent,
              border: Border.all(
                color: selected ? const Color(0xFFF2CACA) : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor:
                      selected ? _primary : const Color(0xFFEAEAF0),
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: selected ? _white : _textDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? _primary : _textDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFBEAEA),
                border: Border.all(color: const Color(0xFFF2CACA)),
              ),
              child: Icon(icon, color: _primary, size: 34),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: _textMuted,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _directMessagesHeader(String currentUserId) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 12, 0, 4),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'DIRECT MESSAGES',
              style: TextStyle(
                fontSize: 11,
                color: _textMuted,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ),
          IconButton(
            tooltip: 'New direct message',
            icon: const Icon(
              Icons.add_comment_outlined,
              size: 18,
              color: _primary,
            ),
            onPressed: selectedWorkspaceId == null
                ? null
                : () => _openNewDirectMessageDialog(currentUserId),
          ),
        ],
      ),
    );
  }

  Widget _channelsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 0, 0),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'CHANNELS',
              style: TextStyle(
                fontSize: 11,
                color: _textMuted,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Create channel',
            icon: const Icon(
              Icons.add_box_outlined,
              size: 18,
              color: _primary,
            ),
            onPressed:
                selectedWorkspaceId == null ? null : _openCreateChannelDialog,
          ),
        ],
      ),
    );
  }
}
