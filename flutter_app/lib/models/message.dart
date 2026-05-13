import 'user.dart';

class Attachment {
  final String url;
  final String type;
  final String name;
  final int size;

  Attachment({
    required this.url,
    required this.type,
    required this.name,
    this.size = 0,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      url: (json['url'] ?? '').toString(),
      type: (json['type'] ?? 'file').toString(),
      name: (json['name'] ?? '').toString(),
      size: json['size'] is int
          ? json['size']
          : int.tryParse((json['size'] ?? '0').toString()) ?? 0,
    );
  }
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

  static String _readId(dynamic value) {
    if (value == null) return '';

    if (value is Map) {
      return (value['_id'] ?? value['id'] ?? '').toString();
    }

    return value.toString();
  }

  static User _senderFromJson(dynamic value) {
    if (value is Map) {
      return User.fromJson(
        Map<String, dynamic>.from(value),
      );
    }

    return User.fromJson({
      '_id': value?.toString() ?? '',
      'name': 'Unknown',
      'email': '',
      'avatar': '',
      'status': 'offline',
      'statusMessage': '',
    });
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    final attachments = <Attachment>[];

    if (json['attachments'] is List) {
      for (final item in json['attachments']) {
        if (item is Map) {
          attachments.add(
            Attachment.fromJson(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }

    final reactions = <Map<String, dynamic>>[];

    if (json['reactions'] is List) {
      for (final item in json['reactions']) {
        if (item is Map) {
          reactions.add(Map<String, dynamic>.from(item));
        }
      }
    }

    return Message(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      channelId: _readId(json['channel'] ?? json['channelId']),
      sender: _senderFromJson(json['sender']),
      content: (json['content'] ?? '').toString(),
      attachments: attachments,
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      edited: json['edited'] == true,
      deleted: json['deleted'] == true,
      reactions: reactions,
    );
  }
}
