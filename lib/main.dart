import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/services/preferences_service.dart';
import 'core/theme/app_theme.dart';
import 'features/home/main_navigation_scaffold.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  await PreferencesService().init();
  runApp(const UtilityApp());
}

class UtilityApp extends StatelessWidget {
  const UtilityApp({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = PreferencesService();

    return AnimatedBuilder(
      animation: prefs,
      builder: (context, _) {
        return MaterialApp(
          title: 'ToolBox Pro',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: prefs.themeMode,
          home: const MainNavigationScaffold(),
        );
      },
    );
  }
}
