import 'user.dart';

class Attachment {
  final String url;
  final String type;
  final String name;
  final int size;

  Attachment({required this.url, required this.type, required this.name, this.size = 0});

  factory Attachment.fromJson(Map<String, dynamic> json) => Attachment(
        url: json['url'] ?? '',
        type: json['type'] ?? 'file',
        name: json['name'] ?? '',
        size: json['size'] ?? 0,
      );
}

class Message {
  final String id;
  final String channelId;
  final User sender;
  final String content;
  final List<Attachment> attachments;
  final DateTime createdAt;
  final bool edited;
  final bool deleted;
  final List<Map<String, dynamic>> reactions;

  Message({
    required this.id,
    required this.channelId,
    required this.sender,
    required this.content,
    this.attachments = const [],
    required this.createdAt,
    this.edited = false,
    this.deleted = false,
    this.reactions = const [],
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    List<Attachment> atts = [];
    if (json['attachments'] is List) {
      for (var a in json['attachments']) {
        if (a is Map<String, dynamic>) atts.add(Attachment.fromJson(a));
      }
    }

    User sender;
    if (json['sender'] is Map<String, dynamic>) {
      sender = User.fromJson(json['sender']);
    } else {
      sender = User(id: json['sender']?.toString() ?? '', name: 'Unknown', email: '');
    }

    List<Map<String, dynamic>> reactions = [];
    if (json['reactions'] is List) {
      for (var r in json['reactions']) {
        if (r is Map<String, dynamic>) reactions.add(r);
      }
    }

    return Message(
      id: json['_id'] ?? '',
      channelId: json['channel']?.toString() ?? '',
      sender: sender,
      content: json['content'] ?? '',
      attachments: atts,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      edited: json['edited'] ?? false,
      deleted: json['deleted'] ?? false,
      reactions: reactions,
    );
  }
}
