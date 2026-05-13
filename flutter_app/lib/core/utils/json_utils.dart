Map<String, dynamic> asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

String readId(dynamic value) {
  if (value == null) return '';

  if (value is Map) {
    return (value['_id'] ?? value['id'] ?? '').toString();
  }

  return value.toString();
}

String readUserName(dynamic value) {
  if (value is Map) {
    return (value['name'] ?? value['email'] ?? 'Unknown User').toString();
  }
  return 'Unknown User';
}

String cleanChannelName(String value) {
  return value.trim().replaceFirst(RegExp(r'^#+\s*'), '');
}
