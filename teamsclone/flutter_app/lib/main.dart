import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'config/constants.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop window setup
  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 800),
      minimumSize: Size(800, 600),
      center: true,
      title: 'TeamsClone',
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const TeamsCloneApp());
}

class TeamsCloneApp extends StatelessWidget {
  const TeamsCloneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider()..tryAutoLogin(),
      child: MaterialApp(
        title: 'TeamsClone',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(AppColors.primaryColor)),
          useMaterial3: true,
          fontFamily: 'Segoe UI',
        ),
        home: Consumer<AuthProvider>(
          builder: (_, auth, __) {
            if (auth.loading && auth.user == null) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            return auth.isLoggedIn ? const HomeScreen() : const LoginScreen();
          },
        ),
      ),
    );
  }
}
