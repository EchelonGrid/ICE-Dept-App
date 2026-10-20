import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/resource_item_model.dart';

class QuickAccessService extends ChangeNotifier {
  static const String _prefKey = 'pinned_quick_access_resources';
  static final QuickAccessService instance = QuickAccessService._internal();
  QuickAccessService._internal();

  List<ResourceItem> _pinnedItems = [];
  bool _isLoaded = false;

  List<ResourceItem> get pinnedItems => List.unmodifiable(_pinnedItems);
  bool get isLoaded => _isLoaded;
  int get count => _pinnedItems.length;

  // Default seed resources if the user has not pinned anything yet
  static final List<ResourceItem> _defaultSeed = [
    const ResourceItem(
      id: 'bm1',
      title: 'ICE Dept 4-Year Academic Syllabus & Regulation',
      category: 'library',
      courseName: 'ICE-General',
      subjectName: 'Curriculum Regulation',
      fileUrl: 'https://cdn.syncfusion.com/content/PDFViewer/flutter-succinctly.pdf',
      uploaderName: 'ICE Academic Council',
    ),
    const ResourceItem(
      id: 'bm2',
      title: 'AI & Robotics - Midterm Solved Papers',
      category: 'question_bank',
      courseName: 'ICE-3101',
      subjectName: 'Artificial Intelligence and Robotics',
      fileUrl: 'https://cdn.syncfusion.com/content/PDFViewer/flutter-succinctly.pdf',
      uploaderName: 'CR Academic Repo',
    ),
    const ResourceItem(
      id: 'bm3',
      title: 'Database Systems Lab Manual & SQL Exercises',
      category: 'notes',
      courseName: 'ICE-3103',
      subjectName: 'Database Management Systems',
      fileUrl: 'https://cdn.syncfusion.com/content/PDFViewer/flutter-succinctly.pdf',
      uploaderName: 'Faculty Dean',
    ),
    const ResourceItem(
      id: 'bm4',
      title: 'Modern Digital Communications - Reference Book',
      category: 'library',
      courseName: 'ICE-3203',
      subjectName: 'Digital Communication',
      fileUrl: 'https://cdn.syncfusion.com/content/PDFViewer/flutter-succinctly.pdf',
      uploaderName: 'Central Library',
    ),
  ];

  /// Load pinned items from SharedPreferences
  Future<void> loadPinnedItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_prefKey);
      if (rawList == null) {
        // Initial setup: seed default bookmarks
        _pinnedItems = List.from(_defaultSeed);
        await _save();
      } else {
        _pinnedItems = rawList
            .map((str) => ResourceItem.fromJson(jsonDecode(str) as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('[QuickAccessService] Error loading pinned items: $e');
      _pinnedItems = List.from(_defaultSeed);
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  /// Check whether a resource is pinned by its ID
  bool isPinned(String id) {
    return _pinnedItems.any((item) => item.id == id);
  }

  /// Toggle pin state for a resource item.
  /// Returns true if pinned, false if unpinned.
  Future<bool> togglePin(ResourceItem item) async {
    final alreadyPinned = isPinned(item.id);
    if (alreadyPinned) {
      _pinnedItems.removeWhere((i) => i.id == item.id);
      debugPrint('[QuickAccessService] Unpinned: ${item.title} (${item.id})');
    } else {
      _pinnedItems.insert(0, item);
      debugPrint('[QuickAccessService] Pinned: ${item.title} (${item.id})');
    }
    await _save();
    notifyListeners();
    return !alreadyPinned;
  }

  /// Directly unpin a resource by ID
  Future<void> unpin(String id) async {
    _pinnedItems.removeWhere((item) => item.id == id);
    await _save();
    notifyListeners();
    debugPrint('[QuickAccessService] Removed pinned item: $id');
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stringList = _pinnedItems.map((item) => jsonEncode(item.toJson())).toList();
      await prefs.setStringList(_prefKey, stringList);
    } catch (e) {
      debugPrint('[QuickAccessService] Error saving pinned items: $e');
    }
  }
}
