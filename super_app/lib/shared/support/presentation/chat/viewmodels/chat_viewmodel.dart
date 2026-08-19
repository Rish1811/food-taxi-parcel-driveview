import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:superapp_user/modules/food/data/models/chat_model.dart';
import 'package:superapp_user/shared/support/application/chat_providers.dart';
import 'package:superapp_user/core/network/network_providers.dart';
import 'package:superapp_user/core/push/push_providers.dart';
import 'package:superapp_user/modules/food/application/providers/socket_providers.dart';
import 'package:superapp_user/shared/auth/presentation/viewmodels/auth_viewmodel.dart';

/// Identifies one chat thread. For the delivery-partner chat, [orderId]
/// uniquely pins the conversation; support chat (`peerRole: ADMIN`) needs
/// neither [peerId] nor [orderId].
typedef ChatTarget = ({String peerRole, String? peerId, String? orderId});

class ChatState {
  final List<ChatMessage> messages;
  final String? conversationId;
  final bool isLoading;
  final bool isSending;
  final String? error;
  final bool peerTyping;

  const ChatState({
    this.messages = const [],
    this.conversationId,
    this.isLoading = true,
    this.isSending = false,
    this.error,
    this.peerTyping = false,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    String? conversationId,
    bool? isLoading,
    bool? isSending,
    String? error,
    bool? peerTyping,
    bool clearError = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      conversationId: conversationId ?? this.conversationId,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: clearError ? null : (error ?? this.error),
      peerTyping: peerTyping ?? this.peerTyping,
    );
  }
}

final chatViewModelProvider =
    NotifierProvider.family<ChatViewModel, ChatState, ChatTarget>(ChatViewModel.new);

class ChatViewModel extends Notifier<ChatState> {
  final ChatTarget arg;
  ChatViewModel(this.arg);

  StreamSubscription? _messageSub;
  StreamSubscription? _pushSub;
  StreamSubscription? _typingSub;
  Timer? _typingResetTimer;

  @override
  ChatState build() {
    ref.onDispose(() {
      _messageSub?.cancel();
      _pushSub?.cancel();
      _typingSub?.cancel();
      _typingResetTimer?.cancel();
    });
    _listenSocket();
    _listenPush();
    unawaited(Future.microtask(_init));
    return const ChatState();
  }

  void _listenPush() {
    final pushService = ref.read(pushServiceProvider);
    _pushSub = pushService.onForeground.listen((msg) {
      final data = msg.data;
      if (!_isForThisThread(data)) return;

      final map = Map<String, dynamic>.from(data);
      if (map['text'] == null || map['text'].toString().isEmpty) {
        map['text'] = msg.notification?.body ?? '';
      }
      if (map['createdAt'] == null) {
        map['createdAt'] = DateTime.now().toIso8601String();
      }

      final message = ChatMessage.fromApi(map);
      // Avoid duplicate messages
      if (state.messages.any((m) => m.id == message.id && m.id.isNotEmpty)) return;

      state = state.copyWith(
        messages: [...state.messages, message],
        conversationId: state.conversationId ?? message.conversationId,
      );

      final convId = state.conversationId;
      if (convId != null && convId.isNotEmpty) {
        unawaited(ref.read(chatRemoteDataSourceProvider).markRead(convId));
      }
    });
  }

  void _listenSocket() {
    final service = ref.read(socketServiceProvider);
    _messageSub = service.chatMessages.listen((msg) {
      final data = msg.data;
      if (!_isForThisThread(data)) return;
      final message = ChatMessage.fromApi(data);
      // Avoid duplicating a message we just sent and already appended
      // optimistically (same id arriving back over the socket).
      if (state.messages.any((m) => m.id == message.id && m.id.isNotEmpty)) return;
      state = state.copyWith(
        messages: [...state.messages, message],
        conversationId: state.conversationId ?? message.conversationId,
      );
      final convId = state.conversationId;
      if (convId != null && convId.isNotEmpty) {
        unawaited(ref.read(chatRemoteDataSourceProvider).markRead(convId));
      }
    });
    _typingSub = service.chatTyping.listen((msg) {
      if (!_isForThisThread(msg.data)) return;
      final typing = msg.data['typing'] as bool? ?? false;
      state = state.copyWith(peerTyping: typing);
    });
  }

