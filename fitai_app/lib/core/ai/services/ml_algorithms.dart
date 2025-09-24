import 'dart:math';
import '../models/user_profile.dart';
import '../../models/workout_model.dart';

/// Implementação dos algoritmos de Machine Learning para recomendação
/// Inclui: Content-Based Filtering, Collaborative Filtering e Hybrid Approach
class MLAlgorithms {
  static const String version = '1.0.0';
  
  /// Content-Based Filtering: Recomenda baseado nas características dos treinos
  /// e preferências do usuário
  static double contentBasedScore(WorkoutModel workout, UserProfile user) {
    double score = 0.0;
    int factors = 0;

    // 1. Compatibilidade de categoria (peso: 25%)
    if (user.preferredCategories.contains(workout.category)) {
      score += 0.25;
    }
    factors++;

    // 2. Adequação de dificuldade (peso: 20%)
    final difficultyScore = _calculateDifficultyMatch(workout.difficulty, user);
    score += difficultyScore * 0.20;
    factors++;

    // 3. Duração adequada (peso: 15%)
    final durationScore = _calculateDurationMatch(workout.duration, user);
    score += durationScore * 0.15;
    factors++;

    // 4. Calorias vs objetivo (peso: 15%)
    final calorieScore = _calculateCalorieMatch(workout.calories, user);
    score += calorieScore * 0.15;
    factors++;

    // 5. Histórico de categoria (peso: 15%)
    final categoryHistoryScore = _calculateCategoryHistoryMatch(workout.category, user);
    score += categoryHistoryScore * 0.15;
    factors++;

    // 6. Frequência de treino (peso: 10%)
    final frequencyScore = _calculateFrequencyMatch(user);
    score += frequencyScore * 0.10;
    factors++;

    return score.clamp(0.0, 1.0);
  }

  /// Collaborative Filtering: Recomenda baseado em usuários similares
  /// (Simulado com dados mock para demonstração)
  static double collaborativeFilteringScore(WorkoutModel workout, UserProfile user) {
    // Simula usuários similares com base em características
    final similarUsers = _findSimilarUsers(user);
    
    if (similarUsers.isEmpty) return 0.5; // Score neutro se não há dados

    double totalScore = 0.0;
    int validRatings = 0;

    for (final similarUser in similarUsers) {
      // Simula rating do usuário similar para este treino
      final rating = _simulateUserRating(workout, similarUser);
      if (rating > 0) {
        final similarity = _calculateUserSimilarity(user, similarUser);
        totalScore += rating * similarity;
        validRatings++;
      }
    }

    return validRatings > 0 ? (totalScore / validRatings).clamp(0.0, 1.0) : 0.5;
  }

  /// Hybrid Approach: Combina Content-Based e Collaborative Filtering
  static double hybridScore(WorkoutModel workout, UserProfile user) {
    final contentScore = contentBasedScore(workout, user);
    final collaborativeScore = collaborativeFilteringScore(workout, user);
    
    // Peso dinâmico baseado na experiência do usuário
    double contentWeight = 0.7; // Maior peso para content-based inicialmente
    double collaborativeWeight = 0.3;

    // Se o usuário tem mais histórico, dá mais peso ao collaborative
    if (user.totalWorkoutsCompleted > 20) {
      contentWeight = 0.4;
      collaborativeWeight = 0.6;
    }

    return (contentScore * contentWeight + collaborativeScore * collaborativeWeight)
        .clamp(0.0, 1.0);
  }

  /// Algoritmo de Diversidade: Pontuação baseada em variedade
  static double diversityScore(WorkoutModel workout, UserProfile user) {
    final recentCategories = user.workoutHistory
        .where((h) => h.completedAt.isAfter(DateTime.now().subtract(const Duration(days: 14))))
        .map((h) => h.category)
        .toList();

    // Se a categoria é nova ou pouco usada recentemente, score maior
    final categoryFrequency = recentCategories.where((c) => c == workout.category).length;
    final maxFrequency = recentCategories.length;

    if (maxFrequency == 0) return 0.8; // Se não há histórico recente, favorece diversidade

    final diversityScore = 1.0 - (categoryFrequency / maxFrequency);
    return diversityScore.clamp(0.0, 1.0);
  }

