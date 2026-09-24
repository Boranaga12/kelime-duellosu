import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'data/services/supabase_service.dart';
import 'domain/ai_referee_service.dart';
import 'presentation/controllers/friends_controller.dart';
import 'presentation/controllers/game_controller.dart';
import 'presentation/controllers/leaderboard_controller.dart';
import 'presentation/controllers/profile_controller.dart';
import 'presentation/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Supabase bağlantısını başlat
  await SupabaseService.initialize();

  // Yapay Zeka Hakemi & Öğrenilmiş Kelime Havuzunu Yükle
  await AiRefereeService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProfileController()),
        ChangeNotifierProvider(create: (_) => FriendsController()),
        ChangeNotifierProvider(create: (_) => GameController()),
        ChangeNotifierProvider(create: (_) => LeaderboardController()),
      ],
      child: const KelimeDuellosuApp(),
    ),
  );
}

class KelimeDuellosuApp extends StatelessWidget {
  const KelimeDuellosuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kelime Düellosu',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
