import 'package:flutter/material.dart';
import 'package:habit_flow/presentation/screens/habit_board_screen.dart';
import 'package:habit_flow/presentation/screens/todo_list_screen.dart';
import 'package:habit_flow/presentation/screens/analytics_screen.dart';
import 'package:habit_flow/presentation/screens/settings_screen.dart';
import 'package:habit_flow/presentation/screens/journal_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/cupertino.dart'; // 🚨 Ye Apple/iOS style animations deta hai

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _buttonSlideAnimation; // 🚨 NAYI LINE: Button slide ke liye

  final List<Widget> _screens = [
    const HabitBoardScreen(),
    const TodoListScreen(),
    const JournalScreen(), 
    const AnalyticsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    //  NAYA: Button ko Right to Left smoothly slide karne ka engine
    
    _buttonSlideAnimation = Tween<Offset>(
      begin: const Offset(0.4, 0.0), // Halkaa sa right side se start hoga
      end: Offset.zero,              // Apni asli jagah par aakar rukega
    ).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );

    _fadeController.forward(); 
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) async {
    if (_selectedIndex == index) return; 

    
    await _fadeController.reverse();
    
    setState(() {
      _selectedIndex = index;
    });
    
    
    _fadeController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onTabSelected(0); 
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
          title: Text(
            'Habitick',
            style: GoogleFonts.agbalumo(
              fontWeight: FontWeight.bold,
              fontSize: 40, 
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 5.0,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1.0),
            child: Container(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
              height: 1.0,
            ),
          ),
          actions: [
            
            //  NAYA: Menu Button ke liye Right-to-Left Slide + Fade Transition
            
            FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _buttonSlideAnimation,
                child: IconButton(
                  icon: Icon(
                    Icons.segment_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 30,
                  ),
                  tooltip: 'Settings',
                  onPressed: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                )
              ),
            ),
            const SizedBox(width: 8)
          ],
        ),

        // INDEXEDSTACK WITH SMOOTH FADE (No Glitches, No Card Margins)
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: IndexedStack(
            index: _selectedIndex,
            children: _screens,
          ),
        ),

        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onTabSelected, 
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view),
              label: 'Habits',
            ),
            NavigationDestination(
              icon: Icon(Icons.checklist_outlined),
              selectedIcon: Icon(Icons.checklist),
              label: 'To-Do',
            ),
            NavigationDestination(
              icon: Icon(Icons.book_outlined), 
              selectedIcon: Icon(Icons.book), 
              label: 'Journal',
            ),
            NavigationDestination(
              icon: Icon(Icons.analytics_outlined),
              selectedIcon: Icon(Icons.analytics),
              label: 'Stats',
            ),
          ],
        ),
      ),
    );
  }
}

