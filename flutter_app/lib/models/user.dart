class User {
  final String id;
  final String name;
  final String email;
  final String avatar;
  final String status;
  final String statusMessage;
  final String jobTitle;
  final String department;
  final String phone;
  final String location;
  final String? token;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.avatar = '',
    this.status = 'offline',
    this.statusMessage = '',
    this.token,
    this.jobTitle = '',
    this.department = '',
    this.phone = '',
    this.location = '',
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
      jobTitle: (json['jobTitle'] ?? '').toString(),
      department: (json['department'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
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
