import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/wordsearch_screen.dart';

void main() async {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Word Hunt',
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        if (settings.name == '/') {
          return MaterialPageRoute(
            builder: (context) => const HomeScreen(),
          );
        }
        if (settings.name == '/wordsearch') {
          final args = settings.arguments as Map<String, String>?;

          if (args == null) {
            // Handle direct URL access with a fallback or error page
            return MaterialPageRoute(builder: (context) => const HomeScreen());
          }

          return MaterialPageRoute(
            builder: (context) => WordSearchGameScreen(
              category: settings.arguments as Map<String, String>,
            ),
          );
        }
        return MaterialPageRoute(
          builder: (context) => const HomeScreen(),
        );
      },
    );
  }
}
