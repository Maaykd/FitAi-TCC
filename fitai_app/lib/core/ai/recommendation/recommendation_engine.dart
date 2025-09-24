import 'dart:async';
import 'dart:math';
import '../models/user_profile.dart';
import '../models/recommendation_result.dart';
import '../services/recommendation_service.dart';
import '../../models/workout_model.dart';

/// Engine principal que gerencia todo o sistema de recomendações
/// Singleton para gerenciar estado e performance
class RecommendationEngine {
  static RecommendationEngine? _instance;
  static RecommendationEngine get instance => _instance ??= RecommendationEngine._();
  
  RecommendationEngine._();

  // Cache das recomendações
  RecommendationList? _cachedRecommendations;
  DateTime? _cacheTimestamp;
  static const Duration _cacheExpiration = Duration(minutes: 30);

  // Estado atual
  UserProfile? _currentUserProfile;
  List<WorkoutModel> _availableWorkouts = [];
  bool _isInitialized = false;

  // Stream para notificar mudanças
  final StreamController<RecommendationList> _recommendationsController = 
      StreamController<RecommendationList>.broadcast();
  
  Stream<RecommendationList> get recommendationsStream => 
      _recommendationsController.stream;

  // Métricas de performance
  final Map<String, dynamic> _performanceMetrics = {
    'total_recommendations_generated': 0,
    'cache_hits': 0,
    'cache_misses': 0,
    'average_generation_time_ms': 0.0,
    'last_generation_time': null,
  };

  /// Inicializa o engine com dados do usuário e treinos disponíveis
  Future<void> initialize({
    required UserProfile userProfile,
    required List<WorkoutModel> availableWorkouts,
  }) async {
    _currentUserProfile = userProfile;
    _availableWorkouts = availableWorkouts;
    _isInitialized = true;

    // Gera recomendações iniciais em background
    _generateRecommendationsInBackground();

    print('✅ RecommendationEngine inicializado para usuário ${userProfile.name}');
    print('📊 ${availableWorkouts.length} treinos disponíveis');
  }

  /// Obtém recomendações (usa cache se disponível)
  Future<RecommendationList> getRecommendations({
    int maxRecommendations = 5,
    bool forceRefresh = false,
  }) async {
    _ensureInitialized();

    // Verifica cache
    if (!forceRefresh && _isCacheValid()) {
      _performanceMetrics['cache_hits']++;
      return _cachedRecommendations!;
    }

    _performanceMetrics['cache_misses']++;
    
    final stopwatch = Stopwatch()..start();
    
    final recommendations = await RecommendationService.generateRecommendations(
      userProfile: _currentUserProfile!,
      availableWorkouts: _availableWorkouts,
      maxRecommendations: maxRecommendations,
    );

    stopwatch.stop();

    // Atualiza métricas
    _updatePerformanceMetrics(stopwatch.elapsedMilliseconds);
    
    // Atualiza cache
    _updateCache(recommendations);
    
    // Notifica listeners
    _recommendationsController.add(recommendations);

    print('🤖 Geradas ${recommendations.recommendations.length} recomendações');
    print('⚡ Tempo: ${stopwatch.elapsedMilliseconds}ms');

    return recommendations;
  }

  /// Obtém recomendação específica para um objetivo
  Future<RecommendationResult?> getGoalFocusedRecommendation({
    required FitnessGoal goal,
  }) async {
    _ensureInitialized();

    final stopwatch = Stopwatch()..start();
    
    final recommendation = await RecommendationService.generateGoalFocusedRecommendation(
      userProfile: _currentUserProfile!,
      availableWorkouts: _availableWorkouts,
      specificGoal: goal,
    );

    stopwatch.stop();
    
    if (recommendation != null) {
      print('🎯 Recomendação focada em ${_getGoalName(goal)} gerada');
      print('⚡ Tempo: ${stopwatch.elapsedMilliseconds}ms');
    }

    return recommendation;
  }

