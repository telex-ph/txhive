import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/constants.dart';
import 'api_service.dart';

class SocketService {
  static IO.Socket? _socket;

  static IO.Socket? get socket => _socket;

  static Future<void> connect() async {
    if (_socket != null && _socket!.connected) return;

    final token = await ApiService.getToken();
    if (token == null) return;

    _socket = IO.io(
      AppConfig.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) => print('✅ Socket connected'));
    _socket!.onDisconnect((_) => print('❌ Socket disconnected'));
    _socket!.onConnectError((err) => print('Socket connect error: $err'));
  }

  static void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  static void joinChannel(String channelId) {
    _socket?.emit('channel:join', channelId);
  }

  static void leaveChannel(String channelId) {
    _socket?.emit('channel:leave', channelId);
  }

  static void typingStart(String channelId) {
    _socket?.emit('typing:start', {'channelId': channelId});
  }

  static void typingStop(String channelId) {
    _socket?.emit('typing:stop', {'channelId': channelId});
  }

  static void on(String event, Function(dynamic) handler) {
    _socket?.on(event, handler);
  }

  static void off(String event, [Function(dynamic)? handler]) {
    if (handler != null) {
      _socket?.off(event, handler); // ✅ Tanggalin ang specific handler lang
    } else {
      _socket?.off(event); // Tanggalin lahat (for emergency use only)
    }
  }
}
