import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class ShareIntentService {
  static final ShareIntentService instance = ShareIntentService._internal();
  ShareIntentService._internal();

  StreamSubscription<List<SharedMediaFile>>? _intentSub;
  GoRouter? _router;

  /// Initialize listening for incoming shared text / links
  void initialize(GoRouter router) {
    _router = router;

    // Platform guard: ReceiveSharingIntent is supported on Android & iOS
    if (kIsWeb || (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS)) {
      debugPrint('[ShareIntentService] Not on mobile platform, skipping native share intent listener.');
      return;
    }

    try {
      // 1. Listen for links while the app is running in memory / background
      _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
        (List<SharedMediaFile> files) {
          _handleSharedFiles(files);
        },
        onError: (err) {
          debugPrint('[ShareIntentService] Stream error: $err');
        },
      );

      // 2. Handle initial link when app was closed and launched via Share intent
      ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> files) {
        _handleSharedFiles(files);
      }).catchError((err) {
        debugPrint('[ShareIntentService] Initial media error: $err');
      });
    } catch (e) {
      debugPrint('[ShareIntentService] Initialization error: $e');
    }
  }

  void _handleSharedFiles(List<SharedMediaFile> files) {
    if (files.isEmpty) return;

    for (final file in files) {
      final sharedText = file.path.trim();
      if (sharedText.isNotEmpty) {
        debugPrint('[ShareIntentService] Received shared link/text: $sharedText');

        // Reset so the same intent is not consumed repeatedly
        ReceiveSharingIntent.instance.reset();

        // Route to /chat with sharedText parameter
        if (_router != null) {
          final uri = Uri(
            path: '/chat',
            queryParameters: {'sharedText': sharedText},
          );
          _router!.go(uri.toString(), extra: {'sharedText': sharedText});
        }
        break;
      }
    }
  }

  void dispose() {
    _intentSub?.cancel();
  }
}
