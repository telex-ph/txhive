import 'user.dart';

class Channel {
  final String id;
  final String name;
  final String description;
  final String type; // 'channel', 'dm', 'group'
  final bool isPrivate;
  final String? workspace;
  final List<User> members;
  final DateTime? lastActivity;

  Channel({
    required this.id,
    required this.name,
    required this.type,
    this.description = '',
    this.isPrivate = false,
    this.workspace,
    this.members = const [],
    this.lastActivity,
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    List<User> members = [];
    if (json['members'] is List) {
      for (var m in json['members']) {
        if (m is Map<String, dynamic>) {
          members.add(User.fromJson(m));
        }
      }
    }

    return Channel(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      type: json['type'] ?? 'channel',
      isPrivate: json['isPrivate'] ?? false,
      workspace: json['workspace'] is String ? json['workspace'] : null,
      members: members,
      lastActivity: json['lastActivity'] != null ? DateTime.tryParse(json['lastActivity']) : null,
    );
  }

  String displayName(String currentUserId) {
    if (type == 'dm') {
      final other = members.where((m) => m.id != currentUserId).firstOrNull;
      return other?.name ?? 'DM';
    }
    return name;
  }
}

extension FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
