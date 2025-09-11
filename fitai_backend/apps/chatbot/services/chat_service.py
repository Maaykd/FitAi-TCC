# apps/chatbot/services/chat_service.py
import json
import time
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple
from django.conf import settings
from django.core.cache import cache
from django.utils import timezone
from django.contrib.auth.models import User

from ..models import Conversation, Message, ChatContext
from apps.users.models import UserProfile
from apps.workouts.models import Workout, WorkoutSession
from apps.recommendations.services.ai_service import AIService

logger = logging.getLogger(__name__)


class ChatService:
    """
    Serviço principal para gerenciamento de conversas de chatbot com IA
    Integrado com o sistema de fitness existente
    """
    
    def __init__(self):
        self.ai_service = AIService()
        self.max_context_messages = 10
        self.conversation_timeout_hours = 24
        
    def start_conversation(self, user: User, conversation_type: str = 'general_fitness',
                          initial_message: str = None) -> Dict:
        """
        Inicia nova conversa de chatbot com contexto personalizado
        """
        try:
            # Verificar se usuário tem conversa ativa recente
            recent_conversation = Conversation.objects.filter(
                user=user,
                status='active',
                created_at__gte=timezone.now() - timedelta(hours=2)
            ).first()
            
            if recent_conversation and not initial_message:
                return {
                    'conversation_id': recent_conversation.id,
                    'status': 'resumed',
                    'message': 'Continuando conversa anterior...',
                    'conversation_type': recent_conversation.conversation_type,
                    'context_loaded': True
                }
            
            # Criar nova conversa
            conversation = Conversation.objects.create(
                user=user,
                conversation_type=conversation_type,
                ai_model_used=getattr(settings, 'OPENAI_MODEL', 'gpt-3.5-turbo')
            )
            
            # Carregar contexto inicial do usuário
            self._initialize_conversation_context(conversation)
            
            # Primeira mensagem da IA se não fornecida pelo usuário
            if not initial_message:
                welcome_response = self._generate_welcome_message(conversation)
                if welcome_response:
                    self._save_ai_message(
                        conversation, 
                        welcome_response['content'],
                        response_time_ms=welcome_response.get('response_time', 0),
                        confidence_score=welcome_response.get('confidence', 0.8)
                    )
            else:
                # Processar mensagem inicial do usuário
                user_message = self._save_user_message(conversation, initial_message)
                ai_response = self.process_user_message(conversation.id, initial_message)
            
            return {
                'conversation_id': conversation.id,
                'status': 'created',
                'conversation_type': conversation_type,
                'context_loaded': True,
                'welcome_message': True,
                'ai_available': self.ai_service.is_available
            }
            
        except Exception as e:
            logger.error(f"Error starting conversation for user {user.id}: {e}")
            return {
                'error': 'Não foi possível iniciar conversa',
                'fallback': 'Tente novamente em alguns instantes'
            }
    
    def process_user_message(self, conversation_id: int, message: str) -> Dict:
        """
        Processa mensagem do usuário e gera resposta da IA
        """
        start_time = time.time()
        
        try:
            conversation = Conversation.objects.get(id=conversation_id)
            
            # Verificar se conversa não expirou
            if conversation.is_expired():
                return {
                    'error': 'Conversa expirada',
                    'suggestion': 'Inicie uma nova conversa para continuar'
                }
            
            # Salvar mensagem do usuário
            user_message = self._save_user_message(conversation, message)
            
            # Detectar intenção e contexto
            intent_analysis = self._analyze_message_intent(message, conversation)
            user_message.intent_detected = intent_analysis.get('intent', 'general_question')
            user_message.save()
            
            # Atualizar contexto da conversa
            self._update_conversation_context(conversation, message, intent_analysis)
            
            # Gerar resposta da IA
            ai_response = self._generate_ai_response(conversation, message, intent_analysis)
            
            if ai_response and ai_response.get('success'):
                # Salvar resposta da IA
                ai_message = self._save_ai_message(
                    conversation,
                    ai_response['content'],
                    response_time_ms=round((time.time() - start_time) * 1000, 2),
                    confidence_score=ai_response.get('confidence_score', 0.8),
                    intent=intent_analysis.get('intent')
                )
                
                return {
                    'message_id': ai_message.id,
                    'response': ai_response['content'],
                    'conversation_updated': True,
                    'intent_detected': intent_analysis.get('intent'),
                    'confidence_score': ai_response.get('confidence_score'),
                    'response_time_ms': round((time.time() - start_time) * 1000, 2),
                    'suggested_actions': ai_response.get('suggested_actions', []),
                    'workout_references': ai_response.get('workout_references', []),
                    'method': 'ai_powered'
                }
            else:
                # Fallback para resposta baseada em regras
                fallback_response = self._generate_fallback_response(conversation, message, intent_analysis)
                
                ai_message = self._save_ai_message(
                    conversation,
                    fallback_response,
                    response_time_ms=round((time.time() - start_time) * 1000, 2),
                    confidence_score=0.6,
                    intent=intent_analysis.get('intent')
                )
                
                return {
                    'message_id': ai_message.id,
                    'response': fallback_response,
                    'conversation_updated': True,
                    'intent_detected': intent_analysis.get('intent'),
                    'method': 'rule_based_fallback',
                    'note': 'IA temporariamente indisponível'
                }
                
        except Conversation.DoesNotExist:
            return {
                'error': 'Conversa não encontrada',
                'suggestion': 'Verifique o ID da conversa ou inicie uma nova'
            }
        except Exception as e:
            logger.error(f"Error processing message in conversation {conversation_id}: {e}")
            return {
                'error': 'Erro ao processar mensagem',
                'suggestion': 'Tente novamente ou reformule sua pergunta'
            }
    
    def _initialize_conversation_context(self, conversation: Conversation):
        """
        Carrega contexto inicial do usuário para personalização
        """
        try:
            user = conversation.user
            
            # Contexto do perfil do usuário
            try:
                profile = UserProfile.objects.get(user=user)
                ChatContext.set_context(
                    conversation, 'user_profile', 'basic_info',
                    {
                        'goal': profile.goal,
                        'activity_level': profile.activity_level,
                        'focus_areas': profile.focus_areas,
                        'age': profile.age,
                        'current_weight': profile.current_weight,
                        'target_weight': profile.target_weight,
                    },
                    relevance=1.0
                )
            except UserProfile.DoesNotExist:
                ChatContext.set_context(
                    conversation, 'user_profile', 'basic_info',
                    {'profile_complete': False},
                    relevance=0.5
                )
            
            # Contexto do histórico de treinos (últimos 7 dias)
            recent_sessions = WorkoutSession.objects.filter(
                user=user,
                completed=True,
                completed_at__gte=timezone.now() - timedelta(days=7)
            ).order_by('-completed_at')[:5]
            
            workout_history = []
            for session in recent_sessions:
                workout_history.append({
                    'workout_name': session.workout.name if session.workout else 'Treino Personalizado',
                    'completed_at': session.completed_at.strftime('%d/%m/%Y'),
                    'rating': session.user_rating,
                    'duration': session.actual_duration
                })
            
            ChatContext.set_context(
                conversation, 'workout_history', 'recent_workouts',
                {'recent_sessions': workout_history},
                relevance=0.8
            )
            
            # Preferências conversacionais (será atualizado durante a conversa)
            ChatContext.set_context(
                conversation, 'preferences', 'conversation_style',
                {'preferred_response_length': 'medium', 'technical_level': 'intermediate'},
                relevance=0.6
            )
            
        except Exception as e:
            logger.error(f"Error initializing conversation context: {e}")
    
    def _analyze_message_intent(self, message: str, conversation: Conversation) -> Dict:
        """
        Analisa intenção da mensagem usando IA ou regras
        """
        try:
            # Cache da análise por 1 hora
            cache_key = f"intent_analysis_{hash(message.lower())}"
            cached_intent = cache.get(cache_key)
            if cached_intent:
                return cached_intent
            
            # Tentar análise com IA
            if self.ai_service.is_available:
                ai_intent = self._ai_intent_analysis(message, conversation)
                if ai_intent:
                    cache.set(cache_key, ai_intent, 3600)
                    return ai_intent
            
            # Fallback: análise por regras
            rule_intent = self._rule_based_intent_analysis(message)
            cache.set(cache_key, rule_intent, 1800)  # Cache menor para fallback
            return rule_intent
            
        except Exception as e:
            logger.error(f"Error analyzing message intent: {e}")
            return {'intent': 'general_question', 'confidence': 0.5}
    
    def _ai_intent_analysis(self, message: str, conversation: Conversation) -> Optional[Dict]:
        """
        Análise de intenção usando IA
        """
        try:
            system_prompt = """Você é um especialista em análise de intenções para conversas sobre fitness.
Analise a mensagem e identifique a intenção principal, respondendo APENAS em formato JSON."""
            
            user_prompt = f"""
Analise esta mensagem: "{message}"

INTENÇÕES POSSÍVEIS:
- workout_request: Pedir treino/exercícios
- technique_question: Dúvidas sobre técnica
- nutrition_advice: Orientação nutricional  
- progress_inquiry: Perguntas sobre progresso
- motivation_need: Busca motivação/encorajamento
- equipment_question: Dúvidas sobre equipamentos
- injury_concern: Preocupações com lesões
- schedule_planning: Planejamento de rotina
- general_question: Pergunta geral sobre fitness

Responda em JSON:
{{
    "intent": "categoria_principal",
    "confidence": 0.0-1.0,
    "secondary_intents": ["intent1", "intent2"],
    "keywords": ["palavra1", "palavra2"],
    "urgency_level": "low|medium|high",
    "requires_personalization": true/false
}}
"""
            
            messages = [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ]
            
            response = self.ai_service._make_openai_request(messages, max_tokens=200, temperature=0.3)
            
            if response:
                return json.loads(response)
                
        except Exception as e:
            logger.error(f"Error in AI intent analysis: {e}")
        
        return None
    
    def _rule_based_intent_analysis(self, message: str) -> Dict:
        """
        Análise de intenção baseada em regras
        """
        message_lower = message.lower()
        
        # Palavras-chave para cada intenção
        intent_keywords = {
            'workout_request': ['treino', 'exercício', 'workout', 'série', 'repetição', 'treinar'],
            'technique_question': ['como', 'técnica', 'forma', 'postura', 'execução', 'executar'],
            'nutrition_advice': ['alimentação', 'dieta', 'nutrição', 'proteína', 'comer', 'comida'],
            'progress_inquiry': ['progresso', 'resultado', 'evolução', 'melhora', 'crescimento'],
            'motivation_need': ['motivação', 'desânimo', 'preguiça', 'força', 'conseguir'],
            'equipment_question': ['equipamento', 'aparelho', 'peso', 'halteres', 'academia'],
            'injury_concern': ['dor', 'lesão', 'machuca', 'problema', 'desconforto'],
            'schedule_planning': ['rotina', 'horário', 'frequência', 'quando', 'quantas vezes']
        }
        
        # Calcular score para cada intenção
        intent_scores = {}
        for intent, keywords in intent_keywords.items():
            score = sum([1 for keyword in keywords if keyword in message_lower])
            if score > 0:
                intent_scores[intent] = score / len(keywords)
        
        # Determinar intenção principal
        if intent_scores:
            main_intent = max(intent_scores, key=intent_scores.get)
            confidence = intent_scores[main_intent]
        else:
            main_intent = 'general_question'
            confidence = 0.5
        
        return {
            'intent': main_intent,
            'confidence': confidence,
            'secondary_intents': [intent for intent, score in intent_scores.items() 
                                 if intent != main_intent and score > 0.2],
            'keywords': [word for word in message_lower.split() 
                        if any(word in keywords for keywords in intent_keywords.values())],
            'urgency_level': 'high' if any(word in message_lower for word in ['dor', 'lesão', 'urgente']) else 'medium',
            'requires_personalization': True
        }
    
    def _generate_ai_response(self, conversation: Conversation, message: str, intent_analysis: Dict) -> Optional[Dict]:
        """
        Gera resposta usando IA com contexto completo
        """
        if not self.ai_service.is_available:
            return None
        
        try:
            # Buscar contexto da conversa
            context_data = self._build_conversation_context(conversation)
            
            # Buscar mensagens recentes para contexto
            recent_messages = conversation.get_last_messages(8)
            conversation_history = []
            for msg in reversed(recent_messages):
                conversation_history.append({
                    'role': 'user' if msg.message_type == 'user' else 'assistant',
                    'content': msg.content
                })
            
            # Prompt otimizado para chat fitness
            system_prompt = self._build_fitness_chat_system_prompt(intent_analysis, context_data)
            
            # Construir mensagens para IA
            messages = [{"role": "system", "content": system_prompt}]
            
            # Adicionar histórico da conversa (limitado)
            messages.extend(conversation_history[-6:])  # Últimas 6 mensagens
            
            # Mensagem atual do usuário
            messages.append({"role": "user", "content": message})
            
            response = self.ai_service._make_openai_request(
                messages, 
                max_tokens=500,  # Respostas mais conversacionais
                temperature=0.7
            )
            
            if response:
                # Processar resposta para extrair ações e referências
                processed_response = self._process_ai_response(response, intent_analysis)
                return processed_response
            
        except Exception as e:
            logger.error(f"Error generating AI response: {e}")
        
        return None
    
    def _build_fitness_chat_system_prompt(self, intent_analysis: Dict, context_data: Dict) -> str:
        """
        Constrói prompt de sistema otimizado para chat fitness
        """
        user_profile = context_data.get('user_profile', {})
        workout_history = context_data.get('workout_history', {})
        
        base_prompt = """Você é Alex, um personal trainer virtual especialista em fitness com 10 anos de experiência.

PERSONALIDADE:
- Amigável, motivador e profissional
- Usa linguagem clara e acessível
- Encoraja sem ser excessivo
- Foca na segurança e na progressão gradual
- Baseado em evidência científica

DIRETRIZES DE RESPOSTA:
- Máximo 200 palavras por resposta
- Use emojis ocasionalmente para engajamento
- Seja específico e prático
- Sempre priorize a segurança
- Adapte ao nível do usuário"""
        
        # Adicionar contexto específico
        if user_profile.get('goal'):
            base_prompt += f"\n\nOBJETIVO DO USUÁRIO: {user_profile['goal']}"
        
        if user_profile.get('activity_level'):
            base_prompt += f"\nNÍVEL ATUAL: {user_profile['activity_level']}"
        
        # Contexto baseado na intenção
        intent_contexts = {
            'workout_request': "\nFOCO: Recomende exercícios seguros e progressivos. Sempre inclua aquecimento e alongamento.",
            'technique_question': "\nFOCO: Explique técnica com clareza, enfatize segurança e sugira progressões.",
            'nutrition_advice': "\nFOCO: Dê orientações gerais, sempre recomende consulta com nutricionista para planos específicos.",
            'progress_inquiry': "\nFOCO: Analise dados disponíveis, celebre conquistas e sugira próximos passos.",
            'motivation_need': "\nFOCO: Seja encorajador, lembre dos benefícios e sugira estratégias práticas.",
            'injury_concern': "\nFOCO: Priorize segurança, recomende descanso se necessário e consulta profissional."
        }
        
        intent = intent_analysis.get('intent', 'general_question')
        if intent in intent_contexts:
            base_prompt += intent_contexts[intent]
        
        if workout_history.get('recent_sessions'):
            base_prompt += f"\n\nHISTÓRICO RECENTE: {len(workout_history['recent_sessions'])} treinos realizados recentemente."
        
        base_prompt += "\n\nSempre termine perguntando se precisa de mais alguma coisa ou esclarecimento adicional."
        
        return base_prompt
    
    def _process_ai_response(self, response: str, intent_analysis: Dict) -> Dict:
        """
        Processa resposta da IA para extrair metadados úteis
        """
        processed = {
            'success': True,
            'content': response,
            'confidence_score': 0.8,
            'suggested_actions': [],
            'workout_references': []
        }
        
        # Detectar ações sugeridas na resposta
        response_lower = response.lower()
        
        action_patterns = {
            'try_exercise': ['experimente', 'tente fazer', 'faça'],
            'rest_recovery': ['descanse', 'pause', 'recuperação'],
            'seek_professional': ['consulte', 'procure um', 'médico', 'fisioterapeuta'],
            'schedule_workout': ['agende', 'planeje', 'organize'],
            'track_progress': ['anote', 'registre', 'acompanhe']
        }
        
        for action, patterns in action_patterns.items():
            if any(pattern in response_lower for pattern in patterns):
                processed['suggested_actions'].append(action)
        
        # Detectar referências a exercícios/treinos específicos
        # (Pode ser expandido com NLP mais sofisticado)
        exercise_mentions = []
        common_exercises = ['agachamento', 'flexão', 'corrida', 'caminhada', 'prancha', 'abdominais']
        
        for exercise in common_exercises:
            if exercise in response_lower:
                exercise_mentions.append(exercise)
        
        processed['workout_references'] = exercise_mentions
        
        return processed
    
    def _generate_fallback_response(self, conversation: Conversation, message: str, intent_analysis: Dict) -> str:
        """
        Gera resposta baseada em regras quando IA não está disponível
        """
        intent = intent_analysis.get('intent', 'general_question')
        user_name = conversation.user.first_name or 'amigo(a)'
        
        fallback_responses = {
            'workout_request': f"Olá, {user_name}! Para recomendações de treino personalizadas, que tal começarmos com alguns exercícios básicos? Posso sugerir um treino de corpo inteiro com agachamentos, flexões e prancha. Você tem alguma preferência específica ou restrição?",
            
            'technique_question': f"Ótima pergunta sobre técnica, {user_name}! A execução correta é fundamental para evitar lesões e maximizar resultados. Para exercícios específicos, sempre foque em: postura correta, movimento controlado, respiração adequada e progressão gradual. Sobre qual exercício você gostaria de saber mais?",
            
            'nutrition_advice': f"Nutrição é super importante, {user_name}! Algumas dicas básicas: mantenha-se hidratado, inclua proteínas em cada refeição, e consuma vegetais variados. Para um plano nutricional específico, recomendo consultar um nutricionista qualificado. Posso ajudar com mais alguma coisa sobre fitness?",
            
            'progress_inquiry': f"Que bom que você está acompanhando seu progresso, {user_name}! O importante é a consistência. Celebre cada pequena vitória e lembre-se que resultados levam tempo. Continue firme na sua rotina! Como você tem se sentido nos treinos recentes?",
            
            'motivation_need': f"Entendo, {user_name}. Todos passamos por momentos assim! Lembre-se: cada treino é um investimento na sua saúde e bem-estar. Comece pequeno se necessário - até 10 minutos já fazem diferença. Você é mais forte do que imagina! O que te motivou a começar essa jornada?",
            
            'injury_concern': f"Sua segurança é prioridade, {user_name}. Se você está sentindo dor, é importante parar e avaliar. Para dores persistentes, sempre consulte um profissional de saúde. No treino, escute sempre seu corpo. Posso ajudar com exercícios de baixo impacto enquanto se recupera?",
            
            'general_question': f"Oi, {user_name}! Estou aqui para ajudar com suas dúvidas sobre fitness. Posso orientar sobre exercícios, técnicas, motivação e planejamento de treinos. No que posso te auxiliar hoje?"
        }
        
        return fallback_responses.get(intent, fallback_responses['general_question'])
    
    def _generate_welcome_message(self, conversation: Conversation) -> Optional[Dict]:
        """
        Gera mensagem de boas-vindas personalizada
        """
        try:
            user_name = conversation.user.first_name or 'atleta'
            conversation_type = conversation.conversation_type
            
            # Tentar gerar com IA
            if self.ai_service.is_available:
                context_data = self._build_conversation_context(conversation)
                ai_welcome = self._ai_welcome_message(user_name, conversation_type, context_data)
                if ai_welcome:
                    return ai_welcome
            
            # Fallback: mensagens pré-definidas
            type_messages = {
                'workout_consultation': f"Olá, {user_name}! 💪 Sou Alex, seu personal trainer virtual. Estou aqui para ajudar você a criar treinos personalizados e alcançar seus objetivos. Como posso te ajudar hoje?",
                
                'progress_analysis': f"Oi, {user_name}! 📈 Que bom te ver aqui! Vamos analisar seu progresso e ver como você está evoluindo. Tenho algumas perguntas para entender melhor sua jornada. Pronto para começar?",
                
                'motivation_chat': f"Hey, {user_name}! 🌟 Às vezes todos precisamos de um empurrãozinho, né? Estou aqui para te motivar e lembrar do incrível que você é. Vamos conversar sobre o que está te preocupando?",
                
                'technique_guidance': f"Salve, {user_name}! 🎯 Técnica correta é tudo no fitness! Estou aqui para te ajudar com dúvidas sobre execução de exercícios e boa forma. Qual movimento você gostaria de aperfeiçoar?",
                
                'general_fitness': f"Olá, {user_name}! 🏃‍♂️ Bem-vindo(a) ao seu chat fitness personalizado! Sou Alex e estou aqui para tirar dúvidas, sugerir treinos e te apoiar nessa jornada. O que você gostaria de saber?"
            }
            
            welcome_content = type_messages.get(conversation_type, type_messages['general_fitness'])
            
            return {
                'content': welcome_content,
                'confidence': 0.8,
                'response_time': 100
            }
            
        except Exception as e:
            logger.error(f"Error generating welcome message: {e}")
            return {
                'content': f"Olá! Sou Alex, seu assistente de fitness. Como posso ajudar você hoje?",
                'confidence': 0.6,
                'response_time': 50
            }
    
    def _ai_welcome_message(self, user_name: str, conversation_type: str, context_data: Dict) -> Optional[Dict]:
        """
        Gera mensagem de boas-vindas usando IA
        """
        try:
            user_profile = context_data.get('user_profile', {})
            
            system_prompt = "Você é Alex, um personal trainer virtual amigável. Crie uma mensagem de boas-vindas personalizada e motivadora para iniciar uma conversa sobre fitness."
            
            user_prompt = f"""
Crie mensagem de boas-vindas para {user_name}.

TIPO DE CONVERSA: {conversation_type}
PERFIL: {user_profile.get('goal', 'não informado')}
NÍVEL: {user_profile.get('activity_level', 'não informado')}

REQUISITOS:
- Máximo 100 palavras
- Tom amigável e profissional
- Mencione o nome da pessoa
- Relacione com o tipo de conversa
- Termine com pergunta envolvente
- Use 1-2 emojis apropriados
"""
            
            messages = [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ]
            
            start_time = time.time()
            response = self.ai_service._make_openai_request(messages, max_tokens=150, temperature=0.8)
            
            if response:
                return {
                    'content': response.strip(),
                    'confidence': 0.9,
                    'response_time': round((time.time() - start_time) * 1000)
                }
                
        except Exception as e:
            logger.error(f"Error generating AI welcome message: {e}")
        
        return None
    
    def _save_user_message(self, conversation: Conversation, content: str) -> Message:
        """Salva mensagem do usuário"""
        return Message.objects.create(
            conversation=conversation,
            message_type='user',
            content=content,
            status='delivered'
        )
    
    def _save_ai_message(self, conversation: Conversation, content: str, 
                        response_time_ms: int = 0, confidence_score: float = 0.8,
                        intent: str = None) -> Message:
        """Salva mensagem da IA com metadados"""
        return Message.objects.create(
            conversation=conversation,
            message_type='ai',
            content=content,
            confidence_score=confidence_score,
            ai_model_version=getattr(settings, 'OPENAI_MODEL', 'gpt-3.5-turbo'),
            response_time_ms=response_time_ms,
            tokens_used=len(content.split()) * 1.3,  # Estimativa aproximada
            intent_detected=intent,
            status='delivered'
        )
    
    def _build_conversation_context(self, conversation: Conversation) -> Dict:
        """Constrói contexto completo da conversa"""
        context_data = {}
        
        # Buscar todos os contextos ativos
        contexts = ChatContext.get_context(conversation)
        
        for context in contexts:
            context_type = context.context_type
            if context_type not in context_data:
                context_data[context_type] = {}
            context_data[context_type][context.context_key] = context.context_value
        
        return context_data
    
    def _update_conversation_context(self, conversation: Conversation, message: str, intent_analysis: Dict):
        """Atualiza contexto da conversa baseado na mensagem atual"""
        try:
            # Atualizar preferências conversacionais
            message_length = len(message.split())
            if message_length > 20:
                ChatContext.set_context(
                    conversation, 'preferences', 'message_style',
                    {'prefers_detailed': True, 'last_message_length': message_length},
                    relevance=0.7
                )
            
            # Atualizar tópicos de interesse
            intent = intent_analysis.get('intent')
            if intent:
                current_topics = ChatContext.get_context(
                    conversation, 'preferences', 'topics_of_interest'
                ).first()
                
                if current_topics:
                    topics = current_topics.context_value.get('topics', [])
                    if intent not in topics:
                        topics.append(intent)
                        topics = topics[-5:]  # Manter últimos 5 tópicos
                    
                    ChatContext.set_context(
                        conversation, 'preferences', 'topics_of_interest',
                        {'topics': topics},
                        relevance=0.6
                    )
                else:
                    ChatContext.set_context(
                        conversation, 'preferences', 'topics_of_interest',
                        {'topics': [intent]},
                        relevance=0.6
                    )
            
        except Exception as e:
            logger.error(f"Error updating conversation context: {e}")
    
    def get_conversation_history(self, conversation_id: int, limit: int = 50) -> List[Dict]:
        """Retorna histórico formatado da conversa"""
        try:
            conversation = Conversation.objects.get(id=conversation_id)
            messages = conversation.messages.order_by('created_at')[:limit]
            
            history = []
            for message in messages:
                history.append({
                    'id': message.id,
                    'type': message.message_type,
                    'content': message.content,
                    'timestamp': message.created_at.isoformat(),
                    'intent': message.intent_detected,
                    'confidence': message.confidence_score,
                    'user_reaction': message.user_reaction
                })
            
            return history
            
        except Conversation.DoesNotExist:
            return []
        except Exception as e:
            logger.error(f"Error getting conversation history: {e}")
            return []
    
    def end_conversation(self, conversation_id: int, user_rating: float = None) -> Dict:
        """Finaliza conversa com avaliação opcional"""
        try:
            conversation = Conversation.objects.get(id=conversation_id)
            conversation.status = 'completed'
            
            if user_rating:
                conversation.user_satisfaction_rating = user_rating
            
            conversation.save()
            
            return {
                'conversation_ended': True,
                'total_messages': conversation.message_count,
                'duration_minutes': (timezone.now() - conversation.created_at).total_seconds() / 60,
                'rating_saved': user_rating is not None
            }
            
        except Conversation.DoesNotExist:
            return {'error': 'Conversa não encontrada'}
        except Exception as e:
            logger.error(f"Error ending conversation: {e}")
            return {'error': 'Erro ao finalizar conversa'}