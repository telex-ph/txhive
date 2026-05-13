import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/json_utils.dart';
import '../core/widgets/app_empty_state.dart';
import '../models/channel.dart';
import '../models/message.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import 'chat/dialogs/confirm_delete_message_dialog.dart';
import 'chat/dialogs/edit_message_dialog.dart';
import 'chat/utils/message_payload_parser.dart';
import 'chat/widgets/chat_header.dart';
import 'chat/widgets/message_composer.dart';
import 'chat/widgets/message_list.dart';
import 'chat/widgets/typing_indicator.dart';

class ChatScreen extends StatefulWidget {
  final Channel channel;

  const ChatScreen({
    super.key,
    required this.channel,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final Map<String, Timer> _typingTimers = {};

  void Function(dynamic)? _onMessageNew;
  void Function(dynamic)? _onMessageUpdated;
  void Function(dynamic)? _onMessageDeleted;
  void Function(dynamic)? _onTypingStart;
  void Function(dynamic)? _onTypingStop;

  List<Message> messages = [];
  bool loading = true;
  bool sending = false;
  bool _isTyping = false;
  Timer? _selfTypingTimer;
  final Set<String> typingUsers = {};

  @override
  void initState() {
    super.initState();
    _setupSocket();
    _loadMessages();
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.channel.id == widget.channel.id) return;

    _stopTypingNow(channelId: oldWidget.channel.id);
    _teardownSocket(oldWidget.channel.id);

    setState(() {
      messages = [];
      typingUsers.clear();
      loading = true;
      sending = false;
    });

    _setupSocket();
    _loadMessages();
  }

  @override
  void dispose() {
    _stopTypingNow(emit: false);
    _teardownSocket(widget.channel.id);

    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _teardownSocket(String channelId) {
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    _typingTimers.clear();

    if (_onMessageNew != null) SocketService.off('message:new', _onMessageNew!);
    if (_onMessageUpdated != null) {
      SocketService.off('message:updated', _onMessageUpdated!);
    }
    if (_onMessageDeleted != null) {
      SocketService.off('message:deleted', _onMessageDeleted!);
    }
    if (_onTypingStart != null) {
      SocketService.off('typing:start', _onTypingStart!);
    }
    if (_onTypingStop != null) {
      SocketService.off('typing:stop', _onTypingStop!);
    }

    SocketService.leaveChannel(channelId);
  }

  void _setupSocket() {
    SocketService.joinChannel(widget.channel.id);

    _onMessageNew = (payload) {
      if (!mounted) return;

      try {
        final message = MessagePayloadParser.messageFromPayload(payload);
        final channelId = MessagePayloadParser.channelIdFromPayload(
          payload,
          message,
        );

        if (channelId != widget.channel.id &&
            message.channelId != widget.channel.id) {
          return;
        }

        if (messages.any((existing) => existing.id == message.id)) return;

        setState(() {
          messages.add(message);
          typingUsers.clear();
        });
        _scrollToBottom();
      } catch (e) {
        debugPrint('❌ Error parsing message:new: $e');
      }
    };

    _onMessageUpdated = (payload) {
      if (!mounted) return;

      try {
        final updatedMessage = MessagePayloadParser.messageFromPayload(payload);
        if (updatedMessage.channelId != widget.channel.id) return;

        setState(() {
          final index = messages.indexWhere((m) => m.id == updatedMessage.id);
          if (index == -1) {
            messages.add(updatedMessage);
          } else {
            messages[index] = updatedMessage;
          }
        });
      } catch (e) {
        debugPrint('❌ Error parsing message:updated: $e');
      }
    };

    _onMessageDeleted = (payload) {
      if (!mounted) return;

      final id = MessagePayloadParser.messageIdFromPayload(payload);
      if (id.isEmpty) return;

      setState(() {
        messages.removeWhere((message) => message.id == id);
      });
    };

    _onTypingStart = (payload) {
      final data = asMap(payload);
      final channelId = readId(data['channelId'] ?? data['channel']);
      if (!mounted || channelId != widget.channel.id) return;

      final user = asMap(data['user']);
      final name = (user['name'] ?? user['username'] ?? data['name'] ?? '')
          .toString();
      if (name.isEmpty) return;

      _typingTimers[name]?.cancel();
      setState(() => typingUsers.add(name));

      _typingTimers[name] = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => typingUsers.remove(name));
        _typingTimers.remove(name);
      });
    };

