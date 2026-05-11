import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/channel.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../providers/auth_provider.dart';

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

  static const Color _primary = Color(0xFFA10000);
  static const Color _primaryDark = Color(0xFF650000);
  static const Color _dark = Color(0xFF171717);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _surface = Color(0xFFF7F7F9);
  static const Color _surfaceAlt = Color(0xFFF1F1F4);
  static const Color _textDark = Color(0xFF202020);
  static const Color _textMuted = Color(0xFF8A8A8F);
  static const Color _border = Color(0xFFE9E9ED);

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
        print(
            '🔔 Got message:new — channel: ${data['channel']} | current: ${widget.channel.id}');
        final m = Message.fromJson(Map<String, dynamic>.from(data));
        if (m.channelId == widget.channel.id) {
          // Prevent duplicate kung naipasok na via HTTP response
          if (!messages.any((existing) => existing.id == m.id)) {
            setState(() => messages.add(m));
            _scrollToBottom();
          }
        }
      } catch (e) {
        print('❌ Error parsing socket message: $e');
      }
    });

    SocketService.on('message:deleted', (data) {
      final id = data['_id'];
      setState(() => messages.removeWhere((m) => m.id == id));
    });

    SocketService.on('typing:start', (data) {
      if (data['channelId'] == widget.channel.id) {
        final name = data['user']?['name'] ?? '';
        if (name.isNotEmpty) {
          setState(() => typingUsers.add(name));
        }
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
      // ✅ Get response & add message immediately (fallback kung di gumana socket)
      final data = await ApiService.post(
        '/messages',
        {
          'channel': widget.channel.id,
          'content': text,
        },
      );

      final newMessage = Message.fromJson(Map<String, dynamic>.from(data));

      // Add only if not already added by socket broadcast
      if (mounted && !messages.any((m) => m.id == newMessage.id)) {
        setState(() => messages.add(newMessage));
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: _dark,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthProvider>().user?.id ?? '';
    final isMobile = MediaQuery.of(context).size.width < 720;

    return Container(
      color: _white,
      child: Column(
        children: [
          if (!isMobile) _buildHeader(currentUserId),
          Expanded(
            child: Container(
              color: _surface,
              child: loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _primary),
                    )
                  : messages.isEmpty
                      ? _buildEmptyMessages()
                      : ListView.builder(
                          controller: _scrollCtrl,
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 12 : 18,
                            vertical: 16,
                          ),
                          itemCount: messages.length,
                          itemBuilder: (_, i) {
                            final message = messages[i];
                            return _MessageBubble(
                              message: message,
                              isMe: message.sender.id == currentUserId,
                            );
                          },
                        ),
            ),
          ),
          if (typingUsers.isNotEmpty) _buildTypingIndicator(),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildHeader(String currentUserId) {
    final displayName = widget.channel.type == 'dm'
        ? widget.channel.displayName(currentUserId)
        : '# ${widget.channel.name}';

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
      decoration: const BoxDecoration(
        color: _white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [_primaryDark, _primary],
              ),
            ),
            child: Icon(
              widget.channel.type == 'dm'
                  ? Icons.person_outline_rounded
                  : Icons.tag_rounded,
              color: _white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.channel.type == 'dm'
                      ? 'Direct message conversation'
                      : 'Channel conversation',
                  style: const TextStyle(
                    fontSize: 12,
                    color: _textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMessages() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFBEAEA),
                border: Border.all(color: const Color(0xFFF2CACA)),
              ),
              child: Icon(
                widget.channel.type == 'dm'
                    ? Icons.chat_bubble_outline_rounded
                    : Icons.forum_outlined,
                color: _primary,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.channel.type == 'dm'
                  ? 'No messages yet'
                  : 'Start the conversation',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Send the first message and begin chatting with your team.',
              textAlign: TextAlign.center,
              style: TextStyle(
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

  Widget _buildTypingIndicator() {
    return Container(
      width: double.infinity,
      color: _surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Text(
            '${typingUsers.join(", ")} ${typingUsers.length == 1 ? "is" : "are"} typing...',
            style: const TextStyle(
              fontStyle: FontStyle.italic,
              color: _textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComposer() {
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
          color: _white,
          border: Border(top: BorderSide(color: _border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _surfaceAlt,
                borderRadius: BorderRadius.circular(14),
              ),
              child: IconButton(
                icon: const Icon(Icons.attach_file_rounded, color: _textMuted),
                onPressed: () {},
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _border),
                ),
                child: TextField(
                  controller: _msgCtrl,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: widget.channel.type == 'channel'
                        ? 'Message #${widget.channel.name}'
                        : 'Type a message...',
                    hintStyle: const TextStyle(
                      color: _textMuted,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
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
            ),
            const SizedBox(width: 10),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [_primaryDark, _primary],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _primary.withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: sending ? null : _sendMessage,
                icon: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: _white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, color: _white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;

  const _MessageBubble({
    required this.message,
    required this.isMe,
  });

  static const Color _primary = Color(0xFFA10000);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _textDark = Color(0xFF202020);
  static const Color _textMuted = Color(0xFF8A8A8F);
  static const Color _bubbleOther = Color(0xFFFFFFFF);
  static const Color _bubbleMe = Color(0xFFA10000);
  static const Color _border = Color(0xFFE9E9ED);

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('h:mm a').format(message.createdAt.toLocal());
    final initial = message.sender.name.isNotEmpty
        ? message.sender.name[0].toUpperCase()
        : '?';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFF2D7D7),
              child: Text(
                initial,
                style: const TextStyle(
                  color: _primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.68,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              decoration: BoxDecoration(
                color: isMe ? _bubbleMe : _bubbleOther,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 6),
                  bottomRight: Radius.circular(isMe ? 6 : 18),
                ),
                border: isMe ? null : Border.all(color: _border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.sender.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: _textDark,
                        ),
                      ),
                    ),
                  Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.45,
                      color: isMe ? _white : _textDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.edited)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            'edited',
                            style: TextStyle(
                              color: isMe
                                  ? Colors.white.withOpacity(0.85)
                                  : _textMuted,
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      Text(
                        time,
                        style: TextStyle(
                          color: isMe
                              ? Colors.white.withOpacity(0.88)
                              : _textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 2),
        ],
      ),
    );
  }
}
