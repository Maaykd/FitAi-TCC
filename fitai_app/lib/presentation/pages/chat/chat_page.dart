import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fitai_app/core/models/conversation.dart';
import 'package:fitai_app/core/theme/app_theme.dart';
import 'package:fitai_app/core/router/app_router.dart';
import '../../../providers/chat_provider.dart';
import 'widgets/message_bubble.dart';
import 'widgets/typing_indicator.dart';
import 'widgets/chat_input.dart';
import 'widgets/quick_questions.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _scrollController = ScrollController();
  ConversationType? _currentConversationType;
  bool _showQuickQuestions = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ChatProvider>();
      if (!provider.hasActiveConversation) {
        // Não mostrar dialog automático, deixar usuário escolher
        // _showStartDialog();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // Nova função para iniciar conversa com pergunta rápida
  Future<void> _startConversationWithQuestion(ConversationType type, String question) async {
    final provider = context.read<ChatProvider>();
    
    setState(() {
      _currentConversationType = type;
      _showQuickQuestions = false;
    });

    final success = await provider.startNewConversation(
      type: type,
      initialMessage: question,
    );

    if (!success && mounted) {
      _showError('Erro ao iniciar conversa. Tente novamente.');
      setState(() {
        _showQuickQuestions = true;
      });
    } else {
      // Scroll para o final após iniciar conversa
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  // Função para usar pergunta sugerida durante conversa ativa
  void _useQuickQuestion(String question) {
    final provider = context.read<ChatProvider>();
    provider.sendMessage(question);
    
    // Esconder perguntas após usar uma
    setState(() {
      _showQuickQuestions = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _showStartDialog() async {
    final controller = TextEditingController();
    ConversationType selectedType = ConversationType.generalFitness;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text(
            'Iniciar Conversa',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<ConversationType>(
                value: selectedType,
                isExpanded: true,
                items: ConversationType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => selectedType = value!);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Digite sua mensagem...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.pop(context, {
                    'message': controller.text.trim(),
                    'type': selectedType,
                  });
                }
              },
              child: const Text('Enviar'),
            ),
          ],
        ),
      ),
    );

    if (result == null && mounted) {
      AppRouter.goBack();
      return;
    }

    if (result != null && mounted) {
      await _startConversationWithQuestion(
        result['type'] as ConversationType,
        result['message'] as String,
      );
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat FitAI'),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.lightbulb_outline),
            onPressed: () {
              setState(() {
                _showQuickQuestions = !_showQuickQuestions;
              });
            },
            tooltip: 'Perguntas sugeridas',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _showStartDialog,
            tooltip: 'Nova conversa',
          ),
        ],
      ),
      body: Consumer<ChatProvider>(
        builder: (context, provider, _) {
          // Auto-scroll quando novas mensagens chegam
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (provider.messages.isNotEmpty) _scrollToBottom();
          });

          if (provider.error != null) {
            return _buildErrorView(provider.error!);
          }

          // Tela inicial com quick start
          if (provider.messages.isEmpty && !provider.hasActiveConversation) {
            return WelcomeQuickStart(
              onStartConversation: _startConversationWithQuestion,
            );
          }

          return Column(
            children: [
              // Perguntas sugeridas (aparece quando ativado)
              if (_showQuickQuestions && provider.hasActiveConversation)
                QuickQuestions(
                  conversationType: _currentConversationType,
                  onQuestionTapped: _useQuickQuestion,
                  isExpanded: _showQuickQuestions,
                ),

              // Lista de mensagens
              Expanded(
                child: provider.messages.isEmpty
                  ? _buildEmptyView()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(top: 8, bottom: 16),
                      itemCount: provider.messages.length,
                      itemBuilder: (context, index) {
                        final msg = provider.messages[index];
                        return msg.isLoading 
                          ? const TypingIndicator()
                          : MessageBubble(message: msg);
                      },
                    ),
              ),
              
              // Campo de input (só aparece se tem conversa ativa)
              if (provider.hasActiveConversation)
                ChatInput(
                  onSendMessage: provider.sendMessage,
                  enabled: !provider.isSending,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Conversa iniciada!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Digite sua mensagem ou use uma das sugestões acima.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            const Text(
              'Ocorreu um erro',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    context.read<ChatProvider>();
                    // Reset state
                    setState(() {
                      _showQuickQuestions = true;
                      _currentConversationType = null;
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar Novamente'),
                ),
                TextButton.icon(
                  onPressed: () => AppRouter.goBack(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Voltar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}