class Conversation {
  final int id;
  final String title;
  final ConversationType type;
  final String status;
  final DateTime createdAt;
  final DateTime lastActivity;
  final int totalMessages;

  const Conversation({
    required this.id,
    required this.title,
    required this.type,
    required this.status,
    required this.createdAt,
    required this.lastActivity,
    this.totalMessages = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as int,
      title: json['title'] as String,
      type: _conversationTypeFromString(json['type'] as String),  // ✅ CORRETO
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastActivity: DateTime.parse(json['last_activity'] as String),
      totalMessages: json['total_messages'] as int? ?? 0,
    );
  }
}

// Função helper FORA da classe
ConversationType _conversationTypeFromString(String value) {
  switch (value) {
    case 'workout_consultation':
      return ConversationType.workoutConsultation;
    case 'motivation_chat':
      return ConversationType.motivationChat;
    default:
      return ConversationType.generalFitness;
  }
}

enum ConversationType {
  workoutConsultation,
  motivationChat,
  generalFitness,
}

extension ConversationTypeExtension on ConversationType {
  String get apiValue {
    switch (this) {
      case ConversationType.workoutConsultation:
        return 'workout_consultation';
      case ConversationType.motivationChat:
        return 'motivation_chat';
      case ConversationType.generalFitness:
        return 'general_fitness';
    }
  }

  String get displayName {
    switch (this) {
      case ConversationType.workoutConsultation:
        return 'Consulta de Treino';
      case ConversationType.motivationChat:
        return 'Motivação';
      case ConversationType.generalFitness:
        return 'Fitness Geral';
    }
  }

  String get description {
    switch (this) {
      case ConversationType.workoutConsultation:
        return 'Tire dúvidas sobre treinos';
      case ConversationType.motivationChat:
        return 'Receba motivação';
      case ConversationType.generalFitness:
        return 'Fitness em geral';
    }
  }
}