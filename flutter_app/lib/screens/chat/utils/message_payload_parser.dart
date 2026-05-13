import '../../../core/utils/json_utils.dart';
import '../../../models/message.dart';

class MessagePayloadParser {
  MessagePayloadParser._();

  static Message messageFromPayload(dynamic payload) {
    final map = asMap(payload);
    final rawMessage = map['message'] ?? map;
    return Message.fromJson(asMap(rawMessage));
  }

  static String messageIdFromPayload(dynamic payload) {
    if (payload is String) return payload;

    final map = asMap(payload);
    final messageMap = asMap(map['message']);

    return (map['_id'] ??
            map['id'] ??
            map['messageId'] ??
            messageMap['_id'] ??
            messageMap['id'] ??
            '')
        .toString();
  }

  static String channelIdFromPayload(dynamic payload, Message? message) {
    final map = asMap(payload);
    final messageMap = asMap(map['message']);

    return readId(
      map['channelId'] ??
          map['channel'] ??
          messageMap['channelId'] ??
          messageMap['channel'] ??
          message?.channelId,
    );
  }
}
