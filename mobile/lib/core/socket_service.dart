import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

/// Live events from the backend (/rt namespace):
///  - notification:new  -> fresh activity notification
///  - message:new       -> new DM message
///  - typing            -> other side is typing
///  - message:read      -> read receipts
class SocketService {
  io.Socket? _socket;
  String? _connectedForToken;

  final _notification = StreamController<Map<String, dynamic>>.broadcast();
  final _message = StreamController<Map<String, dynamic>>.broadcast();
  final _typing = StreamController<Map<String, dynamic>>.broadcast();
  final _read = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get notifications => _notification.stream;
  Stream<Map<String, dynamic>> get messages => _message.stream;
  Stream<Map<String, dynamic>> get typing => _typing.stream;
  Stream<Map<String, dynamic>> get reads => _read.stream;

  bool get connected => _socket?.connected ?? false;

  static String socketBase(String apiBaseUrl) =>
      apiBaseUrl.replaceAll(RegExp(r'/api/?$'), '');

  void connect(String apiBaseUrl, String token) {
    if (_connectedForToken == token && connected) return;
    disconnect();
    _connectedForToken = token;
    _socket = io.io(
      '${SocketService.socketBase(apiBaseUrl)}/rt',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableReconnection()
          .build(),
    )..onConnect((_) => _socket?.emit('ping'));
    _socket?.on('notification:new', (data) {
      if (data is Map<String, dynamic>) _notification.add(data);
    });
    _socket?.on('message:new', (data) {
      if (data is Map<String, dynamic>) _message.add(data);
    });
    _socket?.on('typing', (data) {
      if (data is Map<String, dynamic>) _typing.add(data);
    });
    _socket?.on('message:read', (data) {
      if (data is Map<String, dynamic>) _read.add(data);
    });
  }

  void emitTyping(String conversationId, bool typing) {
    _socket?.emit('typing', {'conversationId': conversationId, 'typing': typing});
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connectedForToken = null;
  }
}

final socketManager = SocketService();
