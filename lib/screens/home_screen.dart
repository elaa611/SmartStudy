import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'plan_screen.dart';
import 'profile_screen.dart';
import 'study_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}


class _HomeScreenState extends State<HomeScreen> {

  static const Color primaryNavy = Color(0xFF0B1F5C);
  static const Color background = Color(0xFFF3F5F9);


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {
            // Ouvre le menu
          },
        ),
        backgroundColor: primaryNavy,
        title: Text(
          'SmartStudy',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 1, color: Colors.grey.shade300),

          NavigationBar(
            backgroundColor: Colors.white,
            height: 80,
            selectedIndex: 0,
            indicatorColor: const Color.fromARGB(255, 222, 230, 255),

            onDestinationSelected: (index) {
              if (index == 1) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StudyScreen()),
                );
              }
              if (index == 2) {
                showChatModal(context);
              }
              if (index == 3) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PlanScreen()),
                );
              }
              if (index == 4) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              }
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.menu_book_outlined),
                label: 'Study',
              ),
              NavigationDestination(
                icon: Icon(Icons.smart_toy_outlined),
                label: 'AI Chat',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_today_outlined),
                label: 'Plan',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                label: 'Profile',
              ),
            ],
          ),
        ],
      ),
    );
  }
}