  /// Registra feedback do usuário sobre uma recomendação
  Future<void> recordFeedback({
    required int workoutId,
    required double rating, // 1-5
    required bool wasCompleted,
    String? comments,
  }) async {
    _ensureInitialized();

    // Encontra a recomendação no cache
    final recommendation = _cachedRecommendations?.recommendations
        .firstWhere((r) => r.workoutId == workoutId, orElse: () => throw Exception('Recommendation not found'));

    if (recommendation != null) {
      final qualityScore = await RecommendationService.evaluateRecommendationQuality(
        recommendation: recommendation,
        userFeedback: rating,
        wasCompleted: wasCompleted,
      );

      // Atualiza perfil do usuário com feedback
      await _updateUserProfileWithFeedback(
        workoutId: workoutId,
        rating: rating,
        wasCompleted: wasCompleted,
      );

      print('📝 Feedback registrado: Rating ${rating}/5, Qualidade: ${(qualityScore * 100).toStringAsFixed(1)}%');
    }

    // Invalida cache para próximas recomendações considerarem o feedback
    _invalidateCache();
  }

  /// Atualiza o perfil do usuário (ex: peso, objetivos)
  Future<void> updateUserProfile(UserProfile newProfile) async {
    _currentUserProfile = newProfile;
    _invalidateCache();
    
    // Regenera recomendações com novo perfil
    await _generateRecommendationsInBackground();
    
    print('👤 Perfil do usuário atualizado');
  }

  /// Adiciona novos treinos disponíveis
  void addWorkouts(List<WorkoutModel> newWorkouts) {
    _availableWorkouts.addAll(newWorkouts);
    _invalidateCache();
    
    print('➕ ${newWorkouts.length} novos treinos adicionados');
  }

  /// Obtém estatísticas de performance do engine
  Map<String, dynamic> getPerformanceStats() {
    return Map.from(_performanceMetrics)
      ..['cache_hit_rate'] = _calculateCacheHitRate()
      ..['is_initialized'] = _isInitialized
      ..['cache_valid'] = _isCacheValid()
      ..['available_workouts_count'] = _availableWorkouts.length
      ..['user_profile_loaded'] = _currentUserProfile != null;
  }

  /// Limpa cache e dados (útil para logout)
  void reset() {
    _cachedRecommendations = null;
    _cacheTimestamp = null;
    _currentUserProfile = null;
    _availableWorkouts.clear();
    _isInitialized = false;
    _performanceMetrics.clear();
    
    print('🔄 RecommendationEngine resetado');
  }

  /// Obtém recomendações por categoria específica
  Future<List<RecommendationResult>> getRecommendationsByCategory({
    required String category,
    int maxCount = 3,
  }) async {
    final allRecommendations = await getRecommendations(maxRecommendations: 20);
    
    return allRecommendations.recommendations
        .where((r) => r.metadata['workout_category'] == category)
        .take(maxCount)
        .toList();
  }

  /// Simula learning do sistema baseado no uso
  Future<void> performModelLearning() async {
    if (_currentUserProfile == null) return;

    // Simula processo de aprendizado
    await Future.delayed(const Duration(seconds: 2));
    
    // Atualiza "pesos" dos algoritmos baseado no sucesso histórico
    _adjustAlgorithmWeights();
    
    // Invalida cache para aplicar aprendizado
    _invalidateCache();
    
    print('🧠 Modelo de ML atualizado com base no histórico do usuário');
  }

  /// Diagnóstico do sistema para debugging
  Future<Map<String, dynamic>> runDiagnostics() async {
    final diagnostics = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'engine_status': 'healthy',
      'issues': <String>[],
      'recommendations': <String, dynamic>{},
    };

    // Testa geração de recomendações
    try {
      final testRecommendations = await getRecommendations(maxRecommendations: 3);
      diagnostics['recommendations'] = {
        'count': testRecommendations.recommendations.length,
        'average_confidence': testRecommendations.averageConfidence,
        'generation_time': _performanceMetrics['average_generation_time_ms'],
      };
    } catch (e) {
      diagnostics['issues'].add('Failed to generate recommendations: $e');
      diagnostics['engine_status'] = 'degraded';
    }

    // Verifica dados necessários
    if (_currentUserProfile == null) {
      diagnostics['issues'].add('User profile not loaded');
      diagnostics['engine_status'] = 'error';
    }

    if (_availableWorkouts.isEmpty) {
      diagnostics['issues'].add('No workouts available');
      diagnostics['engine_status'] = 'warning';
    }

