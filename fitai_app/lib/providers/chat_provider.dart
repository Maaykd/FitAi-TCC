import 'package:flutter/foundation.dart';
import 'package:fitai_app/core/models/chat_message.dart';
import 'package:fitai_app/core/models/conversation.dart';
import 'package:fitai_app/core/services/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService;

  ChatProvider(this._chatService);

  List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  int? _conversationId;
  bool get hasActiveConversation => _conversationId != null;

  bool _isSending = false;
  bool get isSending => _isSending;

  String? _error;
  String? get error => _error;

  Future<bool> startNewConversation({
    required ConversationType type,
    required String initialMessage,
  }) async {
    try {
      _messages.clear();
      _messages.add(ChatMessage.user(content: initialMessage));
      notifyListeners();

      _conversationId = await _chatService.startConversation(
        type: type,
        initialMessage: initialMessage,
      );

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendMessage(String content) async {
    if (_conversationId == null || content.trim().isEmpty) return false;

    try {
      _isSending = true;
      _messages.add(ChatMessage.user(content: content));
      _messages.add(ChatMessage.loading());
      notifyListeners();

      final response = await _chatService.sendMessage(
        conversationId: _conversationId!,
        message: content,
      );

      _messages.removeLast(); // Remove loading
      _messages.add(response.toAIMessage());

      _isSending = false;
      notifyListeners();
      return true;
    } catch (e) {
      if (_messages.last.isLoading) _messages.removeLast();
      _error = e.toString();
      _isSending = false;
      notifyListeners();
      return false;
    }
  }

  void setAuthToken(String token) {
    _chatService.setAuthToken(token);
  }
}