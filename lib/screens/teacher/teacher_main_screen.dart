import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/bottom_nav_bar.dart';
import 'teacher_home_screen.dart';
import 'teacher_schedule_tab.dart';
import 'teacher_direct_inbox_screen.dart';
import 'teacher_resources_tab.dart';

class TeacherMainScreen extends StatefulWidget {
  const TeacherMainScreen({super.key});

  @override
  State<TeacherMainScreen> createState() => _TeacherMainScreenState();
}

class _TeacherMainScreenState extends State<TeacherMainScreen> {
  int _currentIndex = 0;

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return TeacherHomeScreen(onNavigateTab: _onTabTapped);
      case 1:
        return const TeacherScheduleTab();
      case 2:
        return const TeacherDirectInboxScreen();
      case 3:
        return const TeacherResourcesTab();
      default:
        return TeacherHomeScreen(onNavigateTab: _onTabTapped);
    }
  }

  @override
  Widget build(BuildContext context) {
    const List<NavItem> navItems = [
      NavItem(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
        label: 'Dashboard',
      ),
      NavItem(
        icon: Icons.calendar_month_outlined,
        activeIcon: Icons.calendar_month,
        label: 'Schedule',
      ),
      NavItem(
        icon: Icons.mark_chat_unread_outlined,
        activeIcon: Icons.mark_chat_unread,
        label: 'CR Inbox',
      ),
      NavItem(
        icon: Icons.folder_outlined,
        activeIcon: Icons.folder,
        label: 'Resources',
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
