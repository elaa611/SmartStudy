import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'study_screen.dart';
import 'profile_screen.dart';
import 'plan_screen.dart';
import 'chat_screen.dart';
import 'generate_quiz_screen.dart';
import 'generate_flashcards_screen.dart';
import 'generate_summary_screen.dart';
import 'generate_qa_screen.dart';
import 'generate_mock_exam_screen.dart';

class RevisionScreen extends StatefulWidget {
  // statefulWidget parce que l'écran change pendant son utilisation
  const RevisionScreen({super.key});

  @override
  State<RevisionScreen> createState() => _RevisionScreenState();
}

class _RevisionScreenState extends State<RevisionScreen> {
  static const Color primaryNavy = Color(0xFF0B1F5C);
  static const Color accentBlue = Color(0xFF2A6DF4);
  static const Color background = Color(0xFFF3F5F9);

  Widget _buildStudyTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 230, 237, 251),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StudyScreen()),
                );
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    'My Subjects',
                    style: TextStyle(
                      fontSize: 15,
                      //fontFamily: 'Pacifico',
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF0B2A6F),
                    ),
                  ),
                ),
              ),
            ),
          ),

          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'Revision Center',
                  style: TextStyle(
                    fontSize: 15,
                    //fontFamily: 'Pacifico',
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0B2A6F),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {
            // Ouvre le menu
          },
        ),
        backgroundColor: primaryNavy,
        title: const Text(
          'SmartStudy',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStudyTabs(),
              const SizedBox(height: 15),

              Text(
                'Choose how you’d like to study ',
                style: TextStyle(
                  fontSize: 24,
                  fontFamily: 'Lora',
                  fontWeight: FontWeight(900),
                  color: primaryNavy,
                ),
              ),

              const SizedBox(height: 7),

              Text(
                'Explore smart revision tools designed to help you learn faster and remember more.',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight(600),
                  fontFamily: 'Lora',
                  fontStyle: FontStyle.italic,
                  color: primaryNavy,
                ),
              ),

              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Option 1 : SUMMARY ',
                      style: TextStyle(
                        fontFamily: 'Lora',
                        fontSize: 24,
                        fontWeight: FontWeight(800),
                        color: Colors.indigoAccent,
                      ),
                    ),
                    SizedBox(height: 15),
                    const Text(
                      'Turn your course materials into clear, concise Summaries and focus on the key concepts.',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight(500),
                        fontStyle: FontStyle.italic,
                        color: Color.fromARGB(255, 0, 0, 0),
                      ),
                    ),
                    SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                      width: 120,
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const GenerateSummaryScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          side: BorderSide(
                            color: const Color.fromARGB(255, 81, 126, 238),
                          ),
                          backgroundColor: Color.fromARGB(255, 212, 224, 254),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 3,
                        ),
                        icon: const Icon(
                          Icons.auto_awesome,
                          size: 17,
                          color: accentBlue,
                        ),
                        label: const Text(
                          'START',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: accentBlue,
                          ),
                        ),
                      ),
                    ),
                      ],
                    ),

                    const SizedBox(height: 5),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Option 2 : QUIZ ',
                      style: TextStyle(
                        fontFamily: 'Lora',
                        fontSize: 24,
                        fontWeight: FontWeight(800),
                        color: Colors.indigoAccent,
                      ),
                    ),
                    SizedBox(height: 15),
                    const Text(
                      'Test your knowledge with personalized Quizzes based on your course content.',
                      style: TextStyle(
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight(500),
                        color: Color.fromARGB(255, 0, 0, 0),
                      ),
                    ),
                    SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                      width: 120,
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const GenerateQuizScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          side: BorderSide(
                            color: const Color.fromARGB(255, 81, 126, 238),
                          ),
                          backgroundColor: Color.fromARGB(255, 212, 224, 254),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 3,
                        ),
                        icon: const Icon(
                          Icons.auto_awesome,
                          size: 17,
                          color: accentBlue,
                        ),
                        label: const Text(
                          'START',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: accentBlue,
                          ),
                        ),
                      ),
                    ),
                      ],
                    ),

                    const SizedBox(height: 5),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Option 3 : FLASHCARDS ',
                      style: TextStyle(
                        fontFamily: 'Lora',
                        fontSize: 24,
                        fontWeight: FontWeight(800),
                        color: Colors.indigoAccent,
                      ),
                    ),
                    SizedBox(height: 15),
                    const Text(
                      'Review key concepts with personalized Flashcards designed to strengthen your memory.',
                      style: TextStyle(
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight(500),
                        color: Color.fromARGB(255, 0, 0, 0),
                      ),
                    ),
                    SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                      width: 120,
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const GenerateFlashcardsScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          side: BorderSide(
                            color: const Color.fromARGB(255, 81, 126, 238),
                          ),
                          backgroundColor: Color.fromARGB(255, 212, 224, 254),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 3,
                        ),
                        icon: const Icon(
                          Icons.auto_awesome,
                          size: 17,
                          color: accentBlue,
                        ),
                        label: const Text(
                          'START',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: accentBlue,
                          ),
                        ),
                      ),
                    ),
                      ],
                    ),
                    
                    const SizedBox(height: 5),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Option 4 : Q/A ',
                      style: TextStyle(
                        fontFamily: 'Lora',
                        fontSize: 24,
                        fontWeight: FontWeight(800),
                        color: Colors.indigoAccent,
                      ),
                    ),
                    SizedBox(height: 15),
                    const Text(
                      'Get clear, personalized Questions & Answers and deepen your understanding of your courses.',
                      style: TextStyle(
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight(500),
                        color: Color.fromARGB(255, 0, 0, 0),
                      ),
                    ),
                    SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                      width: 120,
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const GenerateQAScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          side: BorderSide(
                            color: const Color.fromARGB(255, 81, 126, 238),
                          ),
                          backgroundColor: Color.fromARGB(255, 212, 224, 254),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 3,
                        ),
                        icon: const Icon(
                          Icons.auto_awesome,
                          size: 17,
                          color: accentBlue,
                        ),
                        label: const Text(
                          'START',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: accentBlue,
                          ),
                        ),
                      ),
                    ),
                      ],
                    ),
                    
                    const SizedBox(height: 5),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Option 5 : Mock EXAM ',
                      style: TextStyle(
                        fontFamily: 'Lora',
                        fontSize: 24,
                        fontWeight: FontWeight(800),
                        color: Colors.indigoAccent,
                      ),
                    ),
                    SizedBox(height: 15),
                    const Text(
                      'Get clear, personalized Questions & Answers and deepen your understanding of your courses.',
                      style: TextStyle(
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight(500),
                        color: Color.fromARGB(255, 0, 0, 0),
                      ),
                    ),
                    SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                      width: 120,
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const GenerateMockExamScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          side: BorderSide(
                            color: const Color.fromARGB(255, 81, 126, 238),
                          ),
                          backgroundColor: Color.fromARGB(255, 212, 224, 254),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 3,
                        ),
                        icon: const Icon(
                          Icons.auto_awesome,
                          size: 17,
                          color: accentBlue,
                        ),
                        label: const Text(
                          'START',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: accentBlue,
                          ),
                        ),
                      ),
                    ),
                      ],
                    ),
                    
                    const SizedBox(height: 5),
                  ],
                ),
              ),

              const SizedBox(height: 25),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 1, color: Colors.grey.shade300),

          NavigationBar(
            backgroundColor: Colors.white,
            height: 80,
            selectedIndex: 1,
            indicatorColor: const Color.fromARGB(255, 222, 229, 251),

            onDestinationSelected: (index) {
              if (index == 0) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                );
              }
              if (index == 2) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ChatScreen()),
                );
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