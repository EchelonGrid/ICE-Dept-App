// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/widgets.dart';

final Set<String> _registeredViewTypes = <String>{};

/// Native hardware-accelerated Web IFrame PDF Viewer implementation.
Widget buildWebPdfIframe({
  required String documentUrl,
  List<int>? fileBytes,
}) {
  final String effectiveSrc;
  if (fileBytes != null && fileBytes.isNotEmpty) {
    final blob = html.Blob([fileBytes], 'application/pdf');
    final blobUrl = html.Url.createObjectUrlFromBlob(blob);
    effectiveSrc = '$blobUrl#toolbar=1&navpanes=0';
  } else {
    effectiveSrc = '$documentUrl#toolbar=1&navpanes=0';
  }

  final viewType = 'pdf-native-view-${effectiveSrc.hashCode}';

  if (!_registeredViewTypes.contains(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = effectiveSrc
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = true;
      return iframe;
    });
    _registeredViewTypes.add(viewType);
  }

  return HtmlElementView(viewType: viewType);
}
