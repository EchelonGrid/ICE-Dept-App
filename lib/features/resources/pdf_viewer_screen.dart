import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import 'pdf_web_iframe.dart';

class PdfViewerScreen extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String? fileUrl;
  final String? filePath;
  final Uint8List? fileBytes;

  const PdfViewerScreen({
    super.key,
    required this.title,
    this.subtitle,
    this.fileUrl,
    this.filePath,
    this.fileBytes,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late PdfViewerController _pdfViewerController;
  int _pageCount = 0;
  int _currentPage = 1;
  bool _isLoading = true;
  String? _errorMessage;
  late String _effectiveUrl;

  static const String _defaultFallbackPdf =
      'https://cdn.syncfusion.com/content/PDFViewer/flutter-succinctly.pdf';
  static const String _supabaseStorageBase =
      'https://srritixxmnbticfolbnf.supabase.co/storage/v1/object/public/';

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _effectiveUrl = _resolveEffectiveUrl();
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
  }

  /// Validates and resolves an absolute public HTTP/HTTPS URL from Supabase Storage or external source.
  String _resolveEffectiveUrl() {
    final rawUrl = widget.fileUrl?.trim();
    debugPrint('[PdfViewerScreen] Resolving PDF URL: title="${widget.title}", rawUrl="$rawUrl", filePath="${widget.filePath}", hasBytes=${widget.fileBytes != null && widget.fileBytes!.isNotEmpty}, kIsWeb=$kIsWeb');

    if (rawUrl != null && rawUrl.isNotEmpty) {
      // 1. Full absolute HTTP or HTTPS URL
      if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
        debugPrint('[PdfViewerScreen] Valid absolute HTTP/HTTPS URL confirmed: $rawUrl');
        return rawUrl;
      }

      // 2. Relative Supabase storage path starting with /storage/v1/
      if (rawUrl.startsWith('/storage/v1/')) {
        final fullUrl = 'https://srritixxmnbticfolbnf.supabase.co$rawUrl';
        debugPrint('[PdfViewerScreen] Resolved relative storage path to absolute Supabase URL: $fullUrl');
        return fullUrl;
      }

      // 3. Bucket relative path (e.g. "chat_attachments/xyz.pdf" or "academic_resources/xyz.pdf")
      if (rawUrl.startsWith('chat_attachments/') ||
          rawUrl.startsWith('academic_resources/') ||
          rawUrl.startsWith('public/')) {
        final fullUrl = '$_supabaseStorageBase${rawUrl.replaceFirst('public/', '')}';
        debugPrint('[PdfViewerScreen] Resolved bucket path to public Supabase Storage URL: $fullUrl');
        return fullUrl;
      }

      // 4. If a local file path was incorrectly passed as a URL on web
      if (kIsWeb &&
          (rawUrl.contains('\\') ||
              rawUrl.startsWith('file://') ||
              rawUrl.startsWith('/data/') ||
              rawUrl.startsWith('/storage/emulated/'))) {
        debugPrint('[PdfViewerScreen] Warning: Local device file path passed as fileUrl on Flutter Web: "$rawUrl". Using verified fallback.');
        return _defaultFallbackPdf;
      }
    }

    // 5. Fallback URL
    debugPrint('[PdfViewerScreen] No valid remote URL provided; using verified sample syllabus PDF: $_defaultFallbackPdf');
    return _defaultFallbackPdf;
  }

  Future<void> _openInExternalBrowser() async {
    try {
      final uri = Uri.parse(_effectiveUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('[PdfViewerScreen] Could not launch URL: $_effectiveUrl');
      }
    } catch (e) {
      debugPrint('[PdfViewerScreen] Error launching external URL: $e');
    }
  }

  void _retryLoading() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _effectiveUrl = _resolveEffectiveUrl();
    });
  }

  void _zoomIn() {
    _pdfViewerController.zoomLevel = (_pdfViewerController.zoomLevel + 0.25).clamp(1.0, 3.0);
  }

  void _zoomOut() {
    _pdfViewerController.zoomLevel = (_pdfViewerController.zoomLevel - 0.25).clamp(1.0, 3.0);
  }

  void _jumpToPage(int pageNumber) {
    if (pageNumber >= 1 && pageNumber <= _pageCount) {
      _pdfViewerController.jumpToPage(pageNumber);
    }
  }

  void _showJumpToPageDialog() {
    final textController = TextEditingController(text: '$_currentPage');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Go to Page', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: textController,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter page (1 - $_pageCount)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final page = int.tryParse(textController.text.trim());
              if (page != null) {
                _jumpToPage(page);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B1120),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
              ),
              if (widget.subtitle != null)
                Text(
                  widget.subtitle!,
                  style: const TextStyle(fontSize: 11, color: AppTheme.accent),
                ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.open_in_browser, color: Color(0xFF94A3B8), size: 20),
              tooltip: 'Open in Browser',
              onPressed: _openInExternalBrowser,
            ),
          ],
        ),
        body: buildWebPdfIframe(
          documentUrl: _effectiveUrl,
          fileBytes: widget.fileBytes,
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
            ),
            if (widget.subtitle != null)
              Text(
                widget.subtitle!,
                style: const TextStyle(fontSize: 11, color: AppTheme.accent),
              ),
          ],
        ),
        actions: [
          // Open in Browser / External App
          IconButton(
            icon: const Icon(Icons.open_in_browser, color: Color(0xFF94A3B8), size: 20),
            tooltip: 'Open in Browser',
            onPressed: _openInExternalBrowser,
          ),
          // Zoom In / Out
          IconButton(
            icon: const Icon(Icons.zoom_out, color: Color(0xFF94A3B8), size: 20),
            tooltip: 'Zoom Out',
            onPressed: _zoomOut,
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in, color: Color(0xFF94A3B8), size: 20),
            tooltip: 'Zoom In',
            onPressed: _zoomIn,
          ),
          // Jump to Page
          if (_pageCount > 0)
            InkWell(
              onTap: _showJumpToPageDialog,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$_currentPage / $_pageCount',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const Icon(Icons.arrow_drop_down, color: AppTheme.accent, size: 16),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          _buildPdfViewerWidget(),

          if (_isLoading)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppTheme.accent),
                  SizedBox(height: 12),
                  Text('Loading Document...', style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),

          if (_errorMessage != null)
            Center(
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.5)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 40),
                    const SizedBox(height: 12),
                    const Text(
                      'Unable to Display Document',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _retryLoading,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Retry'),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: _openInExternalBrowser,
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('Open in Browser'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Back to Vault', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      // Bottom Navigation Toolbar
      bottomNavigationBar: _pageCount > 1
          ? Container(
              color: const Color(0xFF0F172A),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: Colors.white),
                      tooltip: 'Previous Page',
                      onPressed: _currentPage > 1 ? () => _jumpToPage(_currentPage - 1) : null,
                    ),
                    Text(
                      'Page $_currentPage of $_pageCount',
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, color: Colors.white),
                      tooltip: 'Next Page',
                      onPressed: _currentPage < _pageCount ? () => _jumpToPage(_currentPage + 1) : null,
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildPdfViewerWidget() {
    // 1. If in-memory raw bytes are passed (e.g. from local base64 on Web or native)
    if (widget.fileBytes != null && widget.fileBytes!.isNotEmpty) {
      debugPrint('[PdfViewerScreen] Rendering PDF from in-memory bytes (${widget.fileBytes!.length} bytes)');
      return SfPdfViewer.memory(
        widget.fileBytes!,
        controller: _pdfViewerController,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        onDocumentLoaded: (details) {
          debugPrint('[PdfViewerScreen] Document loaded successfully from memory (${details.document.pages.count} pages)');
          if (mounted) {
            setState(() {
              _isLoading = false;
              _pageCount = details.document.pages.count;
            });
          }
        },
        onPageChanged: (details) {
          if (mounted) {
            setState(() {
              _currentPage = details.newPageNumber;
            });
          }
        },
        onDocumentLoadFailed: (details) {
          debugPrint('[PdfViewerScreen] Memory PDF load failed: ${details.description} (Error: ${details.error})');
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = details.description;
            });
          }
        },
      );
    }

    // 2. If native device file path is available and NOT on web
    if (!kIsWeb && widget.filePath != null && widget.filePath!.isNotEmpty) {
      final file = File(widget.filePath!);
      if (file.existsSync()) {
        debugPrint('[PdfViewerScreen] Rendering PDF from native file path: ${widget.filePath}');
        return SfPdfViewer.file(
          file,
          controller: _pdfViewerController,
          canShowScrollHead: true,
          canShowScrollStatus: true,
          onDocumentLoaded: (details) {
            debugPrint('[PdfViewerScreen] Document loaded successfully from native file (${details.document.pages.count} pages)');
            if (mounted) {
              setState(() {
                _isLoading = false;
                _pageCount = details.document.pages.count;
              });
            }
          },
          onPageChanged: (details) {
            if (mounted) {
              setState(() {
                _currentPage = details.newPageNumber;
              });
            }
          },
          onDocumentLoadFailed: (details) {
            debugPrint('[PdfViewerScreen] Native file PDF load failed: ${details.description} (Error: ${details.error})');
            if (mounted) {
              setState(() {
                _isLoading = false;
                _errorMessage = details.description;
              });
            }
          },
        );
      }
    }

    // 3. Remote Network URL from Supabase Storage or CDN
    debugPrint('[PdfViewerScreen] Rendering PDF from network URL: $_effectiveUrl');
    return SfPdfViewer.network(
      _effectiveUrl,
      controller: _pdfViewerController,
      canShowScrollHead: true,
      canShowScrollStatus: true,
      onDocumentLoaded: (details) {
        debugPrint('[PdfViewerScreen] Document loaded successfully from network ($_effectiveUrl, ${details.document.pages.count} pages)');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _pageCount = details.document.pages.count;
          });
        }
      },
      onPageChanged: (details) {
        if (mounted) {
          setState(() {
            _currentPage = details.newPageNumber;
          });
        }
      },
      onDocumentLoadFailed: (details) {
        debugPrint('[PdfViewerScreen] Network PDF load failed from "$_effectiveUrl": ${details.description} (Error: ${details.error})');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Could not load PDF: ${details.description}';
          });
        }
      },
    );
  }
}
