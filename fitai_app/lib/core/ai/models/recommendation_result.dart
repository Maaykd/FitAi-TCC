/// Resultado de uma recomendação do sistema de IA
/// Contém o treino recomendado e toda a metadata da recomendação
class RecommendationResult {
  final int workoutId;
  final String workoutName;
  final double confidenceScore; // 0.0 a 1.0
  final String reasoning; // Explicação de por que foi recomendado
  final RecommendationType type;
  final List<String> reasons; // Lista de motivos específicos
  final Map<String, double> algorithmScores; // Score de cada algoritmo usado
  final DateTime generatedAt;
  final int priority; // 1 = alta, 2 = média, 3 = baixa

  // Metadata adicional
  final Map<String, dynamic> metadata;

  const RecommendationResult({
    required this.workoutId,
    required this.workoutName,
    required this.confidenceScore,
    required this.reasoning,
    required this.type,
    required this.reasons,
    required this.algorithmScores,
    required this.generatedAt,
    required this.priority,
    required this.metadata,
  });

  // Classificação de confiança
  ConfidenceLevel get confidenceLevel {
    if (confidenceScore >= 0.8) return ConfidenceLevel.high;
    if (confidenceScore >= 0.6) return ConfidenceLevel.medium;
    return ConfidenceLevel.low;
  }

  // Cor para UI baseada na confiança
  String get confidenceColor {
    switch (confidenceLevel) {
      case ConfidenceLevel.high:
        return '#4CAF50'; // Verde
      case ConfidenceLevel.medium:
        return '#FF9800'; // Laranja
      case ConfidenceLevel.low:
        return '#f44336'; // Vermelho
    }
  }

  // Emoji para representar o tipo de recomendação
  String get typeEmoji {
    switch (type) {
      case RecommendationType.personalBest:
        return '🎯';
      case RecommendationType.progressive:
        return '📈';
      case RecommendationType.recovery:
        return '💆‍♂️';
      case RecommendationType.variety:
        return '🔄';
      case RecommendationType.goalOriented:
        return '🏆';
      case RecommendationType.challenge:
        return '💪';
    }
  }

  // Título amigável do tipo
  String get typeTitle {
    switch (type) {
      case RecommendationType.personalBest:
        return 'Ideal para Você';
      case RecommendationType.progressive:
        return 'Evolução Progressiva';
      case RecommendationType.recovery:
        return 'Recuperação Ativa';
      case RecommendationType.variety:
        return 'Variedade no Treino';
      case RecommendationType.goalOriented:
        return 'Focado no Objetivo';
      case RecommendationType.challenge:
        return 'Desafio Pessoal';
    }
  }

  // Algoritmo principal usado (o com maior score)
  String get primaryAlgorithm {
    if (algorithmScores.isEmpty) return 'unknown';
    
    var highest = algorithmScores.entries.first;
    for (final entry in algorithmScores.entries) {
      if (entry.value > highest.value) {
        highest = entry;
      }
    }
    return highest.key;
  }

  // Cria uma cópia com novos valores
  RecommendationResult copyWith({
    int? workoutId,
    String? workoutName,
    double? confidenceScore,
    String? reasoning,
    RecommendationType? type,
    List<String>? reasons,
    Map<String, double>? algorithmScores,
    DateTime? generatedAt,
    int? priority,
    Map<String, dynamic>? metadata,
  }) {
    return RecommendationResult(
      workoutId: workoutId ?? this.workoutId,
      workoutName: workoutName ?? this.workoutName,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      reasoning: reasoning ?? this.reasoning,
      type: type ?? this.type,
      reasons: reasons ?? this.reasons,
      algorithmScores: algorithmScores ?? this.algorithmScores,
      generatedAt: generatedAt ?? this.generatedAt,
      priority: priority ?? this.priority,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'RecommendationResult(workout: $workoutName, confidence: ${(confidenceScore * 100).toStringAsFixed(1)}%, type: $type)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecommendationResult &&
        other.workoutId == workoutId &&
        other.confidenceScore == confidenceScore;
  }

  @override
  int get hashCode => workoutId.hashCode ^ confidenceScore.hashCode;
}

/// Lista de recomendações ordenadas por prioridade e confiança
class RecommendationList {
  final List<RecommendationResult> recommendations;
  final DateTime generatedAt;
  final String algorithmVersion;
  final Map<String, dynamic> sessionMetadata;

  const RecommendationList({
    required this.recommendations,
    required this.generatedAt,
    required this.algorithmVersion,
    required this.sessionMetadata,
  });

  // Top 3 recomendações
  List<RecommendationResult> get top3 => recommendations.take(3).toList();

  // Apenas recomendações de alta confiança
  List<RecommendationResult> get highConfidence =>
      recommendations.where((r) => r.confidenceLevel == ConfidenceLevel.high).toList();

  // Agrupa por tipo
  Map<RecommendationType, List<RecommendationResult>> get byType {
    final grouped = <RecommendationType, List<RecommendationResult>>{};
    for (final rec in recommendations) {
      grouped.putIfAbsent(rec.type, () => []).add(rec);
    }
    return grouped;
  }

  // Score médio de confiança
  double get averageConfidence {
    if (recommendations.isEmpty) return 0.0;
    final sum = recommendations.fold<double>(0, (sum, r) => sum + r.confidenceScore);
    return sum / recommendations.length;
  }

  // Estatísticas por algoritmo
  Map<String, AlgorithmStats> get algorithmStats {
    final stats = <String, AlgorithmStats>{};
    
    for (final rec in recommendations) {
      for (final entry in rec.algorithmScores.entries) {
        if (!stats.containsKey(entry.key)) {
          stats[entry.key] = AlgorithmStats(name: entry.key);
        }
        stats[entry.key]!.addScore(entry.value);
      }
    }
    
    return stats;
  }

  // Factory para lista vazia
  factory RecommendationList.empty() {
    return RecommendationList(
      recommendations: [],
      generatedAt: DateTime.now(),
      algorithmVersion: '1.0.0',
      sessionMetadata: {},
    );
  }
}

/// Estatísticas de performance de um algoritmo
class AlgorithmStats {
  final String name;
  final List<double> _scores = [];

  AlgorithmStats({required this.name});

  void addScore(double score) {
    _scores.add(score);
  }

  int get count => _scores.length;
  
  double get averageScore {
    if (_scores.isEmpty) return 0.0;
    return _scores.reduce((a, b) => a + b) / _scores.length;
  }

  double get maxScore => _scores.isEmpty ? 0.0 : _scores.reduce((a, b) => a > b ? a : b);
  
  double get minScore => _scores.isEmpty ? 0.0 : _scores.reduce((a, b) => a < b ? a : b);

  double get standardDeviation {
    if (_scores.length < 2) return 0.0;
    
    final mean = averageScore;
    final variance = _scores
        .map((score) => (score - mean) * (score - mean))
        .reduce((a, b) => a + b) / _scores.length;
    
    return variance.squareRoot();
  }
}

// Enums
enum RecommendationType {
  personalBest,   // Melhor match para o perfil
  progressive,    // Próximo nível de dificuldade
  recovery,       // Treino de recuperação/baixa intensidade  
  variety,        // Algo diferente do usual
  goalOriented,   // Focado no objetivo específico
  challenge       // Treino desafiador
}

enum ConfidenceLevel {
  high,    // >= 0.8
  medium,  // >= 0.6
  low      // < 0.6
}

// Extensão para facilitar cálculos matemáticos
extension DoubleExtension on double {
  double squareRoot() => this >= 0 ? (this * this) : 0.0;
}