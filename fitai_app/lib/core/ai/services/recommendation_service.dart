import 'dart:math';
import '../models/user_profile.dart';
import '../models/recommendation_result.dart';
import '../../models/workout_model.dart';
import 'ml_algorithms.dart';

/// Serviço principal de recomendações
/// Orquestra os diferentes algoritmos de ML e gera recomendações personalizadas
class RecommendationService {
  static const String _version = '1.0.0';
  static final Random _random = Random();

  /// Gera recomendações personalizadas para o usuário
  static Future<RecommendationList> generateRecommendations({
    required UserProfile userProfile,
    required List<WorkoutModel> availableWorkouts,
    int maxRecommendations = 10,
    bool includeVariety = true,
    bool includeProgression = true,
  }) async {
    // Simula processamento assíncrono
    await Future.delayed(const Duration(milliseconds: 500));

    final recommendations = <RecommendationResult>[];
    final sessionMetadata = <String, dynamic>{
      'user_id': userProfile.userId,
      'total_workouts_analyzed': availableWorkouts.length,
      'algorithms_used': ['content_based', 'collaborative', 'hybrid'],
      'generation_time_ms': 500,
      'filters_applied': [],
    };

    // Filtra treinos inadequados (muito longos, nível inapropriado, etc.)
    final filteredWorkouts = _filterInappropriateWorkouts(
      availableWorkouts, 
      userProfile,
    );

    sessionMetadata['workouts_after_filtering'] = filteredWorkouts.length;

    for (final workout in filteredWorkouts) {
      // Calcula scores de diferentes algoritmos
      final scores = await _calculateAllScores(workout, userProfile);
      
      // Determina o tipo de recomendação
      final recommendationType = _determineRecommendationType(workout, userProfile, scores);
      
      // Calcula score final e confiança
      final finalScore = _calculateFinalScore(scores, recommendationType);
      final confidenceScore = _calculateConfidenceScore(scores, userProfile);
      
      // Gera explicação
      final reasoning = _generateReasoning(workout, userProfile, scores, recommendationType);
      final reasons = _generateReasonsList(workout, userProfile, scores);

      // Determina prioridade
      final priority = _calculatePriority(finalScore, recommendationType, userProfile);

      final recommendation = RecommendationResult(
        workoutId: workout.id,
        workoutName: workout.name,
        confidenceScore: confidenceScore,
        reasoning: reasoning,
        type: recommendationType,
        reasons: reasons,
        algorithmScores: scores,
        generatedAt: DateTime.now(),
        priority: priority,
        metadata: {
          'workout_category': workout.category,
          'workout_difficulty': workout.difficulty,
          'workout_duration': workout.duration,
          'final_score': finalScore,
          'user_experience_level': userProfile.experienceLevel.toString(),
        },
      );

      recommendations.add(recommendation);
    }

    // Ordena por prioridade e score
    recommendations.sort((a, b) {
      final priorityComparison = a.priority.compareTo(b.priority);
      if (priorityComparison != 0) return priorityComparison;
      return b.confidenceScore.compareTo(a.confidenceScore);
    });

    // Aplica diversidade se solicitado
    final finalRecommendations = includeVariety 
        ? _applyDiversityFilter(recommendations, maxRecommendations)
        : recommendations.take(maxRecommendations).toList();

    sessionMetadata['final_recommendations_count'] = finalRecommendations.length;
    sessionMetadata['average_confidence'] = finalRecommendations.isEmpty 
        ? 0.0 
        : finalRecommendations.fold<double>(0, (sum, r) => sum + r.confidenceScore) / finalRecommendations.length;

    return RecommendationList(
      recommendations: finalRecommendations,
      generatedAt: DateTime.now(),
      algorithmVersion: _version,
      sessionMetadata: sessionMetadata,
    );
  }

