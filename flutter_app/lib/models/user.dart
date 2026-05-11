class User {
  final String id;
  final String name;
  final String email;
  final String avatar;
  final String status;
  final String statusMessage;
  final String? token;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.avatar = '',
    this.status = 'offline',
    this.statusMessage = '',
    this.token,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      avatar: json['avatar'] ?? '',
      status: json['status'] ?? 'offline',
      statusMessage: json['statusMessage'] ?? '',
      token: json['token'],
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'name': name,
        'email': email,
        'avatar': avatar,
        'status': status,
        'statusMessage': statusMessage,
      };
}
