import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/injection/injection.dart';
import 'core/router/app_router.dart';
import 'providers/chat_provider.dart';
import 'core/services/chat_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.background,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  
  try {
    await Injection.init();
    debugPrint('✅ FITAI: Dependências inicializadas com sucesso');
  } catch (e) {
    debugPrint('❌ FITAI: Erro ao inicializar dependências: $e');
  }
  
  debugPrint('🚀 FITAI: Aplicativo iniciando...');
  
  runApp(const FitAIApp());
}

class FitAIApp extends StatelessWidget {
  const FitAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ChatProvider(ChatService()),
        ),
      ],
      child: MaterialApp.router(
        title: 'FITAI - Personal Trainer Inteligente',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        routerConfig: AppRouter.router,
      ),
    );
  }
}