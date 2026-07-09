import 'package:flutter/material.dart';
import 'package:habit_flow/presentation/screens/habit_board_screen.dart';
import 'package:habit_flow/presentation/screens/todo_list_screen.dart';
import 'package:habit_flow/presentation/screens/analytics_screen.dart';
import 'package:habit_flow/presentation/screens/settings_screen.dart';
import 'package:habit_flow/presentation/screens/journal_screen.dart';

import 'package:flutter/cupertino.dart'; // 🚨 Ye Apple/iOS style animations deta hai
import 'package:flutter/services.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
 // late Animation<Offset> _buttonSlideAnimation;

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

   //_buttonSlideAnimation =
   //   Tween<Offset>(
   //   begin: const Offset(0.4, 0.0), // Halkaa sa right side se start hoga
    //  end: Offset.zero, // Apni asli jagah par aakar rukega
       // ).animate(
       //   CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
       // ); 

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) async {
    if (index == 4) {
      Navigator.push(
        context,
        CupertinoPageRoute(builder: (_) => const SettingsScreen()),
      );
      return;
    }
    if (_selectedIndex == index) return;

    HapticFeedback.selectionClick();

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
        // INDEXEDSTACK WITH SMOOTH FADE (No Glitches, No Card Margins)
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: IndexedStack(index: _selectedIndex, children: _screens),
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
            NavigationDestination(
              icon: Icon(Icons.segment_rounded),
              selectedIcon: Icon(Icons.segment_rounded),
              label: 'dash',
            ),
          ],
        ),
      ),
    );
  }
}
