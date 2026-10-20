import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/qr_token_helper.dart';

class DynamicQRSession extends ChangeNotifier {
  final String classId;
  final String courseName;
  
  Timer? _timer;
  String _currentPayload = '';
  int _secondsRemaining = AppConstants.qrRefreshIntervalSeconds;

  DynamicQRSession({
    required this.classId,
    required this.courseName,
  }) {
    _generateNextToken();
    _startTicker();
  }

  String get currentPayload => _currentPayload;
  int get secondsRemaining => _secondsRemaining;
  double get progressFraction => _secondsRemaining / AppConstants.qrRefreshIntervalSeconds;

  void _generateNextToken() {
    _currentPayload = QRTokenHelper.generateQRPayload(classId);
    _secondsRemaining = AppConstants.qrRefreshIntervalSeconds;
    notifyListeners();
  }

  void _startTicker() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        _secondsRemaining--;
        notifyListeners();
      } else {
        _generateNextToken();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
