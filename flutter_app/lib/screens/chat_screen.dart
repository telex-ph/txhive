import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/channel.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../providers/auth_provider.dart';
import 'dart:async';
import 'package:flutter/services.dart';

class SendMessageIntent extends Intent {
  const SendMessageIntent();
}

class InsertNewLineIntent extends Intent {
  const InsertNewLineIntent();
}

class ChatScreen extends StatefulWidget {
  final Channel channel;
  const ChatScreen({super.key, required this.channel});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  void Function(dynamic)? _onMessageNew;
  void Function(dynamic)? _onMessageDeleted;
  void Function(dynamic)? _onTypingStart;
  void Function(dynamic)? _onTypingStop;
  void Function(dynamic)? _onMessageUpdated;

  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final Map<String, Timer> _typingTimers = {};

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
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    _typingTimers.clear();

    if (_onMessageNew != null) SocketService.off('message:new', _onMessageNew!);
    if (_onMessageUpdated != null)
      SocketService.off('message:updated', _onMessageUpdated!);
    if (_onMessageDeleted != null)
      SocketService.off('message:deleted', _onMessageDeleted!);
    if (_onTypingStart != null)
      SocketService.off('typing:start', _onTypingStart!);
    if (_onTypingStop != null) SocketService.off('typing:stop', _onTypingStop!);

    SocketService.leaveChannel(widget.channel.id);
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  Message _messageFromPayload(dynamic payload) {
    final map = _asMap(payload);
    final rawMessage = map['message'] ?? map;

    return Message.fromJson(
      Map<String, dynamic>.from(rawMessage as Map),
    );
  }

  String _messageIdFromPayload(dynamic payload) {
    if (payload is String) return payload;

    final map = _asMap(payload);
    final rawMessage = map['message'];
    final messageMap =
        rawMessage is Map ? Map<String, dynamic>.from(rawMessage) : null;

    return (map['_id'] ??
            map['id'] ??
            map['messageId'] ??
            messageMap?['_id'] ??
            messageMap?['id'] ??
            '')
        .toString();
  }

