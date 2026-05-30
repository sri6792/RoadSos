// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'firebase_options.dart';
import 'models/hive_adapters.dart';
import 'services/cache_service.dart';
import 'services/connectivity_service.dart';
import 'services/auth_service.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);


  // ── Hive init ──────────────────────────────────────────────────────────────
  await Hive.initFlutter();
  Hive.registerAdapter(ServiceTypeAdapter()); // typeId 0
  Hive.registerAdapter(CachedServiceAdapter()); // typeId 1
  await CacheService.instance.init();
  await AuthService.instance.init(); // persistent login state

  // ── Connectivity watcher ───────────────────────────────────────────────────
  await ConnectivityService.instance.init();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const RoadSOSApp());
}

class RoadSOSApp extends StatelessWidget {
  const RoadSOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RoadSOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const SplashScreen(),
    );
  }
}