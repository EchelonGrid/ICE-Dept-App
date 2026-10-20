import 'package:flutter/material.dart';

class SemesterInfo {
  final String key; // e.g. '1-1', '1-2'
  final String title; // e.g. '1st Year 1st Semester'
  final String shortTitle; // e.g. 'Year 1, Sem 1'
  final List<SubjectInfo> subjects;

  const SemesterInfo({
    required this.key,
    required this.title,
    required this.shortTitle,
    required this.subjects,
  });
}

class SubjectInfo {
  final String name;
  final String code;
  final String iconEmoji;
  final IconData iconData;

  const SubjectInfo({
    required this.name,
    required this.code,
    this.iconEmoji = '📁',
    this.iconData = Icons.folder_outlined,
  });
}

class DepartmentCurriculum {
  static const Map<String, SemesterInfo> semesters = {
    '1-1': SemesterInfo(
      key: '1-1',
      title: '1st Year 1st Semester',
      shortTitle: 'Year 1, Sem 1',
      subjects: [
        SubjectInfo(name: 'Fundamentals of ICT', code: 'ICE-1101', iconEmoji: '💻', iconData: Icons.computer_outlined),
        SubjectInfo(name: 'Basic Electronics', code: 'ICE-1102', iconEmoji: '⚡', iconData: Icons.bolt_outlined),
        SubjectInfo(name: 'Structured Programming', code: 'ICE-1103', iconEmoji: '⌨️', iconData: Icons.code_outlined),
        SubjectInfo(name: 'Applied Electricity and Magnetism', code: 'PHY-1101', iconEmoji: '🧲', iconData: Icons.electrical_services_outlined),
        SubjectInfo(name: 'Differential and Integral Calculus', code: 'MATH-1101', iconEmoji: '📐', iconData: Icons.functions_outlined),
      ],
    ),
    '1-2': SemesterInfo(
      key: '1-2',
      title: '1st Year 2nd Semester',
      shortTitle: 'Year 1, Sem 2',
      subjects: [
        SubjectInfo(name: 'Object Oriented Programming', code: 'ICE-1201', iconEmoji: '☕', iconData: Icons.integration_instructions_outlined),
        SubjectInfo(name: 'Circuit Theory and Analysis', code: 'ICE-1202', iconEmoji: '🔌', iconData: Icons.cable_outlined),
        SubjectInfo(name: 'Analog Electronics', code: 'ICE-1203', iconEmoji: '📻', iconData: Icons.sensors_outlined),
        SubjectInfo(name: 'Differential Equations and Complex Variables', code: 'MATH-1201', iconEmoji: '📈', iconData: Icons.show_chart_outlined),
        SubjectInfo(name: 'Communicative English', code: 'HUM-1201', iconEmoji: '🗣️', iconData: Icons.record_voice_over_outlined),
      ],
    ),
    '2-1': SemesterInfo(
      key: '2-1',
      title: '2nd Year 1st Semester',
      shortTitle: 'Year 2, Sem 1',
      subjects: [
        SubjectInfo(name: 'Analog Communication', code: 'ICE-2101', iconEmoji: '📡', iconData: Icons.cell_tower_outlined),
        SubjectInfo(name: 'Digital Electronics', code: 'ICE-2102', iconEmoji: '💡', iconData: Icons.developer_board_outlined),
        SubjectInfo(name: 'Discrete Mathematics and Numerical Methods', code: 'MATH-2101', iconEmoji: '🔢', iconData: Icons.calculate_outlined),
        SubjectInfo(name: 'Industrial Management and Accountancy', code: 'HUM-2101', iconEmoji: '📊', iconData: Icons.assessment_outlined),
        SubjectInfo(name: 'Elementary Statistics and Probability', code: 'STAT-2101', iconEmoji: '🎲', iconData: Icons.analytics_outlined),
      ],
    ),
    '2-2': SemesterInfo(
      key: '2-2',
      title: '2nd Year 2nd Semester',
      shortTitle: 'Year 2, Sem 2',
      subjects: [
        SubjectInfo(name: 'Data Structure and Algorithm', code: 'ICE-2201', iconEmoji: '🌳', iconData: Icons.account_tree_outlined),
        SubjectInfo(name: 'Signals and Systems', code: 'ICE-2202', iconEmoji: '🌊', iconData: Icons.waves_outlined),
        SubjectInfo(name: 'Vector, Matrix and Linear Algebra', code: 'MATH-2201', iconEmoji: '🧮', iconData: Icons.grid_4x4_outlined),
        SubjectInfo(name: 'Economics for Technology and Innovation Management', code: 'HUM-2201', iconEmoji: '💼', iconData: Icons.trending_up_outlined),
        SubjectInfo(name: 'Engineering Statistics', code: 'STAT-2201', iconEmoji: '📉', iconData: Icons.pie_chart_outline),
      ],
    ),
    '3-1': SemesterInfo(
      key: '3-1',
      title: '3rd Year 1st Semester',
      shortTitle: 'Year 3, Sem 1',
      subjects: [
        SubjectInfo(name: 'Artificial Intelligence and Robotics', code: 'ICE-3101', iconEmoji: '🤖', iconData: Icons.psychology_outlined),
        SubjectInfo(name: 'Web Programming', code: 'ICE-3102', iconEmoji: '🌐', iconData: Icons.language_outlined),
        SubjectInfo(name: 'Database Management Systems', code: 'ICE-3103', iconEmoji: '🗄️', iconData: Icons.dns_outlined),
        SubjectInfo(name: 'Electromagnetic Fields and Waves', code: 'ICE-3104', iconEmoji: '🧲', iconData: Icons.radar_outlined),
        SubjectInfo(name: 'Computer Architecture and Microcontroller Design', code: 'ICE-3105', iconEmoji: '🖥️', iconData: Icons.memory_outlined),
      ],
    ),
    '3-2': SemesterInfo(
      key: '3-2',
      title: '3rd Year 2nd Semester',
      shortTitle: 'Year 3, Sem 2',
      subjects: [
        SubjectInfo(name: 'Network Programming with Java', code: 'ICE-3201', iconEmoji: '☕', iconData: Icons.hub_outlined),
        SubjectInfo(name: 'Antenna Engineering', code: 'ICE-3202', iconEmoji: '🛰️', iconData: Icons.satellite_alt_outlined),
        SubjectInfo(name: 'Digital Communication', code: 'ICE-3203', iconEmoji: '📡', iconData: Icons.wifi_tethering_outlined),
        SubjectInfo(name: 'Digital Image and Speech Processing', code: 'ICE-3204', iconEmoji: '🎙️', iconData: Icons.graphic_eq_outlined),
        SubjectInfo(name: 'Operating System', code: 'ICE-3205', iconEmoji: '⚙️', iconData: Icons.terminal_outlined),
      ],
    ),
    '4-1': SemesterInfo(
      key: '4-1',
      title: '4th Year 1st Semester',
      shortTitle: 'Year 4, Sem 1',
      subjects: [
        SubjectInfo(name: 'Data Communication and Networking', code: 'ICE-4101', iconEmoji: '🖧', iconData: Icons.router_outlined),
        SubjectInfo(name: 'Machine Learning', code: 'ICE-4102', iconEmoji: '🧠', iconData: Icons.auto_awesome_outlined),
        SubjectInfo(name: 'Cryptography and Data Security', code: 'ICE-4103', iconEmoji: '🔒', iconData: Icons.security_outlined),
        SubjectInfo(name: 'Elective-I', code: 'ICE-4104', iconEmoji: '🎯', iconData: Icons.tune_outlined),
        SubjectInfo(name: 'Elective-II', code: 'ICE-4105', iconEmoji: '🚀', iconData: Icons.biotech_outlined),
      ],
    ),
    '4-2': SemesterInfo(
      key: '4-2',
      title: '4th Year 2nd Semester',
      shortTitle: 'Year 4, Sem 2',
      subjects: [
        SubjectInfo(name: 'Cellular and Wireless Communication', code: 'ICE-4201', iconEmoji: '📱', iconData: Icons.phone_android_outlined),
        SubjectInfo(name: 'System Analysis and Software Testing', code: 'ICE-4202', iconEmoji: '🧪', iconData: Icons.fact_check_outlined),
        SubjectInfo(name: 'Information Theory and Coding', code: 'ICE-4203', iconEmoji: '📜', iconData: Icons.tag_outlined),
        SubjectInfo(name: 'Elective-III', code: 'ICE-4204', iconEmoji: '🔬', iconData: Icons.science_outlined),
        SubjectInfo(name: 'Elective-IV', code: 'ICE-4205', iconEmoji: '💡', iconData: Icons.lightbulb_outline),
      ],
    ),
  };

  static SemesterInfo getSemester(String key) {
    return semesters[key] ?? semesters['3-1']!;
  }

  static List<SemesterInfo> get allSemesters => semesters.values.toList();
}
