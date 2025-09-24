import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/pages/auth/login_page.dart';
import '../../core/theme/app_theme.dart';
import '../../presentation/pages/dashboard/dashboard_page.dart';
import '../../presentation/pages/workouts/workouts_page.dart';
import '../../presentation/pages/chat/chat_page.dart';  // 👈 Adicione este import

/// Rotas da aplicação FITAI
class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String dashboard = '/dashboard';
  static const String workouts = '/workouts';
  static const String chat = '/chat';  // 👈 Adicionado
}

/// Sistema de roteamento da aplicação FITAI
class AppRouter {
  static GoRouter get router => _router;

  static final GoRouter _router = GoRouter(
    debugLogDiagnostics: false,
    initialLocation: AppRoutes.login,
    
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        builder: (context, state) => const RegisterPage(),
      ),
      
      GoRoute(
        path: AppRoutes.dashboard,
        name: 'dashboard',
        builder: (context, state) => const DashboardPage(),
      ),
      
      GoRoute(
        path: AppRoutes.workouts,
        name: 'workouts',
        builder: (context, state) => const WorkoutsPage(),
      ),
      
      GoRoute(  // 👈 Adicionado
        path: AppRoutes.chat,
        name: 'chat',
        builder: (context, state) => const ChatPage(),
      ),
    ],
    
    errorBuilder: (context, state) => const ErrorPage(),
  );

  // Métodos de navegação
  static void goToLogin() {
    try {
      _router.go(AppRoutes.login);
      debugPrint('✅ Navegação para Login realizada');
    } catch (e) {
      debugPrint('❌ Erro ao navegar para Login: $e');
    }
  }

  static void goToRegister() {
    try {
      _router.go(AppRoutes.register);
      debugPrint('✅ Navegação para Registro realizada');
    } catch (e) {
      debugPrint('❌ Erro ao navegar para Registro: $e');
    }
  }

  static void goToDashboard() {
    try {
      _router.go(AppRoutes.dashboard);
      debugPrint('✅ Navegação para Dashboard realizada');
    } catch (e) {
      debugPrint('❌ Erro ao navegar para Dashboard: $e');
    }
  }

  static void goToWorkouts() {  
    try {
      _router.go(AppRoutes.workouts);
      debugPrint('✅ Navegação para Workouts realizada');
    } catch (e) {
      debugPrint('❌ Erro ao navegar para Workouts: $e');
    }
  }

  static void goToChat() {  // 👈 Adicionado
    try {
      _router.go(AppRoutes.chat);
      debugPrint('✅ Navegação para Chat realizada');
    } catch (e) {
      debugPrint('❌ Erro ao navegar para Chat: $e');
    }
  }

  static void goBack() {
    try {
      if (_router.canPop()) {
        _router.pop();
      } else {
        goToLogin();
      }
    } catch (e) {
      debugPrint('❌ Erro ao navegar de volta: $e');
    }
  }

  static void logout() {
    try {
      goToLogin();
      debugPrint('✅ Logout realizado');
    } catch (e) {
      debugPrint('❌ Erro durante logout: $e');
    }
  }
}

// Páginas da aplicação
class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar Conta'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => AppRouter.goToLogin(),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo FITAI
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.person_add,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              
              const SizedBox(height: 24),
              
              Text(
                'Junte-se ao FITAI',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 12),
              
              Text(
                'Crie sua conta e transforme seu fitness com inteligência artificial',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 40),
              
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.construction,
                      size: 48,
                      color: AppColors.primary,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Em Desenvolvimento',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'A tela de registro completa será implementada na próxima fase.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              ElevatedButton(
                onPressed: () => AppRouter.goToLogin(),
                child: const Text('Voltar ao Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorPage extends StatelessWidget {
  const ErrorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Erro - FITAI'),
        backgroundColor: AppColors.background,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 80,
                color: AppColors.error,
              ),
              SizedBox(height: 24),
              Text(
                'Oops! Algo deu errado',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Tente voltar e tentar novamente',
                style: TextStyle(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),
              Text(
                'Volte ao login para continuar',
                style: TextStyle(
                  color: AppColors.textHint,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AppRouter.goToLogin(),
        label: const Text('Voltar ao Login'),
        icon: const Icon(Icons.home),
      ),
    );
  }
}