  bool _isForThisThread(Map<String, dynamic> data) {
    final convId = state.conversationId;
    if (convId != null && data['conversationId'] == convId) return true;
    if (arg.orderId != null && data['orderId'] == arg.orderId) return true;
    return false;
  }

  Future<void> _init() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final conversations = await ref.read(chatRemoteDataSourceProvider).getConversations();
      final existing = conversations.where((c) {
        if (arg.orderId != null) return c.orderId == arg.orderId;
        return c.peerRole == arg.peerRole;
      }).toList();

      if (existing.isEmpty) {
        // No messages exchanged yet — start with an empty thread; the first
        // send establishes the conversation.
        state = state.copyWith(isLoading: false, messages: const []);
        return;
      }

      final conversationId = existing.first.conversationId;
      final result = await ref.read(chatRemoteDataSourceProvider).getMessages(conversationId: conversationId);
      state = state.copyWith(isLoading: false, messages: result.messages, conversationId: conversationId);
      unawaited(ref.read(chatRemoteDataSourceProvider).markRead(conversationId));
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Could not load messages. Pull down to retry.');
    }
  }

  Future<void> resumeChat() async {
    final convId = state.conversationId;
    if (convId == null || convId.isEmpty) return;

    // 1. Reconnect socket if needed
    final socketService = ref.read(socketServiceProvider);
    if (!socketService.isConnected) {
      final token = await ref.read(tokenStorageProvider).accessToken;
      if (token != null && token.isNotEmpty) {
        socketService.disconnect();
        socketService.connect(token);
      }
    }

    // 2. Fetch recent messages to sync any missed ones
    try {
      final result = await ref.read(chatRemoteDataSourceProvider).getMessages(
            conversationId: convId,
            page: 1,
            limit: 20,
          );

      final existingIds = state.messages.map((m) => m.id).toSet();
      final newMessages = result.messages.where((m) => !existingIds.contains(m.id)).toList();
      if (newMessages.isNotEmpty) {
        // Sort by createdAt
        newMessages.sort((a, b) => (a.createdAt ?? DateTime.now()).compareTo(b.createdAt ?? DateTime.now()));
        state = state.copyWith(
          messages: [...state.messages, ...newMessages],
        );
      }
      unawaited(ref.read(chatRemoteDataSourceProvider).markRead(convId));
    } catch (_) {
      // Keep existing state if offline
    }
  }

  Future<void> retry() => _init();

  Future<String?> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    state = state.copyWith(isSending: true, clearError: true);
    try {
      final message = await ref.read(chatRemoteDataSourceProvider).sendMessage(
            peerRole: arg.peerRole,
            peerId: arg.peerId,
            orderId: arg.orderId,
            text: trimmed,
          );
      state = state.copyWith(
        messages: [...state.messages, message],
        conversationId: state.conversationId ?? message.conversationId,
        isSending: false,
      );
      return null;
    } catch (_) {
      state = state.copyWith(isSending: false);
      return 'Could not send. Check your connection and try again.';
    }
  }

  /// Debounced typing signal — call on every keystroke; auto-clears after 3s
  /// of inactivity so a forgotten field doesn't show "typing" forever.
  void notifyTyping() {
    final convId = state.conversationId;
    if (convId == null) return;
    ref.read(socketServiceProvider).emitChatTyping(
          toRole: arg.peerRole,
          toId: arg.peerId,
          conversationId: convId,
          typing: true,
        );
    _typingResetTimer?.cancel();
    _typingResetTimer = Timer(const Duration(seconds: 3), () {
      ref.read(socketServiceProvider).emitChatTyping(
            toRole: arg.peerRole,
            toId: arg.peerId,
            conversationId: convId,
            typing: false,
          );
    });
  }
}

/// The signed-in user's id, so message bubbles can tell "mine" from "theirs".
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authViewModelProvider).value?.id;
});