    _onTypingStop = (payload) {
      final data = asMap(payload);
      final channelId = readId(data['channelId'] ?? data['channel']);
      if (!mounted || channelId != widget.channel.id) return;

      final user = asMap(data['user']);
      final name = (user['name'] ?? user['username'] ?? data['name'] ?? '')
          .toString();

      _typingTimers[name]?.cancel();
      _typingTimers.remove(name);

      setState(() {
        if (name.isEmpty) {
          typingUsers.clear();
        } else {
          typingUsers.remove(name);
        }
      });
    };

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
      final loadedMessages = (data as List)
          .map((item) => Message.fromJson(asMap(item)))
          .toList();

      if (!mounted) return;

      setState(() {
        messages = loadedMessages;
      });
    } catch (e) {
      debugPrint('❌ Load messages error: $e');
      _showSnack(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || sending) return;

    final channelId = widget.channel.id;

    setState(() {
      sending = true;
      typingUsers.clear();
    });

    _msgCtrl.clear();
    _stopTypingNow(channelId: channelId);

    try {
      final data = await ApiService.post(
        '/messages',
        {
          'channel': channelId,
          'content': text,
        },
      );

      final newMessage = MessagePayloadParser.messageFromPayload(data);

      if (!mounted || widget.channel.id != channelId) return;

      if (!messages.any((message) => message.id == newMessage.id)) {
        setState(() => messages.add(newMessage));
        _scrollToBottom();
      }
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _copyMessage(Message message) async {
    await Clipboard.setData(ClipboardData(text: message.content));
    _showSnack('Message copied');
  }

  Future<void> _editMessage(Message message) async {
    final updatedText = await showEditMessageDialog(
      context,
      initialContent: message.content,
    );

    final text = updatedText?.trim() ?? '';
    if (text.isEmpty || text == message.content.trim()) return;

    try {
      final data = await ApiService.put(
        '/messages/${message.id}',
        {'content': text},
      );

      final updatedMessage = MessagePayloadParser.messageFromPayload(data);
      if (!mounted) return;

      setState(() {
        final index = messages.indexWhere((m) => m.id == updatedMessage.id);
        if (index != -1) messages[index] = updatedMessage;
      });
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _deleteMessage(Message message) async {
    final confirmed = await confirmDeleteMessageDialog(context);
    if (!confirmed) return;

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

  void _handleTypingChanged(String value) {
    final text = value.trim();

    if (text.isEmpty) {
      _stopTypingNow();
      return;
    }

    if (!_isTyping) {
      _isTyping = true;
      SocketService.typingStart(widget.channel.id);
    }

    _selfTypingTimer?.cancel();
    _selfTypingTimer = Timer(const Duration(milliseconds: 1200), () {
      _stopTypingNow();
    });
  }

  void _stopTypingNow({String? channelId, bool emit = true}) {
    _selfTypingTimer?.cancel();
    _selfTypingTimer = null;

    if (!_isTyping) return;

    _isTyping = false;
    if (emit) SocketService.typingStop(channelId ?? widget.channel.id);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.dark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthProvider>().user?.id ?? '';
    final isMobile = MediaQuery.of(context).size.width < 720;

    return Container(
      color: AppColors.white,
      child: Column(
        children: [
          if (!isMobile)
            ChatHeader(
              channel: widget.channel,
              currentUserId: currentUserId,
            ),
          Expanded(
            child: Container(
              color: AppColors.surface,
              child: loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : messages.isEmpty
                      ? AppEmptyState(
                          icon: widget.channel.type == 'dm'
                              ? Icons.chat_bubble_outline_rounded
                              : Icons.forum_outlined,
                          title: widget.channel.type == 'dm'
                              ? 'No messages yet'
                              : 'Start the conversation',
                          subtitle:
                              'Send the first message and begin chatting with your team.',
                        )
                      : MessageList(
                          messages: messages,
                          currentUserId: currentUserId,
                          scrollController: _scrollCtrl,
                          isMobile: isMobile,
                          onCopy: _copyMessage,
                          onEdit: _editMessage,
                          onDelete: _deleteMessage,
                        ),
            ),
          ),
          if (typingUsers.isNotEmpty)
            TypingIndicator(typingUsers: typingUsers),
          MessageComposer(
            controller: _msgCtrl,
            channelName: widget.channel.name,
            isChannel: widget.channel.type == 'channel',
            sending: sending,
            onSend: _sendMessage,
            onChanged: _handleTypingChanged,
          ),
        ],
      ),
    );
  }
}
