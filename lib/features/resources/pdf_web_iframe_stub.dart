import 'package:flutter/widgets.dart';

/// Stub implementation for non-web platforms (mobile & desktop).
Widget buildWebPdfIframe({
  required String documentUrl,
  List<int>? fileBytes,
}) {
  return const SizedBox.shrink();
}
