/// Modelo dos dados de um treino
/// Usado tanto pela UI quanto pelo sistema de recomendação de IA
class WorkoutModel {
  final int id;
  final String name;
  final String description;
  final int duration; // minutos
  final int exercises; // número de exercícios
  final String difficulty; // 'Iniciante', 'Intermediário', 'Avançado'
  final String category; // 'Força', 'Cardio', 'HIIT', etc.
  final int calories; // calorias estimadas
  final String? imageUrl;
  final bool isRecommended; // Se aparece na aba de recomendados
  
  // Campos adicionais para IA
  final List<String> muscleGroups; // grupos musculares trabalhados
  final List<String> equipment; // equipamentos necessários
  final double intensity; // 0.0 a 1.0
  final List<String> tags; // tags adicionais para busca
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const WorkoutModel({
    required this.id,
    required this.name,
    required this.description,
    required this.duration,
    required this.exercises,
    required this.difficulty,
    required this.category,
    required this.calories,
    this.imageUrl,
    this.isRecommended = false,
    this.muscleGroups = const [],
    this.equipment = const ['bodyweight'],
    this.intensity = 0.5,
    this.tags = const [],
    this.createdAt,
    this.updatedAt,
  });

  // Getters úteis
  bool get isBeginner => difficulty.toLowerCase() == 'iniciante';
  bool get isIntermediate => difficulty.toLowerCase() == 'intermediário';
  bool get isAdvanced => difficulty.toLowerCase() == 'avançado';
  
  bool get isStrength => category.toLowerCase() == 'força';
  bool get isCardio => category.toLowerCase() == 'cardio';
  bool get isHIIT => category.toLowerCase() == 'hiit';
  
  double get caloriesPerMinute => calories / duration;
  
  // Intensidade calculada baseada na categoria e dificuldade
  double get calculatedIntensity {
    double baseIntensity = intensity;
    
    // Ajusta baseado na categoria
    switch (category.toLowerCase()) {
      case 'hiit':
        baseIntensity += 0.3;
        break;
      case 'cardio':
        baseIntensity += 0.2;
        break;
      case 'força':
        baseIntensity += 0.1;
        break;
    }
    
    // Ajusta baseado na dificuldade
    switch (difficulty.toLowerCase()) {
      case 'iniciante':
        baseIntensity -= 0.1;
        break;
      case 'avançado':
        baseIntensity += 0.2;
        break;
    }
    
    return baseIntensity.clamp(0.0, 1.0);
  }

