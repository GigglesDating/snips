import 'package:flutter/material.dart';
import 'package:snips/screens/member/snips.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Temporary UUID for development
const String TEMP_UUID = '947259263682';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Set temporary UUID
  await prefs.setString('user_uuid', TEMP_UUID);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const SnipsScreen(),
    );
  }
}
