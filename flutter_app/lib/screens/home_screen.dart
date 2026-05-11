import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../config/constants.dart';
import '../models/channel.dart';
import 'chat_screen.dart';

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
    if (channels.isNotEmpty) selectedChannel = channels.first;
  }

  Future<void> _loadDms() async {
    final data = await ApiService.get('/channels/dms');
    dms = (data as List).map((c) => Channel.fromJson(c)).toList();
  }

  Future<void> _createWorkspace() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New Workspace'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Workspace name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Create')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      try {
        await ApiService.post('/workspaces', {'name': result});
        await _loadData();
      } catch (e) {
        _showError(e.toString());
      }
    }
  }

  Future<void> _joinWorkspace() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Join Workspace'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Invite code')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Join')),
        ],
      ),
    );
    if (code != null && code.isNotEmpty) {
      try {
        await ApiService.post('/workspaces/join', {'inviteCode': code});
        await _loadData();
      } catch (e) {
        _showError(e.toString());
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg.replaceAll('Exception: ', '')), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isWide = MediaQuery.of(context).size.width > 800;

    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Row(
        children: [
          // Workspace rail (Teams-style left bar)
          Container(
            width: 68,
            color: const Color(AppColors.sidebar),
            child: Column(
              children: [
                const SizedBox(height: 16),
                ...workspaces.map((w) {
                  final isSelected = w['_id'] == selectedWorkspaceId;
                  return GestureDetector(
                    onTap: () async {
                      setState(() => selectedWorkspaceId = w['_id']);
                      await _loadChannels(w['_id']);
                      setState(() {});
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(AppColors.primaryColor) : Colors.grey[700],
                        borderRadius: BorderRadius.circular(isSelected ? 12 : 24),
                      ),
                      child: Center(
                        child: Text(
                          (w['name'] as String).substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                    ),
                  );
                }),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: _createWorkspace,
                  tooltip: 'Create workspace',
                ),
                IconButton(
                  icon: const Icon(Icons.group_add, color: Colors.white),
                  onPressed: _joinWorkspace,
                  tooltip: 'Join workspace',
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  onPressed: () => context.read<AuthProvider>().logout(),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          // Channel list
          Container(
            width: 260,
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    workspaces.firstWhere((w) => w['_id'] == selectedWorkspaceId, orElse: () => {'name': 'No workspace'})['name'],
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text('CHANNELS', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                ...channels.map((c) => ListTile(
                      dense: true,
                      leading: Icon(c.isPrivate ? Icons.lock : Icons.tag, size: 18),
                      title: Text('# ${c.name}'),
                      selected: selectedChannel?.id == c.id,
                      onTap: () => setState(() => selectedChannel = c),
                    )),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text('DIRECT MESSAGES', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                ...dms.map((d) => ListTile(
                      dense: true,
                      leading: CircleAvatar(radius: 12, child: Text(d.displayName(user?.id ?? '').substring(0, 1))),
                      title: Text(d.displayName(user?.id ?? '')),
                      selected: selectedChannel?.id == d.id,
                      onTap: () => setState(() => selectedChannel = d),
                    )),
              ],
            ),
          ),
          // Chat area
          Expanded(
            child: selectedChannel == null
                ? const Center(child: Text('Select a channel to start chatting'))
                : ChatScreen(channel: selectedChannel!, key: ValueKey(selectedChannel!.id)),
          ),
        ],
      ),
    );
  }
}