    return diagnostics;
  }

  // ========== MÉTODOS PRIVADOS ==========

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw Exception('RecommendationEngine not initialized. Call initialize() first.');
    }
  }

  bool _isCacheValid() {
    if (_cachedRecommendations == null || _cacheTimestamp == null) {
      return false;
    }
    
    return DateTime.now().difference(_cacheTimestamp!) < _cacheExpiration;
  }

  void _updateCache(RecommendationList recommendations) {
    _cachedRecommendations = recommendations;
    _cacheTimestamp = DateTime.now();
  }

  void _invalidateCache() {
    _cachedRecommendations = null;
    _cacheTimestamp = null;
  }

  void _updatePerformanceMetrics(int generationTimeMs) {
    _performanceMetrics['total_recommendations_generated']++;
    _performanceMetrics['last_generation_time'] = DateTime.now().toIso8601String();
    
    final total = _performanceMetrics['total_recommendations_generated'] as int;
    final currentAvg = _performanceMetrics['average_generation_time_ms'] as double;
    final newAvg = ((currentAvg * (total - 1)) + generationTimeMs) / total;
    
    _performanceMetrics['average_generation_time_ms'] = newAvg;
  }

  double _calculateCacheHitRate() {
    final hits = _performanceMetrics['cache_hits'] as int? ?? 0;
    final misses = _performanceMetrics['cache_misses'] as int? ?? 0;
    final total = hits + misses;
    
    return total > 0 ? hits / total : 0.0;
  }

  Future<void> _generateRecommendationsInBackground() async {
    if (!_isInitialized) return;
    
    try {
      await getRecommendations(forceRefresh: true);
    } catch (e) {
      print('❌ Erro ao gerar recomendações em background: $e');
    }
  }

  Future<void> _updateUserProfileWithFeedback({
    required int workoutId,
    required double rating,
    required bool wasCompleted,
  }) async {
    if (_currentUserProfile == null) return;

    final workout = _availableWorkouts.firstWhere(
      (w) => w.id == workoutId,
      orElse: () => throw Exception('Workout not found'),
    );

    // Atualiza histórico do usuário
    final newHistory = WorkoutHistory(
      workoutId: workoutId,
      workoutName: workout.name,
      category: workout.category,
      completedAt: DateTime.now(),
      duration: workout.duration,
      rating: rating,
      caloriesBurned: workout.calories,
      difficulty: workout.difficulty,
    );

    final updatedHistory = [..._currentUserProfile!.workoutHistory, newHistory];
    final updatedCategories = [..._currentUserProfile!.completedWorkoutCategories, workout.category];
    
    // Recalcula rating médio
    final allRatings = updatedHistory.map((h) => h.rating).toList();
    final newAverageRating = allRatings.reduce((a, b) => a + b) / allRatings.length;

    // Atualiza preferências baseado no feedback
    final updatedPreferences = Map<String, double>.from(_currentUserProfile!.muscleGroupPreference);
    if (rating >= 4.0) {
      // Se gostou, aumenta preferência pela categoria
      final currentPref = updatedPreferences[workout.category.toLowerCase()] ?? 0.5;
      updatedPreferences[workout.category.toLowerCase()] = (currentPref + 0.1).clamp(0.0, 1.0);
    }

    _currentUserProfile = _currentUserProfile!.copyWith(
      workoutHistory: updatedHistory,
      completedWorkoutCategories: updatedCategories,
      averageWorkoutRating: newAverageRating,
      totalWorkoutsCompleted: _currentUserProfile!.totalWorkoutsCompleted + (wasCompleted ? 1 : 0),
      muscleGroupPreference: updatedPreferences,
    );
  }

  void _adjustAlgorithmWeights() {
    // Simula ajuste de pesos dos algoritmos baseado no feedback histórico
    // Em uma implementação real, isso seria baseado em dados reais
    print('🔧 Ajustando pesos dos algoritmos baseado no feedback do usuário');
  }

  String _getGoalName(FitnessGoal goal) {
    switch (goal) {
      case FitnessGoal.loseWeight: return 'perda de peso';
      case FitnessGoal.gainMuscle: return 'ganho de massa muscular';
      case FitnessGoal.maintain: return 'manutenção';
      case FitnessGoal.endurance: return 'resistência';
      case FitnessGoal.flexibility: return 'flexibilidade';
      case FitnessGoal.strength: return 'força';
    }
  }

  /// Cleanup quando a instância for destruída
  void dispose() {
    _recommendationsController.close();
    reset();
  }
}