import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/conversation.dart';

class QuickQuestions extends StatelessWidget {
  final ConversationType? conversationType;
  final Function(String) onQuestionTapped;
  final bool isExpanded;

  const QuickQuestions({
    super.key,
    this.conversationType,
    required this.onQuestionTapped,
    this.isExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final questions = _getQuestionsForType(conversationType);
    
    if (!isExpanded || questions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.psychology,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Perguntas Sugeridas',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: questions.map((question) {
              return _buildQuestionChip(question);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionChip(String question) {
    return GestureDetector(
      onTap: () => onQuestionTapped(question),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 14,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                question,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _getQuestionsForType(ConversationType? type) {
    if (type == null) {
      // Perguntas gerais para quando não há tipo definido
      return [
        "Como começar a treinar?",
        "Qual é o melhor exercício para iniciantes?",
        "Como criar uma rotina de exercícios?",
        "Preciso de equipamentos para treinar?",
      ];
    }

    switch (type) {
      case ConversationType.workoutConsultation:
        return [
          "Qual treino é ideal para iniciantes?",
          "Como dividir os grupos musculares?",
          "Quantas vezes por semana devo treinar?",
          "Treino em casa ou academia?",
          "Como aumentar a intensidade dos treinos?",
          "Qual a duração ideal de um treino?",
        ];

      case ConversationType.motivationChat:
        return [
          "Não tenho motivação para treinar",
          "Como manter a consistência?",
          "Estou desanimado com os resultados",
          "Como superar a preguiça?",
          "Dicas para não desistir",
          "Como criar o hábito de exercitar-se?",
        ];

      case ConversationType.generalFitness:
        return [
          "Como melhorar meu condicionamento físico?",
          "Qual a importância do aquecimento?",
          "Como evitar lesões durante o exercício?",
          "Dicas de alongamento",
          "Como medir meu progresso?",
          "Quando devo descansar?",
        ];
    }
  }
}

// Widget para usar na tela inicial (quando não tem conversa)
class WelcomeQuickStart extends StatelessWidget {
  final Function(ConversationType, String) onStartConversation;

  const WelcomeQuickStart({
    super.key,
    required this.onStartConversation,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Header
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.psychology,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          
          Text(
            'Como posso ajudar?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          
          Text(
            'Escolha uma das opções abaixo ou digite sua própria pergunta',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          // Cartões de início rápido
          ..._buildQuickStartCards(),
        ],
      ),
    );
  }

  List<Widget> _buildQuickStartCards() {
    final quickStarts = [
      {
        'type': ConversationType.workoutConsultation,
        'icon': Icons.fitness_center,
        'title': 'Consulta de Treino',
        'question': 'Preciso de ajuda para montar meu treino',
      },
      {
        'type': ConversationType.motivationChat,
        'icon': Icons.psychology,
        'title': 'Motivação',
        'question': 'Preciso de motivação para continuar treinando',
      },
      {
        'type': ConversationType.generalFitness,
        'icon': Icons.health_and_safety,
        'title': 'Fitness Geral',
        'question': 'Tenho dúvidas sobre exercícios e saúde',
      },
    ];

    return quickStarts.map((item) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              onStartConversation(
                item['type'] as ConversationType,
                item['question'] as String,
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      item['icon'] as IconData,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title'] as String,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['question'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppColors.textHint,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }
}