  /// Algoritmo de Progressão: Baseado no avanço gradual de dificuldade
  static double progressionScore(WorkoutModel workout, UserProfile user) {
    final currentLevel = user.experienceLevel;
    final workoutDifficulty = _getDifficultyLevel(workout.difficulty);
    
    // Score ideal quando o treino está um pouco acima do nível atual
    final levelDifference = workoutDifficulty - _getExperienceLevelValue(currentLevel);
    
    if (levelDifference == 0) return 0.8; // Mesmo nível: bom
    if (levelDifference == 1) return 1.0; // Um nível acima: ideal
    if (levelDifference == -1) return 0.6; // Um nível abaixo: ok
    if (levelDifference < -1) return 0.3; // Muito fácil
    return 0.4; // Muito difícil
  }

  // ========== MÉTODOS AUXILIARES ==========

  static double _calculateDifficultyMatch(String workoutDifficulty, UserProfile user) {
    final userLevel = user.experienceLevel;
    final workoutLevel = _getDifficultyLevel(workoutDifficulty);
    final userLevelValue = _getExperienceLevelValue(userLevel);
    
    final difference = (workoutLevel - userLevelValue).abs();
    
    if (difference == 0) return 1.0; // Perfeito
    if (difference == 1) return 0.8; // Bom
    if (difference == 2) return 0.4; // Aceitável
    return 0.1; // Inadequado
  }

  static double _calculateDurationMatch(int workoutDuration, UserProfile user) {
    final maxDuration = user.maxWorkoutDuration;
    
    if (workoutDuration <= maxDuration) {
      // Dentro do limite, score baseado na proximidade do ideal (75% do máximo)
      final idealDuration = maxDuration * 0.75;
      final difference = (workoutDuration - idealDuration).abs();
      return (1.0 - (difference / idealDuration)).clamp(0.0, 1.0);
    } else {
      // Acima do limite, penalidade
      final excess = workoutDuration - maxDuration;
      return (1.0 - (excess / maxDuration)).clamp(0.0, 1.0);
    }
  }

  static double _calculateCalorieMatch(int workoutCalories, UserProfile user) {
    // Calorias ideais baseadas no objetivo e peso
    double idealCalories;
    
    switch (user.fitnessGoal) {
      case FitnessGoal.loseWeight:
        idealCalories = user.weight * 4.5; // ~4.5 cal por kg para perda de peso
        break;
      case FitnessGoal.gainMuscle:
        idealCalories = user.weight * 3.0; // Menor gasto calórico
        break;
      case FitnessGoal.endurance:
        idealCalories = user.weight * 6.0; // Maior gasto
        break;
      default:
        idealCalories = user.weight * 4.0;
    }

    final difference = (workoutCalories - idealCalories).abs();
    return (1.0 - (difference / idealCalories)).clamp(0.0, 1.0);
  }

  static double _calculateCategoryHistoryMatch(String workoutCategory, UserProfile user) {
    final categoryCount = user.completedWorkoutCategories
        .where((c) => c == workoutCategory)
        .length;
    
    if (user.completedWorkoutCategories.isEmpty) return 0.5;
    
    final percentage = categoryCount / user.completedWorkoutCategories.length;
    
    // Se já faz muito de uma categoria, diminui o score (evita monotonia)
    if (percentage > 0.6) return 0.3;
    if (percentage > 0.4) return 0.6;
    if (percentage > 0.2) return 0.9;
    return 1.0; // Categoria pouco explorada
  }

  static double _calculateFrequencyMatch(UserProfile user) {
    final consistency = user.workoutConsistency;
    
    // Score baseado na consistência (usuários consistentes = scores melhores)
    return consistency;
  }

