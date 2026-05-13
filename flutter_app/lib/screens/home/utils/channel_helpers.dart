import '../../../core/utils/json_utils.dart';
import '../../../models/channel.dart';

bool canManageChannel(Channel channel, String currentUserId) {
  if (currentUserId.isEmpty) return false;

  return channel.createdBy == currentUserId ||
      channel.admins.contains(currentUserId);
}

String channelName(String value) => cleanChannelName(value);
