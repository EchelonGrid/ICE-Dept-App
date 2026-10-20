import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/qr_token_helper.dart';
import '../../services/attendance_service.dart';
import '../../widgets/app_button.dart';

class StudentQRScannerScreen extends StatefulWidget {
  const StudentQRScannerScreen({super.key});

  @override
  State<StudentQRScannerScreen> createState() => _StudentQRScannerScreenState();
}

class _StudentQRScannerScreenState extends State<StudentQRScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final AttendanceService _attendanceService = AttendanceService();

  bool _isProcessing = false;
  String? _statusMessage;
  bool _isSuccess = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final rawValue = barcode.rawValue!;
    final parsed = QRTokenHelper.parsePayload(rawValue);

    if (parsed == null) {
      setState(() {
        _statusMessage = 'Invalid QR Code format. Please scan the official ICE attendance screen.';
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Validating anti-proxy token with server...';
    });

    try {
      final classId = parsed['classId'] as String;
      final timestamp = parsed['timestamp'] as int;
      final token = parsed['token'] as String;

      final result = await _attendanceService.submitQRAttendance(
        classId: classId,
        qrTimestamp: timestamp,
        qrToken: token,
      );

      final success = result['success'] as bool? ?? false;
      final message = result['message'] as String? ?? 'Attendance processed';

      if (mounted) {
        setState(() {
          _isSuccess = success;
          _statusMessage = message;
          _isProcessing = false;
        });

        if (success) {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) Navigator.pop(context, true);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSuccess = false;
          _statusMessage = 'Submission failed: $e';
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Scan Attendance QR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _scannerController,
              builder: (context, state, child) {
                return Icon(
                  state.torchState == TorchState.on ? Icons.flash_on : Icons.flash_off,
                  color: Colors.white,
                );
              },
            ),
            onPressed: () => _scannerController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
            onPressed: () => _scannerController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _handleBarcode,
          ),

          // Custom Scanner Overlay
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _isProcessing ? AppTheme.accent : Colors.white.withValues(alpha: 0.8),
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),

          // Bottom Status Sheet
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isProcessing)
                    const CircularProgressIndicator()
                  else if (_statusMessage != null)
                    Row(
                      children: [
                        Icon(
                          _isSuccess ? Icons.check_circle : Icons.error_outline,
                          color: _isSuccess ? AppTheme.success : AppTheme.error,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _statusMessage!,
                            style: TextStyle(
                              color: _isSuccess ? AppTheme.success : AppTheme.error,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    const Column(
                      children: [
                        Text(
                          'Point camera at the Teacher\'s Live Screen',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Tokens refresh every 10s. Screenshots & proxies are rejected.',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  AppButton(
                    text: 'Close Scanner',
                    isOutlined: true,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
