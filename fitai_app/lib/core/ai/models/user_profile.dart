/// Modelo do perfil do usuário para sistema de recomendação
/// Contém todas as características usadas pelos algoritmos de ML
class UserProfile {
  // Dados básicos do usuário
  final int userId;
  final String name;
  final int age;
  final double weight; // kg
  final double height; // metros
  final String gender; // 'male', 'female', 'other'
  
  // Objetivo fitness
  final FitnessGoal fitnessGoal;
  final ActivityLevel activityLevel;
  
  // Preferências de treino
  final List<String> preferredCategories;
  final List<String> availableEquipment;
  final int maxWorkoutDuration; // minutos
  final List<String> dislikedExercises;
  
  // Histórico e progresso
  final int totalWorkoutsCompleted;
  final List<WorkoutHistory> workoutHistory;
  final double averageWorkoutRating;
  final List<String> completedWorkoutCategories;
  
  // Disponibilidade
  final List<DayOfWeek> availableDays;
  final TimePreference timePreference;
  
  // Métricas de performance
  final double currentFitnessLevel; // 0.0 a 1.0
  final Map<String, double> muscleGroupPreference; // score 0-1 para cada grupo
  final double injuryRisk; // 0.0 a 1.0 (0 = baixo risco)
  
  // Data de última atualização
  final DateTime lastUpdated;

  const UserProfile({
    required this.userId,
    required this.name,
    required this.age,
    required this.weight,
    required this.height,
    required this.gender,
    required this.fitnessGoal,
    required this.activityLevel,
    required this.preferredCategories,
    required this.availableEquipment,
    required this.maxWorkoutDuration,
    required this.dislikedExercises,
    required this.totalWorkoutsCompleted,
    required this.workoutHistory,
    required this.averageWorkoutRating,
    required this.completedWorkoutCategories,
    required this.availableDays,
    required this.timePreference,
    required this.currentFitnessLevel,
    required this.muscleGroupPreference,
    required this.injuryRisk,
    required this.lastUpdated,
  });

  // Cálculo do IMC
  double get bmi => weight / (height * height);
  
  // Classificação do IMC
  String get bmiCategory {
    if (bmi < 18.5) return 'underweight';
    if (bmi < 25) return 'normal';
    if (bmi < 30) return 'overweight';
    return 'obese';
  }
  
  // Nível de experiência baseado no histórico
  ExperienceLevel get experienceLevel {
    if (totalWorkoutsCompleted < 10) return ExperienceLevel.beginner;
    if (totalWorkoutsCompleted < 50) return ExperienceLevel.intermediate;
    return ExperienceLevel.advanced;
  }
  
  // Consistência de treino (últimos 30 dias)
  double get workoutConsistency {
    final recentWorkouts = workoutHistory
        .where((w) => w.completedAt.isAfter(DateTime.now().subtract(const Duration(days: 30))))
        .length;
    return (recentWorkouts / 30).clamp(0.0, 1.0);
  }
  
  // Categorias mais realizadas
  List<String> get topCategories {
    final categoryCount = <String, int>{};
    for (final category in completedWorkoutCategories) {
      categoryCount[category] = (categoryCount[category] ?? 0) + 1;
    }
    
    final sortedCategories = categoryCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedCategories.take(3).map((e) => e.key).toList();
  }

  // Factory para criar perfil mockado (para desenvolvimento)
  factory UserProfile.mock({int userId = 1}) {
    return UserProfile(
      userId: userId,
      name: 'José Silva',
      age: 28,
      weight: 82.5,
      height: 1.75,
      gender: 'male',
      fitnessGoal: FitnessGoal.loseWeight,
      activityLevel: ActivityLevel.moderate,
      preferredCategories: ['Força', 'Cardio'],
      availableEquipment: ['bodyweight', 'dumbbells'],
      maxWorkoutDuration: 60,
      dislikedExercises: ['burpees'],
      totalWorkoutsCompleted: 15,
      workoutHistory: _generateMockHistory(),
      averageWorkoutRating: 4.2,
      completedWorkoutCategories: ['Força', 'Força', 'Cardio', 'HIIT', 'Força'],
      availableDays: [DayOfWeek.monday, DayOfWeek.wednesday, DayOfWeek.friday],
      timePreference: TimePreference.morning,
      currentFitnessLevel: 0.6,
      muscleGroupPreference: {
        'chest': 0.8,
        'back': 0.7,
        'legs': 0.6,
        'arms': 0.9,
        'core': 0.5,
      },
      injuryRisk: 0.2,
      lastUpdated: DateTime.now(),
    );
  }

