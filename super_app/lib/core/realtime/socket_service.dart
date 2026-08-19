import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'package:superapp_user/core/config/api_config.dart';

/// Events the user app cares about. `new_order`, `order_claimed` and friends
/// are restaurant/rider/admin events and are deliberately ignored.
enum OrderSocketEvent { statusUpdate, orderReady, riderMoved, dropOtp }

class OrderSocketMessage {
  final OrderSocketEvent event;
  final Map<String, dynamic> data;

  const OrderSocketMessage(this.event, this.data);

  static double? _num(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  // The location-update payload sends numbers (int or double), plus legacy
  // `boy_lat`/`boy_lng` aliases — parse all of them robustly.
  double? get lat => _num(data['lat'] ?? data['latitude'] ?? data['boy_lat']);
  double? get lng => _num(data['lng'] ?? data['longitude'] ?? data['boy_lng']);
  double get heading => _num(data['heading']) ?? 0.0;
  String? get otp => data['otp']?.toString();
  String? get orderId => (data['orderId'] ?? data['orderMongoId'])?.toString();
}

/// One `chat:message` or `chat:typing` payload.
class ChatSocketMessage {
  final Map<String, dynamic> data;
  const ChatSocketMessage(this.data);
}

/// The app's single Socket.IO connection — shared by order tracking and chat.
///
/// Sockets are an optimisation, not the contract — both tracking and chat
/// must still work by polling. This class never throws upward: if the socket
/// can't connect, callers simply keep polling/pulling.
///
/// One connection is opened for the app's lifetime (see
/// `di/socket_providers.dart`); `joinTracking`/`leaveTracking` layer per-order
/// rooms on top without opening a second connection.
class SocketService {
  io.Socket? _socket;
  final _orderController = StreamController<OrderSocketMessage>.broadcast();
  final _chatMessageController = StreamController<ChatSocketMessage>.broadcast();
  final _chatTypingController = StreamController<ChatSocketMessage>.broadcast();
  final Set<String> _trackedOrderIds = {};

  Stream<OrderSocketMessage> get orderEvents => _orderController.stream;
  Stream<ChatSocketMessage> get chatMessages => _chatMessageController.stream;
  Stream<ChatSocketMessage> get chatTyping => _chatTypingController.stream;
  bool get isConnected => _socket?.connected ?? false;

  /// Connects (or reconnects, if the token changed) once for the app.
  void connect(String accessToken) {
    if (_socket != null) return;

    try {
      final socket = io.io(
        ApiConfig.host,
        io.OptionBuilder()
            // Keep 'polling' first — some networks block the initial
            // websocket upgrade handshake.
            .setTransports(['polling', 'websocket'])
            .setAuth({'token': accessToken})
            .disableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(1 << 30)
            .setReconnectionDelay(2000)
            .setReconnectionDelayMax(10000)
            .build(),
      );

      // Re-joins every tracked room on every (re)connect, so a dropped socket
      // resumes tracking automatically without any caller doing anything.
      socket.onConnect((_) {
        _log('connected');
        for (final id in _trackedOrderIds) {
          socket.emit('join-tracking', id);
        }
      });
      socket.onReconnect((_) {
        _log('reconnected');
        for (final id in _trackedOrderIds) {
          socket.emit('join-tracking', id);
        }
      });

      socket.on('order_status_update', (d) => _emitOrder(OrderSocketEvent.statusUpdate, d));
      socket.on('order_ready', (d) => _emitOrder(OrderSocketEvent.orderReady, d));
      socket.on('location-update', (d) => _emitOrder(OrderSocketEvent.riderMoved, d));
      socket.on('delivery_drop_otp', (d) => _emitOrder(OrderSocketEvent.dropOtp, d));
      socket.on('chat:message', (d) => _emitChat(_chatMessageController, d));
      socket.on('chat:typing', (d) => _emitChat(_chatTypingController, d));

      socket.onConnectError((e) => _log('connect error: $e'));
      socket.onError((e) => _log('error: $e'));

      socket.connect();
      _socket = socket;
    } catch (e) {
      // Polling covers us; never surface a socket failure to the UI.
      _log('socket unavailable: $e');
    }
  }

  /// Joins `tracking:<orderId>` — the server verifies the order actually
  /// belongs to this user and silently refuses otherwise.
  void joinTracking(String orderId) {
    _trackedOrderIds.add(orderId);
    _socket?.emit('join-tracking', orderId);
  }

  void leaveTracking(String orderId) {
    _trackedOrderIds.remove(orderId);
    _socket?.emit('leave-tracking', orderId);
  }

  void emitChatTyping({
    required String toRole,
    String? toId,
    required String conversationId,
    required bool typing,
  }) {
    _socket?.emit('chat:typing', {
      'toRole': toRole,
      if (toId != null) 'toId': toId,
      'conversationId': conversationId,
      'typing': typing,
    });
  }

  void _emitOrder(OrderSocketEvent event, dynamic payload) {
    if (_orderController.isClosed) return;
    final map = payload is Map ? payload.cast<String, dynamic>() : <String, dynamic>{};
    _orderController.add(OrderSocketMessage(event, map));
  }

  void _emitChat(StreamController<ChatSocketMessage> controller, dynamic payload) {
    if (controller.isClosed) return;
    final map = payload is Map ? payload.cast<String, dynamic>() : <String, dynamic>{};
    controller.add(ChatSocketMessage(map));
  }

  /// Disconnects entirely — called on logout. A fresh [connect] re-opens.
  void disconnect() {
    final socket = _socket;
    _socket = null;
    _trackedOrderIds.clear();
    if (socket == null) return;
    try {
      socket.dispose();
    } catch (_) {
      // Already gone.
    }
  }

  void dispose() {
    disconnect();
    _orderController.close();
    _chatMessageController.close();
    _chatTypingController.close();
  }

  void _log(String msg) {
    if (kDebugMode) debugPrint('[Socket] $msg');
  }
}
