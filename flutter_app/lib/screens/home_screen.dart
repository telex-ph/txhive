import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/app_empty_state.dart';
import '../models/channel.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';
import 'eod_settings_screen.dart';
import 'home/dialogs/channel_members_dialog.dart';
import 'home/dialogs/channel_settings_dialog.dart';
import 'home/dialogs/create_channel_dialog.dart';
import 'home/dialogs/new_direct_message_dialog.dart';
import 'home/dialogs/workspace_dialog.dart';
import 'home/utils/channel_helpers.dart';
import 'home/widgets/channel_sidebar.dart';
import 'home/widgets/workspace_rail.dart';
import 'workspace_details_screen.dart';
import 'profile/edit_profile_dialog.dart';
import 'home/widgets/shell_top_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<dynamic> workspaces = [];
  List<Channel> channels = [];
  List<Channel> dms = [];
  String? selectedWorkspaceId;
  Channel? selectedChannel;
  bool loading = true;

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

  Future<void> _loadChannels(String workspaceId) async {
    final data = await ApiService.get('/channels/workspace/$workspaceId');
    channels = (data as List).map((item) => Channel.fromJson(item)).toList();

    if (channels.isNotEmpty && selectedChannel == null) {
      selectedChannel = channels.first;
    }
  }

  Future<void> _loadDms() async {
    final data = await ApiService.get('/channels/dms');
    dms = (data as List).map((item) => Channel.fromJson(item)).toList();
  }

  Future<void> _selectWorkspace(dynamic workspace) async {
    final workspaceId = workspace['_id']?.toString();
    if (workspaceId == null || workspaceId.isEmpty) return;

    setState(() {
      selectedWorkspaceId = workspaceId;
      selectedChannel = null;
    });

    await _loadChannels(workspaceId);

    if (mounted) setState(() {});
  }

  Future<void> _openEditProfileDialog() async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => const EditProfileDialog(),
    );

    if (updated == true && mounted) {
      setState(() {});
      await _loadData();
    }
  }

  void _selectChannel(Channel channel) {
    setState(() => selectedChannel = channel);

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
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
        if (!exists) dms.insert(0, dm);
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

    try {
      final data = await ApiService.get('/workspaces/$selectedWorkspaceId');
      final rawMembers = (data['members'] as List?) ?? [];

      final members = rawMembers.where((member) {
        final user = member['user'];
        if (user is! Map) return false;
        return user['_id']?.toString() != currentUserId;
      }).toList();

      if (!mounted) return;

      final userId = await showNewDirectMessageDialog(
        context,
        members: members,
      );

      if (userId == null || userId.isEmpty) return;

      await _createOrOpenDm(userId);

      if (!mounted) return;

      if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _openCreateChannelDialog() async {
    if (selectedWorkspaceId == null) {
      _showError('Please select a workspace first');
      return;
    }

    final result = await showCreateChannelDialog(context);
    if (result == null) return;

    try {
      final data = await ApiService.post(
        '/channels',
        {
          'name': result.name,
          'description': result.description,
          'workspace': selectedWorkspaceId,
          'isPrivate': result.isPrivate,
        },
      );

      final newChannel = Channel.fromJson(data);
      await _loadChannels(selectedWorkspaceId!);

      if (!mounted) return;

      setState(() => selectedChannel = newChannel);

      if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _openChannelSettingsDialog(Channel channel) async {
    if (!_canCurrentUserManageChannel(channel)) {
      _showError(
          'Only the channel owner or channel admin can update this channel');
      return;
    }

    final result = await showChannelSettingsDialog(
      context,
      channel: channel,
    );

    if (result == null) return;

    try {
      await ApiService.put(
        '/channels/${channel.id}',
        {
          'name': result.name,
          'description': result.description,
          'isPrivate': result.isPrivate,
        },
      );

      await _refreshChannelsAfterChange(channel.id);
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _openChannelMembersDialog(Channel channel) async {
    if (selectedWorkspaceId == null) return;

    await showChannelMembersDialog(
      context,
      channel: channel,
      onSaved: () => _refreshChannelsAfterChange(channel.id),
      onError: _showError,
    );
  }

  Future<void> _confirmDeleteChannel(Channel channel) async {
    if (!_canCurrentUserManageChannel(channel)) {
      _showError(
          'Only the channel owner or channel admin can delete this channel');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete channel?'),
          content: Text(
            'This will delete #${channelName(channel.name)} and its messages. This action cannot be undone.',
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

    if (!_canCurrentUserManageChannel(channel)) {
      _showError(
          'Only the channel owner or channel admin can delete this channel');
      return;
    }

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

  Future<void> _refreshChannelsAfterChange(String channelId) async {
    if (selectedWorkspaceId == null) return;

    final wasSelected = selectedChannel?.id == channelId;
    await _loadChannels(selectedWorkspaceId!);

    if (!mounted) return;

    setState(() {
      if (wasSelected) {
        final index = channels.indexWhere((channel) => channel.id == channelId);
        selectedChannel = index >= 0
            ? channels[index]
            : channels.isNotEmpty
                ? channels.first
                : null;
      }
    });
  }

  Future<void> _createWorkspace() async {
    final result = await showWorkspaceDialog(
      context,
      title: 'Create Workspace',
      hint: 'Workspace name',
      actionLabel: 'Create',
      icon: Icons.add_business_rounded,
    );

    if (result == null || result.trim().isEmpty) return;

    try {
      await ApiService.post('/workspaces', {'name': result.trim()});
      await _loadData();
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _joinWorkspace() async {
    final code = await showWorkspaceDialog(
      context,
      title: 'Join Workspace',
      hint: 'Invite code',
      actionLabel: 'Join',
      icon: Icons.group_add_rounded,
    );

    if (code == null || code.trim().isEmpty) return;

    try {
      await ApiService.post('/workspaces/join', {'inviteCode': code.trim()});
      await _loadData();
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _openWorkspaceDetails() {
    if (selectedWorkspaceId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkspaceDetailsScreen(
          workspaceId: selectedWorkspaceId!,
        ),
      ),
    ).then((_) => _loadData());
  }

  void _openEodSettings() {
    if (selectedChannel == null || selectedWorkspaceId == null) return;

    if (selectedChannel!.type != 'channel') {
      _showError('EOD settings only available for channels');
      return;
    }

    _openEodSettingsFor(selectedChannel!);
  }

  void _openEodSettingsFor(Channel channel) {
    if (selectedWorkspaceId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EodSettingsScreen(
          channelId: channel.id,
          channelName: channelName(channel.name),
          workspaceId: selectedWorkspaceId!,
        ),
      ),
    );
  }

  bool _canCurrentUserManageChannel(Channel channel) {
    final currentUserId = context.read<AuthProvider>().user?.id ?? '';
    return canManageChannel(channel, currentUserId);
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.replaceAll('Exception: ', '')),
        backgroundColor: AppColors.dark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final currentUserId = user?.id ?? '';
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 720;

    if (loading) {
      return const Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final workspaceRail = WorkspaceRail(
      workspaces: workspaces,
      selectedWorkspaceId: selectedWorkspaceId,
      onWorkspaceSelected: _selectWorkspace,
      onCreateWorkspace: _createWorkspace,
      onJoinWorkspace: _joinWorkspace,
    );

    final channelSidebar = ChannelSidebar(
      workspaces: workspaces,
      channels: channels,
      dms: dms,
      selectedWorkspaceId: selectedWorkspaceId,
      selectedChannel: selectedChannel,
      currentUserId: currentUserId,
      onOpenWorkspaceDetails: _openWorkspaceDetails,
      onCreateChannel: _openCreateChannelDialog,
      onNewDirectMessage: () => _openNewDirectMessageDialog(currentUserId),
      onSelectChannel: _selectChannel,
      onOpenChannelSettings: _openChannelSettingsDialog,
      onOpenChannelMembers: _openChannelMembersDialog,
      onOpenEodSettings: _openEodSettingsFor,
      onDeleteChannel: _confirmDeleteChannel,
    );

    if (isMobile) {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppColors.surface,
        appBar: _MobileHomeAppBar(
          selectedChannel: selectedChannel,
          currentUserId: currentUserId,
          selectedWorkspaceId: selectedWorkspaceId,
          onOpenWorkspaceDetails: _openWorkspaceDetails,
          onOpenEodSettings: _openEodSettings,
        ),
        drawer: SizedBox(
          width: width < 420 ? width * 0.92 : 380,
          child: Drawer(
            backgroundColor: AppColors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            child: SafeArea(
              child: Row(
                children: [
                  SizedBox(width: 72, child: workspaceRail),
                  Expanded(child: channelSidebar),
                ],
              ),
            ),
          ),
        ),
        body: selectedChannel == null
            ? const AppEmptyState(
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
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            ShellTopBar(
              title: 'TxHive',
              onOpenProfile: _openEditProfileDialog,
              onLogout: () => context.read<AuthProvider>().logout(),
            ),
            Expanded(
              child: Row(
                children: [
                  SizedBox(width: 72, child: workspaceRail),
                  Container(
                    width: 300,
                    decoration: _sidebarPanelDecoration(),
                    child: channelSidebar,
                  ),
                  Expanded(
                    child: Container(
                      decoration: _chatPanelDecoration(),
                      child: selectedChannel == null
                          ? const AppEmptyState(
                              icon: Icons.chat_bubble_outline_rounded,
                              title: 'Select a channel',
                              subtitle:
                                  'Choose a channel or direct message from the sidebar to start chatting.',
                            )
                          : ChatScreen(
                              channel: selectedChannel!,
                              key: ValueKey(selectedChannel!.id),
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

  BoxDecoration _sidebarPanelDecoration() {
    return const BoxDecoration(
      color: AppColors.white,
      border: Border(
        right: BorderSide(color: AppColors.border),
      ),
    );
  }

  BoxDecoration _chatPanelDecoration() {
    return const BoxDecoration(
      color: AppColors.white,
    );
  }
}

class _MobileHomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Channel? selectedChannel;
  final String currentUserId;
  final String? selectedWorkspaceId;
  final VoidCallback onOpenWorkspaceDetails;
  final VoidCallback onOpenEodSettings;

  const _MobileHomeAppBar({
    required this.selectedChannel,
    required this.currentUserId,
    required this.selectedWorkspaceId,
    required this.onOpenWorkspaceDetails,
    required this.onOpenEodSettings,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final title = selectedChannel == null
        ? 'TxHive'
        : selectedChannel!.type == 'channel'
            ? '# ${selectedChannel!.name}'
            : selectedChannel!.displayName(currentUserId);

    return AppBar(
      elevation: 0,
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.textDark,
      centerTitle: false,
      titleSpacing: 8,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const Text(
            'TelexPH Messaging Workspace',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
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
            onPressed: onOpenWorkspaceDetails,
          ),
        IconButton(
          icon: const Icon(Icons.summarize_outlined),
          tooltip: 'EOD Settings',
          onPressed: onOpenEodSettings,
        ),
      ],
    );
  }
}