  void _showSnack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _dark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  void _insertNewLine() {
    final text = _msgCtrl.text;
    final selection = _msgCtrl.selection;

    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;

    final nextText = text.replaceRange(start, end, '\n');

    _msgCtrl.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: start + 1),
    );
  }

  void _setupSocket() {
    SocketService.joinChannel(widget.channel.id);

    _onMessageNew = (data) {
      if (!mounted) return;
      try {
        final m = Message.fromJson(Map<String, dynamic>.from(data));
        if (m.channelId == widget.channel.id) {
          if (!messages.any((existing) => existing.id == m.id)) {
            setState(() => messages.add(m));
            _scrollToBottom();
          }
        }
      } catch (e) {
        debugPrint('❌ Error parsing socket message: $e');
      }
    };

    _onMessageUpdated = (data) {
      if (!mounted) return;

      try {
        final updatedMessage = _messageFromPayload(data);

        if (updatedMessage.channelId != widget.channel.id) return;

        setState(() {
          final index = messages.indexWhere((m) => m.id == updatedMessage.id);

          if (index != -1) {
            messages[index] = updatedMessage;
          } else {
            messages.add(updatedMessage);
          }
        });
      } catch (e) {
        debugPrint('❌ Error parsing socket message:updated: $e');
      }
    };

    _onMessageDeleted = (data) {
      if (!mounted) return;

      final id = _messageIdFromPayload(data);
      if (id.isEmpty) return;

      setState(() {
        messages.removeWhere((m) => m.id == id);
      });
    };

    _onTypingStart = (data) {
      if (!mounted) return;
      if (data['channelId'] == widget.channel.id) {
        final name = data['user']?['name'] ?? '';
        if (name.isNotEmpty) {
          // ✅ I-cancel ang dati bago mag-reset ng timer
          _typingTimers[name]?.cancel();

          setState(() => typingUsers.add(name));

          // ✅ Auto-remove kung 3 seconds walang bagong typing event
          _typingTimers[name] = Timer(const Duration(seconds: 3), () {
            if (mounted) setState(() => typingUsers.remove(name));
            _typingTimers.remove(name);
          });
        }
      }
    };

    _onTypingStop = (data) {
      if (!mounted) return;
      if (data['channelId'] == widget.channel.id) {
        final name = data['user']?['name'] ?? '';
        // ✅ I-cancel ang timer at tanggalin agad
        _typingTimers[name]?.cancel();
        _typingTimers.remove(name);
        setState(() => typingUsers.remove(name));
      }
    };

    // ✅ I-register ang mga stored handlers
    SocketService.on('message:new', _onMessageNew!);
    SocketService.on('message:updated', _onMessageUpdated!);
    SocketService.on('message:deleted', _onMessageDeleted!);
    SocketService.on('typing:start', _onTypingStart!);
    SocketService.on('typing:stop', _onTypingStop!);
  }

  Future<void> _loadMessages() async {
    setState(() => loading = true);
    try {
      final data = await ApiService.get('/messages/${widget.channel.id}');
      messages = (data as List).map((m) => Message.fromJson(m)).toList();
    } catch (e) {
      debugPrint('❌ Load messages error: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: _dark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || sending) return;

    setState(() {
      sending = true;
      typingUsers.clear();
    });
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

  Future<void> _copyMessage(Message message) async {
    await Clipboard.setData(
      ClipboardData(text: message.content),
    );

    _showSnack('Message copied');
  }

  Future<void> _openEditMessageDialog(Message message) async {
    final ctrl = TextEditingController(text: message.content);

    final updatedText = await showDialog<String>(
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
                backgroundColor: _primary,
              ),
              child: const Text(
                'Save',
                style: TextStyle(color: _white),
              ),
            ),
          ],
        );
      },
    );

    ctrl.dispose();

    if (updatedText == null) return;

    await _editMessage(message, updatedText);
  }

  Future<void> _editMessage(Message message, String value) async {
    final text = value.trim();

    if (text.isEmpty) return;
    if (text == message.content.trim()) return;

    try {
      final data = await ApiService.put(
        '/messages/${message.id}',
        {
          'content': text,
        },
      );

      final updatedMessage = _messageFromPayload(data);

      if (!mounted) return;

      setState(() {
        final index = messages.indexWhere((m) => m.id == updatedMessage.id);

        if (index != -1) {
          messages[index] = updatedMessage;
        }
      });
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _confirmDeleteMessage(Message message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete message?'),
          content: const Text(
            'This message will be deleted from the conversation.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteMessage(message);
    }
  }

  Future<void> _deleteMessage(Message message) async {
    try {
      await ApiService.delete('/messages/${message.id}');

      if (!mounted) return;

      setState(() {
        messages.removeWhere((m) => m.id == message.id);
      });
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''));
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
                            final isMe = message.sender.id == currentUserId;

                            return _MessageBubble(
                              message: message,
                              isMe: isMe,
                              onCopy: () => _copyMessage(message),
                              onEdit: isMe
                                  ? () => _openEditMessageDialog(message)
                                  : null,
                              onDelete: isMe
                                  ? () => _confirmDeleteMessage(message)
                                  : null,
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
                child: Actions(
                  actions: <Type, Action<Intent>>{
                    SendMessageIntent: CallbackAction<SendMessageIntent>(
                      onInvoke: (_) {
                        _sendMessage();
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
                      const SingleActivator(LogicalKeyboardKey.enter,
                          shift: true): const InsertNewLineIntent(),
                    },
                    child: TextField(
                      controller: _msgCtrl,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
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
  final VoidCallback onCopy;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.onCopy,
    this.onEdit,
    this.onDelete,
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

    final actionMenu = PopupMenuButton<String>(
      tooltip: 'Message actions',
      icon: Icon(
        Icons.more_horiz_rounded,
        color: isMe ? _primary : _textMuted,
        size: 20,
      ),
      onSelected: (value) {
        switch (value) {
          case 'copy':
            onCopy();
            break;
          case 'edit':
            onEdit?.call();
            break;
          case 'delete':
            onDelete?.call();
            break;
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'copy',
          child: Row(
            children: [
              Icon(Icons.copy_rounded, size: 18),
              SizedBox(width: 10),
              Text('Copy'),
            ],
          ),
        ),
        if (onEdit != null)
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 18),
                SizedBox(width: 10),
                Text('Edit'),
              ],
            ),
          ),
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
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ],
            ),
          ),
      ],
    );

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
          if (isMe) actionMenu,
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
                  SelectableText(
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
          if (!isMe) ...[
            const SizedBox(width: 4),
            actionMenu,
          ],
          if (isMe) const SizedBox(width: 2),
        ],
      ),
    );
  }
}
