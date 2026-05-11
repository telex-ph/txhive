import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/channel.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../providers/auth_provider.dart';
import '../config/constants.dart';

class ChatScreen extends StatefulWidget {
  final Channel channel;
  const ChatScreen({super.key, required this.channel});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<Message> messages = [];
  bool loading = true;
  bool sending = false;
  final Set<String> typingUsers = {};

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _setupSocket();
  }

  @override
  void dispose() {
    SocketService.leaveChannel(widget.channel.id);
    SocketService.off('message:new');
    SocketService.off('message:updated');
    SocketService.off('message:deleted');
    SocketService.off('typing:start');
    SocketService.off('typing:stop');
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _setupSocket() {
    SocketService.joinChannel(widget.channel.id);

    SocketService.on('message:new', (data) {
      try {
        final m = Message.fromJson(Map<String, dynamic>.from(data));
        if (m.channelId == widget.channel.id) {
          setState(() => messages.add(m));
          _scrollToBottom();
        }
      } catch (_) {}
    });

    SocketService.on('message:deleted', (data) {
      final id = data['_id'];
      setState(() => messages.removeWhere((m) => m.id == id));
    });

    SocketService.on('typing:start', (data) {
      if (data['channelId'] == widget.channel.id) {
        final name = data['user']?['name'] ?? '';
        setState(() => typingUsers.add(name));
      }
    });

    SocketService.on('typing:stop', (data) {
      if (data['channelId'] == widget.channel.id) {
        setState(() => typingUsers.clear());
      }
    });
  }

  Future<void> _loadMessages() async {
    setState(() => loading = true);
    try {
      final data = await ApiService.get('/messages/${widget.channel.id}');
      messages = (data as List).map((m) => Message.fromJson(m)).toList();
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => loading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || sending) return;
    setState(() => sending = true);
    _msgCtrl.clear();
    SocketService.typingStop(widget.channel.id);
    try {
      await ApiService.post('/messages', {'channel': widget.channel.id, 'content': text});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthProvider>().user?.id ?? '';

    return Column(
      children: [
        // Channel header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            children: [
              Icon(widget.channel.type == 'dm' ? Icons.person : Icons.tag, size: 20),
              const SizedBox(width: 8),
              Text(
                widget.channel.displayName(currentUserId),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        // Messages
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (_, i) => _MessageBubble(message: messages[i], isMe: messages[i].sender.id == currentUserId),
                ),
        ),
        // Typing indicator
        if (typingUsers.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Text(
              '${typingUsers.join(", ")} ${typingUsers.length == 1 ? "is" : "are"} typing...',
              style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ),
        // Input
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.attach_file), onPressed: () {}),
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  decoration: InputDecoration(
                    hintText: 'Message #${widget.channel.name}',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    fillColor: Colors.grey[100],
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onChanged: (v) {
                    if (v.isNotEmpty) {
                      SocketService.typingStart(widget.channel.id);
                    } else {
                      SocketService.typingStop(widget.channel.id);
                    }
                  },
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send, color: Color(AppColors.primaryColor)),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(AppColors.primaryColor),
            child: Text(
              message.sender.name.isNotEmpty ? message.sender.name[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(message.sender.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('h:mm a').format(message.createdAt.toLocal()),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    if (message.edited)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Text('(edited)', style: TextStyle(color: Colors.grey, fontSize: 11)),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(message.content, style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
