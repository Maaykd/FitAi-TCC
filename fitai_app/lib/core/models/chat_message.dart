class ChatMessage {
  final int id;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final bool isLoading;
  final String? intentDetected;
  final double? confidenceScore;

  const ChatMessage({
    required this.id,
    required this.content,
    required this.type,
    required this.timestamp,
    this.isLoading = false,
    this.intentDetected,
    this.confidenceScore,
  });

  factory ChatMessage.user({required String content, int? id}) {
    return ChatMessage(
      id: id ?? DateTime.now().millisecondsSinceEpoch,
      content: content,
      type: MessageType.user,
      timestamp: DateTime.now(),
    );
  }

  factory ChatMessage.ai({
    required int id,
    required String content,
    String? intentDetected,
    double? confidenceScore,
  }) {
    return ChatMessage(
      id: id,
      content: content,
      type: MessageType.ai,
      timestamp: DateTime.now(),
      intentDetected: intentDetected,
      confidenceScore: confidenceScore,
    );
  }

  factory ChatMessage.loading() {
    return ChatMessage(
      id: -1,
      content: '',
      type: MessageType.ai,
      timestamp: DateTime.now(),
      isLoading: true,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json, MessageType type) {
    return ChatMessage(
      id: json['id'] as int,
      content: json['content'] as String,
      type: type,
      timestamp: DateTime.parse(json['timestamp'] as String),
      intentDetected: json['intent_detected'] as String?,
      confidenceScore: json['confidence_score'] as double?,
    );
  }
}

enum MessageType { user, ai }

extension MessageTypeExtension on MessageType {
  bool get isUser => this == MessageType.user;
  bool get isAI => this == MessageType.ai;
  String get label => this == MessageType.user ? 'Você' : 'FitAI';
}