import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../models/department_routine_model.dart';
import '../../services/db_service.dart';
import '../../services/routine_service.dart';
import '../../utils/routine_helper.dart';
import '../../widgets/app_text_field.dart';

class ClerkRoutineUploadScreen extends StatefulWidget {
  final List<String>? initialBatches;

  const ClerkRoutineUploadScreen({super.key, this.initialBatches});

  @override
  State<ClerkRoutineUploadScreen> createState() => _ClerkRoutineUploadScreenState();
}

class _ClerkRoutineUploadScreenState extends State<ClerkRoutineUploadScreen> {
  final RoutineService _routineService = RoutineService.instance;
  final DbService _dbService = DbService();

  List<DepartmentRoutineModel> _parsedItems = [];
  List<String> _availableBatches = ['Batch 21', 'Batch 22', 'Batch 23', 'Batch 24'];
  String _selectedBatch = 'Batch 21';
  bool _isParsing = false;
  bool _isPublishing = false;
  bool _isLoadingBatch = true;
  String? _uploadedFileName;
  final bool _clearExisting = true;
  StreamSubscription? _routineSubscription;
  Map<String, String> _facultyDirectory = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialBatches != null && widget.initialBatches!.isNotEmpty) {
      _availableBatches = List.from(widget.initialBatches!);
      _selectedBatch = _availableBatches.first;
    }
    _initBatchesAndRoutine();
  }

  @override
  void dispose() {
    _routineSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initBatchesAndRoutine() async {
    await Future.wait([
      _loadBatches(),
      _loadFacultyDirectory(),
    ]);
    _listenToBatchRoutine(_selectedBatch);
  }

  Future<void> _loadFacultyDirectory() async {
    try {
      final dir = await _routineService.getFacultyDirectory(forceRefresh: true);
      if (mounted) {
        setState(() => _facultyDirectory = dir);
      }
    } catch (_) {}
  }

  Future<void> _loadBatches() async {
    try {
      final batches = await _dbService.getBatches();
      if (batches.isNotEmpty) {
        final batchList = batches.map((b) => 'Batch ${b.batchNumber}').toList();
        batchList.sort((a, b) {
          final numA = int.tryParse(RegExp(r'\d+').firstMatch(a)?.group(0) ?? '') ?? 0;
          final numB = int.tryParse(RegExp(r'\d+').firstMatch(b)?.group(0) ?? '') ?? 0;
          return numA.compareTo(numB);
        });
        if (mounted) {
          setState(() {
            _availableBatches = batchList;
            if (!_availableBatches.contains(_selectedBatch)) {
              _selectedBatch = _availableBatches.first;
            }
          });
        }
      }
    } catch (_) {}
  }

  /// Real-time listener for routines of the active batch, preventing infinite rebuild loops
  void _listenToBatchRoutine(String batch) {
    _routineSubscription?.cancel();
    setState(() {
      _isLoadingBatch = true;
      _parsedItems.clear();
      _uploadedFileName = null;
    });

    final client = Supabase.instance.client;
    _routineSubscription = client
        .from('department_routines')
        .stream(primaryKey: ['id'])
        .eq('batch', batch)
        .listen((data) async {
          final facultyMap = await _routineService.getFacultyDirectory();
          final models = data.map((row) {
            final m = DepartmentRoutineModel.fromJson(row);
            final initial = (m.teacherInitial ?? '').trim().toUpperCase();
            return m.copyWith(teacherFullName: facultyMap[initial] ?? m.teacherInitial);
          }).toList();

          models.sort((a, b) {
            final dayCompare = a.dayOfWeek.compareTo(b.dayOfWeek);
            if (dayCompare != 0) return dayCompare;
            return a.startTime.compareTo(b.startTime);
          });

          if (mounted) {
            setState(() {
              _parsedItems = models;
              _isLoadingBatch = false;
            });
          }
        }, onError: (err) {
          if (mounted) setState(() => _isLoadingBatch = false);
        });
  }

  /// Pick and parse .xlsx file
  Future<void> _pickAndParseExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      Uint8List? bytes = file.bytes;

      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not read file data. Please try again.'),
            backgroundColor: AppTheme.error,
          ),
        );
        return;
      }

      setState(() {
        _isParsing = true;
        _uploadedFileName = file.name;
      });

      final items = await compute(_parseExcelBytes, {
        'bytes': bytes,
        'defaultBatch': _selectedBatch,
      });

      // Explicitly tag every newly parsed slot with the active target batch
      final taggedItems = items.map((e) => e.copyWith(batch: _selectedBatch)).toList();

      setState(() {
        _parsedItems = taggedItems;
        _isParsing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully extracted ${items.length} routine slots from ${file.name}!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _isParsing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel parsing error: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  /// Top-level or static compute worker for excel parsing
  static List<DepartmentRoutineModel> _parseExcelBytes(Map<String, dynamic> args) {
    final Uint8List bytes = args['bytes'] as Uint8List;
    final String defaultBatch = args['defaultBatch'] as String;

    final excel = Excel.decodeBytes(bytes);
    final List<DepartmentRoutineModel> results = [];

    // Regex
    final regex = RegExp(
      r'([A-Z]{3,4}-\d{4})\s*([A-Z]{2,4})?\s*(?:\[(\d+)\])?(?:\s*\[(odd|even)\s*weeks?\])?',
      caseSensitive: false,
    );

    // Days to match
    final daysList = ['Saturday', 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

    for (final tableKey in excel.tables.keys) {
      final sheet = excel.tables[tableKey];
      if (sheet == null) continue;

      int headerRowIndex = -1;
      final Map<int, Map<String, String>> colTimeSlots = {};

      // 1. Scan first 10 rows for time headers
      for (int r = 0; r < sheet.maxRows && r < 10; r++) {
        final row = sheet.rows[r];
        for (int c = 0; c < row.length; c++) {
          final cellText = _cellString(row[c]);
          final slot = _matchTimeSlot(cellText);
          if (slot != null) {
            colTimeSlots[c] = slot;
            headerRowIndex = r;
          }
        }
        if (colTimeSlots.length >= 3) break;
      }

      // Default slot map if headers weren't structured
      if (colTimeSlots.isEmpty) {
        colTimeSlots[2] = {'start': '09:00:00', 'end': '10:00:00'};
        colTimeSlots[3] = {'start': '10:00:00', 'end': '11:00:00'};
        colTimeSlots[4] = {'start': '11:00:00', 'end': '12:00:00'};
        colTimeSlots[5] = {'start': '12:00:00', 'end': '13:00:00'};
        colTimeSlots[6] = {'start': '14:00:00', 'end': '15:00:00'};
        colTimeSlots[7] = {'start': '15:00:00', 'end': '16:00:00'};
        colTimeSlots[8] = {'start': '16:00:00', 'end': '17:00:00'};
      }

      String currentDay = 'Sunday';
      String currentBatch = defaultBatch;

      final startRow = (headerRowIndex >= 0) ? headerRowIndex + 1 : 0;

      for (int r = startRow; r < sheet.maxRows; r++) {
        final row = sheet.rows[r];
        if (row.isEmpty) continue;

        // Check if day is specified in col 0 or 1
        for (int c = 0; c < 3 && c < row.length; c++) {
          final text = _cellString(row[c]);
          for (final day in daysList) {
            if (text.toLowerCase().contains(day.toLowerCase())) {
              currentDay = day;
              break;
            }
          }

          // Check batch identifier (e.g. 18B, 16B, Batch 18)
          final batchMatch = RegExp(r'\b(\d{1,2})[B]?\b', caseSensitive: false).firstMatch(text);
          if (batchMatch != null) {
            currentBatch = RoutineHelper.normalizeBatch(batchMatch.group(1));
          }
        }

        // Track afternoon lab span (2:00 to 5:00)
        DepartmentRoutineModel? activeAfternoonLab;

        for (final colIdx in colTimeSlots.keys) {
          if (colIdx >= row.length) continue;
          final cellText = _cellString(row[colIdx]);
          if (cellText.isEmpty) continue;

          final match = regex.firstMatch(cellText);
          if (match != null) {
            final courseCode = match.group(1)?.trim().toUpperCase() ?? '';
            final teacherInitial = match.group(2)?.trim().toUpperCase();
            final roomNumber = match.group(3)?.trim() ?? '903';
            final parityRaw = match.group(4)?.trim().toLowerCase();
            final parity = (parityRaw == 'odd' || parityRaw == 'even') ? parityRaw! : 'all';

            final slot = colTimeSlots[colIdx]!;
            final startTime = slot['start']!;
            final endTime = slot['end']!;

            // Lab Span Detection:
            // Afternoon slots between 14:00:00 and 17:00:00
            final isAfternoonSlot = startTime.compareTo('14:00:00') >= 0;
            final isLabCode = _isLabCourse(courseCode) || cellText.toLowerCase().contains('lab');

            if (isAfternoonSlot && isLabCode) {
              if (activeAfternoonLab == null) {
                activeAfternoonLab = DepartmentRoutineModel(
                  id: '${currentBatch}_${currentDay}_${courseCode}_$startTime',
                  batch: currentBatch,
                  dayOfWeek: currentDay,
                  startTime: '14:00:00',
                  endTime: '17:00:00',
                  courseCode: courseCode,
                  teacherInitial: teacherInitial,
                  roomNumber: roomNumber,
                  isLab: true,
                  weekParity: parity,
                  effectiveStartDate: DateTime(2026, 7, 15),
                );
              } else if (activeAfternoonLab.courseCode == courseCode) {
                // Already merged into 14:00 - 17:00
                continue;
              }
            } else {
              // Regular lecture slot
              results.add(DepartmentRoutineModel(
                id: '${currentBatch}_${currentDay}_${courseCode}_$startTime',
                batch: currentBatch,
                dayOfWeek: currentDay,
                startTime: startTime,
                endTime: endTime,
                courseCode: courseCode,
                teacherInitial: teacherInitial,
                roomNumber: roomNumber,
                isLab: isLabCode,
                weekParity: parity,
                effectiveStartDate: DateTime(2026, 7, 15),
              ));
            }
          }
        }

        if (activeAfternoonLab != null) {
          results.add(activeAfternoonLab);
        }
      }
    }

    return results;
  }

  static String _cellString(Data? cell) {
    if (cell == null || cell.value == null) return '';
    return cell.value.toString().trim();
  }

  static Map<String, String>? _matchTimeSlot(String header) {
    final clean = header.replaceAll(' ', '').toLowerCase();
    if (clean.contains('9:00-10:00') || clean.contains('09:00-10:00')) {
      return {'start': '09:00:00', 'end': '10:00:00'};
    } else if (clean.contains('10:00-11:00')) {
      return {'start': '10:00:00', 'end': '11:00:00'};
    } else if (clean.contains('11:00-12:00')) {
      return {'start': '11:00:00', 'end': '12:00:00'};
    } else if (clean.contains('12:00-1:00') || clean.contains('12:00-01:00') || clean.contains('12:00-13:00')) {
      return {'start': '12:00:00', 'end': '13:00:00'};
    } else if (clean.contains('2:00-3:00') || clean.contains('02:00-03:00') || clean.contains('14:00-15:00')) {
      return {'start': '14:00:00', 'end': '15:00:00'};
    } else if (clean.contains('3:00-4:00') || clean.contains('03:00-04:00') || clean.contains('15:00-16:00')) {
      return {'start': '15:00:00', 'end': '16:00:00'};
    } else if (clean.contains('4:00-5:00') || clean.contains('04:00-05:00') || clean.contains('16:00-17:00')) {
      return {'start': '16:00:00', 'end': '17:00:00'};
    }
    return null;
  }

  static bool _isLabCourse(String code) {
    final match = RegExp(r'\d+$').firstMatch(code);
    if (match != null) {
      final num = int.tryParse(match.group(0)!);
      if (num != null && num % 2 == 0) return true; // Even course number = Lab in ICE syllabus
    }
    return false;
  }

  /// Bulk publishes items to database
  Future<void> _publishRoutine() async {
    if (_parsedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No routine slots to publish. Upload or add slots first.'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    setState(() => _isPublishing = true);

    try {
      final tagged = _parsedItems.map((e) => e.copyWith(batch: _selectedBatch)).toList();
      await _routineService.publishRoutines(
        routines: tagged,
        clearExistingBatchRoutines: _clearExisting,
      );

      if (mounted) {
        setState(() => _isPublishing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🎉 Published ${_parsedItems.length} routine slots for $_selectedBatch successfully to Supabase!',
            ),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPublishing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Publish failed: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _editItemDialog(int index) {
    final item = _parsedItems[index];
    final courseCtrl = TextEditingController(text: item.courseCode);
    final teacherCtrl = TextEditingController(text: item.teacherInitial ?? '');
    final roomCtrl = TextEditingController(text: item.roomNumber ?? '903');
    final startCtrl = TextEditingController(text: item.startTime);
    final endCtrl = TextEditingController(text: item.endTime);
    String day = item.dayOfWeek;
    String parity = item.weekParity;
    bool isLab = item.isLab;

    String currentInit = (item.teacherInitial ?? '').trim().toUpperCase();
    bool isCustom = currentInit.isNotEmpty && !_facultyDirectory.containsKey(currentInit);
    String? selectedTeacher = isCustom
        ? '__CUSTOM__'
        : (currentInit.isNotEmpty ? currentInit : (_facultyDirectory.isNotEmpty ? _facultyDirectory.keys.first : null));
    if (!isCustom && selectedTeacher != null && teacherCtrl.text.isEmpty) {
      teacherCtrl.text = selectedTeacher;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Routine Slot'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(controller: courseCtrl, label: 'Course Code', hint: 'ICE-2203'),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selectedTeacher,
                  decoration: const InputDecoration(
                    labelText: 'Teacher / Faculty Initial',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    ..._facultyDirectory.entries.map((e) => DropdownMenuItem<String>(
                          value: e.key,
                          child: Text(
                            '${e.key} (${e.value})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                    const DropdownMenuItem<String>(
                      value: '__CUSTOM__',
                      child: Text('+ Custom / Other Initial...'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val == null) return;
                    setDialogState(() {
                      selectedTeacher = val;
                      if (val == '__CUSTOM__') {
                        isCustom = true;
                      } else {
                        isCustom = false;
                        teacherCtrl.text = val;
                      }
                    });
                  },
                ),
                if (isCustom) ...[
                  const SizedBox(height: 10),
                  AppTextField(
                    controller: teacherCtrl,
                    label: 'Custom Teacher Initial',
                    hint: 'MIH',
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 5,
                  ),
                ],
                const SizedBox(height: 12),
                AppTextField(controller: roomCtrl, label: 'Room Number', hint: '903'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: AppTextField(controller: startCtrl, label: 'Start Time', hint: '09:00:00')),
                    const SizedBox(width: 8),
                    Expanded(child: AppTextField(controller: endCtrl, label: 'End Time', hint: '10:00:00')),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: day,
                  decoration: const InputDecoration(labelText: 'Day of Week'),
                  items: RoutineHelper.academicDays
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => day = val);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: parity,
                  decoration: const InputDecoration(labelText: 'Week Parity'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Weeks (Regular)')),
                    DropdownMenuItem(value: 'odd', child: Text('Odd Weeks Only')),
                    DropdownMenuItem(value: 'even', child: Text('Even Weeks Only')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => parity = val);
                  },
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: isLab,
                  title: const Text('Is Laboratory Course', style: TextStyle(fontSize: 14)),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setDialogState(() => isLab = val ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _parsedItems.removeAt(index);
                });
                Navigator.pop(ctx);
              },
              child: const Text('Delete Slot', style: TextStyle(color: AppTheme.error)),
            ),
            ElevatedButton(
              onPressed: () {
                final resolvedInit = teacherCtrl.text.trim().toUpperCase();
                setState(() {
                  _parsedItems[index] = item.copyWith(
                    courseCode: courseCtrl.text.trim().toUpperCase(),
                    teacherInitial: resolvedInit,
                    teacherFullName: _facultyDirectory[resolvedInit] ?? resolvedInit,
                    roomNumber: roomCtrl.text.trim().isEmpty ? 'TBA' : roomCtrl.text.trim(),
                    startTime: startCtrl.text.trim(),
                    endTime: endCtrl.text.trim(),
                    dayOfWeek: day,
                    weekParity: parity,
                    isLab: isLab,
                  );
                });
                Navigator.pop(ctx);
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _addNewSlotDialog() {
    final courseCtrl = TextEditingController(text: 'ICE-');
    final teacherCtrl = TextEditingController();
    final roomCtrl = TextEditingController(text: '903');
    final startCtrl = TextEditingController(text: '09:00:00');
    final endCtrl = TextEditingController(text: '10:00:00');
    String day = 'Sunday';
    String parity = 'all';
    bool isLab = false;

    bool isCustom = false;
    String? selectedTeacher = _facultyDirectory.isNotEmpty ? _facultyDirectory.keys.first : null;
    if (selectedTeacher != null) {
      teacherCtrl.text = selectedTeacher;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Routine Slot'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(controller: courseCtrl, label: 'Course Code', hint: 'ICE-2203'),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selectedTeacher,
                  decoration: const InputDecoration(
                    labelText: 'Teacher / Faculty Initial',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    ..._facultyDirectory.entries.map((e) => DropdownMenuItem<String>(
                          value: e.key,
                          child: Text(
                            '${e.key} (${e.value})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                    const DropdownMenuItem<String>(
                      value: '__CUSTOM__',
                      child: Text('+ Custom / Other Initial...'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val == null) return;
                    setDialogState(() {
                      selectedTeacher = val;
                      if (val == '__CUSTOM__') {
                        isCustom = true;
                      } else {
                        isCustom = false;
                        teacherCtrl.text = val;
                      }
                    });
                  },
                ),
                if (isCustom) ...[
                  const SizedBox(height: 10),
                  AppTextField(
                    controller: teacherCtrl,
                    label: 'Custom Teacher Initial',
                    hint: 'MIH',
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 5,
                  ),
                ],
                const SizedBox(height: 12),
                AppTextField(controller: roomCtrl, label: 'Room Number', hint: '903'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: AppTextField(controller: startCtrl, label: 'Start Time', hint: '09:00:00')),
                    const SizedBox(width: 8),
                    Expanded(child: AppTextField(controller: endCtrl, label: 'End Time', hint: '10:00:00')),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: day,
                  decoration: const InputDecoration(labelText: 'Day of Week'),
                  items: RoutineHelper.academicDays
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => day = val);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: parity,
                  decoration: const InputDecoration(labelText: 'Week Parity'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Weeks (Regular)')),
                    DropdownMenuItem(value: 'odd', child: Text('Odd Weeks Only')),
                    DropdownMenuItem(value: 'even', child: Text('Even Weeks Only')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => parity = val);
                  },
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: isLab,
                  title: const Text('Is Laboratory Course', style: TextStyle(fontSize: 14)),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setDialogState(() => isLab = val ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final resolvedInit = teacherCtrl.text.trim().toUpperCase();
                final newModel = DepartmentRoutineModel(
                  id: 'manual_${DateTime.now().millisecondsSinceEpoch}',
                  batch: _selectedBatch,
                  dayOfWeek: day,
                  startTime: startCtrl.text.trim(),
                  endTime: endCtrl.text.trim(),
                  courseCode: courseCtrl.text.trim().toUpperCase(),
                  teacherInitial: resolvedInit,
                  teacherFullName: _facultyDirectory[resolvedInit] ?? resolvedInit,
                  roomNumber: roomCtrl.text.trim().isEmpty ? 'TBA' : roomCtrl.text.trim(),
                  weekParity: parity,
                  isLab: isLab,
                  effectiveStartDate: DateTime(2026, 7, 15),
                );
                setState(() => _parsedItems.add(newModel));
                Navigator.pop(ctx);
              },
              child: const Text('Add Slot'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
              boxShadow: AppTheme.softCardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.table_chart_outlined, color: AppTheme.accent, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Excel Academic Routine Parser & Dispatcher',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Import department XLSX timetable, audit parsed cells, verify lab spans & parity, and bulk publish.',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Controls Row
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Dynamic Target Batch Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Target Batch: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          DropdownButton<String>(
                            value: _availableBatches.contains(_selectedBatch)
                                ? _selectedBatch
                                : (_availableBatches.isNotEmpty ? _availableBatches.first : null),
                            underline: const SizedBox(),
                            items: _availableBatches.map((b) {
                              return DropdownMenuItem<String>(
                                value: b,
                                child: Text(b),
                              );
                            }).toList(),
                            onChanged: (newBatch) {
                              if (newBatch != null && newBatch != _selectedBatch) {
                                setState(() {
                                  _selectedBatch = newBatch;
                                  _parsedItems.clear();
                                  _uploadedFileName = null;
                                  _isLoadingBatch = true;
                                });
                                _listenToBatchRoutine(newBatch);
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                    // File Picker Button
                    ElevatedButton.icon(
                      onPressed: _isParsing ? null : _pickAndParseExcel,
                      icon: _isParsing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.upload_file, size: 18),
                      label: Text(_isParsing ? 'Parsing XLSX...' : 'Choose .xlsx File'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),

                    // Add Slot Button
                    OutlinedButton.icon(
                      onPressed: _addNewSlotDialog,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Slot Manually'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),

                    // Refresh Button
                    IconButton(
                      tooltip: 'Refresh routines for $_selectedBatch',
                      icon: const Icon(Icons.refresh, color: AppTheme.textSecondary, size: 20),
                      onPressed: () => _listenToBatchRoutine(_selectedBatch),
                    ),
                  ],
                ),

                if (_uploadedFileName != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppTheme.success, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Active File: $_uploadedFileName (${_parsedItems.length} slots loaded)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Interactive Review Section Header
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;
              return Flex(
                direction: isNarrow ? Axis.vertical : Axis.horizontal,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: isNarrow ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                children: [
                  const Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Interactive Schedule Review Table',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Tap any row to edit course code, room number, teacher initials, or odd/even parity.',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  if (isNarrow && _parsedItems.isNotEmpty) const SizedBox(height: 12),
                  if (_parsedItems.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: _isPublishing ? null : _publishRoutine,
                      icon: _isPublishing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.cloud_upload, size: 18),
                      label: Text(_isPublishing ? 'Publishing...' : 'Publish Routine (${_parsedItems.length})'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),

          // Table Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _isLoadingBatch
                  ? Padding(
                      padding: const EdgeInsets.all(50.0),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(color: AppTheme.accent),
                            const SizedBox(height: 16),
                            Text(
                              'Loading schedule for $_selectedBatch...',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _parsedItems.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.feed_outlined, size: 48, color: AppTheme.textMuted.withValues(alpha: 0.5)),
                                const SizedBox(height: 12),
                                Text(
                                  'No Routine Slots for $_selectedBatch',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Upload an Excel file (.xlsx) or tap "Add Slot Manually" to configure the schedule for $_selectedBatch.',
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                child: DataTable(
                        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                        columns: const [
                          DataColumn(label: Text('Day')),
                          DataColumn(label: Text('Time Slot')),
                          DataColumn(label: Text('Course Code')),
                          DataColumn(label: Text('Teacher')),
                          DataColumn(label: Text('Room')),
                          DataColumn(label: Text('Type')),
                          DataColumn(label: Text('Parity')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: _parsedItems.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final item = entry.value;

                          return DataRow(cells: [
                            DataCell(Text(item.dayOfWeek, style: const TextStyle(fontWeight: FontWeight.w600))),
                            DataCell(Text(RoutineHelper.formatTimeRange(item.startTime, item.endTime))),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(item.courseCode, style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                            DataCell(
                              Text(item.teacherInitial ?? 'TBA', style: const TextStyle(fontWeight: FontWeight.w600)),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('Room ${item.roomNumber ?? 'TBA'}', style: const TextStyle(fontSize: 12)),
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: item.isLab
                                      ? const Color(0xFF8B5CF6).withValues(alpha: 0.12)
                                      : AppTheme.success.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.isLab ? 'LAB (3h)' : 'Lecture',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: item.isLab ? const Color(0xFF8B5CF6) : AppTheme.success,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: item.weekParity == 'all'
                                      ? AppTheme.textMuted.withValues(alpha: 0.1)
                                      : (item.weekParity == 'odd'
                                          ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                                          : const Color(0xFF0284C7).withValues(alpha: 0.15)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.weekParity == 'all'
                                      ? 'All Weeks'
                                      : '${item.weekParity.toUpperCase()} Weeks',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: item.weekParity == 'all'
                                        ? AppTheme.textSecondary
                                        : (item.weekParity == 'odd' ? const Color(0xFFB45309) : const Color(0xFF0284C7)),
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    tooltip: 'Edit Slot',
                                    onPressed: () => _editItemDialog(idx),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                                    tooltip: 'Delete Slot',
                                    onPressed: () {
                                      setState(() => _parsedItems.removeAt(idx));
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ]);
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