  static List<UserProfile> _findSimilarUsers(UserProfile user) {
    // Simula banco de dados de usuários similares
    // Em produção, seria uma consulta real ao banco
    return List.generate(5, (index) {
      return UserProfile.mock(userId: index + 100)
          .copyWith(
            age: user.age + (index - 2),
            weight: user.weight + (index * 2 - 4),
            fitnessGoal: index.isEven ? user.fitnessGoal : FitnessGoal.gainMuscle,
          );
    });
  }

  static double _simulateUserRating(WorkoutModel workout, UserProfile user) {
    // Simula rating baseado no perfil do usuário
    final random = Random(workout.id * user.userId);
    final baseRating = 2.5 + random.nextDouble() * 2.5; // 2.5-5.0
    
    // Ajusta baseado na compatibilidade
    double adjustment = 0.0;
    
    if (user.preferredCategories.contains(workout.category)) {
      adjustment += 0.5;
    }
    
    if (_calculateDifficultyMatch(workout.difficulty, user) > 0.7) {
      adjustment += 0.3;
    }

    return (baseRating + adjustment).clamp(1.0, 5.0);
  }

  static double _calculateUserSimilarity(UserProfile user1, UserProfile user2) {
    double similarity = 0.0;
    int factors = 0;

    // Idade similar
    final ageDiff = (user1.age - user2.age).abs();
    similarity += (1.0 - (ageDiff / 20.0)).clamp(0.0, 1.0);
    factors++;

    // Objetivo similar
    if (user1.fitnessGoal == user2.fitnessGoal) {
      similarity += 1.0;
    }
    factors++;

    // Nível de atividade similar
    final activityDiff = (_getActivityLevelValue(user1.activityLevel) - 
                         _getActivityLevelValue(user2.activityLevel)).abs();
    similarity += (1.0 - (activityDiff / 4.0)).clamp(0.0, 1.0);
    factors++;

    // IMC similar
    final bmiDiff = (user1.bmi - user2.bmi).abs();
    similarity += (1.0 - (bmiDiff / 10.0)).clamp(0.0, 1.0);
    factors++;

    return (similarity / factors).clamp(0.0, 1.0);
  }

  static int _getDifficultyLevel(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'iniciante':
        return 1;
      case 'intermediário':
        return 2;
      case 'avançado':
        return 3;
      default:
        return 1;
    }
  }

  static int _getExperienceLevelValue(ExperienceLevel level) {
    switch (level) {
      case ExperienceLevel.beginner:
        return 1;
      case ExperienceLevel.intermediate:
        return 2;
      case ExperienceLevel.advanced:
        return 3;
    }
  }

  static int _getActivityLevelValue(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.sedentary:
        return 1;
      case ActivityLevel.light:
        return 2;
      case ActivityLevel.moderate:
        return 3;
      case ActivityLevel.active:
        return 4;
      case ActivityLevel.veryActive:
        return 5;
    }
  }

  /// Método para análise e debug dos algoritmos
  static Map<String, dynamic> analyzeAlgorithmPerformance(
    List<WorkoutModel> workouts,
    UserProfile user,
  ) {
    final results = <String, List<double>>{
      'content_based': [],
      'collaborative': [],
      'hybrid': [],
      'diversity': [],
      'progression': [],
    };

    for (final workout in workouts) {
      results['content_based']!.add(contentBasedScore(workout, user));
      results['collaborative']!.add(collaborativeFilteringScore(workout, user));
      results['hybrid']!.add(hybridScore(workout, user));
      results['diversity']!.add(diversityScore(workout, user));
      results['progression']!.add(progressionScore(workout, user));
    }

    final analysis = <String, dynamic>{};
    
    for (final entry in results.entries) {
      final scores = entry.value;
      analysis[entry.key] = {
        'average': scores.isEmpty ? 0.0 : scores.reduce((a, b) => a + b) / scores.length,
        'max': scores.isEmpty ? 0.0 : scores.reduce(max),
        'min': scores.isEmpty ? 0.0 : scores.reduce(min),
        'count': scores.length,
      };
    }

    return analysis;
  }
}