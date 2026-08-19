import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:food_user_application/core/error/result.dart';
import 'package:food_user_application/core/services/haptic_service.dart';
import 'package:food_user_application/core/services/socket_service.dart';
import 'package:food_user_application/features/chat/data/chat_repository.dart';
import 'package:food_user_application/features/chat/data/models/chat_message.dart';
import 'package:food_user_application/features/orders/data/models/delivery_order.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.order});

  final DeliveryOrder order;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  String? _conversationId;
  bool _loading = true;
  bool _sending = false;
  bool _peerTyping = false;
  String? _error;
  StreamSubscription<Map<String, dynamic>>? _messageSub;
  StreamSubscription<Map<String, dynamic>>? _typingSub;
  Timer? _typingResetTimer;

  @override
  void initState() {
    super.initState();
    _load();
    final socket = ref.read(socketServiceProvider);
    _messageSub = socket.onChatMessage.listen(_onSocketMessage);
    _typingSub = socket.onChatTyping.listen(_onSocketTyping);
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _typingSub?.cancel();
    _typingResetTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(chatRepositoryProvider);
    final conversationsResult = await repo.getConversations();
    String? conversationId;
    conversationsResult.when(
      success: (conversations) {
        for (final c in conversations) {
          if (c.orderId == widget.order.id && c.peerRole == 'USER') {
            conversationId = c.conversationId;
            break;
          }
        }
      },
      failure: (_) {},
    );

    if (conversationId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    _conversationId = conversationId;
    final historyResult = await repo.getMessages(conversationId: conversationId!);
    if (!mounted) return;
    historyResult.when(
      success: (page) => setState(() {
        _messages
          ..clear()
          ..addAll(page.messages);
        _loading = false;
      }),
      failure: (error) => setState(() {
        _error = error.message;
        _loading = false;
      }),
    );
    _scrollToBottom();
  }

  void _onSocketMessage(Map<String, dynamic> data) {
    final message = ChatMessage.fromJson(data);
    if (message.orderId != widget.order.id) return;
    if (_conversationId != null && message.conversationId != _conversationId) return;
    if (_messages.any((m) => m.id == message.id)) return;
    setState(() {
      _conversationId ??= message.conversationId;
      _messages.add(message);
    });
    _scrollToBottom();
  }

  void _onSocketTyping(Map<String, dynamic> data) {
    if (_conversationId == null || data['conversationId'] != _conversationId) return;
    if (data['fromRole'] != 'USER') return;
    setState(() => _peerTyping = data['typing'] as bool? ?? false);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _emitTyping(bool typing) {
    if (widget.order.customerId == null) return;
    ref.read(socketServiceProvider).sendChatTyping(
          toRole: 'USER',
          toId: widget.order.customerId,
          conversationId: _conversationId ?? '',
          typing: typing,
        );
  }

  void _onTextChanged(String value) {
    _typingResetTimer?.cancel();
    _emitTyping(value.isNotEmpty);
    if (value.isNotEmpty) {
      _typingResetTimer = Timer(const Duration(seconds: 2), () => _emitTyping(false));
    }
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    _textController.clear();
    _typingResetTimer?.cancel();
    _emitTyping(false);

    final result = await ref.read(chatRepositoryProvider).sendMessage(
          peerRole: 'USER',
          peerId: widget.order.customerId,
          orderId: widget.order.id,
          text: text,
        );
    if (!mounted) return;
    result.when(
      success: (message) {
        setState(() {
          _conversationId ??= message.conversationId;
          if (!_messages.any((m) => m.id == message.id)) {
            _messages.add(message);
          }
          _sending = false;
        });
        _scrollToBottom();
      },
      failure: (error) => setState(() {
        _error = error.message;
        _sending = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final bgColor = isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1E1E1E);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0.5,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            HapticService.light();
            Navigator.of(context).pop();
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.order.customerName.isNotEmpty ? widget.order.customerName : 'Customer',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.sp, color: textColor),
            ),
            if (_peerTyping)
              Text('typing…', style: TextStyle(fontSize: 11.sp, color: theme.primaryColor))
            else
              Text(
                'Order #${widget.order.orderCode}',
                style: TextStyle(fontSize: 11.sp, color: Colors.grey[500]),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          'No messages yet. Say hello!',
                          style: TextStyle(color: Colors.grey[500], fontSize: 13.sp),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) =>
                            _buildBubble(theme, isDarkMode, _messages[index]),
                      ),
          ),
          if (_error != null)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
              child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 8.h),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      onChanged: _onTextChanged,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 2000,
                      buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                          null,
                      decoration: InputDecoration(
                        hintText: 'Type a message…',
                        filled: true,
                        fillColor: isDarkMode ? Colors.white10 : Colors.white,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24.r),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      width: 44.r,
                      height: 44.r,
                      decoration: BoxDecoration(color: theme.primaryColor, shape: BoxShape.circle),
                      child: _sending
                          ? Padding(
                              padding: EdgeInsets.all(12.r),
                              child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(ThemeData theme, bool isDarkMode, ChatMessage message) {
    final isMine = message.isFromDeliveryPartner;
    final bubbleColor = isMine ? theme.primaryColor : (isDarkMode ? Colors.white10 : Colors.white);
    final textColor = isMine ? Colors.white : (isDarkMode ? Colors.white : Colors.black87);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        constraints: BoxConstraints(maxWidth: 0.75.sw),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16.r),
            topRight: Radius.circular(16.r),
            bottomLeft: Radius.circular(isMine ? 16.r : 4.r),
            bottomRight: Radius.circular(isMine ? 4.r : 16.r),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Text(message.text, style: TextStyle(color: textColor, fontSize: 14.sp)),
      ),
    );
  }
}
