import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_eme_base/flutter_eme_base.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BaseApp.initialize(
    appSettingsPath: 'config/appsettings.json',
    initialWorkspace: const Workspace(
      id: 'genaiapp',
      name: 'GenAI Labs',
      mediaDBRoot: 'https://app.genailabs.tech/site/mediadb',
    ),
  );
  runApp(
    ProviderScope(
      child: BaseApp(
        config: AppConfig(
          appTitle: 'Catalog Dashboard',
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF0F1319),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF38B6FF),
              secondary: Color(0xFF8A2387),
              surface: Color(0xFF0F1319),
              error: Color(0xFFF50057),
            ),
            textTheme: const TextTheme(
              displayLarge: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                color: Colors.white,
              ),
              titleLarge: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
                color: Colors.white,
              ),
              bodyLarge: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.normal,
                color: Color(0xFF90A4AE),
              ),
              bodyMedium: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.normal,
                color: Color(0xFF78909C),
              ),
              labelLarge: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            useMaterial3: true,
          ),
        ),
      ),
    ),
  );
}