  static List<WorkoutHistory> _generateMockHistory() {
    return List.generate(15, (index) {
      return WorkoutHistory(
        workoutId: index + 1,
        workoutName: 'Treino ${index + 1}',
        category: ['Força', 'Cardio', 'HIIT'][index % 3],
        completedAt: DateTime.now().subtract(Duration(days: index * 2)),
        duration: 30 + (index % 3) * 15,
        rating: 3.0 + (index % 3),
        caloriesBurned: 200 + (index % 3) * 50,
        difficulty: ['Iniciante', 'Intermediário', 'Avançado'][index % 3],
      );
    });
  }

  // Copia o perfil com novos valores
  UserProfile copyWith({
    String? name,
    int? age,
    double? weight,
    double? height,
    String? gender,
    FitnessGoal? fitnessGoal,
    ActivityLevel? activityLevel,
    List<String>? preferredCategories,
    List<String>? availableEquipment,
    int? maxWorkoutDuration,
    List<String>? dislikedExercises,
    int? totalWorkoutsCompleted,
    List<WorkoutHistory>? workoutHistory,
    double? averageWorkoutRating,
    List<String>? completedWorkoutCategories,
    List<DayOfWeek>? availableDays,
    TimePreference? timePreference,
    double? currentFitnessLevel,
    Map<String, double>? muscleGroupPreference,
    double? injuryRisk,
  }) {
    return UserProfile(
      userId: userId,
      name: name ?? this.name,
      age: age ?? this.age,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      gender: gender ?? this.gender,
      fitnessGoal: fitnessGoal ?? this.fitnessGoal,
      activityLevel: activityLevel ?? this.activityLevel,
      preferredCategories: preferredCategories ?? this.preferredCategories,
      availableEquipment: availableEquipment ?? this.availableEquipment,
      maxWorkoutDuration: maxWorkoutDuration ?? this.maxWorkoutDuration,
      dislikedExercises: dislikedExercises ?? this.dislikedExercises,
      totalWorkoutsCompleted: totalWorkoutsCompleted ?? this.totalWorkoutsCompleted,
      workoutHistory: workoutHistory ?? this.workoutHistory,
      averageWorkoutRating: averageWorkoutRating ?? this.averageWorkoutRating,
      completedWorkoutCategories: completedWorkoutCategories ?? this.completedWorkoutCategories,
      availableDays: availableDays ?? this.availableDays,
      timePreference: timePreference ?? this.timePreference,
      currentFitnessLevel: currentFitnessLevel ?? this.currentFitnessLevel,
      muscleGroupPreference: muscleGroupPreference ?? this.muscleGroupPreference,
      injuryRisk: injuryRisk ?? this.injuryRisk,
      lastUpdated: DateTime.now(),
    );
  }
}

// Enums e classes auxiliares
enum FitnessGoal {
  loseWeight,
  gainMuscle,
  maintain,
  endurance,
  flexibility,
  strength
}

enum ActivityLevel {
  sedentary,    // < 3 dias por semana
  light,        // 3-4 dias por semana
  moderate,     // 4-5 dias por semana  
  active,       // 5-6 dias por semana
  veryActive    // 6-7 dias por semana
}

enum ExperienceLevel {
  beginner,
  intermediate, 
  advanced
}

enum DayOfWeek {
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday,
  sunday
}

enum TimePreference {
  morning,
  afternoon,
  evening,
  night
}

class WorkoutHistory {
  final int workoutId;
  final String workoutName;
  final String category;
  final DateTime completedAt;
  final int duration; // minutos
  final double rating; // 1-5
  final int caloriesBurned;
  final String difficulty;

  const WorkoutHistory({
    required this.workoutId,
    required this.workoutName,
    required this.category,
    required this.completedAt,
    required this.duration,
    required this.rating,
    required this.caloriesBurned,
    required this.difficulty,
  });
}