import 'package:flutter/material.dart';
import 'package:smart_study/screens/splash_screen.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://mofwswzxeojfbzbcncfq.supabase.co',
    publishableKey: 'sb_publishable_rSm9eDw8P81YnBT3iabIMg_7SsbBIN3',
  );
  runApp(SmartStudy());
}

class SmartStudy extends StatelessWidget {
  const SmartStudy({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFF3F5F9),
      ),
      home: SplashScreen(),
    );
  }
}