  // Cópia com modificações
  WorkoutModel copyWith({
    int? id,
    String? name,
    String? description,
    int? duration,
    int? exercises,
    String? difficulty,
    String? category,
    int? calories,
    String? imageUrl,
    bool? isRecommended,
    List<String>? muscleGroups,
    List<String>? equipment,
    double? intensity,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorkoutModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      duration: duration ?? this.duration,
      exercises: exercises ?? this.exercises,
      difficulty: difficulty ?? this.difficulty,
      category: category ?? this.category,
      calories: calories ?? this.calories,
      imageUrl: imageUrl ?? this.imageUrl,
      isRecommended: isRecommended ?? this.isRecommended,
      muscleGroups: muscleGroups ?? this.muscleGroups,
      equipment: equipment ?? this.equipment,
      intensity: intensity ?? this.intensity,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Factory para criar dados mock expandidos
  static List<WorkoutModel> getMockWorkouts() {
    return [
      WorkoutModel(
        id: 1,
        name: 'Full Body - Iniciante',
        description: 'Treino completo para iniciantes focado em todos os grupos musculares com exercícios funcionais',
        duration: 45,
        exercises: 8,
        difficulty: 'Iniciante',
        category: 'Força',
        calories: 280,
        isRecommended: true,
        muscleGroups: ['chest', 'back', 'legs', 'arms', 'core'],
        equipment: ['bodyweight', 'dumbbells'],
        intensity: 0.4,
        tags: ['beginner-friendly', 'full-body', 'functional'],
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        updatedAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      WorkoutModel(
        id: 2,
        name: 'Cardio HIIT Intenso',
        description: 'Treino intervalado de alta intensidade para máxima queima de gordura e condicionamento cardiovascular',
        duration: 30,
        exercises: 6,
        difficulty: 'Intermediário',
        category: 'HIIT',
        calories: 350,
        isRecommended: true,
        muscleGroups: ['legs', 'core', 'cardio'],
        equipment: ['bodyweight'],
        intensity: 0.8,
        tags: ['fat-burn', 'cardio', 'high-intensity', 'quick'],
        createdAt: DateTime.now().subtract(const Duration(days: 25)),
        updatedAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      WorkoutModel(
        id: 3,
        name: 'Força - Peito e Tríceps',
        description: 'Desenvolvimento muscular focado em peito e tríceps com exercícios compostos e isoladores',
        duration: 50,
        exercises: 10,
        difficulty: 'Avançado',
        category: 'Força',
        calories: 320,
        muscleGroups: ['chest', 'triceps', 'shoulders'],
        equipment: ['dumbbells', 'bench', 'barbell'],
        intensity: 0.7,
        tags: ['muscle-building', 'upper-body', 'strength'],
        createdAt: DateTime.now().subtract(const Duration(days: 20)),
        updatedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      WorkoutModel(
        id: 4,
        name: 'Yoga Matinal',
        description: 'Sequência suave de yoga para alongar o corpo, acalmar a mente e começar o dia com energia positiva',
        duration: 25,
        exercises: 12,
        difficulty: 'Iniciante',
        category: 'Yoga',
        calories: 120,
        muscleGroups: ['core', 'flexibility'],
        equipment: ['yoga-mat'],
        intensity: 0.3,
        tags: ['morning', 'flexibility', 'mindfulness', 'recovery'],
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      WorkoutModel(
        id: 5,
        name: 'Core e Abdomen',
        description: 'Fortalecimento completo do core e músculos abdominais para estabilidade e força funcional',
        duration: 35,
        exercises: 8,
        difficulty: 'Intermediário',
        category: 'Força',
        calories: 200,
        muscleGroups: ['core', 'abs', 'obliques'],
        equipment: ['bodyweight', 'medicine-ball'],
        intensity: 0.6,
        tags: ['core-strength', 'abs', 'stability'],
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      WorkoutModel(
        id: 6,
        name: 'Flexibilidade Total',
        description: 'Sessão completa de alongamento para melhorar flexibilidade, mobilidade e prevenir lesões',
        duration: 40,
        exercises: 15,
        difficulty: 'Iniciante',
        category: 'Flexibilidade',
        calories: 100,
        muscleGroups: ['flexibility', 'mobility'],
        equipment: ['yoga-mat', 'resistance-bands'],
        intensity: 0.2,
        tags: ['flexibility', 'mobility', 'recovery', 'injury-prevention'],
        createdAt: DateTime.now().subtract(const Duration(days: 8)),
        updatedAt: DateTime.now(),
      ),
      WorkoutModel(
        id: 7,
        name: 'Pernas e Glúteos Power',
        description: 'Treino intenso para pernas e glúteos com foco em força, potência e definição muscular',
        duration: 55,
        exercises: 12,
        difficulty: 'Avançado',
        category: 'Força',
        calories: 400,
        muscleGroups: ['legs', 'glutes', 'calves'],
        equipment: ['barbell', 'dumbbells', 'squat-rack'],
        intensity: 0.8,
        tags: ['leg-day', 'glutes', 'power', 'strength'],
        createdAt: DateTime.now().subtract(const Duration(days: 12)),
        updatedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      WorkoutModel(
        id: 8,
        name: 'Cardio Dance Fitness',
        description: 'Exercício cardiovascular divertido combinando dança com movimentos fitness para queimar calorias',
        duration: 40,
        exercises: 8,
        difficulty: 'Intermediário',
        category: 'Cardio',
        calories: 300,
        muscleGroups: ['cardio', 'coordination'],
        equipment: ['bodyweight'],
        intensity: 0.6,
        tags: ['fun', 'dance', 'cardio', 'coordination'],
        createdAt: DateTime.now().subtract(const Duration(days: 6)),
        updatedAt: DateTime.now(),
      ),
    ];
  }

  @override
  String toString() {
    return 'WorkoutModel(id: $id, name: $name, category: $category, difficulty: $difficulty)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WorkoutModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}