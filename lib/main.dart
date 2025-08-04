import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/model_management_screen.dart';
import 'screens/chat_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set system UI overlay style for better integration
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  
  runApp(const GemmaChatApp());
}

class GemmaChatApp extends StatelessWidget {
  const GemmaChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gemma Chat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const ModelManagementScreen(),
        '/chat': (context) => const ChatScreen(),
      },
    );
  }
}
