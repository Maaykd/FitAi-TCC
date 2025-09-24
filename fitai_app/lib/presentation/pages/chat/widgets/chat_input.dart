import 'package:flutter/material.dart';
import 'package:fitai_app/core/theme/app_theme.dart';

class ChatInput extends StatefulWidget {
  final Future<bool> Function(String) onSendMessage; // ✅ Mudança aqui
  final bool enabled;

  const ChatInput({
    super.key,
    required this.onSendMessage,
    this.enabled = true,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _controller = TextEditingController();
  bool _isSending = false; // ✅ Adicionar estado de envio

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async { // ✅ Agora é async
    if (_controller.text.trim().isEmpty || _isSending) return;
    
    final text = _controller.text.trim();
    _controller.clear(); // Limpa imediatamente
    
    setState(() => _isSending = true);
    
    try {
      await widget.onSendMessage(text); // ✅ Aguarda o Future
    } catch (e) {
      // Se der erro, restaura o texto
      _controller.text = text;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: widget.enabled && !_isSending, // ✅ Desabilita durante envio
              decoration: const InputDecoration(
                hintText: 'Digite sua mensagem...',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: (widget.enabled && !_isSending) ? _send : null,
            icon: _isSending 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send),
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }
}