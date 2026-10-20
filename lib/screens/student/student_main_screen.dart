import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/bottom_nav_bar.dart';
import 'student_home_screen.dart';
import 'schedule_tab_screen.dart';
import '../chat/chat_list_screen.dart';
import '../../features/resources/resource_screen.dart';

class StudentMainScreen extends StatefulWidget {
  const StudentMainScreen({super.key});

  @override
  State<StudentMainScreen> createState() => _StudentMainScreenState();
}

class _StudentMainScreenState extends State<StudentMainScreen> {
  int _currentIndex = 0;

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return StudentHomeScreen(onNavigateTab: _onTabTapped);
      case 1:
        return const ScheduleTabScreen();
      case 2:
        return const ResourceScreen();
      case 3:
        return const ChatListScreen();
      default:
        return StudentHomeScreen(onNavigateTab: _onTabTapped);
    }
  }

  @override
  Widget build(BuildContext context) {
    const List<NavItem> navItems = [
      NavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        label: 'Home',
      ),
      NavItem(
        icon: Icons.calendar_today_outlined,
        activeIcon: Icons.calendar_today,
        label: 'Routine',
      ),
      NavItem(
        icon: Icons.folder_outlined,
        activeIcon: Icons.folder,
        label: 'Resources',
      ),
      NavItem(
        icon: Icons.forum_outlined,
        activeIcon: Icons.forum,
        label: 'Batch Chat',
      ),
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: _buildBody(),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        items: navItems,
      ),
    );
  }
}
