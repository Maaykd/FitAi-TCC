import 'chat_message.dart';

class MessageSendResponse {
  final String aiContent;
  final int messageId;

  const MessageSendResponse({
    required this.aiContent,
    required this.messageId,
  });

  factory MessageSendResponse.fromJson(Map<String, dynamic> json) {
    final aiResponse = json['ai_response'] as Map<String, dynamic>;
    return MessageSendResponse(
      aiContent: aiResponse['content'] as String,
      messageId: aiResponse['message_id'] as int,
    );
  }

  ChatMessage toAIMessage() {
    return ChatMessage.ai(
      id: messageId,
      content: aiContent,
    );
  }
}