  /// Gera recomendação única focada no objetivo específico
  static Future<RecommendationResult?> generateGoalFocusedRecommendation({
    required UserProfile userProfile,
    required List<WorkoutModel> availableWorkouts,
    required FitnessGoal specificGoal,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final goalSpecificWorkouts = availableWorkouts.where((workout) {
      return _isWorkoutAlignedWithGoal(workout, specificGoal, userProfile);
    }).toList();

    if (goalSpecificWorkouts.isEmpty) return null;

    // Encontra o melhor treino para o objetivo específico
    WorkoutModel? bestWorkout;
    double bestScore = 0.0;

    for (final workout in goalSpecificWorkouts) {
      final score = await _calculateGoalSpecificScore(workout, userProfile, specificGoal);
      if (score > bestScore) {
        bestScore = score;
        bestWorkout = workout;
      }
    }

    if (bestWorkout == null) return null;

    final scores = await _calculateAllScores(bestWorkout, userProfile);
    
    return RecommendationResult(
      workoutId: bestWorkout.id,
      workoutName: bestWorkout.name,
      confidenceScore: bestScore,
      reasoning: _generateGoalSpecificReasoning(bestWorkout, userProfile, specificGoal),
      type: RecommendationType.goalOriented,
      reasons: [
        'Ideal para seu objetivo: ${_getGoalName(specificGoal)}',
        'Compatível com seu nível atual',
        'Duração adequada para sua disponibilidade',
      ],
      algorithmScores: scores,
      generatedAt: DateTime.now(),
      priority: 1,
      metadata: {
        'specific_goal': specificGoal.toString(),
        'goal_alignment_score': bestScore,
      },
    );
  }

  /// Avalia a qualidade de uma recomendação após feedback do usuário
  static Future<double> evaluateRecommendationQuality({
    required RecommendationResult recommendation,
    required double userFeedback, // 1.0-5.0
    required bool wasCompleted,
  }) async {
    double qualityScore = 0.0;

    // Score baseado no feedback do usuário
    qualityScore += (userFeedback / 5.0) * 0.4;

    // Score baseado na conclusão
    qualityScore += wasCompleted ? 0.3 : 0.0;

    // Score baseado na confiança original vs resultado real
    final confidencePenalty = (recommendation.confidenceScore - (userFeedback / 5.0)).abs() * 0.2;
    qualityScore -= confidencePenalty;

    // Score baseado no tipo de recomendação vs resultado
    qualityScore += _getTypeSuccessBonus(recommendation.type, userFeedback) * 0.1;

    return qualityScore.clamp(0.0, 1.0);
  }

  // ========== MÉTODOS PRIVADOS ==========

  static List<WorkoutModel> _filterInappropriateWorkouts(
    List<WorkoutModel> workouts, 
    UserProfile user,
  ) {
    return workouts.where((workout) {
      // Filtra treinos muito longos
      if (workout.duration > user.maxWorkoutDuration * 1.2) return false;

      // Filtra treinos muito fáceis/difíceis baseado na experiência
      final difficultyLevel = _getDifficultyValue(workout.difficulty);
      final userLevel = _getExperienceLevelValue(user.experienceLevel);
      if ((difficultyLevel - userLevel).abs() > 2) return false;

      // Filtra exercícios não recomendados por segurança
      if (user.injuryRisk > 0.7 && workout.category.toLowerCase() == 'hiit') return false;

      return true;
    }).toList();
  }

  static Future<Map<String, double>> _calculateAllScores(
    WorkoutModel workout, 
    UserProfile user,
  ) async {
    return {
      'content_based': MLAlgorithms.contentBasedScore(workout, user),
      'collaborative': MLAlgorithms.collaborativeFilteringScore(workout, user),
      'hybrid': MLAlgorithms.hybridScore(workout, user),
      'diversity': MLAlgorithms.diversityScore(workout, user),
      'progression': MLAlgorithms.progressionScore(workout, user),
    };
  }

  static RecommendationType _determineRecommendationType(
    WorkoutModel workout,
    UserProfile user,
    Map<String, double> scores,
  ) {
    final hybridScore = scores['hybrid'] ?? 0.0;
    final diversityScore = scores['diversity'] ?? 0.0;
    final progressionScore = scores['progression'] ?? 0.0;

    // Lógica para determinar o tipo baseado nos scores
    if (progressionScore > 0.8) return RecommendationType.progressive;
    if (diversityScore > 0.8) return RecommendationType.variety;
    if (hybridScore > 0.9) return RecommendationType.personalBest;
    
    // Baseado no objetivo do usuário
    switch (user.fitnessGoal) {
      case FitnessGoal.loseWeight:
        if (workout.calories > user.weight * 4) return RecommendationType.goalOriented;
        break;
      case FitnessGoal.gainMuscle:
        if (workout.category == 'Força') return RecommendationType.goalOriented;
        break;
      case FitnessGoal.endurance:
        if (workout.category == 'Cardio') return RecommendationType.goalOriented;
        break;
      default:
        break;
    }

    // Baseado na consistência do usuário
    if (user.workoutConsistency < 0.3) return RecommendationType.recovery;
    if (hybridScore > 0.7) return RecommendationType.challenge;

    return RecommendationType.personalBest;
  }

  static double _calculateFinalScore(
    Map<String, double> scores, 
    RecommendationType type,
  ) {
    switch (type) {
      case RecommendationType.personalBest:
        return scores['hybrid'] ?? 0.0;
      case RecommendationType.progressive:
        return scores['progression'] ?? 0.0;
      case RecommendationType.variety:
        return scores['diversity'] ?? 0.0;
      case RecommendationType.goalOriented:
        return scores['content_based'] ?? 0.0;
      default:
        return (scores.values.reduce((a, b) => a + b) / scores.length);
    }
  }

  static double _calculateConfidenceScore(
    Map<String, double> scores, 
    UserProfile user,
  ) {
    final averageScore = scores.values.reduce((a, b) => a + b) / scores.length;
    
    // Confiança maior para usuários com mais histórico
    final historyBonus = (user.totalWorkoutsCompleted / 100).clamp(0.0, 0.2);
    
    // Confiança menor se os algoritmos discordam muito
    final standardDeviation = _calculateStandardDeviation(scores.values.toList());
    final consensusPenalty = standardDeviation * 0.3;

    return (averageScore + historyBonus - consensusPenalty).clamp(0.0, 1.0);
  }

  static String _generateReasoning(
    WorkoutModel workout,
    UserProfile user,
    Map<String, double> scores,
    RecommendationType type,
  ) {
    final reasons = <String>[];

    // Razão principal baseada no tipo
    switch (type) {
      case RecommendationType.personalBest:
        reasons.add('Este treino combina perfeitamente com suas preferências e histórico');
        break;
      case RecommendationType.progressive:
        reasons.add('Um próximo passo ideal para sua evolução no fitness');
        break;
      case RecommendationType.variety:
        reasons.add('Uma mudança refrescante na sua rotina de treinos');
        break;
      case RecommendationType.goalOriented:
        reasons.add('Especialmente eficaz para seu objetivo de ${_getGoalName(user.fitnessGoal)}');
        break;
      case RecommendationType.recovery:
        reasons.add('Um treino mais suave para manter consistência');
        break;
      case RecommendationType.challenge:
        reasons.add('Um desafio para testar seus limites atuais');
        break;
    }

    // Adiciona razões específicas baseadas nos scores
    if (scores['content_based']! > 0.8) {
      reasons.add('Categoria ${workout.category} está em suas preferências');
    }
    
    if (workout.duration <= user.maxWorkoutDuration * 0.8) {
      reasons.add('Duração ideal para sua agenda (${workout.duration} min)');
    }

    return reasons.join('. ');
  }

  static List<String> _generateReasonsList(
    WorkoutModel workout,
    UserProfile user,
    Map<String, double> scores,
  ) {
    final reasons = <String>[];

    if (user.preferredCategories.contains(workout.category)) {
      reasons.add('${workout.category} é uma de suas categorias favoritas');
    }

    if (workout.difficulty == _getRecommendedDifficulty(user.experienceLevel)) {
      reasons.add('Nível de dificuldade ideal para você');
    }

    if (workout.duration <= user.maxWorkoutDuration) {
      reasons.add('Se encaixa na sua disponibilidade de tempo');
    }

    final calorieMatch = _calculateCalorieMatchForGoal(workout, user);
    if (calorieMatch > 0.7) {
      reasons.add('Queima de calorias alinhada com seu objetivo');
    }

    if (scores['diversity']! > 0.7) {
      reasons.add('Adiciona variedade à sua rotina atual');
    }

    return reasons.take(3).toList();
  }

  static int _calculatePriority(
    double finalScore,
    RecommendationType type,
    UserProfile user,
  ) {
    if (finalScore > 0.8) return 1; // Alta prioridade
    if (finalScore > 0.6) return 2; // Média prioridade
    return 3; // Baixa prioridade
  }

  static List<RecommendationResult> _applyDiversityFilter(
    List<RecommendationResult> recommendations,
    int maxRecommendations,
  ) {
    final diverseRecommendations = <RecommendationResult>[];
    final usedCategories = <String>{};

    for (final rec in recommendations) {
      final category = rec.metadata['workout_category'] as String;
      
      // Adiciona se ainda não temos dessa categoria ou se é muito boa
      if (!usedCategories.contains(category) || rec.confidenceScore > 0.9) {
        diverseRecommendations.add(rec);
        usedCategories.add(category);
        
        if (diverseRecommendations.length >= maxRecommendations) break;
      }
    }

    // Se não temos recomendações suficientes, adiciona as melhores restantes
    for (final rec in recommendations) {
      if (!diverseRecommendations.contains(rec)) {
        diverseRecommendations.add(rec);
        if (diverseRecommendations.length >= maxRecommendations) break;
      }
    }

    return diverseRecommendations;
  }

  // Métodos auxiliares
  static bool _isWorkoutAlignedWithGoal(
    WorkoutModel workout, 
    FitnessGoal goal, 
    UserProfile user,
  ) {
    switch (goal) {
      case FitnessGoal.loseWeight:
        return workout.calories > user.weight * 3.5;
      case FitnessGoal.gainMuscle:
        return workout.category == 'Força';
      case FitnessGoal.endurance:
        return workout.category == 'Cardio' || workout.category == 'HIIT';
      case FitnessGoal.flexibility:
        return workout.category == 'Yoga' || workout.category == 'Flexibilidade';
      default:
        return true;
    }
  }

  static Future<double> _calculateGoalSpecificScore(
    WorkoutModel workout,
    UserProfile user,
    FitnessGoal goal,
  ) async {
    final baseScore = MLAlgorithms.contentBasedScore(workout, user);
    
    // Bonus específico do objetivo
    double goalBonus = 0.0;
    if (_isWorkoutAlignedWithGoal(workout, goal, user)) {
      goalBonus = 0.3;
    }

    return (baseScore + goalBonus).clamp(0.0, 1.0);
  }

  static String _generateGoalSpecificReasoning(
    WorkoutModel workout,
    UserProfile user,
    FitnessGoal goal,
  ) {
    return 'Este treino foi especificamente selecionado para seu objetivo de ${_getGoalName(goal)}. '
           'Com duração de ${workout.duration} minutos e ${workout.exercises} exercícios, '
           'é ideal para maximizar seus resultados.';
  }

  static String _getGoalName(FitnessGoal goal) {
    switch (goal) {
      case FitnessGoal.loseWeight: return 'perda de peso';
      case FitnessGoal.gainMuscle: return 'ganho de massa muscular';
      case FitnessGoal.maintain: return 'manutenção da forma física';
      case FitnessGoal.endurance: return 'melhoria da resistência';
      case FitnessGoal.flexibility: return 'aumento da flexibilidade';
      case FitnessGoal.strength: return 'ganho de força';
    }
  }

  static int _getDifficultyValue(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'iniciante': return 1;
      case 'intermediário': return 2;
      case 'avançado': return 3;
      default: return 1;
    }
  }

