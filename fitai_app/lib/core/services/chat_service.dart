import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:fitai_app/core/models/chat_message.dart';
import 'package:fitai_app/core/models/conversation.dart';
import 'package:fitai_app/core/models/chat_response.dart';

class ChatService {
  final Dio _dio;
  
  // IMPORTANTE: Ajuste conforme seu ambiente
  static const String _baseUrl = 'http://10.0.2.2:8000/api/v1/chat';

  ChatService({Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options.baseUrl = _baseUrl;
    _dio.options.headers = {'Content-Type': 'application/json'};
  }

  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Token $token';
    debugPrint('Token configurado');
  }

  Future<int> startConversation({
    required ConversationType type,
    required String initialMessage,
  }) async {
    final response = await _dio.post('/conversations/start/', data: {
      'type': type.apiValue,
      'message': initialMessage,
    });
    return response.data['conversation_id'];
  }

  Future<MessageSendResponse> sendMessage({
    required int conversationId,
    required String message,
  }) async {
    final response = await _dio.post(
      '/conversations/$conversationId/message/',
      data: {'message': message},
    );
    return MessageSendResponse.fromJson(response.data);
  }
}