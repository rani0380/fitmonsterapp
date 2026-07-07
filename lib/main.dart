import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:smart_app/controllers/game_controller.dart';
import 'package:smart_app/features/home/home_screen.dart';
import 'package:smart_app/services/camera_service.dart';
import 'package:smart_app/ui/fitmon_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  Get.put(CameraService());
  Get.put(GameController());
  runApp(const ActiveRunApp());
}

class ActiveRunApp extends StatelessWidget {
  const ActiveRunApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'fit monster',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: FitmonColors.yellow,
          secondary: FitmonColors.greenLight,
          surface: FitmonColors.card,
          error: FitmonColors.red,
        ),
        fontFamily: 'JalnanGothic',
        scaffoldBackgroundColor: FitmonColors.bg,
        appBarTheme: const AppBarTheme(
          backgroundColor: FitmonColors.bg,
          foregroundColor: FitmonColors.text,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: FitmonColors.text,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: FitmonColors.yellow,
            foregroundColor: FitmonColors.bg,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        cardTheme: CardThemeData(
          color: FitmonColors.card,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