  static int _getExperienceLevelValue(ExperienceLevel level) {
    switch (level) {
      case ExperienceLevel.beginner: return 1;
      case ExperienceLevel.intermediate: return 2;
      case ExperienceLevel.advanced: return 3;
    }
  }

  static String _getRecommendedDifficulty(ExperienceLevel level) {
    switch (level) {
      case ExperienceLevel.beginner: return 'Iniciante';
      case ExperienceLevel.intermediate: return 'Intermediário';
      case ExperienceLevel.advanced: return 'Avançado';
    }
  }

  static double _calculateCalorieMatchForGoal(WorkoutModel workout, UserProfile user) {
    double targetCalories = user.weight * 4.0; // Default

    switch (user.fitnessGoal) {
      case FitnessGoal.loseWeight:
        targetCalories = user.weight * 5.0;
        break;
      case FitnessGoal.gainMuscle:
        targetCalories = user.weight * 3.0;
        break;
      case FitnessGoal.endurance:
        targetCalories = user.weight * 6.0;
        break;
      default:
        break;
    }

    final difference = (workout.calories - targetCalories).abs();
    return (1.0 - (difference / targetCalories)).clamp(0.0, 1.0);
  }

  static double _calculateStandardDeviation(List<double> values) {
    if (values.length < 2) return 0.0;
    
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values
        .map((x) => (x - mean) * (x - mean))
        .reduce((a, b) => a + b) / values.length;
    
    return sqrt(variance);
  }

  static double _getTypeSuccessBonus(RecommendationType type, double userFeedback) {
    // Bonus baseado em quão bem cada tipo de recomendação costuma performar
    switch (type) {
      case RecommendationType.personalBest:
        return userFeedback > 4.0 ? 0.2 : 0.0;
      case RecommendationType.progressive:
        return userFeedback > 3.5 ? 0.15 : -0.1;
      case RecommendationType.variety:
        return userFeedback > 3.0 ? 0.1 : 0.0;
      default:
        return 0.0;
    }
  }
}